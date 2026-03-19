#!/usr/bin/env bash
# ark-init.sh — initialize a staging area for the ark

ark_init() {
    local staging_path="${1:-}"

    if [[ -z "$staging_path" ]]; then
        ark_die "Usage: ark init <staging-path>"
    fi

    # Expand to absolute path
    staging_path="$(realpath -m "$staging_path")"

    ark_info "Initializing staging area at: $staging_path"

    # Create directory structure
    mkdir -p "$staging_path/.ark"

    # Write config from template or defaults
    local config="$staging_path/.ark/config.yml"
    if [[ ! -f "$config" ]]; then
        cat > "$config" <<YAML
# Ark staging area configuration
# Override any value with ARK_* environment variables

staging_path: $staging_path

# Kiwix OPDS catalog
catalog_url: https://library.kiwix.org/catalog/v2/entries
catalog_max_age_hours: 24

# Download settings
download_method: http    # http | torrent
download_base: https://download.kiwix.org

# qBittorrent WebUI (for --method=torrent)
qbittorrent:
  url: ""
  username: ""
  password: ""
YAML
        ark_ok "Created config: $config"
    else
        ark_dim "  Config already exists: $config"
    fi

    # Initialize state file
    local state="$staging_path/.ark/state.json"
    if [[ ! -f "$state" ]]; then
        echo '{"files":{}}' | jq . > "$state"
        ark_ok "Created state: $state"
    fi

    # Save staging path link in repo
    echo "$staging_path" > "$ARK_ROOT/.ark-staging"
    ark_ok "Linked staging path: $ARK_ROOT/.ark-staging -> $staging_path"

    echo
    ark_ok "Staging area ready!"
    ark_info "Next steps:"
    echo "  1. Edit $config to configure qBittorrent (optional)"
    echo "  2. Run: ark sync medium"
}
