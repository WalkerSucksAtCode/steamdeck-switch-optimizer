#!/bin/bash
# Shared helpers for Steam Deck storage / orphan scripts.
# Source this file:  source "$(dirname "$0")/steam-common.sh"

STEAM_HOME="${STEAM_HOME:-$HOME/.local/share/Steam}"
COMPATDATA="${COMPATDATA:-$STEAM_HOME/steamapps/compatdata}"
COMPAT_TOOLS="${COMPAT_TOOLS:-$STEAM_HOME/compatibilitytools.d}"
SHADER_CACHE="${SHADER_CACHE:-$STEAM_HOME/steamapps/shadercache}"
DL_CACHE="${DL_CACHE:-$STEAM_HOME/steamapps/downloading}"
STEAM_COMMON="${STEAM_COMMON:-$STEAM_HOME/steamapps/common}"

# Print newline-separated installed Steam app IDs from ALL libraries
# (default + any paths in libraryfolders.vdf), derived from appmanifest_*.acf names.
collect_installed_appids() {
    local installed extra libpath
    installed=$(find "$STEAM_HOME/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -exec basename {} \; 2>/dev/null \
        | sed 's/appmanifest_//; s/\.acf//')

    if [ -f "$STEAM_HOME/steamapps/libraryfolders.vdf" ]; then
        while IFS= read -r libpath; do
            [ -z "$libpath" ] && continue
            [ "$libpath" = "$STEAM_HOME" ] && continue
            extra=$(find "$libpath/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -exec basename {} \; 2>/dev/null \
                | sed 's/appmanifest_//; s/\.acf//')
            installed="$installed
$extra"
        done < <(grep '"path"' "$STEAM_HOME/steamapps/libraryfolders.vdf" | sed 's/.*"path"[[:space:]]*"//; s/".*//' )
    fi

    echo "$installed" | sort -un | grep -v '^$'
}

# Format KB (from du -sk) as human-readable string
format_bytes() {
    local kb=${1:-0}
    [ -z "$kb" ] && kb=0
    if [ "$kb" -ge 1048576 ] 2>/dev/null; then
        local mb=$((kb / 1024))
        local whole=$((mb / 1024))
        local frac=$(((mb % 1024) * 10 / 1024))
        echo "${whole}.${frac} GB"
    elif [ "$kb" -ge 1024 ] 2>/dev/null; then
        local whole=$((kb / 1024))
        local frac=$(((kb % 1024) * 10 / 1024))
        echo "${whole}.${frac} MB"
    else
        echo "${kb} KB"
    fi
}

safe_size() {
    local result
    result=$(du -sk "$1" 2>/dev/null | cut -f1)
    echo "${result:-0}"
}
