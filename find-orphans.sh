#!/bin/bash
# Compatdata vs installed apps (all libraries + Non-Steam shortcuts).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steam-common.sh
source "$SCRIPT_DIR/steam-common.sh"

INSTALLED=$(collect_installed_appids)

echo "=== steam ==="
echo "  $STEAM_HOME"
echo ""
echo "=== libraries ==="
list_library_roots | sed 's/^/  /'
echo ""

echo "=== installed (manifests + shortcuts) ==="
if [ -n "$INSTALLED" ]; then
    echo "$INSTALLED" | sed 's/^/  /'
else
    echo "  (none)"
    echo "  WARNING: empty install list; will not print rm commands"
fi
echo ""

echo "=== compatdata ==="
TOTAL_ORPHAN_KB=0
ORPHAN_COUNT=0
KEEP_COUNT=0
ORPHAN_PATHS=()

COMPAT_ROOTS=$(list_compatdata_roots)
if [ -z "$COMPAT_ROOTS" ]; then
    echo "  none"
    exit 0
fi

while IFS= read -r COMPATDATA_ROOT; do
    [ -d "$COMPATDATA_ROOT" ] || continue
    echo "  $COMPATDATA_ROOT"
    shopt -s nullglob
    for dir in "$COMPATDATA_ROOT"/*/; do
        [ -d "$dir" ] || continue
        appid=$(basename "$dir")
        [[ "$appid" =~ ^[0-9]+$ ]] || continue

        size_h=$(du -sh "$dir" 2>/dev/null | cut -f1)
        size_kb=$(safe_size "$dir")

        if echo "$INSTALLED" | grep -qx "$appid"; then
            echo "    KEEP   $appid ($size_h)"
            KEEP_COUNT=$((KEEP_COUNT + 1))
        else
            echo "    ORPHAN $appid ($size_h)"
            TOTAL_ORPHAN_KB=$((TOTAL_ORPHAN_KB + size_kb))
            ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
            ORPHAN_PATHS+=("${dir%/}")
        fi
    done
    shopt -u nullglob
done <<< "$COMPAT_ROOTS"
echo ""

echo "=== summary ==="
echo "  keep $KEEP_COUNT"
echo "  orphan $ORPHAN_COUNT"
if [ "$TOTAL_ORPHAN_KB" -gt 0 ]; then
    echo "  reclaimable $(format_bytes "$TOTAL_ORPHAN_KB")"
fi

if [ "$ORPHAN_COUNT" -gt 0 ]; then
    echo ""
    if [ -z "$INSTALLED" ]; then
        echo "=== no rm (empty install list) ==="
    else
        echo "=== rm (review first) ==="
        for path in "${ORPHAN_PATHS[@]}"; do
            echo "rm -rf \"$path\""
        done
    fi
fi
