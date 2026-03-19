#!/usr/bin/env bash
# ark-clone.sh — rclone wrapper to copy a loadout to a drive or remote path

ark_clone() {
    local manifest_arg="${1:-}"
    local dest="${2:-}"
    shift 2 || true

    if [[ -z "$manifest_arg" || -z "$dest" ]]; then
        ark_die "Usage: ark clone <loadout|manifest.yml> <destination> [--dry-run] [rclone-flags...]"
    fi

    ark_load_config

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"

    local staging
    staging="$(ark_staging_path)"
    local source_dir="$staging/$loadout"

    if [[ ! -d "$source_dir" ]]; then
        ark_die "Loadout directory not found: $source_dir — run 'ark sync $manifest_arg' first"
    fi

    # Collect extra flags (pass-through to rclone)
    local extra_flags=("$@")
    local is_dry_run=false
    for flag in "${extra_flags[@]}"; do
        [[ "$flag" == "--dry-run" || "$flag" == "-n" ]] && is_dry_run=true
    done

    # Space check for local destinations
    if [[ "$dest" != *:* && -d "$(dirname "$dest")" ]]; then
        local source_size
        source_size="$(du -sb "$source_dir" 2>/dev/null | awk '{print $1}')"
        if [[ -n "$source_size" ]]; then
            local dest_parent
            dest_parent="$(dirname "$dest")"
            local dest_avail
            dest_avail="$(df --output=avail -B1 "$dest_parent" 2>/dev/null | tail -1 | tr -d '[:space:]')"
            if [[ -n "$dest_avail" ]] && (( source_size > dest_avail )); then
                ark_error "Not enough space on destination!"
                ark_error "  Need: $(ark_human_bytes "$source_size")"
                ark_error "  Have: $(ark_human_bytes "$dest_avail")"
                ark_die "Free up space or use a larger drive."
            fi
        fi
    fi

    ark_bold "Cloning: $loadout -> $dest"
    if $is_dry_run; then
        ark_warn "(dry run — no files will be copied)"
    fi
    echo

    # Build rclone command
    local rclone_args=(
        sync
        "$source_dir/"
        "$dest/"
        --exclude=".ark/**"
        --progress
        --stats-one-line
        --stats=5s
    )

    # Add extra flags
    rclone_args+=("${extra_flags[@]}")

    ark_info "rclone ${rclone_args[*]}"
    echo

    if ! rclone "${rclone_args[@]}"; then
        ark_die "rclone failed!"
    fi

    echo
    ark_ok "Clone complete: $loadout -> $dest"

    if ! $is_dry_run; then
        echo
        ark_info "Verify with: rclone check '$source_dir/' '$dest/' --exclude='.ark/**'"
    fi
}
