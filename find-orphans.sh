#!/bin/bash
# find-orphans.sh — cross-reference compatdata vs installed appmanifests
# Uses filename app IDs (appmanifest_123.acf → 123) across ALL Steam libraries.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steam-common.sh
source "$SCRIPT_DIR/steam-common.sh"

INSTALLED=$(collect_installed_appids)

echo "=== Installed App IDs ==="
if [ -n "$INSTALLED" ]; then
    echo "$INSTALLED" | sed 's/^/  /'
else
    echo "  (none found)"
fi
echo ""

echo "=== Compatdata Analysis ==="
TOTAL_ORPHAN_KB=0
ORPHAN_COUNT=0
KEEP_COUNT=0

if [ ! -d "$COMPATDATA" ]; then
    echo "  No compatdata directory at $COMPATDATA"
    exit 0
fi

for dir in "$COMPATDATA"/*/; do
    [ -d "$dir" ] || continue
    appid=$(basename "$dir")
    size_h=$(du -sh "$dir" 2>/dev/null | cut -f1)
    size_kb=$(safe_size "$dir")

    if echo "$INSTALLED" | grep -qx "$appid"; then
        echo "  KEEP   $appid ($size_h)"
        KEEP_COUNT=$((KEEP_COUNT + 1))
    else
        echo "  ORPHAN $appid ($size_h)"
        TOTAL_ORPHAN_KB=$((TOTAL_ORPHAN_KB + size_kb))
        ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
done
echo ""

echo "=== Summary ==="
echo "  $KEEP_COUNT installed (kept)"
echo "  $ORPHAN_COUNT orphaned"
if [ "$TOTAL_ORPHAN_KB" -gt 0 ]; then
    echo "  Reclaimable: $(format_bytes "$TOTAL_ORPHAN_KB")"
fi

if [ "$ORPHAN_COUNT" -gt 0 ]; then
    echo ""
    echo "=== DELETE ORPHANS (review, then paste to run) ==="
    for dir in "$COMPATDATA"/*/; do
        [ -d "$dir" ] || continue
        appid=$(basename "$dir")
        if ! echo "$INSTALLED" | grep -qx "$appid"; then
            echo "rm -rf \"$COMPATDATA/$appid\""
        fi
    done
fi
