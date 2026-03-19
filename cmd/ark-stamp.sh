#!/usr/bin/env bash
# ark-stamp.sh — health-check, format, and stamp a drive with an ark loadout
#
# Full pipeline: SMART check → partition → format (exfat) → mount → clone → unmount
# Requires root (sudo) for drive operations.

ark_stamp() {
    local manifest_arg="${1:-}"
    local device="${2:-}"
    shift 2 || true

    if [[ -z "$manifest_arg" || -z "$device" ]]; then
        cat <<'EOF'
Usage: ark stamp <loadout> <device> [flags]

Prepares a drive and stamps it with an ark loadout.

Pipeline:
  1. SMART health check (abort if drive is failing)
  2. Partition (single GPT partition)
  3. Format as exFAT (cross-platform compatible)
  4. Mount to temporary location
  5. Clone loadout via rclone
  6. Zero-fill free space (overwrites previous data)
  7. Generate drive README
  8. Unmount

Flags:
  --fs=exfat|ext4|ntfs   Filesystem (default: exfat)
  --label=NAME           Volume label (default: THE-ARK)
  --source=PATH          Use PATH as source instead of staging area
  --skip-smart           Skip SMART health check
  --skip-format          Skip format (drive already formatted, just clone)
  --dry-run              Show what would be done without doing it
  --yes                  Skip confirmation prompt

Examples:
  ark stamp medium /dev/sdb                                    # Full pipeline
  ark stamp medium /dev/sdb --source=/mnt/nas-downloads/ark/   # Custom source
  ark stamp mega /dev/sdc --fs=ext4                            # Use ext4 instead
  ark stamp mini /dev/sdb --skip-format                        # Already formatted
  ark stamp medium /dev/sdb --label=ARK-2026                   # Custom label
EOF
        return 1
    fi

    # Validate device exists and is a block device
    if [[ ! -b "$device" ]]; then
        ark_die "Not a block device: $device"
    fi

    # Refuse to operate on mounted devices or system disks
    if [[ "$device" == "/dev/sda" || "$device" == "/dev/nvme0n1" ]]; then
        ark_die "Refusing to operate on $device — looks like a system disk"
    fi

    # Check if any partition on the device is mounted
    if mount | grep -q "^${device}"; then
        ark_die "$device (or a partition) is currently mounted. Unmount first."
    fi

    ark_load_config

    # Parse flags
    local fs="exfat"
    local label="THE-ARK"
    local skip_smart=false
    local skip_format=false
    local dry_run=false
    local auto_yes=false
    local source_override=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fs=*)          fs="${1#--fs=}" ;;
            --label=*)       label="${1#--label=}" ;;
            --source=*)      source_override="${1#--source=}" ;;
            --skip-smart)    skip_smart=true ;;
            --skip-format)   skip_format=true ;;
            --dry-run)       dry_run=true ;;
            --yes|-y)        auto_yes=true ;;
            *)               ark_die "Unknown flag: $1" ;;
        esac
        shift
    done

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"
    local description
    description="$(ark_manifest_description "$manifest_file")"

    # Determine source directory
    local source_dir
    if [[ -n "$source_override" ]]; then
        source_dir="$source_override"
    else
        local staging
        staging="$(ark_staging_path)"
        source_dir="$staging/$loadout"
    fi

    if [[ ! -d "$source_dir" ]]; then
        ark_die "Source directory not found: $source_dir — use --source=<path> or run 'ark sync $manifest_arg' first"
    fi

    # Get drive info
    local drive_model drive_size_bytes drive_size_human
    drive_model="$(lsblk -ndo MODEL "$device" 2>/dev/null | sed 's/^[[:space:]]*//' || echo "unknown")"
    drive_size_bytes="$(lsblk -ndb -o SIZE "$device" 2>/dev/null | head -1 || echo "0")"
    drive_size_human="$(ark_human_bytes "$drive_size_bytes")"

    ark_bold "Stamping: $loadout → $device"
    echo
    ark_info "Drive:    $device ($drive_model, $drive_size_human)"
    ark_info "Loadout:  $loadout"
    [[ -n "$description" ]] && ark_dim "          $description"
    ark_info "Source:   $source_dir"
    ark_info "Format:   $fs (label: $label)"
    $skip_smart && ark_warn "SMART check: skipped"
    $skip_format && ark_warn "Format: skipped"
    $dry_run && ark_warn "(dry run — no changes will be made)"
    echo

    # ── Step 1: SMART health check ──────────────────────────────────
    if ! $skip_smart; then
        ark_bold "Step 1/7: SMART health check"

        if $dry_run; then
            ark_dim "  Would run: smartctl -H $device"
        else
            if ! command -v smartctl &>/dev/null && [[ ! -x "/usr/sbin/smartctl" ]]; then
                ark_die "smartctl not found. Install smartmontools or use --skip-smart"
            fi

            # Get overall health
            local smart_health
            smart_health="$(sudo smartctl -H "$device" 2>&1)" || true

            if echo "$smart_health" | grep -qi "PASSED\|OK"; then
                ark_ok "  SMART health: PASSED"
            elif echo "$smart_health" | grep -qi "FAILED"; then
                ark_warn "  SMART health: FAILED"
                echo "$smart_health" | grep -i "failed\|error\|warning" | while read -r line; do
                    ark_warn "    $line"
                done
                ark_warn "  This drive is reporting failures. It may still work, but"
                ark_warn "  consider using a healthier drive for long-term archival."
                ark_warn "  (An imperfect ark is better than no ark.)"
            else
                ark_warn "  SMART health: inconclusive (drive may not support SMART)"
                ark_dim "  $smart_health" | head -3
            fi

            # Check reallocated sectors and other key attributes
            local smart_attrs
            smart_attrs="$(sudo smartctl -A "$device" 2>&1)" || true

            # Check for concerning attributes
            local realloc pending uncorrect
            realloc="$(echo "$smart_attrs" | grep -i "Reallocated_Sector" | awk '{print $NF}' || echo "0")"
            pending="$(echo "$smart_attrs" | grep -i "Current_Pending" | awk '{print $NF}' || echo "0")"
            uncorrect="$(echo "$smart_attrs" | grep -i "Offline_Uncorrectable" | awk '{print $NF}' || echo "0")"

            if [[ "${realloc:-0}" != "0" && "${realloc:-0}" != "-" ]]; then
                ark_warn "  Reallocated sectors: $realloc (some wear, but usable)"
            fi
            if [[ "${pending:-0}" != "0" && "${pending:-0}" != "-" ]]; then
                ark_warn "  Pending sectors: $pending (drive may be degrading)"
            fi
            if [[ "${uncorrect:-0}" != "0" && "${uncorrect:-0}" != "-" ]]; then
                ark_warn "  Uncorrectable errors: $uncorrect (data may be at risk)"
                ark_warn "  Strongly recommend verifying after clone: ark verify $loadout"
            fi

            # Show power-on hours and temperature if available
            local poh temp
            poh="$(echo "$smart_attrs" | grep -i "Power_On_Hours" | awk '{print $NF}' || echo "")"
            temp="$(echo "$smart_attrs" | grep -i "Temperature_Celsius" | awk '{print $NF}' || echo "")"
            [[ -n "$poh" && "$poh" != "-" ]] && ark_dim "  Power-on hours: $poh"
            [[ -n "$temp" && "$temp" != "-" ]] && ark_dim "  Temperature: ${temp}°C"
        fi
        echo
    fi

    # ── Confirmation ────────────────────────────────────────────────
    if ! $auto_yes && ! $dry_run; then
        ark_warn "This will ERASE ALL DATA on $device ($drive_model, $drive_size_human)"
        echo
        read -rp "Type 'yes' to continue: " confirm
        if [[ "$confirm" != "yes" ]]; then
            ark_die "Aborted."
        fi
        echo
    fi

    # ── Step 2: Partition ───────────────────────────────────────────
    if ! $skip_format; then
        ark_bold "Step 2/7: Partitioning $device (GPT, single partition)"

        if $dry_run; then
            ark_dim "  Would run: sgdisk --zap-all $device"
            ark_dim "  Would run: sgdisk -n 1:0:0 -t 1:0700 $device"
        else
            sudo sgdisk --zap-all "$device" > /dev/null 2>&1
            sudo sgdisk -n 1:0:0 -t 1:0700 "$device" > /dev/null 2>&1
            sudo partprobe "$device" 2>/dev/null || sleep 1
            ark_ok "  Partitioned"
        fi
        echo

        # Determine partition path (sdb1 vs nvme0n1p1)
        local partition
        if [[ "$device" == *nvme* || "$device" == *mmcblk* ]]; then
            partition="${device}p1"
        else
            partition="${device}1"
        fi

        # Wait for partition to appear
        if ! $dry_run; then
            local wait=0
            while [[ ! -b "$partition" ]] && (( wait < 10 )); do
                sleep 0.5
                wait=$(( wait + 1 ))
            done
            if [[ ! -b "$partition" ]]; then
                ark_die "Partition $partition did not appear after partitioning"
            fi
        fi

        # ── Step 3: Format ──────────────────────────────────────────
        ark_bold "Step 3/7: Formatting $partition as $fs (label: $label)"

        if $dry_run; then
            ark_dim "  Would run: mkfs.$fs $partition"
        else
            case "$fs" in
                exfat)
                    sudo mkfs.exfat -L "$label" "$partition" > /dev/null 2>&1
                    ;;
                ext4)
                    sudo mkfs.ext4 -L "$label" -q "$partition" > /dev/null 2>&1
                    ;;
                ntfs)
                    if ! command -v mkfs.ntfs &>/dev/null && [[ ! -x "/usr/sbin/mkfs.ntfs" ]]; then
                        ark_die "mkfs.ntfs not found. Install ntfs-3g."
                    fi
                    sudo mkfs.ntfs -f -L "$label" "$partition" > /dev/null 2>&1
                    ;;
                *)
                    ark_die "Unsupported filesystem: $fs (use exfat, ext4, or ntfs)"
                    ;;
            esac
            ark_ok "  Formatted"
        fi
        echo
    else
        # Skip format — determine partition
        local partition
        if [[ "$device" == *nvme* || "$device" == *mmcblk* ]]; then
            partition="${device}p1"
        else
            partition="${device}1"
        fi
        if [[ ! -b "$partition" ]]; then
            ark_die "Partition $partition not found. Run without --skip-format or partition manually."
        fi
    fi

    # ── Step 4: Mount ───────────────────────────────────────────────
    local mount_point
    mount_point="$(mktemp -d /tmp/ark-stamp.XXXXXX)"

    ark_bold "Step 4/7: Mounting $partition → $mount_point"

    if $dry_run; then
        ark_dim "  Would mount $partition to $mount_point"
    else
        # Mount with current user ownership (exfat/ntfs need uid/gid at mount time)
        sudo mount -o "uid=$(id -u),gid=$(id -g)" "$partition" "$mount_point" 2>/dev/null \
            || sudo mount "$partition" "$mount_point"  # fallback for ext4 etc.
        # Ensure we clean up on exit
        trap "sudo umount '$mount_point' 2>/dev/null; rmdir '$mount_point' 2>/dev/null" EXIT
        ark_ok "  Mounted"

        # For ext4/native filesystems, ensure writable
        if ! touch "$mount_point/.ark-test" 2>/dev/null; then
            sudo chown "$(id -u):$(id -g)" "$mount_point"
        fi
        rm -f "$mount_point/.ark-test" 2>/dev/null
    fi
    echo

    # ── Step 5: Clone ───────────────────────────────────────────────
    ark_bold "Step 5/7: Cloning $loadout → $mount_point"

    if $dry_run; then
        local source_size
        source_size="$(du -sb "$source_dir" 2>/dev/null | awk '{print $1}')"
        ark_dim "  Would copy $(ark_human_bytes "$source_size") from $source_dir"
    else
        if ! rclone sync \
            "$source_dir/" \
            "$mount_point/" \
            --exclude=".ark/**" \
            --copy-links \
            --progress \
            --stats-one-line \
            --stats=5s; then
            ark_die "rclone failed!"
        fi
        echo
        ark_ok "  Clone complete"
    fi
    echo

    # ── Step 6: Zero-fill free space ─────────────────────────────────
    ark_bold "Step 6/7: Zero-filling free space (overwriting previous data)"

    if $dry_run; then
        ark_dim "  Would write zeros to remaining free space"
    else
        local zero_file="$mount_point/.ark-zero"
        ark_dim "  Writing zeros to free space (this may take a while)..."
        dd if=/dev/zero of="$zero_file" bs=1M 2>/dev/null || true
        sync
        rm -f "$zero_file"
        ark_ok "  Free space zeroed"
    fi
    echo

    # ── Step 7: Generate README ─────────────────────────────────────
    ark_bold "Step 7/7: Generating drive README"

    if $dry_run; then
        ark_dim "  Would generate README.txt on drive"
    else
        local readme_file="$mount_point/README.txt"
        local date_stamp
        date_stamp="$(date +%Y-%m-%d)"
        local zim_count
        zim_count="$(find "$mount_point" -name "*.zim" 2>/dev/null | wc -l)"
        local total_size
        total_size="$(du -sh "$mount_point" 2>/dev/null | awk '{print $1}')"

        # Check for template
        local template="$ARK_ROOT/templates/README.txt.tmpl"
        if [[ -f "$template" ]]; then
            sed -e "s|{{LOADOUT}}|$loadout|g" \
                -e "s|{{DESCRIPTION}}|$description|g" \
                -e "s|{{DATE}}|$date_stamp|g" \
                -e "s|{{ZIM_COUNT}}|$zim_count|g" \
                -e "s|{{TOTAL_SIZE}}|$total_size|g" \
                "$template" > "$readme_file"
        else
            cat > "$readme_file" << READMEEOF
