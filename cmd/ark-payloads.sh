#!/usr/bin/env bash
# ark-payloads.sh — publish loadouts as payloads for Za Wiper's Wipe + Load.
#
# Builds $ARK_STAGING/payloads/: a folder per loadout, laid out as a drive
# should be, all symlinks but the few files made here, and a payloads.txt
# listing each with its SHA-256.  ZAWIPER_PAYLOADS points at that folder.
#
# Hashing 870 GB over NFS takes hours the first time.  ZIMs never change under
# a name, so .ark/sha256-cache.tsv keeps the answers for next time.

ark_payloads() {
    local dry_run=false loadouts=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            -*)        ark_die "Unknown flag: $1" ;;
            *)         loadouts+=("$1") ;;
        esac
        shift
    done
    if (( ${#loadouts[@]} == 0 )); then
        cat <<'EOF'
Usage: ark payloads <loadout>... [--dry-run]

Publishes loadouts for Za Wiper's Wipe + Load, replacing payloads.txt with
exactly the loadouts you name.  Biggest fits-first picking is Za Wiper's job.

  ark payloads mini medium mega

Then set ZAWIPER_PAYLOADS=$ARK_STAGING/payloads in the hub's .env.  Its
symlinks point into staging and the download store, so those need mounting at
the same paths in the hub's compose.override.yml.
EOF
        return 1
    fi

    ark_load_config
    local staging root
    staging="$(ark_staging_path)"
    root="$staging/payloads"

    local out loadout manifest_file
    out="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$out'" RETURN
    for loadout in "${loadouts[@]}"; do
        manifest_file="$(ark_resolve_manifest "$loadout")"
        ark_manifest_is_pack "$manifest_file" && ark_die "'$loadout' is an expansion pack.  Payloads are whole loadouts."
        ark_payload_farm "$manifest_file" "$root" "$staging"
        ark_payload_list "$manifest_file" "$root" "$staging" "$dry_run" >> "$out"
        echo >> "$out"
    done

    if $dry_run; then
        ark_info "Dry run: nothing hashed.  $(grep -c '^  file' "$out") files, and the farm is built at $root."
        return 0
    fi
    mkdir -p "$root"
    mv "$out" "$root/payloads.txt.tmp"
    mv "$root/payloads.txt.tmp" "$root/payloads.txt"
    ark_ok "Wrote $root/payloads.txt"
}

# The ZIMs a loadout's manifest asks for: the newest staged build of each
# name, so a drive gets one Wikipedia.  What's staged is what's meant: a held
# build stays newest until a newer one is downloaded on purpose.  A loadout's
# staging holds more than its manifest, so names not in it are left off, the
# way stamp's filter does.  Prints paths relative to zim/: DevDocs live in
# zim/devdocs/, and a drive keeps them there.  Entries with nothing staged
# go to stderr.
ark_payload_newest_zims() {
    local manifest_file="$1" zimdir="$2"
    awk -F'\t' -v OFS='\t' '
        NR == FNR {
            if ($3 != "")      prefix[$3] = 1
            else if ($1 != "") want[$1 ($2 != "" ? "_" $2 : "")] = 1
            next
        }
        {
            hit = ($1 in want)
            if (hit) got[$1] = 1
            else for (p in prefix) if (index($1, p) == 1) { hit = 1; got[p] = 1; break }
            if (hit && !seen[$1]++) print $NF
        }
        END {
            for (k in want)   if (!(k in got)) print "ark: nothing staged for " k > "/dev/stderr"
            for (p in prefix) if (!(p in got)) print "ark: nothing staged for " p "*" > "/dev/stderr"
        }' \
        <(yq -r '.zim[] | [.name // "", .flavour // "", .prefix // ""] | @tsv' "$manifest_file") \
        <(find -L "$zimdir" -name torrents -prune -o -type f -name '*.zim' -printf '%P\n' \
            | sed -E 's#^((.*/)?([^/]*)_([0-9]{4}-[0-9]{2})\.zim)$#\3\t\4\t\1#' \
            | sort -t $'\t' -k1,1 -k2,2r)
}

# The folder a loadout's drive is copied from.
ark_payload_farm() {
    local manifest_file="$1" root="$2" staging="$3"
    local loadout description source_dir farm
    loadout="$(ark_manifest_loadout "$manifest_file")"
    description="$(ark_manifest_description "$manifest_file")"
    source_dir="$staging/$loadout"
    farm="$root/$loadout"
    [[ -d "$source_dir/zim" ]] || ark_die "Nothing staged for $loadout: $source_dir/zim.  Run 'ark sync $loadout' first."

    rm -rf "$farm"
    mkdir -p "$farm/zim" "$farm/data"

    local zim zim_count=0
    while IFS= read -r zim; do
        mkdir -p "$farm/zim/$(dirname "$zim")"
        ln -s "$(realpath "$source_dir/zim/$zim")" "$farm/zim/$zim"
        zim_count=$(( zim_count + 1 ))
    done < <(ark_payload_newest_zims "$manifest_file" "$source_dir/zim")

    # Everything else in the loadout goes as it is.
    local entry name
    for entry in "$source_dir"/*; do
        name="${entry##*/}"
        [[ "$name" == "zim" ]] && continue
        ln -s "$(realpath "$entry")" "$farm/$name"
    done

    local sites data_dir
    sites="$(ark_sites_dir)"
    data_dir="$(ark_data_dir)"
    [[ -d "$sites" && ! -e "$farm/sites" ]] && ln -s "$(realpath "$sites")" "$farm/sites"
    if [[ -d "$data_dir" ]]; then
        for entry in "$data_dir"/*; do
            [[ -e "$entry" ]] && ln -s "$(realpath "$entry")" "$farm/data/${entry##*/}"
        done
    fi

    # Kiwix's portable mode: its Windows reader at the root, and a library.
    local win_zip
    win_zip="$(find -L "$farm/kiwix" -name '*windows*.zip' -print -quit 2>/dev/null || true)"
    if [[ -n "$win_zip" ]]; then
        unzip -qo "$win_zip" -d "$farm" 2>/dev/null || ark_warn "Couldn't unpack $win_zip for portable mode"
    fi
    : > "$farm/.portable"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<library version="20110515">'
        while IFS= read -r zim; do
            printf '  <book path="../zim/%s" id="%s" />\n' "$zim" "$(basename "$zim" .zim)"
        done < <(find "$farm/zim" -mindepth 1 \( -type l -o -type f \) -printf '%P\n' | sort)
        echo '</library>'
    } > "$farm/data/library.xml"

    local total_size
    total_size="$(du -shL "$farm" 2>/dev/null | awk '{print $1}')"
    sed -e "s|{{LOADOUT}}|$loadout|g" \
        -e "s|{{DESCRIPTION}}|$description|g" \
        -e "s|{{DATE}}|$(date +%F)|g" \
        -e "s|{{ZIM_COUNT}}|$zim_count|g" \
        -e "s|{{TOTAL_SIZE}}|$total_size|g" \
        "$ARK_ROOT/templates/README.txt.tmpl" > "$farm/README.txt"
    ark_info "$loadout: $zim_count ZIMs, $total_size"
}

