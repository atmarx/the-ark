#!/usr/bin/env bash
# ark-stamp.sh — secure-erase, health-check, format, and stamp a drive with an ark loadout
#
# Full pipeline: secure erase → SMART analysis → partition → format → mount →
#                clone → README → zero-fill → unmount
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
  1. Secure erase (ATA Secure Erase — full stress test + wipe)
  2. SMART analysis (full health check after the stress test)
  3. Partition (single GPT partition)
  4. Format as exFAT (cross-platform compatible)
  5. Mount to temporary location
  6. Clone loadout via rclone
  7. Generate drive README
  8. Fill remaining space with zeros
  9. Unmount

Flags:
  --fs=exfat|ext4|ntfs   Filesystem (default: exfat)
  --label=NAME           Volume label (default: THE-ARK)
  --source=PATH          Use PATH as source instead of staging area
  --pack=NAME            Add an expansion pack after the loadout (repeatable),
                         e.g. --pack=deep-thought for the LLM pack
  --skip-erase           Skip secure erase (use for drives already wiped)
  --skip-smart           Skip SMART health check
  --skip-format          Skip erase + format (drive already formatted, just clone)
  --no-fill              Skip the zero-fill step at the end
  --dry-run              Show what would be done without doing it
  --yes                  Skip confirmation prompt

Examples:
  ark stamp medium /dev/sdb                                    # Full pipeline
  ark stamp medium /dev/sdb --source=/mnt/nas-downloads/ark/   # Custom source
  ark stamp mega /dev/sdc --skip-erase                         # Skip erase (already wiped)
  ark stamp mini /dev/sdb --skip-format                        # Already formatted, just clone
  ark stamp medium /dev/sdb --label=ARK-2026                   # Custom label
  ark stamp mega /dev/sdd --pack=deep-thought                  # Mega + LLM pack (2 TB)
