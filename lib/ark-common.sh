#!/usr/bin/env bash
# ark-common.sh — shared functions for the ark CLI
# Sourced by all other ark scripts. Never executed directly.

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors (disabled if stdout is not a terminal)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_CYAN='\033[0;36m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RESET='\033[0m'
else
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN='' C_BOLD='' C_DIM='' C_RESET=''
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
ark_info()  { echo -e "${C_BLUE}[ark]${C_RESET} $*"; }
ark_ok()    { echo -e "${C_GREEN}[ark]${C_RESET} $*"; }
ark_warn()  { echo -e "${C_YELLOW}[ark]${C_RESET} $*" >&2; }
ark_error() { echo -e "${C_RED}[ark]${C_RESET} $*" >&2; }
ark_die()   { ark_error "$@"; exit 1; }

# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------
ark_bold()  { echo -e "${C_BOLD}$*${C_RESET}"; }
ark_dim()   { echo -e "${C_DIM}$*${C_RESET}"; }

# Human-readable byte sizes
ark_human_bytes() {
    local bytes="${1:-0}"
    # Guard against non-numeric input
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        printf "? B"
        return
    fi
    if (( bytes >= 1073741824 )); then
        printf "%.1f GB" "$(echo "scale=1; $bytes / 1073741824" | bc)"
    elif (( bytes >= 1048576 )); then
        printf "%.1f MB" "$(echo "scale=1; $bytes / 1048576" | bc)"
    elif (( bytes >= 1024 )); then
        printf "%.1f KB" "$(echo "scale=1; $bytes / 1024" | bc)"
    else
        printf "%d B" "$bytes"
    fi
}

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------
# Resolve the staging path. Priority:
#   1. ARK_STAGING env var
#   2. .ark-staging file in repo root (contains path)
#   3. Fail with helpful message
ark_staging_path() {
    if [[ -n "${ARK_STAGING:-}" ]]; then
        echo "$ARK_STAGING"
        return
    fi

    local link_file="$ARK_ROOT/.ark-staging"
    if [[ -f "$link_file" ]]; then
        local path
        path="$(head -1 "$link_file" | tr -d '[:space:]')"
        if [[ -n "$path" ]]; then
            echo "$path"
            return
        fi
    fi

    ark_die "No staging path configured. Run 'ark init <path>' or set ARK_STAGING."
}

# Load staging config (config.yml from .ark/)
# Sets global variables: ARK_CATALOG_URL, ARK_CATALOG_MAX_AGE, ARK_DOWNLOAD_METHOD, etc.
ark_load_config() {
    local staging
    staging="$(ark_staging_path)"
    local config="$staging/.ark/config.yml"

    if [[ ! -f "$config" ]]; then
        ark_die "Config not found at $config — is the staging area initialized?"
    fi

    ARK_CATALOG_URL="${ARK_CATALOG_URL:-$(yq -r '.catalog_url // "https://library.kiwix.org/catalog/v2/entries"' "$config")}"
    ARK_CATALOG_MAX_AGE="${ARK_CATALOG_MAX_AGE:-$(yq -r '.catalog_max_age_hours // 24' "$config")}"
    ARK_DOWNLOAD_METHOD="${ARK_DOWNLOAD_METHOD:-$(yq -r '.download_method // "http"' "$config")}"
    ARK_DOWNLOAD_BASE="${ARK_DOWNLOAD_BASE:-$(yq -r '.download_base // "https://download.kiwix.org"' "$config")}"

    # qBittorrent settings
    ARK_QBT_URL="${ARK_QBT_URL:-$(yq -r '.qbittorrent.url // ""' "$config")}"
    ARK_QBT_USER="${ARK_QBT_USER:-$(yq -r '.qbittorrent.username // ""' "$config")}"
    ARK_QBT_PASS="${ARK_QBT_PASS:-$(yq -r '.qbittorrent.password // ""' "$config")}"

    export ARK_CATALOG_URL ARK_CATALOG_MAX_AGE ARK_DOWNLOAD_METHOD ARK_DOWNLOAD_BASE
    export ARK_QBT_URL ARK_QBT_USER ARK_QBT_PASS
}

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

# Resolve a manifest name to its file path
# Checks: manifests/<name>.yml in repo, then absolute path
ark_resolve_manifest() {
    local name="$1"

    # If it's already a path to a file
    if [[ -f "$name" ]]; then
        echo "$name"
        return
    fi

    # Check repo manifests dir
    local repo_manifest="$ARK_ROOT/manifests/${name}.yml"
    if [[ -f "$repo_manifest" ]]; then
        echo "$repo_manifest"
        return
    fi

    ark_die "Manifest not found: $name (checked $repo_manifest)"
}

# Get the loadout name from a manifest file
ark_loadout_name() {
    local manifest_file="$1"
    yq -r '.loadout' "$manifest_file"
}

# Get the loadout directory in the staging area
ark_loadout_dir() {
    local loadout="$1"
    local staging
    staging="$(ark_staging_path)"
    echo "$staging/$loadout"
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
ark_require_cmd() {
    local cmd="$1"
    local purpose="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        if [[ -n "$purpose" ]]; then
            ark_die "Required command '$cmd' not found ($purpose)"
        else
            ark_die "Required command '$cmd' not found"
        fi
    fi
}

ark_check_deps() {
    ark_require_cmd curl "downloading files"
    ark_require_cmd jq "JSON state management"
    ark_require_cmd yq "YAML manifest parsing"
    ark_require_cmd xmlstarlet "OPDS catalog parsing"
    ark_require_cmd sha256sum "checksum verification"
}
