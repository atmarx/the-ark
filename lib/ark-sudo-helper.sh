#!/usr/bin/env bash
# ark-sudo-helper.sh — constrained privilege escalation for drive operations
#
# This script is the ONLY thing that gets passwordless sudo via sudoers:
#   <you> ALL=(ALL) NOPASSWD: /path/to/the-ark/lib/ark-sudo-helper.sh
#
# Every privileged operation in ark-stamp.sh routes through here.
# The guard: refuse to operate on any NVMe device (the system disk).
# Everything on /dev/sd* is a USB drive and fair game.

set -euo pipefail

die() { echo "ark-sudo-helper: $*" >&2; exit 1; }

# Guard: reject any argument that references an NVMe device
guard_nvme() {
    for arg in "$@"; do
        [[ "$arg" == /dev/nvme* ]] && die "refusing to operate on NVMe device: $arg"
    done
}

cmd="${1:?Usage: ark-sudo-helper <command> [args...]}"
shift

case "$cmd" in
    # ── Drive health ──────────────────────────────────────────
    smartctl)
        guard_nvme "$@"
        exec /usr/sbin/smartctl "$@"
        ;;

    # ── Secure erase (ATA) ────────────────────────────────────
    hdparm)
        guard_nvme "$@"
        exec /usr/sbin/hdparm "$@"
        ;;

    # ── Partitioning ──────────────────────────────────────────
    sgdisk)
        guard_nvme "$@"
        exec /usr/sbin/sgdisk "$@"
        ;;
    partprobe)
        guard_nvme "$@"
        exec /usr/bin/partprobe "$@"
        ;;

    # ── Formatting ────────────────────────────────────────────
    mkfs.exfat)
        guard_nvme "$@"
        exec /usr/sbin/mkfs.exfat "$@"
        ;;
    mkfs.ext4)
        guard_nvme "$@"
        exec /usr/sbin/mkfs.ext4 "$@"
        ;;
    mkfs.ntfs)
        guard_nvme "$@"
        exec /usr/sbin/mkfs.ntfs "$@"
        ;;

    # ── Mount / unmount ───────────────────────────────────────
    mount)
        exec /usr/bin/mount "$@"
        ;;
    umount)
        exec /usr/bin/umount "$@"
        ;;

    # ── Ownership ─────────────────────────────────────────────
    chown)
        exec /usr/bin/chown "$@"
        ;;

    # ── Write zeros (erase / fill) ────────────────────────────
    dd)
        # Only allow if=/dev/zero — never clone or read devices
        local_if=""
        for arg in "$@"; do
            [[ "$arg" == if=* ]] && local_if="${arg#if=}"
            [[ "$arg" == of=/dev/nvme* ]] && die "refusing to write to NVMe device"
        done
        [[ "$local_if" == "/dev/zero" ]] || die "dd only allowed with if=/dev/zero (got: if=$local_if)"
        exec /usr/bin/dd "$@"
        ;;

    # ── SSD TRIM ──────────────────────────────────────────────
    blkdiscard)
        guard_nvme "$@"
        exec /usr/sbin/blkdiscard "$@"
        ;;

    # ── Sync ──────────────────────────────────────────────────
    sync)
        exec /usr/bin/sync "$@"
        ;;

    # ── Health check (for ark_sudo probe) ───────────────────
    --check)
        exit 0
        ;;

    *)
        die "unknown command: $cmd"
        ;;
esac
