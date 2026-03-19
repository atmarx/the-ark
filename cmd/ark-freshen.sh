#!/usr/bin/env bash
# ark-freshen.sh — check catalog for newer versions of downloaded ZIMs

ark_freshen() {
    local manifest_arg="${1:-}"

    if [[ -z "$manifest_arg" ]]; then
        ark_die "Usage: ark freshen <loadout|manifest.yml>"
    fi

    ark_load_config
    ark_state_init

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"

    ark_bold "Checking for updates: $loadout"
    echo

    # Always refresh catalog for freshen
    ark_catalog_fetch
    echo

    # Resolve manifest
    local resolution
    resolution="$(ark_manifest_resolve "$manifest_file")"

    local updates=0 current=0 unresolved=0 missing=0

    printf "  ${C_BOLD}%-40s %-8s %-10s %-10s %10s${C_RESET}\n" "NAME" "FLAVOUR" "HAVE" "LATEST" "SIZE"
    printf "  %-40s %-8s %-10s %-10s %10s\n" "----" "-------" "----" "------" "----"

    while IFS=$'\t' read -r status name flavour meta4_url size date filename; do
        case "$status" in
            ok)
                local have_date
                have_date="$(ark_catalog_filename_date "$filename")"
                printf "  %-40s %-8s ${C_GREEN}%-10s${C_RESET} %-10s %10s\n" \
                    "$name" "${flavour:--}" "$have_date" "$date" "$(ark_human_bytes "$size")"
                current=$(( current + 1 ))
                ;;
            outdated)
                local have_key
                have_key="$(ark_state_list "$loadout/zim/" | grep "${name}" | head -1 || true)"
                local have_date="-"
                if [[ -n "$have_key" ]]; then
                    have_date="$(ark_state_get "$have_key" ".date")"
                fi
                printf "  %-40s %-8s ${C_YELLOW}%-10s${C_RESET} ${C_GREEN}%-10s${C_RESET} %10s  ${C_YELLOW}UPDATE${C_RESET}\n" \
                    "$name" "${flavour:--}" "$have_date" "$date" "$(ark_human_bytes "$size")"
                updates=$(( updates + 1 ))
                ;;
            missing)
                printf "  %-40s %-8s ${C_RED}%-10s${C_RESET} %-10s %10s  ${C_RED}MISSING${C_RESET}\n" \
                    "$name" "${flavour:--}" "-" "$date" "$(ark_human_bytes "$size")"
                missing=$(( missing + 1 ))
                ;;
            unresolved)
                printf "  %-40s %-8s %-10s %-10s %10s  ${C_RED}NOT FOUND${C_RESET}\n" \
                    "$name" "${flavour:--}" "-" "-" "-"
                unresolved=$(( unresolved + 1 ))
                ;;
        esac
    done <<< "$resolution"

    echo
    ark_bold "Summary"
    echo "  Current:    $current"
    (( updates > 0 ))    && echo -e "  ${C_YELLOW}Updates:    $updates${C_RESET}"
    (( missing > 0 ))    && echo -e "  ${C_RED}Missing:    $missing${C_RESET}"
    (( unresolved > 0 )) && echo -e "  ${C_RED}Unresolved: $unresolved${C_RESET}"

    if (( updates > 0 || missing > 0 )); then
        echo
        ark_info "Run 'ark sync $manifest_arg --refresh' to download updates."
    else
        echo
        ark_ok "Everything is up to date!"
    fi
}
