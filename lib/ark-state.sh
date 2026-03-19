#!/usr/bin/env bash
# ark-state.sh — JSON state tracking for downloaded files
# Sourced by ark scripts. Requires ark-common.sh to be loaded first.

# State file lives at $ARK_STAGING/.ark/state.json
# Structure:
# {
#   "files": {
#     "medium/zim/wikipedia_en_all_maxi_2026-02.zim": {
#       "name": "wikipedia_en_all",
#       "flavour": "maxi",
#       "date": "2026-02",
#       "size": 123456789,
#       "sha256": "abcdef...",
#       "verified": true,
#       "downloaded": "2026-03-14T20:00:00Z",
#       "source_url": "https://..."
#     }
#   }
# }

# Get the state file path
_ark_state_file() {
    local staging
    staging="$(ark_staging_path)"
    echo "$staging/.ark/state.json"
}

# Initialize state file if it doesn't exist
ark_state_init() {
    local state_file
    state_file="$(_ark_state_file)"
    if [[ ! -f "$state_file" ]]; then
        echo '{"files":{}}' | jq . > "$state_file"
    fi
}

# Atomic write to state file (write tmp, then mv)
_ark_state_write() {
    local state_file
    state_file="$(_ark_state_file)"
    local tmp="${state_file}.tmp"
    cat > "$tmp"
    mv -f "$tmp" "$state_file"
}

# Get a value from state for a specific file path
# Usage: ark_state_get "medium/zim/foo.zim" ".sha256"
ark_state_get() {
    local file_key="$1"
    local field="$2"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || { echo "null"; return; }
    jq -r ".files[\"$file_key\"]${field} // empty" "$state_file"
}

# Check if a file entry exists in state
ark_state_has() {
    local file_key="$1"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || return 1
    jq -e ".files[\"$file_key\"] // empty" "$state_file" &>/dev/null
}

# Set/update a file entry in state
# Usage: ark_state_set "medium/zim/foo.zim" name flavour date size sha256 source_url
ark_state_set() {
    local file_key="$1"
    local name="$2"
    local flavour="$3"
    local date_str="$4"
    local size="$5"
    local sha256="$6"
    local source_url="$7"
    local state_file
    state_file="$(_ark_state_file)"
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    ark_state_init

    jq --arg key "$file_key" \
       --arg name "$name" \
       --arg flavour "$flavour" \
       --arg date "$date_str" \
       --argjson size "$size" \
       --arg sha256 "$sha256" \
       --arg url "$source_url" \
       --arg now "$now" \
       '.files[$key] = {
           name: $name,
           flavour: $flavour,
           date: $date,
           size: $size,
           sha256: $sha256,
           verified: true,
           downloaded: $now,
           source_url: $url
       }' "$state_file" | _ark_state_write
}

# Remove a file entry from state
ark_state_remove() {
    local file_key="$1"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || return 0
    jq --arg key "$file_key" 'del(.files[$key])' "$state_file" | _ark_state_write
}

# List all file keys in state
# Optional filter: ark_state_list "medium/" to list only medium loadout files
ark_state_list() {
    local prefix="${1:-}"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || return 0

    if [[ -n "$prefix" ]]; then
        jq -r ".files | keys[] | select(startswith(\"$prefix\"))" "$state_file"
    else
        jq -r '.files | keys[]' "$state_file"
    fi
}

# Get full entry as JSON for a file
ark_state_entry() {
    local file_key="$1"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || { echo "null"; return; }
    jq ".files[\"$file_key\"]" "$state_file"
}

# Mark a file as verified (or not)
ark_state_set_verified() {
    local file_key="$1"
    local verified="${2:-true}"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || return 1
    jq --arg key "$file_key" \
       --argjson v "$verified" \
       '.files[$key].verified = $v' "$state_file" | _ark_state_write
}

# Get total size of all files in state (optionally filtered by prefix)
ark_state_total_size() {
    local prefix="${1:-}"
    local state_file
    state_file="$(_ark_state_file)"

    [[ -f "$state_file" ]] || { echo 0; return; }

    if [[ -n "$prefix" ]]; then
        jq "[.files | to_entries[] | select(.key | startswith(\"$prefix\")) | .value.size] | add // 0" "$state_file"
    else
        jq '[.files[].size] | add // 0' "$state_file"
    fi
}
