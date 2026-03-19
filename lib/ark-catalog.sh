#!/usr/bin/env bash
# ark-catalog.sh — OPDS catalog fetching, caching, and querying
# Sourced by ark scripts. Requires ark-common.sh to be loaded first.

# Atom/OPDS namespace prefix for xmlstarlet
readonly _ATOM_NS="a=http://www.w3.org/2005/Atom"

# ---------------------------------------------------------------------------
# Catalog fetching (paginated)
# ---------------------------------------------------------------------------

# Fetch the full OPDS catalog, paginating through all entries.
# Stores result in $ARK_STAGING/.ark/catalog-cache.xml
ark_catalog_fetch() {
    local staging
    staging="$(ark_staging_path)"
    local cache_dir="$staging/.ark"
    local cache_file="$cache_dir/catalog-cache.xml"
    local timestamp_file="$cache_dir/catalog-cache.timestamp"
    local page_size=100
    local start=0
    local total=-1
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    ark_info "Fetching OPDS catalog from ${ARK_CATALOG_URL}..."

    # Paginate through the catalog
    local page=0
    while true; do
        local url="${ARK_CATALOG_URL}?count=${page_size}&start=${start}"
        local page_file="$tmp_dir/page_${page}.xml"

        if ! curl -sL --fail -o "$page_file" "$url"; then
            rm -rf "$tmp_dir"
            ark_die "Failed to fetch catalog page at start=$start"
        fi

        # Get total on first page
        if (( total < 0 )); then
            total="$(xmlstarlet sel -N "$_ATOM_NS" \
                -t -v '/a:feed/a:totalResults' "$page_file" 2>/dev/null || echo 0)"
            if (( total == 0 )); then
                rm -rf "$tmp_dir"
                ark_die "Catalog returned 0 results — check ARK_CATALOG_URL"
            fi
            ark_info "Catalog has $total entries, fetching..."
        fi

        # Count entries in this page
        local count
        count="$(xmlstarlet sel -N "$_ATOM_NS" \
            -t -v 'count(/a:feed/a:entry)' "$page_file" 2>/dev/null || echo 0)"

        start=$(( start + page_size ))
        page=$(( page + 1 ))

        # Progress
        local pct=$(( start * 100 / total ))
        (( pct > 100 )) && pct=100
        printf "\r  %d%% (%d/%d entries)" "$pct" "$start" "$total" >&2

        if (( count < page_size )) || (( start >= total )); then
            break
        fi
    done
    echo >&2

    # Merge all pages into a single XML file.
    # Extract <entry> blocks from each page and strip Atom namespace so we can
    # query with plain XPath (no namespace prefixes needed).
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo "<catalog totalResults=\"$total\" fetched=\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\">"

        for f in "$tmp_dir"/page_*.xml; do
            xmlstarlet sel -N "$_ATOM_NS" \
                -t -c '/a:feed/a:entry' "$f" 2>/dev/null || true
        done

        echo '</catalog>'
    } | sed 's/ xmlns="[^"]*"//g; s/ xmlns:[a-z]*="[^"]*"//g; s/<dc:[^>]*>[^<]*<\/dc:[^>]*>//g' > "$cache_file"

    # Timestamp
    date -u +%s > "$timestamp_file"

    rm -rf "$tmp_dir"
    local entry_count
    entry_count="$(xmlstarlet sel -t -v 'count(/catalog/entry)' "$cache_file" 2>/dev/null || echo 0)"
    ark_ok "Catalog cached: $entry_count entries -> $cache_file"
}

# Check if catalog cache exists and is fresh enough
ark_catalog_is_fresh() {
    local staging
    staging="$(ark_staging_path)"
    local timestamp_file="$staging/.ark/catalog-cache.timestamp"
    local cache_file="$staging/.ark/catalog-cache.xml"

    [[ -f "$cache_file" ]] || return 1
    [[ -f "$timestamp_file" ]] || return 1

    local cached_at now max_age_secs
    cached_at="$(cat "$timestamp_file")"
    now="$(date -u +%s)"
    max_age_secs=$(( ARK_CATALOG_MAX_AGE * 3600 ))

    (( (now - cached_at) < max_age_secs ))
}

# Ensure catalog is available, fetching if stale/missing
ark_catalog_ensure() {
    local force="${1:-false}"
    if [[ "$force" == "true" ]] || ! ark_catalog_is_fresh; then
        ark_catalog_fetch
    else
        ark_dim "  Catalog cache is fresh (max age: ${ARK_CATALOG_MAX_AGE}h)"
    fi
}

# ---------------------------------------------------------------------------
# Catalog querying
# ---------------------------------------------------------------------------

# Get path to the cached catalog file
_ark_catalog_file() {
    local staging
    staging="$(ark_staging_path)"
    local f="$staging/.ark/catalog-cache.xml"
    [[ -f "$f" ]] || ark_die "No catalog cache found. Run 'ark sync' or 'ark catalog refresh'."
    echo "$f"
}