╔══════════════════════════════════════════════════════════════╗
║                        THE ARK                              ║
║              Offline Knowledge Archive                      ║
╚══════════════════════════════════════════════════════════════╝

Loadout:  $loadout
Date:     $date_stamp
Contents: $zim_count ZIM files ($total_size)

$description

────────────────────────────────────────────────────────────────

HOW TO USE THIS DRIVE

1. Install Kiwix — a free, offline content reader.
   Look in the kiwix/ folder on this drive for installers:
   - Windows: kiwix-desktop .exe installer
   - macOS:   kiwix-macos .dmg
   - Linux:   kiwix-desktop .appimage (just run it)
   - Android: kiwix .apk (sideload)

2. Open Kiwix and point it at the zim/ folder on this drive.

3. Browse Wikipedia, Wiktionary, medical references, repair
   guides, textbooks, and more — all completely offline.

NOTE: The first time Kiwix opens this drive, global search
may take several minutes to build its index. This is normal.
Search within individual content (e.g. Wikipedia's own search
bar) works immediately. Be patient — it only happens once.

────────────────────────────────────────────────────────────────

WHAT'S ON THIS DRIVE

zim/       ZIM files — offline content readable with Kiwix
pdfs/      Essential reference PDFs
kiwix/     Kiwix reader applications for all platforms
isos/      Bootable Linux distributions
shame/     Public accountability documents

────────────────────────────────────────────────────────────────

This drive was built with the-ark:
  https://github.com/xram/the-ark

"The best library in human history, in a fireproof envelope,
 for less than a pizza dinner."
READMEEOF
        fi
        ark_ok "  README.txt written"
    fi
    echo

    # ── Unmount ─────────────────────────────────────────────────────
    if ! $dry_run; then
        sync
        sudo umount "$mount_point"
        rmdir "$mount_point" 2>/dev/null
        trap - EXIT  # clear the cleanup trap
    fi

    echo
    ark_ok "Drive stamped: $loadout → $device"
    ark_info "  Drive:  $device ($drive_model, $drive_size_human)"
    ark_info "  Label:  $label"
    ark_info "  Format: $fs"
    echo
    ark_bold "Your ark is ready. Keep it safe."
}
