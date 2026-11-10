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

# Resolve the sites directory. Priority:
#   1. ARK_SITES_DIR env var
#   2. <staging>/sites/
ark_sites_dir() {
    if [[ -n "${ARK_SITES_DIR:-}" ]]; then
        echo "$ARK_SITES_DIR"
        return
    fi
    echo "$(ark_staging_path)/sites"
}

# Resolve the data directory. Priority:
#   1. ARK_DATA_DIR env var
#   2. <staging>/data/
ark_data_dir() {
    if [[ -n "${ARK_DATA_DIR:-}" ]]; then
        echo "$ARK_DATA_DIR"
        return
    fi
    echo "$(ark_staging_path)/data"
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

    ARK_CATALOG_URL="${ARK_CATALOG_URL:-$(yq -r '.catalog_url // "https://opds.library.kiwix.org/catalog/v2/entries"' "$config")}"
    ARK_CATALOG_MAX_AGE="${ARK_CATALOG_MAX_AGE:-$(yq -r '.catalog_max_age_hours // 24' "$config")}"
    ARK_DOWNLOAD_METHOD="${ARK_DOWNLOAD_METHOD:-$(yq -r '.download_method // "http"' "$config")}"
    ARK_DOWNLOAD_BASE="${ARK_DOWNLOAD_BASE:-$(yq -r '.download_base // "https://download.kiwix.org"' "$config")}"

    # qBittorrent settings
    ARK_QBT_URL="${ARK_QBT_URL:-$(yq -r '.qbittorrent.url // ""' "$config")}"
    ARK_QBT_USER="${ARK_QBT_USER:-$(yq -r '.qbittorrent.username // ""' "$config")}"
    ARK_QBT_PASS="${ARK_QBT_PASS:-$(yq -r '.qbittorrent.password // ""' "$config")}"

    export ARK_CATALOG_URL ARK_CATALOG_MAX_AGE ARK_DOWNLOAD_METHOD ARK_DOWNLOAD_BASE
    export ARK_QBT_URL ARK_QBT_USER ARK_QBT_PASS

    # Local GGUF library for expansion packs (optional)
    ARK_MODELS_SOURCE="${ARK_MODELS_SOURCE:-$(yq -r '.models_source // ""' "$config")}"
    export ARK_MODELS_SOURCE
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
        ark_manifest_validate "$name" || ark_die "Manifest validation failed: $name"
        echo "$name"
        return
    fi

    # Check repo manifests dir
    local repo_manifest="$ARK_ROOT/manifests/${name}.yml"
    if [[ -f "$repo_manifest" ]]; then
        ark_manifest_validate "$repo_manifest" || ark_die "Manifest validation failed: $repo_manifest"
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
    if ! command -v "$cmd" &>/dev/null && [[ ! -x "/usr/sbin/$cmd" ]]; then
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

# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------

# curl wrapper with default timeouts — use for metadata/API calls.
# For large file downloads, use curl directly with --connect-timeout only.
ARK_CURL_CONNECT_TIMEOUT="${ARK_CURL_CONNECT_TIMEOUT:-30}"
ARK_CURL_MAX_TIME="${ARK_CURL_MAX_TIME:-300}"

ark_curl() {
    curl --connect-timeout "$ARK_CURL_CONNECT_TIMEOUT" \
         --max-time "$ARK_CURL_MAX_TIME" \
         "$@"
}

# Retry wrapper — retries a command up to N times with backoff.
# Usage: ark_retry 3 curl -sL --fail -o /tmp/foo http://example.com/foo
ark_retry() {
    local max_retries="$1"; shift
    local attempt=1
    while (( attempt <= max_retries )); do
        if "$@"; then
            return 0
        fi
        if (( attempt < max_retries )); then
            ark_warn "  Attempt $attempt/$max_retries failed, retrying in $(( attempt * 5 ))s..."
            sleep $(( attempt * 5 ))
        fi
        attempt=$(( attempt + 1 ))
    done
    return 1
}

# ---------------------------------------------------------------------------
# Privilege escalation
# ---------------------------------------------------------------------------

# Route privileged commands through the sudo helper script.
# The helper validates arguments (blocks NVMe, restricts dd to if=/dev/zero).
# Falls back to plain sudo if the helper isn't configured in sudoers.
ark_sudo() {
    local helper="$ARK_ROOT/lib/ark-sudo-helper.sh"
    if [[ -x "$helper" ]] && sudo -n "$helper" --check 2>/dev/null; then
        sudo "$helper" "$@"
    else
        sudo "$@"
    fi
}

# ---------------------------------------------------------------------------
# Command initialization helper
# ---------------------------------------------------------------------------

# Common init sequence for commands that take a loadout argument.
# Sets: MANIFEST_FILE, LOADOUT, STAGING in caller's scope.
ark_init_command() {
    local usage_cmd="$1"
    local manifest_arg="${2:-}"

    if [[ -z "$manifest_arg" ]]; then
        ark_die "Usage: ark $usage_cmd <loadout|manifest.yml>"
    fi

    ark_load_config
    ark_state_init

    MANIFEST_FILE="$(ark_resolve_manifest "$manifest_arg")"
    LOADOUT="$(ark_manifest_loadout "$MANIFEST_FILE")"
    STAGING="$(ark_staging_path)"
}

# ---------------------------------------------------------------------------
# Manifest validation
# ---------------------------------------------------------------------------

# Validate a manifest file has required fields and well-formed entries.
# Returns 0 if valid, non-zero on errors (prints warnings).
ark_manifest_validate() {
    local manifest="$1"
    local errors=0

    # Check required top-level keys
    for key in loadout description target_size_gb; do
        local val
        val="$(yq -r ".$key // \"\"" "$manifest" 2>/dev/null)" || val=""
        if [[ -z "$val" || "$val" == "null" ]]; then
            ark_error "Manifest missing required key: $key"
            errors=$(( errors + 1 ))
        fi
    done

    # Check each ZIM entry has name or prefix
    local count
    count="$(yq -r '.zim | length // 0' "$manifest" 2>/dev/null)" || count=0
    local i
    for (( i = 0; i < count; i++ )); do
        local name prefix
        name="$(yq -r ".zim[$i].name // \"\"" "$manifest" 2>/dev/null)" || name=""
        prefix="$(yq -r ".zim[$i].prefix // \"\"" "$manifest" 2>/dev/null)" || prefix=""
        [[ "$name" == "null" ]] && name=""
        [[ "$prefix" == "null" ]] && prefix=""
        if [[ -z "$name" && -z "$prefix" ]]; then
            ark_error "ZIM entry $i has neither 'name' nor 'prefix'"
            errors=$(( errors + 1 ))
        fi
    done

    return "$errors"
}
