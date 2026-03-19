#!/usr/bin/env bash
# ark-publish.sh — create torrents of completed loadouts for distribution

ark_publish() {
    local manifest_arg="${1:-}"
    local output_dir="${2:-}"

    if [[ -z "$manifest_arg" ]]; then
        cat <<'EOF'
Usage: ark publish <loadout|manifest.yml> [output-dir]

Creates .torrent files for each ZIM in a loadout, plus one for the
entire loadout directory. Output defaults to $ARK_STAGING/.ark/torrents/.

Options:
  --tracker=URL    Add a tracker announce URL (can be repeated)
  --webseed=URL    Add a webseed URL (can be repeated)
  --comment=TEXT   Set torrent comment

Examples:
  ark publish medium
  ark publish medium /tmp/torrents --tracker=udp://tracker.example.com:6969
  ark publish medium --webseed=https://myserver.com/ark/medium/
EOF
        return 1
    fi

    ark_require_cmd transmission-create "creating torrents"
    ark_load_config

    # Parse flags
    local trackers=()
    local webseeds=()
    local comment="The Knowledge Ark — offline human knowledge archive"
    local args=()

    for arg in "$@"; do
        case "$arg" in
            --tracker=*)  trackers+=("${arg#--tracker=}") ;;
            --webseed=*)  webseeds+=("${arg#--webseed=}") ;;
            --comment=*)  comment="${arg#--comment=}" ;;
            *)            args+=("$arg") ;;
        esac
    done

    manifest_arg="${args[0]:-$manifest_arg}"
    output_dir="${args[1]:-}"

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"

    local staging
    staging="$(ark_staging_path)"
    local loadout_dir="$staging/$loadout"

    if [[ ! -d "$loadout_dir/zim" ]]; then
        ark_die "Loadout directory not found: $loadout_dir/zim — run 'ark sync $manifest_arg' first"
    fi

    # Default output dir
    if [[ -z "$output_dir" ]]; then
        output_dir="$staging/.ark/torrents/$loadout"
    fi
    mkdir -p "$output_dir"

    ark_bold "Publishing: $loadout"
    ark_info "Output: $output_dir"
    echo

    # Build common transmission-create flags
    local tc_flags=()
    tc_flags+=(-c "$comment")
    for t in "${trackers[@]}"; do
        tc_flags+=(-t "$t")
    done
    for w in "${webseeds[@]}"; do
        tc_flags+=(-w "$w")
    done

    # Create torrent for each ZIM file
    local count=0 skipped=0
    for zim_file in "$loadout_dir"/zim/*.zim; do
        [[ -f "$zim_file" ]] || continue

        local filename
        filename="$(basename "$zim_file")"
        local torrent_file="$output_dir/${filename}.torrent"

        if [[ -f "$torrent_file" ]]; then
            # Skip if torrent is newer than the ZIM
            if [[ "$torrent_file" -nt "$zim_file" ]]; then
                ark_dim "  Skipping (up to date): $filename"
                skipped=$(( skipped + 1 ))
                continue
            fi
        fi

        ark_info "Creating torrent: $filename"
        if transmission-create \
            "${tc_flags[@]}" \
            -o "$torrent_file" \
            "$zim_file"; then
            count=$(( count + 1 ))
        else
            ark_error "Failed to create torrent for: $filename"
        fi
    done

    echo
    ark_ok "Published $count torrents ($skipped skipped), output: $output_dir"

    if (( ${#trackers[@]} == 0 )); then
        echo
        ark_warn "No trackers specified — torrents are trackerless (DHT/PEX only)."
        ark_info "Add trackers with: ark publish $manifest_arg --tracker=udp://tracker.example.com:6969"
    fi
}
