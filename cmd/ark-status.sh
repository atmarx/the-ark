#!/usr/bin/env bash
# ark-status.sh — show inventory vs manifest for a loadout

ark_status() {
    local manifest_arg="${1:-}"

    if [[ -z "$manifest_arg" ]]; then
        ark_die "Usage: ark status <loadout|manifest.yml>"
    fi

    ark_load_config
    ark_state_init

    local manifest_file
    manifest_file="$(ark_resolve_manifest "$manifest_arg")"
    local loadout
    loadout="$(ark_manifest_loadout "$manifest_file")"
    local target_gb
    target_gb="$(ark_manifest_target_gb "$manifest_file")"
    local description
    description="$(ark_manifest_description "$manifest_file")"

    ark_bold "Status: $loadout"
    [[ -n "$description" ]] && ark_dim "  $description"
    echo

    # Check catalog
    if ! ark_catalog_is_fresh; then
        ark_warn "Catalog cache is stale or missing. Run 'ark sync $manifest_arg' to refresh."
        echo
    fi

    local staging
    staging="$(ark_staging_path)"

    # Resolve manifest
    local resolution
    resolution="$(ark_manifest_resolve "$manifest_file")"

    # Print table
    printf "  ${C_BOLD}%-8s %-40s %-8s %10s  %s${C_RESET}\n" "STATUS" "NAME" "FLAVOUR" "SIZE" "DATE"
    printf "  %-8s %-40s %-8s %10s  %s\n" "------" "----" "-------" "----" "----"

    local total=0 ok=0 missing=0 outdated=0 unresolved=0
    local total_size=0 have_size=0 need_size=0

    while IFS=$'\t' read -r status name flavour meta4_url size date filename; do
        total=$(( total + 1 ))
        local size_human=""
        if [[ -n "$size" && "$size" != "0" ]]; then
            size_human="$(ark_human_bytes "$size")"
            total_size=$(( total_size + size ))
        fi

        local status_color=""
        case "$status" in
            ok)
                status_color="${C_GREEN}"
                ok=$(( ok + 1 ))
                have_size=$(( have_size + size ))
                ;;
            missing)
                status_color="${C_RED}"
                missing=$(( missing + 1 ))
                need_size=$(( need_size + size ))
                ;;
            outdated)
                status_color="${C_YELLOW}"
                outdated=$(( outdated + 1 ))
                need_size=$(( need_size + size ))
                ;;
            unresolved)
                status_color="${C_RED}"
                unresolved=$(( unresolved + 1 ))
                ;;
        esac

        printf "  ${status_color}%-8s${C_RESET} %-40s %-8s %10s  %s\n" \
            "$status" "$name" "${flavour:--}" "$size_human" "${date:--}"
    done <<< "$resolution"

    # PDFs
    local pdf_count
    pdf_count="$(ark_manifest_pdf_count "$manifest_file")"
    if (( pdf_count > 0 )); then
        echo
        ark_info "PDFs: $pdf_count listed in manifest"
        local pdf_have=0
        _status_pdf_callback() {
            local idx="$1" url="$2" filename="$3"
            local dest="$staging/$loadout/pdfs/$filename"
            if [[ -f "$dest" ]]; then
                printf "  ${C_GREEN}%-8s${C_RESET} %s\n" "ok" "$filename"
                pdf_have=$(( pdf_have + 1 ))
            else
                printf "  ${C_RED}%-8s${C_RESET} %s\n" "missing" "$filename"
            fi
        }
        ark_manifest_each_pdf "$manifest_file" _status_pdf_callback
        ark_dim "  $pdf_have / $pdf_count PDFs present"
    fi

    # Summary
    echo
    ark_bold "Summary"
    echo "  Total entries:  $total"
    (( ok > 0 ))         && echo -e "  ${C_GREEN}Up to date:   $ok${C_RESET}"
    (( missing > 0 ))    && echo -e "  ${C_RED}Missing:      $missing${C_RESET}"
    (( outdated > 0 ))   && echo -e "  ${C_YELLOW}Outdated:     $outdated${C_RESET}"
    (( unresolved > 0 )) && echo -e "  ${C_RED}Unresolved:   $unresolved${C_RESET}"
    echo
    echo "  Have:    $(ark_human_bytes "$have_size")"
    echo "  Need:    $(ark_human_bytes "$need_size")"
    echo "  Total:   $(ark_human_bytes "$total_size") / ${target_gb} GB target"

    # Disk usage of staging loadout dir
    if [[ -d "$staging/$loadout" ]]; then
        local disk_usage
        disk_usage="$(du -sb "$staging/$loadout" 2>/dev/null | awk '{print $1}')"
        echo "  On disk: $(ark_human_bytes "$disk_usage")"
    fi
}
