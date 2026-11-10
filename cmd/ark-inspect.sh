#!/usr/bin/env bash
# ark-inspect.sh — read an old Ark and compare it with the catalog.  Never
# writes to the drive.  With --record, what it saw goes in the ledger.

# A build that loses more than this share of its articles is SHRANK, not
# UPDATE.  Wikisource 2026-09 lost 81%; a healthy site loses far under 1%.
ARK_SHRINK_PCT="${ARK_SHRINK_PCT:-1}"

ark_inspect() {
    local mount="" record=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --record) record=true ;;
            -*)       ark_die "Unknown flag: $1" ;;
            *)        mount="$1" ;;
        esac
        shift
    done

    if [[ -z "$mount" ]]; then
        cat <<'EOF'
Usage: ark inspect <mounted-drive> [--record]

Reads an old Ark and compares each ZIM with the catalog's newest build.
Mount the drive read-only first.  In a Za Wiper bay: bayd browse <bay>,
then /mnt/zawiper/<bay>/part1.

  SAME     the catalog's newest is this build
  UPDATE   a newer build, with as many articles or within ARK_SHRINK_PCT
  SHRANK   a newer build lost articles.  The drive's copy may be the better one
  GONE     not in the catalog under this name: renamed, or withdrawn
  UNREAD   the ZIM wouldn't open: truncated or damaged

