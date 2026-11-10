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
        source_size="$(du -sbL "$source_dir" 2>/dev/null | awk '{print $1}')"
        if [[ -n "$source_size" ]]; then
            # Check the destination's own filesystem when it exists (a mounted drive)
            local dest_fs="$dest"
            [[ -d "$dest" ]] || dest_fs="$(dirname "$dest")"
            local dest_avail
            dest_avail="$(df --output=avail -B1 "$dest_fs" 2>/dev/null | tail -1 | tr -d '[:space:]')"
            if [[ -n "$dest_avail" ]] && (( source_size > dest_avail )); then
                ark_error "Not enough space on destination!"
                ark_error "  Need: $(ark_human_bytes "$source_size")"
                ark_error "  Have: $(ark_human_bytes "$dest_avail")"
                ark_die "Free up space or use a larger drive."
            fi
        fi
    fi

    # A pack is added to a drive that already has a loadout, so copy it
    # without deleting anything else on the destination.
    local rclone_mode=sync
    if ark_manifest_is_pack "$manifest_file"; then
        rclone_mode=copy
    fi

    ark_bold "Cloning: $loadout -> $dest"
    [[ "$rclone_mode" == "copy" ]] && ark_dim "  Expansion pack: adding to what's already there"
    if $is_dry_run; then
        ark_warn "(dry run — no files will be copied)"
    fi
    echo

    # Build rclone command
    local rclone_args=(
        "$rclone_mode"
        "$source_dir/"
        "$dest/"
        --exclude=".ark/**"
        --copy-links
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
        local check_flags="--exclude='.ark/**' --copy-links"
        [[ "$rclone_mode" == "copy" ]] && check_flags+=" --one-way"
        ark_info "Verify with: rclone check '$source_dir/' '$dest/' $check_flags"
    fi
}
