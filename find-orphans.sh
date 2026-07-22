#!/bin/bash
# Cross-references installed Steam games against compatdata
# Shows exactly which compatdata folders are orphaned and safe to delete

STEAMAPPS="$HOME/.local/share/Steam/steamapps"
COMPATDATA="$STEAMAPPS/compatdata"
TOTAL_ORPHAN_KB=0

echo "=== Installed Games (from appmanifests) ==="
INSTALLED_IDS=""
for manifest in "$STEAMAPPS"/appmanifest_*.acf; do
    [ -f "$manifest" ] || continue
    appid=$(grep -m1 '"appid"' "$manifest" | grep -o '[0-9]*')
    name=$(grep -m1 '"name"' "$manifest" | sed 's/.*"name"[[:space:]]*"//; s/".*//')
    INSTALLED_IDS="$INSTALLED_IDS $appid"
    echo "  $appid: $name"
done
echo ""

echo "=== Orphaned Compatdata (safe to delete) ==="
ORPHAN_COUNT=0
for dir in "$COMPATDATA"/*/; do
    [ -d "$dir" ] || continue
    appid=$(basename "$dir")
    if ! echo " $INSTALLED_IDS " | grep -qw " $appid "; then
        size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
        size_kb=${size_kb:-0}
        TOTAL_ORPHAN_KB=$((TOTAL_ORPHAN_KB + size_kb))
        ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
        size_h=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "  ❌ $appid ($size_h) — NOT INSTALLED"
    fi
done
echo ""

echo "=== Also Checking: .var (Flatpak data) ==="
du -sh ~/.var/app/*/ 2>/dev/null | sort -rh | head -10
echo ""

echo "=== Summary ==="
if [ "$ORPHAN_COUNT" -gt 0 ]; then
    total_h=$(du -sh "$COMPATDATA" 2>/dev/null | cut -f1)
    echo "Found $ORPHAN_COUNT orphaned compatdata entries"
    echo "Total orphaned space:"
    if [ "$TOTAL_ORPHAN_KB" -ge 1048576 ] 2>/dev/null; then
        echo "  $((TOTAL_ORPHAN_KB / 1048576)).$((TOTAL_ORPHAN_KB % 1048576 * 10 / 1048576)) GB"
    elif [ "$TOTAL_ORPHAN_KB" -ge 1024 ] 2>/dev/null; then
        echo "  $((TOTAL_ORPHAN_KB / 1024)).$((TOTAL_ORPHAN_KB % 1024 * 10 / 1024)) MB"
    else
        echo "  ${TOTAL_ORPHAN_KB} KB"
    fi
    echo ""
    echo "=== COPY AND RUN THESE TO DELETE ORPHANS ==="
    for dir in "$COMPATDATA"/*/; do
        [ -d "$dir" ] || continue
        appid=$(basename "$dir")
        if ! echo " $INSTALLED_IDS " | grep -qw " $appid "; then
            echo "rm -rf \"$COMPATDATA/$appid\""
        fi
    done
else
    echo "✅ All compatdata matches installed games — nothing orphaned."
fi