EOF
        return 1
    fi

    # Validate device exists and is a block device
    if [[ ! -b "$device" ]]; then
        ark_die "Not a block device: $device"
    fi

    # Refuse to operate on the actual boot/root device (unless --force)
    local root_device
    root_device="$(lsblk -ndo PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)"
    if [[ -n "$root_device" && "$device" == "/dev/$root_device" ]]; then
        if $force; then
            ark_warn "WARNING: $device contains the root filesystem! Proceeding anyway (--force)."
        else
            ark_die "Refusing to operate on $device — it contains the root filesystem. Use --force to override."
        fi
    fi

    # Check if any partition on the device is mounted
    if mount | grep -q "^${device}"; then
        ark_die "$device (or a partition) is currently mounted. Unmount first."
    fi

    ark_load_config

    # Parse flags
    local fs="exfat"
    local label="THE-ARK"
    local skip_erase=false
    local skip_smart=false
    local skip_format=false
    local no_fill=false
    local dry_run=false
    local auto_yes=false
    local force=false
    local source_override=""
    local packs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fs=*)          fs="${1#--fs=}" ;;
            --label=*)       label="${1#--label=}" ;;
            --source=*)      source_override="${1#--source=}" ;;
            --pack=*)        packs+=("${1#--pack=}") ;;
            --skip-erase)    skip_erase=true ;;
            --skip-smart)    skip_smart=true ;;
            --skip-format)   skip_format=true; skip_erase=true ;;
            --no-fill)       no_fill=true ;;
            --dry-run)       dry_run=true ;;
            --yes|-y)        auto_yes=true ;;
            --force)         force=true ;;
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
    local staging
    staging="$(ark_staging_path)"
    local source_dir
    if [[ -n "$source_override" ]]; then
        source_dir="$source_override"
    else
        source_dir="$staging/$loadout"
    fi

    if [[ ! -d "$source_dir" ]]; then
        ark_die "Source directory not found: $source_dir — use --source=<path> or run 'ark sync $manifest_arg' first"
    fi

    # Resolve expansion packs now, before anything touches the drive
    local pack_names=() pack_dirs=()
    local pack
    for pack in "${packs[@]}"; do
        local pack_manifest
        pack_manifest="$(ark_resolve_manifest "$pack")"
        ark_manifest_is_pack "$pack_manifest" \
            || ark_die "'$pack' is a loadout, not an expansion pack (no 'pack: true')"
        local pack_name
        pack_name="$(ark_manifest_loadout "$pack_manifest")"
        [[ -d "$staging/$pack_name" ]] \
            || ark_die "Pack not staged: $staging/$pack_name — run 'ark sync $pack' first"
        pack_names+=("$pack_name")
        pack_dirs+=("$staging/$pack_name")
    done

    # Get drive info
    local drive_model drive_size_bytes drive_size_human drive_type
    drive_model="$(lsblk -ndo MODEL "$device" 2>/dev/null | sed 's/^[[:space:]]*//' || echo "unknown")"
    drive_size_bytes="$(lsblk -ndb -o SIZE "$device" 2>/dev/null | head -1 || echo "0")"
    drive_size_human="$(ark_human_bytes "$drive_size_bytes")"
    # Detect if SSD or spinner
    local rotational
    rotational="$(lsblk -ndo ROTA "$device" 2>/dev/null | head -1 || echo "1")"
    if [[ "$rotational" == "0" ]]; then
        drive_type="SSD"
    else
        drive_type="HDD"
    fi

    # Will it fit?  (Staging is a symlink farm, so measure what the links point at.)
    if (( ${#pack_dirs[@]} > 0 )); then
        local need_bytes
        need_bytes="$(du -sbcL "$source_dir" "${pack_dirs[@]}" 2>/dev/null | tail -1 | awk '{print $1}')"
        # Leave ~3% for filesystem overhead
        if (( need_bytes > drive_size_bytes / 100 * 97 )); then
            ark_die "Loadout + packs need $(ark_human_bytes "$need_bytes"); $device is $drive_size_human"
        fi
    fi

    local total_steps=$(( 11 + ${#pack_names[@]} ))
    $skip_erase && total_steps=$(( total_steps - 1 ))
    $skip_smart && total_steps=$(( total_steps - 1 ))
    $skip_format && total_steps=$(( total_steps - 2 ))  # skip partition + format
    $no_fill && total_steps=$(( total_steps - 1 ))
    local step=0

    ark_bold "Stamping: $loadout → $device"
    echo
    ark_info "Drive:    $device ($drive_model, $drive_size_human, $drive_type)"
    ark_info "Loadout:  $loadout"
    [[ -n "$description" ]] && ark_dim "          $description"
    ark_info "Source:   $source_dir"
    (( ${#pack_names[@]} > 0 )) && ark_info "Packs:    ${pack_names[*]}"
    ark_info "Format:   $fs (label: $label)"
    $skip_erase && ark_warn "Secure erase: skipped"
    $skip_smart && ark_warn "SMART check: skipped"
    $skip_format && ark_warn "Format: skipped"
    $no_fill && ark_warn "Zero-fill: skipped"
    $dry_run && ark_warn "(dry run — no changes will be made)"
    echo

    # ── Confirmation ────────────────────────────────────────────────
    if ! $auto_yes && ! $dry_run; then
        ark_warn "This will ERASE ALL DATA on $device ($drive_model, $drive_size_human)"
        if ! $skip_erase; then
            ark_warn "A secure erase will be performed first — this can take HOURS on large drives."
            ark_dim  "  ($drive_size_human at ~100 MB/s ≈ $(( drive_size_bytes / 100000000 / 60 )) minutes estimated)"
        fi
        echo
        read -rp "Type 'yes' to continue: " confirm
        if [[ "$confirm" != "yes" ]]; then
            ark_die "Aborted."
        fi
        echo
    fi

    # ── Step: Secure Erase ────────────────────────────────────────
    if ! $skip_erase; then
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Secure erase ($drive_size_human)"

        if $dry_run; then
            ark_dim "  Would perform ATA Secure Erase or dd wipe on $device"
        else
            # Try ATA Secure Erase first (fastest, firmware-level)
            local ata_erase_ok=false

            # Check if drive supports ATA Secure Erase
            local hdparm_info
            hdparm_info="$(ark_sudo hdparm -I "$device" 2>/dev/null)" || true

            if echo "$hdparm_info" | grep -qi "supported: enhanced erase"; then
                ark_info "  Drive supports ATA Secure Erase"

                # Estimate time from hdparm
                local erase_time
                erase_time="$(echo "$hdparm_info" | grep -i "SECURITY ERASE UNIT" | grep -oP '\d+min' | head -1 || echo "")"
                [[ -n "$erase_time" ]] && ark_dim "  Estimated time: $erase_time"

                # Set a temporary security password for the erase
                if ark_sudo hdparm --user-master u --security-set-pass ark-temp "$device" 2>/dev/null; then
                    ark_info "  Starting ATA Secure Erase (this will take a while)..."
                    if ark_sudo hdparm --user-master u --security-erase ark-temp "$device" 2>/dev/null; then
                        ark_ok "  ATA Secure Erase complete"
                        ata_erase_ok=true
                    else
                        ark_warn "  ATA Secure Erase failed — falling back to dd wipe"
                        # Clear the security password if erase failed
                        ark_sudo hdparm --user-master u --security-disable ark-temp "$device" 2>/dev/null || true
                    fi
                else
                    ark_warn "  Could not set security password — falling back to dd wipe"
                fi
            fi

            # Fallback: dd wipe (works on everything, just slower)
            if ! $ata_erase_ok; then
                ark_info "  Performing dd wipe (writing zeros to entire drive)..."
                ark_dim "  This is a full stress test — every sector will be written."
                local dd_start
                dd_start="$(date +%s)"
                ark_sudo dd if=/dev/zero of="$device" bs=4M status=progress 2>&1 || true
                ark_sudo sync
                local dd_end
                dd_end="$(date +%s)"
                local dd_elapsed=$(( dd_end - dd_start ))
                local dd_speed=$(( drive_size_bytes / (dd_elapsed + 1) / 1048576 ))
                ark_ok "  dd wipe complete (${dd_elapsed}s, ~${dd_speed} MB/s)"
            fi

            # For SSDs, also issue TRIM/discard
            if [[ "$drive_type" == "SSD" ]]; then
                ark_info "  Issuing blkdiscard (TRIM) for SSD..."
                ark_sudo blkdiscard "$device" 2>/dev/null && ark_ok "  TRIM complete" \
                    || ark_warn "  blkdiscard not supported — dd wipe is sufficient"
            fi
        fi
        echo
    fi

    # ── Step: SMART Analysis ──────────────────────────────────────
    if ! $skip_smart; then
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: SMART health analysis"

        if $dry_run; then
            ark_dim "  Would run: smartctl -a $device"
        else
            if ! command -v smartctl &>/dev/null && [[ ! -x "/usr/sbin/smartctl" ]]; then
                ark_die "smartctl not found. Install smartmontools or use --skip-smart"
            fi

            # Get overall health
            local smart_health
            smart_health="$(ark_sudo smartctl -H "$device" 2>&1)" || true

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
            fi

            # Full attributes
            local smart_attrs
            smart_attrs="$(ark_sudo smartctl -A "$device" 2>&1)" || true

            # Key attributes
            local realloc pending uncorrect poh temp
            realloc="$(echo "$smart_attrs" | grep -i "Reallocated_Sector" | awk '{print $NF}' || echo "0")"
            pending="$(echo "$smart_attrs" | grep -i "Current_Pending" | awk '{print $NF}' || echo "0")"
            uncorrect="$(echo "$smart_attrs" | grep -i "Offline_Uncorrectable" | awk '{print $NF}' || echo "0")"
            poh="$(echo "$smart_attrs" | grep -i "Power_On_Hours" | awk '{print $NF}' || echo "")"
            temp="$(echo "$smart_attrs" | grep -i "Temperature_Celsius" | awk '{print $NF}' || echo "")"

            if [[ "${realloc:-0}" != "0" && "${realloc:-0}" != "-" ]]; then
                ark_warn "  Reallocated sectors: $realloc (some wear, but usable)"
            else
                ark_ok "  Reallocated sectors: 0"
            fi
            if [[ "${pending:-0}" != "0" && "${pending:-0}" != "-" ]]; then
                ark_warn "  Pending sectors: $pending (drive may be degrading)"
            else
                ark_ok "  Pending sectors: 0"
            fi
            if [[ "${uncorrect:-0}" != "0" && "${uncorrect:-0}" != "-" ]]; then
                ark_warn "  Uncorrectable errors: $uncorrect (data may be at risk)"
                ark_warn "  Strongly recommend verifying after clone: ark verify $loadout"
            else
                ark_ok "  Uncorrectable errors: 0"
            fi
            [[ -n "$poh" && "$poh" != "-" ]] && ark_dim "  Power-on hours: $poh"
            [[ -n "$temp" && "$temp" != "-" ]] && ark_dim "  Temperature: ${temp}°C"

            # Error log summary
            local error_log
            error_log="$(ark_sudo smartctl -l error "$device" 2>&1)" || true
            if echo "$error_log" | grep -qi "No Errors Logged"; then
                ark_ok "  Error log: clean"
            elif echo "$error_log" | grep -qi "Error Count"; then
                local error_count
                error_count="$(echo "$error_log" | grep -i "Error Count" | awk '{print $NF}' || echo "?")"
                ark_warn "  Error log: $error_count errors recorded"
            fi

            # Self-test log
            local test_log
            test_log="$(ark_sudo smartctl -l selftest "$device" 2>&1)" || true
            if echo "$test_log" | grep -qi "No self-tests"; then
                ark_dim "  Self-test log: no previous tests"
            elif echo "$test_log" | grep -qi "Completed without error"; then
                ark_ok "  Self-test log: previous tests passed"
            fi
        fi
        echo
    fi

    # ── Step: Partition ───────────────────────────────────────────
    local partition
    if ! $skip_format; then
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Partitioning $device (GPT, single partition)"

        if $dry_run; then
            ark_dim "  Would run: sgdisk --zap-all $device"
            ark_dim "  Would run: sgdisk -n 1:0:0 -t 1:0700 $device"
        else
            ark_sudo sgdisk --zap-all "$device" > /dev/null 2>&1
            ark_sudo sgdisk -n 1:0:0 -t 1:0700 "$device" > /dev/null 2>&1
            ark_sudo partprobe "$device" 2>/dev/null || sleep 1
            ark_ok "  Partitioned"
        fi
        echo

        # Determine partition path (sdb1 vs nvme0n1p1)
        if [[ "$device" == *nvme* || "$device" == *mmcblk* ]]; then
            partition="${device}p1"
        else
            partition="${device}1"
        fi

        # Wait for partition to appear
        if ! $dry_run; then
            local wait_count=0
            while [[ ! -b "$partition" ]] && (( wait_count < 10 )); do
                sleep 0.5
                wait_count=$(( wait_count + 1 ))
            done
            if [[ ! -b "$partition" ]]; then
                ark_die "Partition $partition did not appear after partitioning"
            fi
        fi

        # ── Step: Format ──────────────────────────────────────────
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Formatting $partition as $fs (label: $label)"

        if $dry_run; then
            ark_dim "  Would run: mkfs.$fs $partition"
        else
            case "$fs" in
                exfat)
                    ark_sudo mkfs.exfat -L "$label" "$partition" > /dev/null 2>&1
                    ;;
                ext4)
                    ark_sudo mkfs.ext4 -L "$label" -q "$partition" > /dev/null 2>&1
                    ;;
                ntfs)
                    if ! command -v mkfs.ntfs &>/dev/null && [[ ! -x "/usr/sbin/mkfs.ntfs" ]]; then
                        ark_die "mkfs.ntfs not found. Install ntfs-3g."
                    fi
                    ark_sudo mkfs.ntfs -f -L "$label" "$partition" > /dev/null 2>&1
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
        if [[ "$device" == *nvme* || "$device" == *mmcblk* ]]; then
            partition="${device}p1"
        else
            partition="${device}1"
        fi
        if [[ ! -b "$partition" ]]; then
            ark_die "Partition $partition not found. Run without --skip-format or partition manually."
        fi
    fi

    # ── Step: Mount ───────────────────────────────────────────────
    local mount_point
    mount_point="$(mktemp -d /tmp/ark-stamp.XXXXXX)"

    step=$(( step + 1 ))
    ark_bold "Step $step/$total_steps: Mounting $partition → $mount_point"

    if $dry_run; then
        ark_dim "  Would mount $partition to $mount_point"
    else
        # Mount with current user ownership (exfat/ntfs need uid/gid at mount time)
        ark_sudo mount -o "uid=$(id -u),gid=$(id -g)" "$partition" "$mount_point" 2>/dev/null \
            || ark_sudo mount "$partition" "$mount_point"  # fallback for ext4 etc.
        # Ensure we clean up on exit
        trap "ark_sudo umount '$mount_point' 2>/dev/null; rmdir '$mount_point' 2>/dev/null" EXIT
        ark_ok "  Mounted"

        # For ext4/native filesystems, ensure writable
        if ! touch "$mount_point/.ark-test" 2>/dev/null; then
            ark_sudo chown "$(id -u):$(id -g)" "$mount_point"
        fi
        rm -f "$mount_point/.ark-test" 2>/dev/null
    fi
    echo

    # ── Step: Clone ───────────────────────────────────────────────
    step=$(( step + 1 ))
    ark_bold "Step $step/$total_steps: Cloning $loadout → $mount_point"

    # Build rclone filter from manifest — only copy ZIMs this loadout declares
    local filter_file
    filter_file="$(mktemp)"
    trap "rm -f '$filter_file'" RETURN

    # Always include non-ZIM content dirs
    cat >> "$filter_file" << 'FILTEREOF'
+ pdfs/**
+ kiwix/**
+ isos/**
+ shame/**
+ README.txt
- .ark/**
- torrents/**
FILTEREOF

    # Resolve manifest to get the exact ZIM filenames for this loadout
    ark_info "  Resolving manifest to build file filter..."
    local resolution
    resolution="$(ark_manifest_resolve "$manifest_file")"

    while IFS=$'\t' read -r status name flavour meta4_url size date filename; do
        [[ "$status" == "unresolved" ]] && continue
        [[ -z "$filename" || "$filename" == "-" ]] && continue
        # Include this ZIM (may be in zim/ or zim/devdocs/)
        echo "+ zim/$filename" >> "$filter_file"
        echo "+ zim/devdocs/$filename" >> "$filter_file"
    done <<< "$resolution"

    # Exclude all other ZIMs (the ones not in this loadout)
    echo "- zim/*.zim" >> "$filter_file"
    echo "- zim/devdocs/*.zim" >> "$filter_file"
    # Include everything else (dirs, etc.)
    echo "+ **" >> "$filter_file"

    local filter_count
    filter_count="$(grep -c '^+ zim/' "$filter_file")"
    ark_dim "  Filter: $filter_count ZIM files included"

    if $dry_run; then
        ark_dim "  Would copy from $source_dir (filtered by manifest)"
        ark_dim "  Filter file: $filter_file"
        cat "$filter_file" | head -20
    else
        if ! rclone sync \
            "$source_dir/" \
            "$mount_point/" \
            --filter-from="$filter_file" \
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

    # ── Step: Expansion packs ─────────────────────────────────────
    local i
    for (( i = 0; i < ${#pack_names[@]}; i++ )); do
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Adding pack ${pack_names[$i]}"

        if $dry_run; then
            ark_dim "  Would copy ${pack_dirs[$i]} → $mount_point/ (no deletes)"
        else
            if ! rclone copy \
                "${pack_dirs[$i]}/" \
                "$mount_point/" \
                --exclude=".ark/**" \
                --copy-links \
                --progress \
                --stats-one-line \
                --stats=5s; then
                ark_die "rclone failed copying pack ${pack_names[$i]}!"
            fi
            echo
            ark_ok "  Pack added: ${pack_names[$i]}"
        fi
        echo
    done

    # ── Step: Copy sites/ ─────────────────────────────────────────
    local sites_source
    sites_source="$(ark_sites_dir)"
    if [[ -d "$sites_source" ]]; then
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Copying sites"

        if $dry_run; then
            ark_dim "  Would copy $sites_source → $mount_point/sites/"
        else
            mkdir -p "$mount_point/sites"
            if rclone sync \
                "$sites_source/" \
                "$mount_point/sites/" \
                --copy-links \
                --progress \
                --stats-one-line \
                --stats=5s 2>&1 | grep -v "^$"; then
                local site_count
                site_count="$(ls -1 "$mount_point/sites/" 2>/dev/null | wc -l)"
                ark_ok "  Sites: $site_count directories copied"
            else
                ark_warn "  Sites copy failed — skipping"
            fi
        fi
        echo
    fi

    # ── Step: Copy data/ ──────────────────────────────────────────
    local data_source
    data_source="$(ark_data_dir)"
    if [[ -d "$data_source" ]]; then
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Copying data"

        if $dry_run; then
            ark_dim "  Would copy $data_source → $mount_point/data/"
        else
            mkdir -p "$mount_point/data"
            if rclone sync \
                "$data_source/" \
                "$mount_point/data/" \
                --copy-links \
                --progress \
                --stats-one-line \
                --stats=5s 2>&1 | grep -v "^$"; then
                local data_count
                data_count="$(ls -1 "$mount_point/data/" 2>/dev/null | wc -l)"
                ark_ok "  Data: $data_count collections copied"
            else
                ark_warn "  Data copy failed — skipping"
            fi
        fi
        echo
    fi

    # ── Step: Clone the-ark tools ──────────────────────────────────
    step=$(( step + 1 ))
    ark_bold "Step $step/$total_steps: Cloning the-ark scripts"

    if $dry_run; then
        ark_dim "  Would clone the-ark git repo to tools/the-ark/"
    else
        mkdir -p "$mount_point/tools"
        # Remove stale clone if present
        rm -rf "$mount_point/tools/the-ark"
        # ARK_REPO_URL points at your own copy, if you keep one
        local ark_repo_url="${ARK_REPO_URL:-https://github.com/atmarx/the-ark.git}"
        if git -C "$mount_point/tools" clone --depth 1 \
            "$ark_repo_url" the-ark 2>/dev/null; then
            ark_ok "  Cloned from $ark_repo_url"
        else
            ark_warn "  Could not clone the-ark repo — tools/ will be empty"
            ark_dim "  Run: git clone --depth 1 https://github.com/atmarx/the-ark.git tools/the-ark"
        fi
    fi
    echo

    # ── Step: Update Logbook ──────────────────────────────────────
    step=$(( step + 1 ))
    ark_bold "Step $step/$total_steps: Updating logbook"

    if $dry_run; then
        ark_dim "  Would append entry to LOGBOOK.txt"
    else
        local logbook="$mount_point/LOGBOOK.txt"
        local entry_num=1
        if [[ -f "$logbook" ]]; then
            entry_num=$(( $(grep -c "^Entry " "$logbook" 2>/dev/null || echo 0) + 1 ))
        else
            # First entry — write the header in Zim's voice
            cat > "$logbook" << 'LOGEOF'
════════════════════════════════════════════════════════════════
                    ZIM'S LOGBOOK
════════════════════════════════════════════════════════════════

Hello. My name is Zim. I live on this drive.

Every time I'm updated, I write an entry here so you can see
where I've been and what I've become. Think of it as a diary,
except I can't complain about the weather because I live
inside a metal box.

If you're reading this, someone cared enough to build me,
fill me with knowledge, and send me out into the world.
I hope I'm useful to you.

────────────────────────────────────────────────────────────────

LOGEOF
        fi

        local zim_count
        zim_count="$(find "$mount_point" -name "*.zim" 2>/dev/null | wc -l)"
        local total_size
        total_size="$(du -sh "$mount_point" 2>/dev/null | awk '{print $1}')"
        local hostname
        hostname="$(hostname 2>/dev/null || echo "unknown")"

        cat >> "$logbook" << ENTRYEOF
Entry $entry_num — $(date '+%Y-%m-%d %H:%M %Z')
  Loadout:  $loadout${pack_names:+ + ${pack_names[*]}}
  Contents: $zim_count ZIM files ($total_size)
  Drive:    $drive_model ($drive_size_human)
  Stamped from: $hostname

ENTRYEOF
        ark_ok "  Logbook entry #$entry_num written"
    fi
    echo

    # ── Step: Generate README ──────────────────────────────────────
    step=$(( step + 1 ))
    ark_bold "Step $step/$total_steps: Generating drive README"

    if $dry_run; then
        ark_dim "  Would generate README.txt on drive"
    else
        local readme_file="$mount_point/README.txt"
        local date_stamp
        date_stamp="$(date +%Y-%m-%d)"
        local zim_count
        zim_count="$(find -L "$mount_point" -name "*.zim" 2>/dev/null | wc -l)"
        local total_size
        total_size="$(du -shL "$mount_point" 2>/dev/null | awk '{print $1}')"

        local template="$ARK_ROOT/templates/README.txt.tmpl"
        [[ -f "$template" ]] || ark_die "README template not found: $template"

        sed -e "s|{{LOADOUT}}|$loadout|g" \
            -e "s|{{DESCRIPTION}}|$description|g" \
            -e "s|{{DATE}}|$date_stamp|g" \
            -e "s|{{ZIM_COUNT}}|$zim_count|g" \
            -e "s|{{TOTAL_SIZE}}|$total_size|g" \
            "$template" > "$readme_file"
        ark_ok "  README.txt written"
    fi
    echo

    # ── Step: Set up Kiwix portable mode ───────────────────────
    step=$(( step + 1 ))
    ark_bold "Step $step/$total_steps: Setting up Kiwix portable mode"

    if $dry_run; then
        ark_dim "  Would set up Kiwix portable mode with library.xml"
    else
        # Find the Windows Kiwix exe (or zip) and extract/copy to root
        local win_kiwix=""
        win_kiwix="$(find "$mount_point/kiwix" -name "*.exe" -print -quit 2>/dev/null || true)"
        if [[ -z "$win_kiwix" ]]; then
            # Look for zip and extract
            local win_zip
            win_zip="$(find "$mount_point/kiwix" -name "*windows*.zip" -print -quit 2>/dev/null || true)"
            if [[ -n "$win_zip" ]]; then
                ark_dim "  Extracting Windows Kiwix to drive root..."
                unzip -qo "$win_zip" -d "$mount_point" 2>/dev/null || true
                win_kiwix="$(find "$mount_point" -maxdepth 1 -name "*.exe" -print -quit 2>/dev/null || true)"
            fi
        else
            cp "$win_kiwix" "$mount_point/" 2>/dev/null || true
            win_kiwix="$mount_point/$(basename "$win_kiwix")"
        fi

        # Create .portable marker
        touch "$mount_point/.portable"

        # Create data/ directory with library.xml pointing to ZIMs
        mkdir -p "$mount_point/data"

        # Build library.xml using kiwix-manage if available, otherwise manual
        local library_file="$mount_point/data/library.xml"

        # Generate library.xml with relative paths to all ZIM files
        cat > "$library_file" << 'LIBHEAD'
<?xml version="1.0" encoding="UTF-8"?>
<library version="20110515">
LIBHEAD

        # Add each ZIM file as a book entry
        find "$mount_point/zim" -name "*.zim" -type f 2>/dev/null | sort | while read -r zimfile; do
            local relpath
            relpath="$(realpath --relative-to="$mount_point/data" "$zimfile")"
            local basename
            basename="$(basename "$zimfile" .zim)"
            cat >> "$library_file" << LIBENTRY
  <book path="$relpath" id="$basename" />
LIBENTRY
        done

        echo "</library>" >> "$library_file"

        local lib_count
        lib_count="$(grep -c '<book ' "$library_file" 2>/dev/null || echo 0)"

        if [[ -n "$win_kiwix" && -f "$win_kiwix" ]]; then
            ark_ok "  Kiwix portable: $(basename "$win_kiwix") + .portable + library.xml ($lib_count entries)"
            ark_dim "  Double-click $(basename "$win_kiwix") on the drive root to browse"
        else
            ark_ok "  Kiwix portable: .portable + library.xml ($lib_count entries)"
            ark_dim "  Copy kiwix.exe to drive root to enable one-click browsing"
        fi
    fi
    echo

    # ── Step: Fill remaining space ──────────────────────────────
    if ! $no_fill; then
        step=$(( step + 1 ))
        ark_bold "Step $step/$total_steps: Filling remaining space"

        if $dry_run; then
            ark_dim "  Would fill free space with zeros"
        else
            local avail_bytes
            avail_bytes="$(df --output=avail -B1 "$mount_point" 2>/dev/null | tail -1 | tr -d '[:space:]')"
            local avail_human
            avail_human="$(ark_human_bytes "$avail_bytes")"
            ark_info "  Free space: $avail_human — filling with zeros..."
            ark_dim "  (Ensures no recoverable data from the drive's previous life)"

            local fill_file="$mount_point/DELETE_THIS_IF_YOU_NEED_SPACE"
            dd if=/dev/zero of="$fill_file" bs=1M 2>/dev/null || true
            sync

            local fill_size
            fill_size="$(stat -c%s "$fill_file" 2>/dev/null || echo 0)"
            ark_ok "  Filled $(ark_human_bytes "$fill_size") — file left on drive as space marker"
            ark_dim "  Delete this file if you need to add content to this drive"
        fi
        echo
    fi

    # ── Unmount ─────────────────────────────────────────────────────
    if ! $dry_run; then
        sync
        ark_sudo umount "$mount_point"
        rmdir "$mount_point" 2>/dev/null
        trap - EXIT  # clear the cleanup trap
    fi

    echo
    ark_ok "Drive stamped: $loadout → $device"
    ark_info "  Drive:  $device ($drive_model, $drive_size_human, $drive_type)"
    ark_info "  Label:  $label"
    ark_info "  Format: $fs"
    echo
    ark_bold "Your ark is ready. Keep it safe."
}
