#!/usr/bin/env bash
# ark-models.sh — language models and llama.cpp builds for expansion packs
# Sourced by ark scripts. Requires ark-common.sh, ark-state.sh, ark-download.sh.
#
# Models are pinned to a Hugging Face revision and checked against the sha256
# in the manifest.  If ARK_MODELS_SOURCE points at an existing GGUF library,
# matching files are linked from there instead of downloaded.

readonly _ARK_HF_BASE="https://huggingface.co"
readonly _ARK_LLAMA_RELEASES="https://github.com/ggml-org/llama.cpp/releases/download"

# Is this manifest an expansion pack (laid on top of another loadout)?
ark_manifest_is_pack() {
    local manifest="$1"
    [[ "$(yq -r '.pack // false' "$manifest")" == "true" ]]
}

# Count model entries in a manifest
ark_manifest_model_count() {
    local manifest="$1"
    yq -r '.models | length // 0' "$manifest"
}

# Print one line per model file, tab-separated (empty fields as "-"):
#   id  file  role  size  sha256  url  source_file
ark_manifest_model_files() {
    local manifest="$1"
    yq -r '
        .models[]? as $m | $m.files[] |
        [ $m.id, .file, (.role // "model"), (.size // 0), .sha256,
          "'"$_ARK_HF_BASE"'/\($m.repo)/resolve/\($m.revision)/\(.file)",
          (.source_file // .file) ] | @tsv
    ' "$manifest"
}

# Print one line per model for the drive launchers, tab-separated:
#   id  ram_gb  auto  model_path  mmproj_path  name
# Paths are relative to models/.  mmproj_path is "-" for text-only models.
ark_manifest_model_index() {
    local manifest="$1"
    yq -r '
        .models[]? |
        .id as $id |
        [ $id, .ram_gb, (if .auto then "yes" else "no" end),
          "\($id)/\(.files[] | select((.role // "model") == "model") | .file)",
          ([.files[] | select(.role == "mmproj") | "\($id)/\(.file)"] | first // "-"),
          .name ] | @tsv
    ' "$manifest"
}

# Fetch one model file into models/<id>/, verify it, and record it in state.
# Usage: _ark_models_fetch_file loadout id file role size sha256 url source_file
_ark_models_fetch_file() {
    local loadout="$1" id="$2" file="$3" role="$4" size="$5" sha256="$6" url="$7" source_file="$8"
    local staging
    staging="$(ark_staging_path)"
    local key="$loadout/models/$id/$file"
    local dest="$staging/$key"

    # Already have it, and it was verified against this exact hash
    if [[ -e "$dest" ]] && [[ "$(ark_state_get "$key" ".sha256" 2>/dev/null)" == "$sha256" ]]; then
        ark_dim "  Already have: $id/$file"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"

    # Prefer a copy from the local model library, if it has the same bytes
    local source_path="${ARK_MODELS_SOURCE:+$ARK_MODELS_SOURCE/$source_file}"
    if [[ -n "$source_path" && -f "$source_path" && ! -e "$dest" ]] \
        && (( $(stat -c%s "$source_path") == size )); then
        ark_info "Checking local copy: $source_file"
        if ark_download_verify "$source_path" "$sha256"; then
            ln -s "$source_path" "$dest"
            ark_state_set "$key" "$id" "$role" "-" "$size" "$sha256" "$source_path"
            ark_ok "  Linked from local library: $id/$file"
            return 0
        fi
        ark_warn "  Local copy doesn't match; downloading instead."
    fi

    if ! ark_download_http "$url" "$dest" "$size"; then
        return 1
    fi
    if ! ark_download_verify "$dest" "$sha256"; then
        ark_error "Removing corrupt file: $file"
        rm -f "$dest"
        return 1
    fi
    ark_state_set "$key" "$id" "$role" "-" "$size" "$sha256" "$url"
}

# Fetch the pinned llama.cpp builds into models/llama.cpp/.
_ark_models_fetch_llama() {
    local manifest="$1" models_dir="$2"
    local release
    release="$(yq -r '.llama_cpp.release // ""' "$manifest")"
    [[ -z "$release" ]] && return 0

    ark_info "Fetching llama.cpp $release builds..."
    mkdir -p "$models_dir/llama.cpp"
    printf '%s\n' "$release" > "$models_dir/llama.cpp/RELEASE"

    local failed=0
    while IFS=$'\t' read -r platform file sha256; do
        local dest="$models_dir/llama.cpp/$file"
        if [[ -f "$dest" ]] && [[ "$(sha256sum "$dest" | awk '{print $1}')" == "$sha256" ]]; then
            ark_dim "  Already have: $platform ($file)"
            continue
        fi
        if ark_download_http "$_ARK_LLAMA_RELEASES/$release/$file" "$dest" \
            && ark_download_verify "$dest" "$sha256"; then
            :
        else
            rm -f "$dest"
            failed=$(( failed + 1 ))
        fi
    done < <(yq -r '.llama_cpp.assets[] | [.platform, .file, .sha256] | @tsv' "$manifest")

    # Platform map for the launchers: platform<TAB>archive
    yq -r '.llama_cpp.assets[] | [.platform, .file] | @tsv' "$manifest" \
        > "$models_dir/llama.cpp/platforms.tsv"

    return "$failed"
}

# Fetch license texts: upstream files where the repo has them, plus Apache-2.0.
_ark_models_fetch_licenses() {
    local manifest="$1" models_dir="$2"
    local id url
    while IFS=$'\t' read -r id url; do
        local dest="$models_dir/$id/$(basename "$url")"
        [[ -f "$dest" ]] && continue
        ark_curl -sL --fail -o "$dest" "$url" \
            || ark_warn "  Could not fetch license file: $url"
    done < <(yq -r '.models[]? | .id as $id | .license_files[]? | [$id, .] | @tsv' "$manifest")

    cp "$ARK_ROOT/templates/models/LICENSE-Apache-2.0.txt" "$models_dir/"
}

# Sync everything under models/ for a loadout.
# Usage: ark_models_sync manifest loadout
ark_models_sync() {
    local manifest="$1" loadout="$2"
    local staging
    staging="$(ark_staging_path)"
    local models_dir="$staging/$loadout/models"
    mkdir -p "$models_dir"

    local count
    count="$(ark_manifest_model_count "$manifest")"
    ark_info "Syncing $count models..."
    [[ -n "${ARK_MODELS_SOURCE:-}" ]] && ark_dim "  Local library: $ARK_MODELS_SOURCE"

    local done_count=0 failed=0
    while IFS=$'\t' read -r id file role size sha256 url source_file; do
        echo
        if _ark_models_fetch_file "$loadout" "$id" "$file" "$role" "$size" "$sha256" "$url" "$source_file"; then
            done_count=$(( done_count + 1 ))
        else
            failed=$(( failed + 1 ))
            ark_error "Failed: $id/$file"
        fi
    done < <(ark_manifest_model_files "$manifest")

    echo
    _ark_models_fetch_llama "$manifest" "$models_dir" || failed=$(( failed + 1 ))
    _ark_models_fetch_licenses "$manifest" "$models_dir"

    # Launchers, README, and the index they read
    ark_manifest_model_index "$manifest" > "$models_dir/models.tsv"
    local f
    for f in README.txt start-ai.sh start-ai.bat start-ai.ps1; do
        cp "$ARK_ROOT/templates/models/$f" "$models_dir/$f"
    done
    chmod +x "$models_dir/start-ai.sh"

    echo
    if (( failed > 0 )); then
        ark_warn "Models: $done_count files ready, $failed failed"
        return 1
    fi
    ark_ok "Models: $done_count files ready"
}

# Print a status line per model file.
# Usage: ark_models_status manifest loadout   (sets MODELS_HAVE / MODELS_NEED bytes)
ark_models_status() {
    local manifest="$1" loadout="$2"
    local staging
    staging="$(ark_staging_path)"
    MODELS_HAVE=0
    MODELS_NEED=0

    while IFS=$'\t' read -r id file role size sha256 url source_file; do
        local key="$loadout/models/$id/$file"
        local status="missing" color="$C_RED"
        if [[ -e "$staging/$key" ]]; then
            if [[ "$(ark_state_get "$key" ".sha256" 2>/dev/null)" == "$sha256" ]]; then
                status="ok"; color="$C_GREEN"
            else
                status="unverified"; color="$C_YELLOW"
            fi
        fi
        if [[ "$status" == "ok" ]]; then
            MODELS_HAVE=$(( MODELS_HAVE + size ))
        else
            MODELS_NEED=$(( MODELS_NEED + size ))
        fi
        printf "  ${color}%-10s${C_RESET} %-18s %-36s %10s\n" \
            "$status" "$id" "$file" "$(ark_human_bytes "$size")"
    done < <(ark_manifest_model_files "$manifest")
}
