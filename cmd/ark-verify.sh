#!/usr/bin/env bash
# ark-verify.sh — verify SHA-256 checksums of all downloaded files

ark_verify() {
    local manifest_arg="${1:-}"

    if [[ -z "$manifest_arg" ]]; then
        ark_die "Usage: ark verify <loadout|manifest.yml>"
    fi

    ark_load_config
    ark_state_init

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"

    ark_bold "Verifying checksums: $loadout"
    echo

    local staging
    staging="$(ark_staging_path)"
    local verified=0 failed=0 skipped=0 missing=0

    # Walk all files in state for this loadout
    local keys
    keys="$(ark_state_list "$loadout/")"

    if [[ -z "$keys" ]]; then
        ark_warn "No files tracked in state for loadout '$loadout'."
        ark_info "Run 'ark sync $manifest_arg' first."
        return 1
    fi

    while IFS= read -r key; do
        local filename
        filename="$(basename "$key")"
        local full_path="$staging/$key"

        if [[ ! -f "$full_path" ]]; then
            printf "  ${C_RED}MISSING${C_RESET}  %s\n" "$filename"
            missing=$(( missing + 1 ))
            continue
        fi

        local expected_sha256
        expected_sha256="$(ark_state_get "$key" ".sha256")"

        if [[ -z "$expected_sha256" ]]; then
            printf "  ${C_YELLOW}SKIP${C_RESET}     %s (no checksum in state)\n" "$filename"
            skipped=$(( skipped + 1 ))
            continue
        fi

        # Compute checksum
        printf "  Checking %s... " "$filename"
        local actual_sha256
        actual_sha256="$(sha256sum "$full_path" | awk '{print $1}')"

        if [[ "$actual_sha256" == "$expected_sha256" ]]; then
            printf "${C_GREEN}OK${C_RESET}\n"
            ark_state_set_verified "$key" true
            verified=$(( verified + 1 ))
        else
            printf "${C_RED}FAILED${C_RESET}\n"
            ark_error "  Expected: $expected_sha256"
            ark_error "  Got:      $actual_sha256"
            ark_state_set_verified "$key" false
            failed=$(( failed + 1 ))
        fi
    done <<< "$keys"

    echo
    ark_bold "Verification complete"
    echo "  Verified: $verified"
    (( skipped > 0 )) && echo -e "  ${C_YELLOW}Skipped:  $skipped${C_RESET} (no stored checksum)"
    (( missing > 0 )) && echo -e "  ${C_RED}Missing:  $missing${C_RESET}"
    (( failed > 0 ))  && echo -e "  ${C_RED}Failed:   $failed${C_RESET}"

    if (( failed > 0 )); then
        ark_error "Some files failed verification! Re-download with 'ark sync $manifest_arg'."
        return 1
    fi
}