--record adds every build it saw, on the drive and in the catalog, to
.ark/ledger.tsv in staging.  The ledger only grows.
EOF
        return 1
    fi

    [[ -d "$mount" ]] || ark_die "Not a directory: $mount"

    ark_load_config
    ark_catalog_ensure

    local python="$ARK_ROOT/.venv/bin/python"
    if [[ ! -x "$python" ]] || ! "$python" -c 'import libzim' 2>/dev/null; then
        ark_die "Article counts need libzim: python3 -m venv '$ARK_ROOT/.venv' && '$ARK_ROOT/.venv/bin/pip' install libzim"
    fi

    local catalog
    catalog="$(ark_staging_path)/.ark/catalog-cache.xml"
    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    # What the drive says about itself
    ark_bold "Inspecting: $mount"
    if [[ -f "$mount/README.txt" ]]; then
        local loadout frozen
        loadout="$(sed -n 's/^Loadout: *//p' "$mount/README.txt" | head -1)"
        frozen="$(grep -oE 'as of [0-9]{4}-[0-9]{2}-[0-9]{2}' "$mount/README.txt" | head -1 | cut -c7-)"
        ark_info "Loadout: ${loadout:-unknown}, frozen ${frozen:-at an unknown date}"
    else
        ark_warn "No README.txt.  This may not be an Ark."
    fi
    if [[ -f "$mount/LOGBOOK.txt" ]]; then
        ark_info "Logbook: $(grep -c '^Entry ' "$mount/LOGBOOK.txt") entries"
    fi
    echo

    # The catalog's newest build of each name: key, build, articles, bytes
    xmlstarlet sel -t -m '//entry' \
        -v 'link[contains(@href, ".zim")]/@href' -o $'\t' \
        -v 'articleCount' -o $'\t' \
        -v 'link[contains(@href, ".zim")]/@length' -n "$catalog" \
        | sed -E 's#^[^\t]*/([^/\t]+)_([0-9]{4}-[0-9]{2})\.zim\.meta4\t#\1\t\2\t#' \
        | grep -E '^[^/	]+	[0-9]{4}-[0-9]{2}	' | sort -t $'\t' -k1,1 > "$tmp/catalog.tsv"

    # The drive's ZIMs.  Opening one reads its header and indexes, not every
    # byte, so UNREAD catches a truncated file, and a clean run isn't a checksum.
    find "$mount" -type f -name '*.zim' -print0 > "$tmp/zims"
    local total
    total="$(tr -cd '\0' < "$tmp/zims" | wc -c)"
    (( total > 0 )) || ark_die "No ZIMs under $mount"
    ark_info "Reading $total ZIMs..."
    xargs -0 "$python" -I "$ARK_ROOT/lib/ark-zimcount.py" < "$tmp/zims" 2>/dev/null > "$tmp/counts.tsv"

    local path count file key build size
    while IFS=$'\t' read -r path count; do
        file="${path##*/}"
        key="${file%_*}"
        build="$(ark_catalog_filename_date "$file")"
        size="$(stat -c %s "$path")"
        printf '%s\t%s\t%s\t%s\n' "$key" "$build" "$count" "$size"
    done < "$tmp/counts.tsv" | sort -t $'\t' -k1,1 > "$tmp/drive.tsv"

    join -t $'\t' -a 1 -e - -o 1.1,1.2,1.3,1.4,2.2,2.3,2.4 "$tmp/drive.tsv" "$tmp/catalog.tsv" \
        | awk -F'\t' -v OFS='\t' -v pct="$ARK_SHRINK_PCT" '{
            if ($3 == "-")                status = "UNREAD"
            else if ($5 == "-")           status = "GONE"
            else if ($5 <= $2)            status = "SAME"
            else if ($6 + 0 < $3 * (1 - pct / 100)) status = "SHRANK"
            else                          status = "UPDATE"
            print status, $0
        }' > "$tmp/report.tsv"

    # The ones a person should look at, worst first
    local flagged
    flagged="$(awk -F'\t' '$1 == "SHRANK" {
        printf "%.4f\t%s\n", $7 / $4 - 1, $0 }' "$tmp/report.tsv" | sort -n | cut -f2-)"
    if [[ -n "$flagged" ]]; then
        ark_bold "Newer builds with fewer articles.  The drive may hold what's gone:"
        echo "$flagged" | awk -F'\t' '{
            printf "  %-44s %s %10d -> %s %10d  %+6.1f%%\n", $2, $3, $4, $6, $7, ($7 / $4 - 1) * 100 }'
        echo
    fi
    if grep -q '^GONE' "$tmp/report.tsv"; then
        ark_bold "Not in the catalog under this name (renamed, or withdrawn):"
        awk -F'\t' '$1 == "GONE" { printf "  %-44s %s %10d\n", $2, $3, $4 }' "$tmp/report.tsv"
        echo
    fi
    if grep -q '^UNREAD' "$tmp/report.tsv"; then
        ark_bold "Wouldn't open:"
        awk -F'\t' '$1 == "UNREAD" { printf "  %s_%s.zim\n", $2, $3 }' "$tmp/report.tsv"
        echo
    fi

    ark_bold "Summary"
    local status
    for status in SAME UPDATE SHRANK GONE UNREAD; do
        printf '  %-8s %d\n' "$status" "$(grep -c "^$status" "$tmp/report.tsv" || true)"
    done
    local grow
    grow="$(awk -F'\t' '$1 == "UPDATE" { d += $8 - $5 } END { printf "%d", d }' "$tmp/report.tsv")"
    if (( grow < 0 )); then
        echo "  Taking every UPDATE frees $(ark_human_bytes $(( -grow )))."
    else
        echo "  Taking every UPDATE needs $(ark_human_bytes "$grow") more."
    fi
    echo "  Free now: $(df --output=avail -B1 "$mount" | tail -1 | tr -d '[:space:]' | { read -r b; ark_human_bytes "$b"; })"
    if [[ -f "$mount/DELETE_THIS_IF_YOU_NEED_SPACE" ]]; then
        echo "  Ballast:  $(ark_human_bytes "$(stat -c %s "$mount/DELETE_THIS_IF_YOU_NEED_SPACE")") (DELETE_THIS_IF_YOU_NEED_SPACE)"
    fi

    if $record; then
        ark_inspect_record "$tmp/drive.tsv" "$tmp/report.tsv" "${frozen:-unknown}"
    fi
}

# The ledger: one line per build ever seen, first sighting wins.
# key, build, articles, bytes, where it was seen, the date of that sighting.
ark_inspect_record() {
    local drive="$1" report="$2" frozen="$3"
    local ledger today
    ledger="$(ark_staging_path)/.ark/ledger.tsv"
    today="$(date +%F)"

    {
        [[ -f "$ledger" ]] && cat "$ledger"
        awk -F'\t' -v OFS='\t' -v d="$today" -v f="$frozen" '$3 != "-" {
            print $1, $2, $3, $4, "ark-drive:" f, d }' "$drive"
        awk -F'\t' -v OFS='\t' -v d="$today" '$6 != "-" {
            print $2, $6, $7, $8, "catalog", d }' "$report"
    } | awk -F'\t' '!seen[$1 FS $2]++' > "$ledger.tmp"
    mv "$ledger.tmp" "$ledger"
    ark_ok "Ledger: $(wc -l < "$ledger") builds in $ledger"
}
