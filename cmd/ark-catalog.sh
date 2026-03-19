#!/usr/bin/env bash
# ark-catalog.sh — search/browse the Kiwix OPDS catalog

ark_catalog_cmd() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        search)   _ark_catalog_search "$@" ;;
        list)     _ark_catalog_list "$@" ;;
        refresh)  _ark_catalog_refresh ;;
        info)     _ark_catalog_info "$@" ;;
        *)
            echo "Usage: ark catalog <subcommand>"
            echo
            echo "Subcommands:"
            echo "  search <query>              Search catalog by name/title/description"
            echo "  list [--category=X] [--lang=X]  List available ZIM files"
            echo "  info <name> [flavour]       Show details for a specific entry"
            echo "  refresh                     Force-refresh the catalog cache"
            exit 1
            ;;
    esac
}

_ark_catalog_search() {
    local query="${1:-}"
    if [[ -z "$query" ]]; then
        ark_die "Usage: ark catalog search <query>"
    fi

    ark_load_config
    ark_catalog_ensure
    echo

    ark_info "Searching catalog for: $query"
    echo

    local results
    results="$(ark_catalog_search "$query")"

    if [[ -z "$results" ]]; then
        ark_warn "No results found for '$query'"
        return
    fi

    printf "  ${C_BOLD}%-40s %-10s %10s  %-12s %s${C_RESET}\n" "NAME" "FLAVOUR" "SIZE" "DATE" "TITLE"
    printf "  %-40s %-10s %10s  %-12s %s\n" "----" "-------" "----" "----" "-----"

    local count=0
    while IFS=$'\t' read -r name flavour size date title; do
        local size_human=""
        if [[ -n "$size" && "$size" != "0" ]]; then
            size_human="$(ark_human_bytes "$size")"
        fi
        # Truncate title to 40 chars
        local title_short="${title:0:40}"
        printf "  %-40s %-10s %10s  %-12s %s\n" \
            "$name" "${flavour:--}" "$size_human" "${date:0:10}" "$title_short"
        count=$(( count + 1 ))
    done <<< "$results"

    echo
    ark_dim "  $count results"
}

_ark_catalog_list() {
    local category="" lang=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --category=*) category="${1#--category=}" ;;
            --lang=*)     lang="${1#--lang=}" ;;
            *)            ark_die "Unknown flag: $1" ;;
        esac
        shift
    done

    ark_load_config
    ark_catalog_ensure
    echo

    local filter_desc="all entries"
    [[ -n "$category" ]] && filter_desc="category=$category"
    [[ -n "$lang" ]] && filter_desc="$filter_desc, lang=$lang"
    ark_info "Listing catalog ($filter_desc):"
    echo

    local results
    results="$(ark_catalog_list "$category" "$lang")"

    if [[ -z "$results" ]]; then
        ark_warn "No entries found"
        return
    fi

    printf "  ${C_BOLD}%-40s %-10s %10s  %-12s %s${C_RESET}\n" "NAME" "FLAVOUR" "SIZE" "DATE" "TITLE"
    printf "  %-40s %-10s %10s  %-12s %s\n" "----" "-------" "----" "----" "-----"

    local count=0
    while IFS=$'\t' read -r name flavour size date title; do
        local size_human=""
        if [[ -n "$size" && "$size" != "0" ]]; then
            size_human="$(ark_human_bytes "$size")"
        fi
        local title_short="${title:0:40}"
        printf "  %-40s %-10s %10s  %-12s %s\n" \
            "$name" "${flavour:--}" "$size_human" "${date:0:10}" "$title_short"
        count=$(( count + 1 ))
    done <<< "$results"

    echo
    ark_dim "  $count entries"
}

_ark_catalog_info() {
    local name="${1:-}"
    local flavour="${2:-}"

    if [[ -z "$name" ]]; then
        ark_die "Usage: ark catalog info <name> [flavour]"
    fi

    ark_load_config
    ark_catalog_ensure
    echo

    local result
    if ! result="$(ark_catalog_resolve "$name" "$flavour")"; then
        ark_die "Not found in catalog: $name ${flavour:+(flavour=$flavour)}"
    fi

    local meta4_url size date cat_name cat_flavour category
    IFS=$'\t' read -r meta4_url size date cat_name cat_flavour category <<< "$result"

    local filename
    filename="$(ark_catalog_meta4_to_filename "$meta4_url")"
    local direct_url
    direct_url="$(ark_catalog_meta4_to_url "$meta4_url")"

    ark_bold "$cat_name"
    echo "  Flavour:   ${cat_flavour:-(none)}"
    echo "  Category:  ${category:-(none)}"
    echo "  Size:      $(ark_human_bytes "$size")"
    echo "  Updated:   $date"
    echo "  Filename:  $filename"
    echo "  URL:       $direct_url"
    echo "  Meta4:     $meta4_url"
    echo "  Torrent:   ${direct_url}.torrent"
}

_ark_catalog_refresh() {
    ark_load_config
    ark_catalog_fetch
}
