#!/bin/bash
# Shared helpers for Steam Deck storage / orphan scripts.
# Source:  source "$(dirname "$0")/steam-common.sh"

# Resolve Steam install root (native Deck, symlink layout, or Flatpak).
detect_steam_home() {
    local candidate
    for candidate in \
        "${STEAM_HOME:-}" \
        "$HOME/.local/share/Steam" \
        "$HOME/.steam/steam" \
        "$HOME/.steam/root" \
        "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
    do
        [ -n "$candidate" ] || continue
        if [ -d "$candidate/steamapps" ]; then
            # Prefer real path so library dedup works across symlinks
            if command -v realpath >/dev/null 2>&1; then
                realpath "$candidate"
            else
                (cd "$candidate" && pwd -P)
            fi
            return 0
        fi
    done
    echo "${STEAM_HOME:-$HOME/.local/share/Steam}"
}

STEAM_HOME="$(detect_steam_home)"
COMPATDATA="$STEAM_HOME/steamapps/compatdata"
COMPAT_TOOLS="$STEAM_HOME/compatibilitytools.d"
SHADER_CACHE="$STEAM_HOME/steamapps/shadercache"
DL_CACHE="$STEAM_HOME/steamapps/downloading"
STEAM_COMMON="$STEAM_HOME/steamapps/common"

_realpath() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null || echo "$1"
    else
        (cd "$1" 2>/dev/null && pwd -P) || echo "$1"
    fi
}

# Print one Steam library root per line (default + libraryfolders.vdf extras).
list_library_roots() {
    local libpath seen="" real root
    root="$(_realpath "$STEAM_HOME")"
    echo "$root"
    seen=$'\n'"$root"$'\n'

    if [ -f "$STEAM_HOME/steamapps/libraryfolders.vdf" ]; then
        while IFS= read -r libpath; do
            [ -z "$libpath" ] && continue
            [ -d "$libpath/steamapps" ] || continue
            real="$(_realpath "$libpath")"
            case "$seen" in
                *$'\n'"$real"$'\n'*) continue ;;
            esac
            seen="${seen}${real}"$'\n'
            echo "$real"
        done < <(grep '"path"' "$STEAM_HOME/steamapps/libraryfolders.vdf" \
            | sed 's/.*"path"[[:space:]]*"//; s/".*//')
    fi
}

# App IDs from Non-Steam shortcuts (binary shortcuts.vdf). Requires python3.
_collect_shortcut_appids() {
    local files=() f
    shopt -s nullglob
    for f in "$STEAM_HOME"/userdata/*/config/shortcuts.vdf; do
        [ -f "$f" ] && files+=("$f")
    done
    shopt -u nullglob
    [ "${#files[@]}" -gt 0 ] || return 0

    if ! command -v python3 >/dev/null 2>&1; then
        echo "warning: python3 not found — Non-Steam shortcuts won't be treated as installed" >&2
        return 0
    fi

    python3 - "${files[@]}" <<'PY'
import struct, sys
ids = set()
needle = b"\x02appid\x00"
for path in sys.argv[1:]:
    try:
        data = open(path, "rb").read()
    except OSError:
        continue
    start = 0
    while True:
        i = data.find(needle, start)
        if i < 0:
            break
        off = i + len(needle)
        if off + 4 <= len(data):
            appid = struct.unpack_from("<I", data, off)[0]
            if appid:
                ids.add(appid)
        start = i + 1
for appid in sorted(ids):
    print(appid)
PY
}

# Newline-separated installed app IDs: all library manifests + Non-Steam shortcuts.
collect_installed_appids() {
    local root installed extra
    installed=""

    while IFS= read -r root; do
        [ -z "$root" ] && continue
        extra=$(find "$root/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -exec basename {} \; 2>/dev/null \
            | sed 's/appmanifest_//; s/\.acf//')
        installed="$installed
$extra"
    done < <(list_library_roots)

    extra=$(_collect_shortcut_appids)
    installed="$installed
$extra"

    echo "$installed" | sort -un | grep -E '^[0-9]+$' || true
}

# Print every existing compatdata directory root across libraries.
list_compatdata_roots() {
    local root
    while IFS= read -r root; do
        [ -d "$root/steamapps/compatdata" ] && echo "$root/steamapps/compatdata"
    done < <(list_library_roots)
}

# Print every existing shadercache directory root across libraries.
list_shadercache_roots() {
    local root
    while IFS= read -r root; do
        [ -d "$root/steamapps/shadercache" ] && echo "$root/steamapps/shadercache"
    done < <(list_library_roots)
}

# Print every existing downloading directory root across libraries.
list_downloading_roots() {
    local root
    while IFS= read -r root; do
        [ -d "$root/steamapps/downloading" ] && echo "$root/steamapps/downloading"
    done < <(list_library_roots)
}

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

# Empty a directory's contents safely (no ARG_MAX glob issues).
empty_dir_contents() {
    local dir=$1
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}
