#!/usr/bin/env bash
# ark-sync.sh — download everything missing or outdated for a loadout

# Generate a README.txt for the drive root
_ark_sync_readme() {
    local loadout_dir="$1"
    local loadout="$2"
    local manifest_file="$3"
    local readme="$loadout_dir/README.txt"
    local template="$ARK_ROOT/templates/README.txt.tmpl"

    if [[ -f "$template" ]]; then
        local description
        description="$(ark_manifest_description "$manifest_file")"
        local date_str
        date_str="$(date -u +%Y-%m-%d)"

        sed -e "s|{{LOADOUT}}|$loadout|g" \
            -e "s|{{DESCRIPTION}}|$description|g" \
            -e "s|{{DATE}}|$date_str|g" \
            "$template" > "$readme"
        ark_ok "README.txt generated."
    fi
}

ark_sync() {
    local manifest_arg="${1:-}"
    local refresh=false
    local method=""

    # Parse flags
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --refresh)    refresh=true ;;
            --method=*)   method="${1#--method=}" ;;
            *)            ark_die "Unknown flag: $1" ;;
        esac
        shift
    done

    if [[ -z "$manifest_arg" ]]; then
        ark_die "Usage: ark sync <loadout|manifest.yml> [--refresh] [--method=http|torrent]"
    fi

    # Load config
    ark_load_config
    ark_state_init

    # Override download method if specified
    if [[ -n "$method" ]]; then
        ARK_DOWNLOAD_METHOD="$method"
    fi

    # Resolve manifest
    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"
    local target_gb
    target_gb="$(ark_manifest_target_gb "$manifest_file")"
    local description
    description="$(ark_manifest_description "$manifest_file")"

    ark_bold "Syncing loadout: $loadout"
    [[ -n "$description" ]] && ark_dim "  $description"
    echo

    # Ensure staging dirs exist
    local staging
    staging="$(ark_staging_path)"
    mkdir -p "$staging/$loadout/zim"
    mkdir -p "$staging/$loadout/pdfs"
    mkdir -p "$staging/$loadout/kiwix"
    mkdir -p "$staging/$loadout/maps"

    # Create archive destination dirs (shame/, etc.)
    local archive_count
    archive_count="$(ark_manifest_archive_count "$manifest_file")"
    if (( archive_count > 0 )); then
        _mkdir_archive_callback() {
            local idx="$1" id="$2" dest="$3" source="$4" note="$5"
            mkdir -p "$staging/$loadout/$dest"
        }
        ark_manifest_each_archive "$manifest_file" _mkdir_archive_callback
    fi

    # Ensure catalog is fresh
    ark_catalog_ensure "$refresh"
    echo

    # Resolve manifest against catalog
    ark_info "Resolving manifest against catalog..."
    local resolution
    resolution="$(ark_manifest_resolve "$manifest_file")"

    # Tally
    local total=0 ok=0 missing=0 outdated=0 unresolved=0
    local download_size=0

    while IFS=$'\t' read -r status name flavour meta4_url size date filename; do
        total=$(( total + 1 ))
        case "$status" in
            ok)         ok=$(( ok + 1 )) ;;
            missing)    missing=$(( missing + 1 )); download_size=$(( download_size + size )) ;;
            outdated)   outdated=$(( outdated + 1 )); download_size=$(( download_size + size )) ;;
            unresolved) unresolved=$(( unresolved + 1 )) ;;
        esac
    done <<< "$resolution"

    echo
    ark_info "Manifest: $total ZIM entries"
    (( ok > 0 ))         && ark_ok   "  Up to date: $ok"
    (( missing > 0 ))    && ark_warn "  Missing:    $missing"
    (( outdated > 0 ))   && ark_warn "  Outdated:   $outdated"
    (( unresolved > 0 )) && ark_error "  Not in catalog: $unresolved"

    if (( missing + outdated == 0 )); then
        echo
        ark_ok "All ZIM files are up to date!"
    else
        echo
        ark_info "Download needed: $(ark_human_bytes "$download_size")"

        # Check target size
        local target_bytes=$(( target_gb * 1073741824 ))
        local existing_size
        existing_size="$(ark_state_total_size "$loadout/")"
        local projected_total=$(( existing_size + download_size ))
        if (( projected_total > target_bytes )); then
            ark_warn "Warning: projected total $(ark_human_bytes $projected_total) exceeds target ${target_gb} GB"
        fi

        echo

        # Download missing and outdated
        local downloaded=0 failed=0
        while IFS=$'\t' read -r status name flavour meta4_url size date filename; do
            case "$status" in
                missing|outdated)
                    echo
                    if [[ "$status" == "outdated" ]]; then
                        ark_info "Updating: $name ($flavour) -> $date"
                        # Remove old version from state (the file on disk gets overwritten)
                        local old_key
                        old_key="$(ark_state_list "$loadout/zim/" | grep "^${loadout}/zim/${name}" | head -1 || true)"
                        if [[ -n "$old_key" ]]; then
                            # Remove old file from disk
                            local old_path="$staging/$old_key"
                            if [[ -f "$old_path" ]]; then
                                ark_dim "  Removing old version: $(basename "$old_path")"
                                rm -f "$old_path"
                            fi
                            ark_state_remove "$old_key"
                        fi
                    fi

                    if ark_download_zim "$loadout" "$name" "$flavour" "$meta4_url" "$size" "$date" "$filename"; then
                        downloaded=$(( downloaded + 1 ))
                    else
                        failed=$(( failed + 1 ))
                        ark_error "Failed: $name"
                    fi
                    ;;
            esac
        done <<< "$resolution"

        echo
        ark_ok "Sync complete: $downloaded downloaded, $failed failed"
    fi

    # Handle PDFs
    local pdf_count
    pdf_count="$(ark_manifest_pdf_count "$manifest_file")"
    if (( pdf_count > 0 )); then
        echo
        ark_info "Syncing $pdf_count PDF files..."

        _sync_pdf_callback() {
            local idx="$1" url="$2" filename="$3"
            ark_download_pdf "$loadout" "$url" "$filename"
        }

        ark_manifest_each_pdf "$manifest_file" _sync_pdf_callback
        ark_ok "PDFs synced."
    fi

    # Handle Kiwix platform binaries
    local platforms
    platforms="$(ark_manifest_kiwix_platforms "$manifest_file")"
    if [[ -n "$platforms" ]]; then
        echo
        source "$ARK_ROOT/lib/ark-kiwix.sh"
        # shellcheck disable=SC2086
        ark_kiwix_fetch "$staging/$loadout" $platforms
    fi

    # Generate README
    _ark_sync_readme "$staging/$loadout" "$loadout" "$manifest_file"

    # Report unresolved entries
    if (( unresolved > 0 )); then
        echo
        ark_warn "The following entries could not be resolved in the catalog:"
        while IFS=$'\t' read -r status name flavour _ _ _ _; do
            if [[ "$status" == "unresolved" ]]; then
                if [[ -n "$flavour" ]]; then
                    echo "  - $name ($flavour)"
                else
                    echo "  - $name"
                fi
            fi
        done <<< "$resolution"
        ark_info "Try 'ark catalog search <name>' to find the correct catalog entry."
    fi

    # Summary
    echo
    local total_size
    total_size="$(ark_state_total_size "$loadout/")"
    ark_bold "Loadout '$loadout': $(ark_human_bytes "$total_size") / ${target_gb} GB"
}
