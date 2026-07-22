#!/bin/bash
# Cross-references installed Steam games against compatdata
# Scans ALL Steam library folders (internal + SD card + external)

STEAM_HOME="$HOME/.local/share/Steam"
COMPATDATA="$STEAM_HOME/steamapps/compatdata"

# Parse all library folders from libraryfolders.vdf
LIBRARY_FOLDERS=""
if [ -f "$STEAM_HOME/steamapps/libraryfolders.vdf" ]; then
    LIBRARY_FOLDERS=$(grep '"path"' "$STEAM_HOME/steamapps/libraryfolders.vdf" | sed 's/.*"path"[[:space:]]*"//; s/".*//')
fi
# Always include default
LIBRARY_FOLDERS="$STEAM_HOME
$LIBRARY_FOLDERS"

echo "=== Scanning Steam Library Folders ===
"
echo "$LIBRARY_FOLDERS" | while read -r folder; do
    [ -z "$folder" ] && continue
    count=$(find "$folder/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' 2>/dev/null | wc -l)
    echo "  $folder ($count games)"
done
echo ""

# Build complete list of installed app IDs from ALL libraries
INSTALLED_IDS=""
for folder in $LIBRARY_FOLDERS; do
    [ -z "$folder" ] && continue
    for manifest in "$folder/steamapps"/appmanifest_*.acf; do
        [ -f "$manifest" ] || continue
        appid=$(grep -m1 '"appid"' "$manifest" | grep -o '[0-9]*')
        name=$(grep -m1 '"name"' "$manifest" | sed 's/.*"name"[[:space:]]*"//; s/".*//')
        if [ -n "$appid" ]; then
            INSTALLED_IDS="$INSTALLED_IDS $appid"
        fi
    done
done

echo "=== Installed Games ==="
for folder in $LIBRARY_FOLDERS; do
    [ -z "$folder" ] && continue
    for manifest in "$folder/steamapps"/appmanifest_*.acf; do
        [ -f "$manifest" ] || continue
        appid=$(grep -m1 '"appid"' "$manifest" | grep -o '[0-9]*')
        name=$(grep -m1 '"name"' "$manifest" | sed 's/.*"name"[[:space:]]*"//; s/".*//')
        [ -n "$appid" ] && echo "  $appid: $name"
    done
done
echo ""

# Now check compatdata
echo "=== Orphaned Compatdata (safe to delete) ==="
TOTAL_ORPHAN_KB=0
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
    else
        size_h=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "  ✅ $appid ($size_h) — installed"
    fi
done
echo ""

echo "=== Summary ==="
if [ "$ORPHAN_COUNT" -gt 0 ]; then
    if [ "$TOTAL_ORPHAN_KB" -ge 1048576 ] 2>/dev/null; then
        echo "Found $ORPHAN_COUNT orphaned entries — $((TOTAL_ORPHAN_KB / 1048576)).$((TOTAL_ORPHAN_KB % 1048576 * 10 / 1048576)) GB reclaimable"
    elif [ "$TOTAL_ORPHAN_KB" -ge 1024 ] 2>/dev/null; then
        echo "Found $ORPHAN_COUNT orphaned entries — $((TOTAL_ORPHAN_KB / 1024)) MB reclaimable"
    else
        echo "Found $ORPHAN_COUNT orphaned entries — ${TOTAL_ORPHAN_KB} KB reclaimable"
    fi
    echo ""
    echo "=== RUN THESE TO DELETE ORPHANS ==="
    for dir in "$COMPATDATA"/*/; do
        [ -d "$dir" ] || continue
        appid=$(basename "$dir")
        if ! echo " $INSTALLED_IDS " | grep -qw " $appid "; then
            echo "rm -rf \"$COMPATDATA/$appid\""
        fi
    done
else
    echo "✅ All compatdata matches installed games."
fi
