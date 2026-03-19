#!/usr/bin/env bash
# ark-kiwix.sh — fetch Kiwix platform binaries for bundling on drives
# Sourced by ark scripts. Requires ark-common.sh.

readonly _KIWIX_RELEASE_BASE="https://download.kiwix.org/release"

# Release directory structure:
#   kiwix-android/     → APKs (kiwix-X.Y.Z.apk, org.kiwix.kiwixmobile.standalone-X.Y.Z.apk)
#   kiwix-desktop/     → source tarballs (not useful for binary distribution)
#   kiwix-js-electron/ → cross-platform Electron app (AppImage, exe, dmg)
#   kiwix-macos/       → macOS DMGs
#   kiwix-tools/       → kiwix-serve binaries (Linux, Windows, macOS tarballs/zips)

# Scrape a release directory for the latest file matching a pattern.
# Returns the filename (not full URL).
_ark_kiwix_latest() {
    local release_dir="$1"
    local pattern="$2"

    local url="${_KIWIX_RELEASE_BASE}/${release_dir}/"
    local listing
    listing="$(curl -sL "$url")" || {
        ark_warn "Failed to fetch release listing: $url"
        return 1
    }

    # Extract hrefs, filter by pattern, sort by version, take latest
    echo "$listing" \
        | grep -oP 'href="\K[^"]+' \
        | grep -E "$pattern" \
        | sort -V \
        | tail -1
}

# Download a Kiwix binary to the loadout's kiwix/ directory
_ark_kiwix_download() {
    local release_dir="$1"
    local filename="$2"
    local dest_subdir="$3"
    local loadout_dir="$4"

    local url="${_KIWIX_RELEASE_BASE}/${release_dir}/${filename}"
    local dest="${loadout_dir}/kiwix/${dest_subdir}/${filename}"

    mkdir -p "$(dirname "$dest")"

    if [[ -f "$dest" ]]; then
        ark_dim "  Already have: $dest_subdir/$filename"
        return 0
    fi

    ark_info "Fetching: $dest_subdir/$filename"
    curl -sL --fail --progress-bar -o "$dest" "$url" || {
        ark_error "Failed to download: $url"
        rm -f "$dest"
        return 1
    }
    ark_ok "  Downloaded: $dest_subdir/$filename"
}

# Fetch all requested platform binaries for a loadout
# Usage: ark_kiwix_fetch loadout_dir platform [platform...]
# Platforms: desktop, android, macos, tools
ark_kiwix_fetch() {
    local loadout_dir="$1"
    shift
    local platforms=("$@")

    ark_info "Fetching Kiwix platform binaries..."

    for platform in "${platforms[@]}"; do
        case "$platform" in
            desktop)
                # Kiwix JS Electron — cross-platform desktop app
                # Linux AppImage
                local linux_file
                linux_file="$(_ark_kiwix_latest "kiwix-js-electron" '\.AppImage$')" || continue
                if [[ -n "$linux_file" ]]; then
                    _ark_kiwix_download "kiwix-js-electron" "$linux_file" "linux" "$loadout_dir"
                fi

                # Windows exe/installer
                local win_file
                win_file="$(_ark_kiwix_latest "kiwix-js-electron" '_Win\.zip$')" || continue
                if [[ -z "$win_file" ]]; then
                    win_file="$(_ark_kiwix_latest "kiwix-js-electron" '\.exe$')" || continue
                fi
                if [[ -n "$win_file" ]]; then
                    _ark_kiwix_download "kiwix-js-electron" "$win_file" "windows" "$loadout_dir"
                fi
                ;;

            android)
                local apk
                apk="$(_ark_kiwix_latest "kiwix-android" '\.apk$')" || continue
                if [[ -n "$apk" ]]; then
                    _ark_kiwix_download "kiwix-android" "$apk" "android" "$loadout_dir"
                fi
                ;;

            macos)
                local dmg
                dmg="$(_ark_kiwix_latest "kiwix-macos" '\.dmg$')" || continue
                if [[ -n "$dmg" ]]; then
                    _ark_kiwix_download "kiwix-macos" "$dmg" "macos" "$loadout_dir"
                fi
                # Also check kiwix-js-electron for macOS DMG
                if [[ -z "$dmg" ]]; then
                    dmg="$(_ark_kiwix_latest "kiwix-js-electron" '_macOS\.dmg$')" || continue
                    if [[ -n "$dmg" ]]; then
                        _ark_kiwix_download "kiwix-js-electron" "$dmg" "macos" "$loadout_dir"
                    fi
                fi
                ;;

            tools)
                # kiwix-serve and related tools — Linux x86_64, aarch64, Windows
                local linux_x86
                linux_x86="$(_ark_kiwix_latest "kiwix-tools" 'linux-x86_64.*\.tar\.gz$')" || continue
                if [[ -n "$linux_x86" ]]; then
                    _ark_kiwix_download "kiwix-tools" "$linux_x86" "serve" "$loadout_dir"
                fi

                local linux_arm
                linux_arm="$(_ark_kiwix_latest "kiwix-tools" 'linux-aarch64.*\.tar\.gz$')" || true
                if [[ -n "$linux_arm" ]]; then
                    _ark_kiwix_download "kiwix-tools" "$linux_arm" "serve" "$loadout_dir"
                fi

                local win_tools
                win_tools="$(_ark_kiwix_latest "kiwix-tools" 'win-x86_64.*\.zip$')" || true
                if [[ -n "$win_tools" ]]; then
                    _ark_kiwix_download "kiwix-tools" "$win_tools" "serve" "$loadout_dir"
                fi
                ;;

            *)
                ark_warn "Unknown Kiwix platform: $platform"
                ;;
        esac
    done

    ark_ok "Kiwix binaries synced."
}
