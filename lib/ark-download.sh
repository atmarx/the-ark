#!/usr/bin/env bash
# ark-download.sh — download engine with HTTP/torrent support and checksum verification
# Sourced by ark scripts. Requires ark-common.sh and ark-catalog.sh.

# ---------------------------------------------------------------------------
# Checksum extraction from .meta4 files
# ---------------------------------------------------------------------------

# Fetch a .meta4 file and extract the SHA-256 hash
# Usage: ark_download_get_sha256 "https://...foo.zim.meta4"
ark_download_get_sha256() {
    local meta4_url="$1"
    local meta4_content
    meta4_content="$(curl -sL --fail "$meta4_url")" || {
        ark_warn "Failed to fetch meta4: $meta4_url"
        echo ""
        return 1
    }

    local sha256
    sha256="$(echo "$meta4_content" | xmlstarlet sel \
        -N ml="urn:ietf:params:xml:ns:metalink" \
        -t -v '//ml:hash[@type="sha-256"]' 2>/dev/null)" || true

    if [[ -z "$sha256" ]]; then
        ark_warn "No SHA-256 found in meta4: $meta4_url"
        echo ""
        return 1
    fi

    echo "$sha256"
}

# ---------------------------------------------------------------------------
# HTTP download with resume
# ---------------------------------------------------------------------------

# Download a file via HTTP with resume support
# Usage: ark_download_http url dest_path [expected_size]
ark_download_http() {
    local url="$1"
    local dest="$2"
    local expected_size="${3:-}"

    local dest_dir
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"

    local filename
    filename="$(basename "$dest")"

    # If file already exists with correct size, skip
    if [[ -f "$dest" && -n "$expected_size" ]]; then
        local actual_size
        actual_size="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
        if (( actual_size == expected_size )); then
            ark_dim "  Already complete: $filename"
            return 0
        fi
    fi

    ark_info "Downloading (HTTP): $filename"
    if [[ -n "$expected_size" ]]; then
        ark_dim "  Size: $(ark_human_bytes "$expected_size")"
    fi

    # Use curl with resume support and progress bar
    local curl_args=(
        -L                  # follow redirects
        -C -                # resume from where we left off
        -o "$dest"          # output file
        --fail              # fail on HTTP errors
        --progress-bar      # show progress
    )

    if ! curl "${curl_args[@]}" "$url"; then
        ark_error "Download failed: $url"
        return 1
    fi

    # Verify size if expected
    if [[ -n "$expected_size" ]]; then
        local actual_size
        actual_size="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
        if (( actual_size != expected_size )); then
            ark_error "Size mismatch for $filename: expected $(ark_human_bytes "$expected_size"), got $(ark_human_bytes "$actual_size")"
            return 1
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Torrent download via transmission-cli
# ---------------------------------------------------------------------------

# Download a file via torrent using transmission-cli
# Usage: ark_download_torrent torrent_url dest_dir expected_filename
ark_download_torrent() {
    local torrent_url="$1"
    local dest_dir="$2"
    local expected_filename="$3"

    ark_require_cmd transmission-cli "torrent downloads"

    mkdir -p "$dest_dir"

    local dest="$dest_dir/$expected_filename"

    # If file already exists, skip
    if [[ -f "$dest" ]]; then
        ark_dim "  Already complete: $expected_filename"
        return 0
    fi

    ark_info "Downloading (torrent): $expected_filename"
    ark_dim "  Torrent: $torrent_url"

    # transmission-cli downloads to the specified directory and exits when complete
    # -w sets the download directory
    if ! transmission-cli \
        -w "$dest_dir" \
        -ep \
        "$torrent_url"; then
        ark_error "Torrent download failed: $torrent_url"
        return 1
    fi

    # Verify the expected file appeared
    if [[ ! -f "$dest" ]]; then
        # transmission-cli might save with a slightly different name — look for it
        local found
        found="$(find "$dest_dir" -maxdepth 1 -name "*.zim" -newer "$dest_dir" -print -quit 2>/dev/null || true)"
        if [[ -n "$found" && "$(basename "$found")" != "$expected_filename" ]]; then
            ark_warn "Torrent saved as $(basename "$found"), expected $expected_filename"
            mv "$found" "$dest"
        elif [[ -z "$found" ]]; then
            ark_error "Expected file not found after torrent download: $expected_filename"
            return 1
        fi
    fi

    ark_ok "Torrent complete: $expected_filename"
    return 0
}

# ---------------------------------------------------------------------------
# Checksum verification
# ---------------------------------------------------------------------------

# Verify SHA-256 checksum of a file
# Usage: ark_download_verify dest_path expected_sha256
ark_download_verify() {
    local dest="$1"
    local expected_sha256="$2"
    local filename
    filename="$(basename "$dest")"

    if [[ -z "$expected_sha256" ]]; then
        ark_warn "No checksum to verify for $filename"
        return 0
    fi

    ark_info "Verifying checksum: $filename..."
    local actual_sha256
    actual_sha256="$(sha256sum "$dest" | awk '{print $1}')"

    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        ark_error "Checksum mismatch for $filename"
        ark_error "  Expected: $expected_sha256"
        ark_error "  Got:      $actual_sha256"
        return 1
    fi

    ark_ok "Checksum OK: $filename"
    return 0
}

# ---------------------------------------------------------------------------
# High-level download: fetch + verify + update state
# ---------------------------------------------------------------------------

# Download a ZIM file: resolve URL, fetch meta4 checksum, download, verify, update state
# Usage: ark_download_zim loadout name flavour meta4_url size date filename
ark_download_zim() {
    local loadout="$1"
    local name="$2"
    local flavour="$3"
    # Normalize "-" placeholder to empty
    [[ "$flavour" == "-" ]] && flavour=""
    local meta4_url="$4"
    local size="$5"
    local date_str="$6"
    local filename="$7"

    local staging
    staging="$(ark_staging_path)"
    local dest="$staging/$loadout/zim/$filename"
    local file_key="$loadout/zim/$filename"
    local direct_url
    direct_url="$(ark_catalog_meta4_to_url "$meta4_url")"

    # Get checksum from meta4
    local sha256=""
    sha256="$(ark_download_get_sha256 "$meta4_url")" || true

    # Download based on method
    case "${ARK_DOWNLOAD_METHOD:-http}" in
        torrent)
            local torrent_url="${direct_url}.torrent"
            local dest_dir="$staging/$loadout/zim"
            if ! ark_download_torrent "$torrent_url" "$dest_dir" "$filename"; then
                return 1
            fi
            ;;
        http|*)
            if ! ark_download_http "$direct_url" "$dest" "$size"; then
                return 1
            fi
            ;;
    esac

    # Verify checksum
    if [[ -n "$sha256" ]]; then
        if ! ark_download_verify "$dest" "$sha256"; then
            ark_error "Removing corrupt file: $filename"
            rm -f "$dest"
            return 1
        fi
    fi

    # Update state
    local file_date
    file_date="$(ark_catalog_filename_date "$filename")"
    ark_state_set "$file_key" "$name" "$flavour" "$file_date" "$size" "$sha256" "$direct_url"

    return 0
}

# Download a PDF file
# Usage: ark_download_pdf loadout url filename
ark_download_pdf() {
    local loadout="$1"
    local url="$2"
    local filename="$3"

    local staging
    staging="$(ark_staging_path)"
    local dest="$staging/$loadout/pdfs/$filename"

    if [[ -f "$dest" ]]; then
        ark_dim "  Already have: $filename"
        return 0
    fi

    ark_download_http "$url" "$dest"
}
