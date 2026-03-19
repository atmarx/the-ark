#!/usr/bin/env bash
# ark-manifest.sh — YAML manifest parsing and resolution against the catalog
# Sourced by ark scripts. Requires ark-common.sh and ark-catalog.sh.

# ---------------------------------------------------------------------------
# Manifest parsing
# ---------------------------------------------------------------------------

# Get the loadout name from a manifest
ark_manifest_loadout() {
    local manifest="$1"
    yq -r '.loadout' "$manifest"
}

# Get the target size in GB from a manifest
ark_manifest_target_gb() {
    local manifest="$1"
    yq -r '.target_size_gb // 465' "$manifest"
}

# Get the description from a manifest
ark_manifest_description() {
    local manifest="$1"
    yq -r '.description // ""' "$manifest"
}

# Count ZIM entries in a manifest
ark_manifest_zim_count() {
    local manifest="$1"
    yq -r '.zim | length' "$manifest"
}

# Iterate ZIM entries. Calls a callback function with: index name flavour tier note
# Usage: ark_manifest_each_zim manifest.yml my_callback
ark_manifest_each_zim() {
    local manifest="$1"
    local callback="$2"
    local count
    count="$(ark_manifest_zim_count "$manifest")"

    local i
    for (( i = 0; i < count; i++ )); do
        local name flavour tier note prefix
        name="$(yq -r ".zim[$i].name // \"\"" "$manifest")"
        prefix="$(yq -r ".zim[$i].prefix // \"\"" "$manifest")"
        flavour="$(yq -r ".zim[$i].flavour // \"\"" "$manifest")"
        tier="$(yq -r ".zim[$i].tier // \"\"" "$manifest")"
        note="$(yq -r ".zim[$i].note // \"\"" "$manifest")"

        if [[ -n "$prefix" && -z "$name" ]]; then
            # Prefix entry: expand to all matching catalog entries
            # Callback signature stays the same; name is set from catalog
            "$callback" "$i" "PREFIX:$prefix" "$flavour" "$tier" "$note"
        else
            "$callback" "$i" "$name" "$flavour" "$tier" "$note"
        fi
    done
}

# Count PDF entries in a manifest
ark_manifest_pdf_count() {
    local manifest="$1"
    yq -r '.pdfs | length // 0' "$manifest"
}

# Iterate PDF entries. Calls callback with: index url filename
ark_manifest_each_pdf() {
    local manifest="$1"
    local callback="$2"
    local count
    count="$(ark_manifest_pdf_count "$manifest")"

    local i
    for (( i = 0; i < count; i++ )); do
        local url filename
        url="$(yq -r ".pdfs[$i].url" "$manifest")"
        filename="$(yq -r ".pdfs[$i].filename" "$manifest")"

        "$callback" "$i" "$url" "$filename"
    done
}

# Count archive entries in a manifest
ark_manifest_archive_count() {
    local manifest="$1"
    yq -r '.archives | length // 0' "$manifest"
}

# Iterate archive entries. Calls callback with: index id dest source note
ark_manifest_each_archive() {
    local manifest="$1"
    local callback="$2"
    local count
    count="$(ark_manifest_archive_count "$manifest")"

    local i
    for (( i = 0; i < count; i++ )); do
        local id dest source note
        id="$(yq -r ".archives[$i].id" "$manifest")"
        dest="$(yq -r ".archives[$i].dest // \"archives\"" "$manifest")"
        source="$(yq -r ".archives[$i].source // \"archive.org\"" "$manifest")"
        note="$(yq -r ".archives[$i].note // \"\"" "$manifest")"

        "$callback" "$i" "$id" "$dest" "$source" "$note"
    done
}

# Count ISO entries in a manifest
ark_manifest_iso_count() {
    local manifest="$1"
    yq -r '.isos | length // 0' "$manifest"
}

# Iterate ISO entries. Calls callback with: index torrent_url url archive_id note
ark_manifest_each_iso() {
    local manifest="$1"
    local callback="$2"
    local count
    count="$(ark_manifest_iso_count "$manifest")"

    local i
    for (( i = 0; i < count; i++ )); do
        local torrent_url url archive_id note
        torrent_url="$(yq -r ".isos[$i].torrent_url // \"\"" "$manifest")"
        url="$(yq -r ".isos[$i].url // \"\"" "$manifest")"
        archive_id="$(yq -r ".isos[$i].archive_id // \"\"" "$manifest")"
        note="$(yq -r ".isos[$i].note // \"\"" "$manifest")"

        "$callback" "$i" "$torrent_url" "$url" "$archive_id" "$note"
    done
}

# Get list of kiwix platforms to bundle
ark_manifest_kiwix_platforms() {
    local manifest="$1"
    yq -r '.kiwix_platforms[]? // empty' "$manifest"
}

# ---------------------------------------------------------------------------
# Resolution — cross-reference manifest against catalog
# ---------------------------------------------------------------------------

# Resolve all ZIM entries in a manifest against the catalog.
# For each entry, prints tab-separated:
#   status  name  flavour  meta4_url  size  date  filename
# where status is: ok | missing | outdated
#
# "ok" means we already have the latest version.
# "missing" means we don't have it at all.
# "outdated" means we have an older version.
# "unresolved" means the catalog doesn't have it.
ark_manifest_resolve() {
    local manifest="$1"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest")"

    local _resolve_callback
    # Resolve a single name against the catalog and emit status line
    _resolve_single() {
        local name="$1" flavour="$2"
        [[ -z "$flavour" ]] && flavour="-"

        local result
        if ! result="$(ark_catalog_resolve "$name" "$flavour")"; then
            printf "unresolved\t%s\t%s\t-\t0\t-\t-\n" "$name" "$flavour"
            return
        fi

        local meta4_url size date cat_name cat_flavour category
        IFS=$'\t' read -r meta4_url size date cat_name cat_flavour category <<< "$result"

        local filename
        filename="$(ark_catalog_meta4_to_filename "$meta4_url")"
        local file_date
        file_date="$(ark_catalog_filename_date "$filename")"
        local file_key="${loadout}/zim/${filename}"

        if ark_state_has "$file_key"; then
            local existing_date
            existing_date="$(ark_state_get "$file_key" ".date")"
            if [[ "$existing_date" == "$file_date" ]]; then
                printf "ok\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$flavour" "$meta4_url" "$size" "$file_date" "$filename"
            else
                printf "outdated\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$flavour" "$meta4_url" "$size" "$file_date" "$filename"
            fi
        else
            local staging
            staging="$(ark_staging_path)"
            if [[ -f "$staging/$file_key" ]]; then
                printf "ok\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$flavour" "$meta4_url" "$size" "$file_date" "$filename"
            else
                printf "missing\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$flavour" "$meta4_url" "$size" "$file_date" "$filename"
            fi
        fi
    }

    _resolve_callback() {
        local idx="$1" name="$2" flavour="$3" tier="$4" note="$5"

        # Handle prefix entries (expand to all matching catalog entries)
        if [[ "$name" == PREFIX:* ]]; then
            local prefix="${name#PREFIX:}"
            local entries
            entries="$(ark_catalog_resolve_prefix "$prefix")"
            if [[ -z "$entries" ]]; then
                printf "unresolved\t%s*\t-\t-\t0\t-\t-\n" "$prefix"
                return
            fi
            while IFS=$'\t' read -r meta4_url size date cat_name cat_flavour category; do
                _resolve_single "$cat_name" "$cat_flavour"
            done <<< "$entries"
            return
        fi

        _resolve_single "$name" "$flavour"
    }

    ark_manifest_each_zim "$manifest" _resolve_callback
}
