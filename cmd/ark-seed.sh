#!/usr/bin/env bash
# ark-seed.sh — download .torrent files and optionally import into qBittorrent
#
# Downloads the official Kiwix .torrent files for every ZIM in a loadout.
# When imported into qBittorrent with the save path pointing at your staging
# ZIM directory, qBittorrent will hash-check the existing files and start
# seeding immediately — no re-download needed.

ark_seed() {
    local manifest_arg="${1:-}"

    if [[ -z "$manifest_arg" ]]; then
        cat <<'EOF'
Usage: ark seed <loadout|manifest.yml> [flags]

Downloads official Kiwix .torrent files for every ZIM in the loadout
and optionally imports them into qBittorrent for seeding.

Flags:
  --import           Import torrents into qBittorrent WebUI automatically
  --torrents-dir=DIR Save .torrent files to DIR (default: $ARK_STAGING/.ark/torrents/<loadout>)
  --category=NAME    qBittorrent category for imported torrents (default: ark)
  --paused           Add torrents to qBittorrent in paused state

The save path is set to your staging loadout's zim/ directory so
qBittorrent will find the existing files and start seeding.

Examples:
  ark seed medium                     # Just download .torrent files
  ark seed medium --import            # Download and import into qBittorrent
  ark seed medium --import --paused   # Import paused (for manual review first)
EOF
        return 1
    fi

    ark_load_config
    ark_state_init

    # Parse flags
    local do_import=false
    local torrents_dir=""
    local qbt_category="ark"
    local qbt_paused=false
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --import)          do_import=true ;;
            --torrents-dir=*)  torrents_dir="${1#--torrents-dir=}" ;;
            --category=*)      qbt_category="${1#--category=}" ;;
            --paused)          qbt_paused=true ;;
            *)                 ark_die "Unknown flag: $1" ;;
        esac
        shift
    done

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"

    local staging
    staging="$(ark_staging_path)"
    local zim_dir="$staging/$loadout/zim"

    # Default torrents dir
    if [[ -z "$torrents_dir" ]]; then
        torrents_dir="$staging/.ark/torrents/$loadout"
    fi
    mkdir -p "$torrents_dir"

    ark_bold "Seeding: $loadout"
    ark_info "Torrent files: $torrents_dir"
    ark_info "ZIM directory:  $zim_dir"
    echo

    # Ensure catalog is available
    ark_catalog_ensure
    echo

    # Resolve manifest
    ark_info "Resolving manifest..."
    local resolution
    resolution="$(ark_manifest_resolve "$manifest_file")"

    # Download .torrent files for every resolved entry
    local downloaded=0 skipped=0 failed=0 total=0
    local torrent_files=()

    while IFS=$'\t' read -r status name flavour meta4_url size date filename; do
        [[ "$status" == "unresolved" ]] && continue
        [[ -z "$meta4_url" || "$meta4_url" == "-" ]] && continue
        total=$(( total + 1 ))

        local direct_url
        direct_url="$(ark_catalog_meta4_to_url "$meta4_url")"
        local torrent_url="${direct_url}.torrent"
        local torrent_file="$torrents_dir/${filename}.torrent"

        if [[ -f "$torrent_file" ]]; then
            skipped=$(( skipped + 1 ))
            torrent_files+=("$torrent_file")
            continue
        fi

        if curl -sL --fail -o "$torrent_file" "$torrent_url"; then
            downloaded=$(( downloaded + 1 ))
            torrent_files+=("$torrent_file")
        else
            ark_warn "  Failed to download torrent: $filename"
            rm -f "$torrent_file"
            failed=$(( failed + 1 ))
        fi
    done <<< "$resolution"

    echo
    ark_ok "ZIM torrents: $downloaded downloaded, $skipped already had, $failed failed (of $total)"

    # Handle archive.org collections (shame/, etc.)
    local archive_count
    archive_count="$(ark_manifest_archive_count "$manifest_file")"
    if (( archive_count > 0 )); then
        echo
        ark_info "Fetching archive.org torrents..."
        local arch_downloaded=0 arch_skipped=0 arch_failed=0

        _seed_archive_callback() {
            local idx="$1" id="$2" dest="$3" source="$4" note="$5"
            local archive_torrent_dir="$torrents_dir/${dest}"
            mkdir -p "$archive_torrent_dir"

            # archive.org torrent URL pattern: https://archive.org/download/{id}/{id}_archive.torrent
            local torrent_url="https://archive.org/download/${id}/${id}_archive.torrent"
            local torrent_file="${archive_torrent_dir}/${id}.torrent"

            if [[ -f "$torrent_file" ]]; then
                arch_skipped=$(( arch_skipped + 1 ))
                torrent_files+=("$torrent_file")
                return
            fi

            ark_dim "  Fetching: $id"
            if curl -sL --fail -o "$torrent_file" "$torrent_url"; then
                arch_downloaded=$(( arch_downloaded + 1 ))
                torrent_files+=("$torrent_file")
            else
                ark_warn "  Failed: $id ($torrent_url)"
                rm -f "$torrent_file"
                arch_failed=$(( arch_failed + 1 ))
            fi
        }

        ark_manifest_each_archive "$manifest_file" _seed_archive_callback
        ark_ok "Archive torrents: $arch_downloaded downloaded, $arch_skipped already had, $arch_failed failed"
    fi

    # Handle Linux ISOs
    local iso_count
    iso_count="$(ark_manifest_iso_count "$manifest_file")"
    if (( iso_count > 0 )); then
        echo
        ark_info "Fetching Linux ISO torrents..."

        local iso_torrent_dir="${ARK_ISO_TORRENT_DIR:-$torrents_dir/isos}"
        local iso_download_dir="${ARK_ISO_DIR:-$staging/$loadout/isos}"
        mkdir -p "$iso_torrent_dir" "$iso_download_dir"
        ark_dim "  Torrent dir: $iso_torrent_dir"
        ark_dim "  ISO dir:     $iso_download_dir"

        local iso_downloaded=0 iso_skipped=0 iso_failed=0 iso_direct=0

        _seed_iso_callback() {
            local idx="$1" torrent_url="$2" url="$3" archive_id="$4" note="$5"

            if [[ -n "$torrent_url" ]]; then
                # Direct .torrent file from distro mirror
                local fname
                fname="$(basename "$torrent_url")"
                local torrent_file="${iso_torrent_dir}/${fname}"

                if [[ -f "$torrent_file" ]]; then
                    iso_skipped=$(( iso_skipped + 1 ))
                    torrent_files+=("$torrent_file")
                    return
                fi

                ark_dim "  Fetching: $fname"
                if curl -sL --fail -o "$torrent_file" "$torrent_url"; then
                    iso_downloaded=$(( iso_downloaded + 1 ))
                    torrent_files+=("$torrent_file")
                else
                    ark_warn "  Failed: $fname"
                    rm -f "$torrent_file"
                    iso_failed=$(( iso_failed + 1 ))
                fi

            elif [[ -n "$archive_id" ]]; then
                # archive.org torrent
                local torrent_url_ia="https://archive.org/download/${archive_id}/${archive_id}_archive.torrent"
                local torrent_file="${iso_torrent_dir}/${archive_id}.torrent"

                if [[ -f "$torrent_file" ]]; then
                    iso_skipped=$(( iso_skipped + 1 ))
                    torrent_files+=("$torrent_file")
                    return
                fi

                ark_dim "  Fetching: $archive_id"
                if curl -sL --fail -o "$torrent_file" "$torrent_url_ia"; then
                    iso_downloaded=$(( iso_downloaded + 1 ))
                    torrent_files+=("$torrent_file")
                else
                    ark_warn "  Failed: $archive_id"
                    rm -f "$torrent_file"
                    iso_failed=$(( iso_failed + 1 ))
                fi

            elif [[ -n "$url" ]]; then
                # Direct HTTP download (e.g. Tails)
                local fname
                fname="$(basename "$url")"
                local dest_file="${iso_download_dir}/${fname}"

                if [[ -f "$dest_file" ]]; then
                    ark_dim "  Already have: $fname"
                    iso_skipped=$(( iso_skipped + 1 ))
                    return
                fi

                ark_info "  Direct download: $fname (no torrent available)"
                if curl -L --fail --progress-bar -o "$dest_file" "$url"; then
                    iso_direct=$(( iso_direct + 1 ))
                else
                    ark_warn "  Failed: $fname"
                    rm -f "$dest_file"
                    iso_failed=$(( iso_failed + 1 ))
                fi
            fi
        }

        ark_manifest_each_iso "$manifest_file" _seed_iso_callback
        local iso_summary="ISO torrents: $iso_downloaded downloaded, $iso_skipped already had, $iso_failed failed"
        (( iso_direct > 0 )) && iso_summary+=", $iso_direct direct downloads"
        ark_ok "$iso_summary"
    fi

    # Import into qBittorrent if requested
    if $do_import; then
        echo
        if [[ -z "$ARK_QBT_URL" ]]; then
            ark_die "qBittorrent URL not configured. Set ARK_QBT_URL or configure in .ark/config.yml"
        fi

        ark_info "Importing ${#torrent_files[@]} torrents into qBittorrent..."
        ark_info "  URL:       $ARK_QBT_URL"
        ark_info "  Save path: $zim_dir"
        ark_info "  Category:  $qbt_category"
        $qbt_paused && ark_info "  State:     paused"
        echo

        # Login to qBittorrent
        local cookie_jar
        cookie_jar="$(mktemp)"
        trap "rm -f '$cookie_jar'" RETURN

        if [[ -n "$ARK_QBT_USER" ]]; then
            local login_resp
            login_resp="$(curl -sL -c "$cookie_jar" \
                "${ARK_QBT_URL}/api/v2/auth/login" \
                -d "username=${ARK_QBT_USER}" \
                -d "password=${ARK_QBT_PASS}" 2>&1)"
            if [[ "$login_resp" != *"Ok"* ]]; then
                ark_die "qBittorrent login failed: $login_resp"
            fi
            ark_ok "Logged into qBittorrent"
        fi

        local imported=0 import_failed=0
        for torrent_file in "${torrent_files[@]}"; do
            local fname
            fname="$(basename "$torrent_file")"

            local paused_flag="false"
            $qbt_paused && paused_flag="true"

            local resp
            resp="$(curl -sL -b "$cookie_jar" \
                "${ARK_QBT_URL}/api/v2/torrents/add" \
                -F "torrents=@${torrent_file}" \
                -F "savepath=${zim_dir}" \
                -F "category=${qbt_category}" \
                -F "paused=${paused_flag}" \
                -F "root_folder=false" \
                -F "skip_checking=false" 2>&1)"

            if [[ "$resp" == *"Ok"* || "$resp" == *"ok"* || -z "$resp" ]]; then
                imported=$(( imported + 1 ))
            else
                ark_warn "  Failed to import: $fname ($resp)"
                import_failed=$(( import_failed + 1 ))
            fi
        done

        echo
        ark_ok "Imported $imported torrents into qBittorrent ($import_failed failed)"
        echo
        ark_info "qBittorrent will now hash-check existing files and start seeding."
        ark_info "Check status at: $ARK_QBT_URL"
    else
        echo
        ark_info "To import into qBittorrent, re-run with --import:"
        echo "  ark seed $manifest_arg --import"
        echo
        ark_info "Or manually import the .torrent files from:"
        echo "  $torrents_dir"
        echo
        ark_info "Set the save path to: $zim_dir"
    fi
}