# Resolve a ZIM entry by name + flavour.
# Returns tab-separated: url  size  date  name  flavour  category
# The URL points to the .meta4 — strip .meta4 for direct download.
# If multiple versions exist, returns the most recent (latest date in URL).
ark_catalog_resolve() {
    local name="$1"
    local flavour="${2:-}"
    # Treat "-" placeholder as empty
    [[ "$flavour" == "-" ]] && flavour=""
    local catalog
    catalog="$(_ark_catalog_file)"

    local results
    if [[ -n "$flavour" ]]; then
        results="$(xmlstarlet sel \
            -t -m "//entry[name='$name'][flavour='$flavour']" \
            -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@href" -o $'\t' \
            -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -o $'\t' \
            -v "updated" -o $'\t' \
            -v "name" -o $'\t' \
            -v "flavour" -o $'\t' \
            -v "category" -n \
            "$catalog" 2>/dev/null)"
    else
        # No flavour specified — match entries with empty or missing flavour
        results="$(xmlstarlet sel \
            -t -m "//entry[name='$name'][flavour='' or not(flavour)]" \
            -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@href" -o $'\t' \
            -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -o $'\t' \
            -v "updated" -o $'\t' \
            -v "name" -o $'\t' \
            -v "flavour" -o $'\t' \
            -v "category" -n \
            "$catalog" 2>/dev/null)"

        # If no results with empty flavour, try matching any flavour
        if [[ -z "$results" ]]; then
            results="$(xmlstarlet sel \
                -t -m "//entry[name='$name']" \
                -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@href" -o $'\t' \
                -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -o $'\t' \
                -v "updated" -o $'\t' \
                -v "name" -o $'\t' \
                -v "flavour" -o $'\t' \
                -v "category" -n \
                "$catalog" 2>/dev/null)"
        fi
    fi

    if [[ -z "$results" ]]; then
        return 1
    fi

    # Replace empty tab-delimited fields with "-" so IFS=$'\t' read works correctly
    # (bash read collapses consecutive delimiters, losing empty fields)
    # Then take the latest version by date.
    echo "$results" | sed 's/\t\t/\t-\t/g; s/\t\t/\t-\t/g; s/\t$/\t-/' \
        | sort -t$'\t' -k3 -r | head -1
}

# Resolve all catalog entries matching a name prefix.
# Returns one line per entry (tab-separated): url  size  date  name  flavour  category
# Used for "prefix:" manifest entries (e.g., devdocs_en_ matches all devdocs).
ark_catalog_resolve_prefix() {
    local prefix="$1"
    local catalog
    catalog="$(_ark_catalog_file)"

    xmlstarlet sel \
        -t -m "//entry[starts-with(name,'$prefix')]" \
        -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@href" -o $'\t' \
        -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -o $'\t' \
        -v "updated" -o $'\t' \
        -v "name" -o $'\t' \
        -v "flavour" -o $'\t' \
        -v "category" -n \
        "$catalog" 2>/dev/null \
        | sed 's/\t\t/\t-\t/g; s/\t\t/\t-\t/g; s/\t$/\t-/'
}

# Search catalog by free text (matches name, title, summary)
# Returns tab-separated lines: name  flavour  size  date  title
ark_catalog_search() {
    local query="$1"
    local catalog
    catalog="$(_ark_catalog_file)"

    # Case-insensitive search across name, title, summary
    # xmlstarlet doesn't have case-insensitive contains, so we use translate()
    local query_lower
    query_lower="$(echo "$query" | tr '[:upper:]' '[:lower:]')"

    xmlstarlet sel \
        -t -m "//entry[contains(translate(name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'$query_lower') or contains(translate(title,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'$query_lower') or contains(translate(summary,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'$query_lower')]" \
        -v "name" -o $'\t' \
        -v "flavour" -o $'\t' \
        -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -o $'\t' \
        -v "updated" -o $'\t' \
        -v "title" -n \
        "$catalog" 2>/dev/null \
        | sed 's/\t\t/\t-\t/g; s/\t\t/\t-\t/g' \
        | sort -t$'\t' -k1,1
}

# List catalog entries, optionally filtered by category or language
ark_catalog_list() {
    local category="${1:-}"
    local lang="${2:-}"
    local catalog
    catalog="$(_ark_catalog_file)"

    local xpath="//entry"
    if [[ -n "$category" && -n "$lang" ]]; then
        xpath="//entry[category='$category'][language='$lang']"
    elif [[ -n "$category" ]]; then
        xpath="//entry[category='$category']"
    elif [[ -n "$lang" ]]; then
        xpath="//entry[language='$lang']"
    fi

    xmlstarlet sel \
        -t -m "$xpath" \
        -v "name" -o $'\t' \
        -v "flavour" -o $'\t' \
        -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -o $'\t' \
        -v "updated" -o $'\t' \
        -v "title" -n \
        "$catalog" 2>/dev/null \
        | sed 's/\t\t/\t-\t/g; s/\t\t/\t-\t/g' \
        | sort -t$'\t' -k1,1
}

# Extract the direct download URL from a meta4 href
# Input:  https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2026-02.zim.meta4
# Output: https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2026-02.zim
ark_catalog_meta4_to_url() {
    local meta4_url="$1"
    echo "${meta4_url%.meta4}"
}

# Extract the ZIM filename from a meta4 URL
# Input:  https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2026-02.zim.meta4
# Output: wikipedia_en_all_maxi_2026-02.zim
ark_catalog_meta4_to_filename() {
    local meta4_url="$1"
    local without_meta4="${meta4_url%.meta4}"
    basename "$without_meta4"
}

# Extract the date portion from a ZIM filename
# Input:  wikipedia_en_all_maxi_2026-02.zim
# Output: 2026-02
ark_catalog_filename_date() {
    local filename="$1"
    # Date is always YYYY-MM just before .zim
    echo "$filename" | sed -E 's/.*_([0-9]{4}-[0-9]{2})\.zim$/\1/'
}