# The set, as payloads.txt holds it.  Stdout is the file; words go to stderr.
ark_payload_list() {
    local manifest_file="$1" root="$2" staging="$3" dry_run="$4"
    local loadout description farm cache
    loadout="$(ark_manifest_loadout "$manifest_file")"
    description="$(ark_manifest_description "$manifest_file")"
    farm="$root/$loadout"
    cache="$staging/.ark/sha256-cache.tsv"
    [[ -f "$cache" ]] || : > "$cache"

    printf 'set %s\n  description %s\n  label THE-ARK\n  filesystem exfat\n  root %s\n' "$loadout" "$description" "$loadout"

    local rel size sum real mtime key n=0 total
    total="$(find -L "$farm" -type f | wc -l)"
    while IFS= read -r rel; do
        n=$(( n + 1 ))
        case "$rel" in
            *[\"\*:\<\>\?\\\|]*)
                ark_die "$rel has a character exFAT can't hold.  Rename it, or Za Wiper will refuse the whole file." ;;
        esac
        real="$(realpath "$farm/$rel")"
        size="$(stat -Lc %s "$farm/$rel")"
        if [[ "$dry_run" == "true" ]]; then
            sum="$(printf '%064d' 0)"
        else
            mtime="$(stat -Lc %Y "$farm/$rel")"
            key="$real"$'\t'"$size"$'\t'"$mtime"
            sum="$(awk -F'\t' -v k="$key" '$1 FS $2 FS $3 == k { print $4; exit }' "$cache")"
            if [[ -z "$sum" ]]; then
                echo "  hashing $n/$total: $rel" >&2
                sum="$(sha256sum "$real" | cut -d' ' -f1)"
                # Files made here change with every run; only keep the rest.
                [[ "$real" == "$farm"/* ]] || printf '%s\t%s\n' "$key" "$sum" >> "$cache"
            fi
        fi
        printf '  file %s  %s  %s\n' "$sum" "$size" "$rel"
    done < <(cd "$farm" && find -L . -type f -printf '%P\n' | LC_ALL=C sort)
}
