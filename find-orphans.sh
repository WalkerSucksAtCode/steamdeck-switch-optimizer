#!/bin/bash
# find-orphans.sh — cross-reference compatdata vs installed apps
# Installed = appmanifest_*.acf in ALL Steam libraries + Non-Steam shortcuts.vdf
# Compatdata is scanned in EVERY library (internal + SD card).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steam-common.sh
source "$SCRIPT_DIR/steam-common.sh"

INSTALLED=$(collect_installed_appids)

echo "=== Steam home ==="
echo "  $STEAM_HOME"
echo ""
echo "=== Libraries ==="
list_library_roots | sed 's/^/  /'
echo ""

echo "=== Installed App IDs (manifests + Non-Steam shortcuts) ==="
if [ -n "$INSTALLED" ]; then
    echo "$INSTALLED" | sed 's/^/  /'
else
    echo "  (none found)"
    echo "  WARNING: empty install list — refuse to suggest deletes (Steam closed? wrong STEAM_HOME?)"
fi
echo ""

echo "=== Compatdata Analysis ==="
TOTAL_ORPHAN_KB=0
ORPHAN_COUNT=0
KEEP_COUNT=0
ORPHAN_PATHS=()

COMPAT_ROOTS=$(list_compatdata_roots)
if [ -z "$COMPAT_ROOTS" ]; then
    echo "  No compatdata directories found"
    exit 0
fi

while IFS= read -r COMPATDATA_ROOT; do
    [ -d "$COMPATDATA_ROOT" ] || continue
    echo "  Library: $COMPATDATA_ROOT"
    shopt -s nullglob
    for dir in "$COMPATDATA_ROOT"/*/; do
        [ -d "$dir" ] || continue
        appid=$(basename "$dir")
        # Skip non-numeric / junk folders
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

echo "=== Summary ==="
echo "  $KEEP_COUNT installed (kept)"
echo "  $ORPHAN_COUNT orphaned"
if [ "$TOTAL_ORPHAN_KB" -gt 0 ]; then
    echo "  Reclaimable: $(format_bytes "$TOTAL_ORPHAN_KB")"
fi

if [ "$ORPHAN_COUNT" -gt 0 ]; then
    echo ""
    if [ -z "$INSTALLED" ]; then
        echo "=== DELETE ORPHANS skipped (no installed apps detected) ==="
        echo "Refusing to print rm commands when the install list is empty."
    else
        echo "=== DELETE ORPHANS (review, then paste to run) ==="
        for path in "${ORPHAN_PATHS[@]}"; do
            echo "rm -rf \"$path\""
        done
    fi
fi
