#!/bin/bash
# find-orphans.sh — correctly identifies orphaned compatdata
# Dead simple approach: build installed ID list, check each compatdata entry

STEAM_HOME="$HOME/.local/share/Steam"
COMPATDATA="$STEAM_HOME/steamapps/compatdata"

# --- Find ALL appmanifest files across ALL Steam libraries ---
MANIFESTS=$(find "$STEAM_HOME/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' 2>/dev/null)

# Also check SD card / external libraries from libraryfolders.vdf
if [ -f "$STEAM_HOME/steamapps/libraryfolders.vdf" ]; then
    EXTRA_PATHS=$(grep '"path"' "$STEAM_HOME/steamapps/libraryfolders.vdf" | sed 's/.*"path"[[:space:]]*"//; s/".*//')
    while IFS= read -r extra; do
        [ -z "$extra" ] && continue
        [ "$extra" = "$STEAM_HOME" ] && continue
        MORE=$(find "$extra/steamapps" -maxdepth 1 -name 'appmanifest_*.acf' 2>/dev/null)
        MANIFESTS="$MANIFESTS
$MORE"
    done <<< "$EXTRA_PATHS"
fi

# --- Build a simple newline-separated list of installed app IDs ---
INSTALLED_FILE=$(mktemp)
for manifest in $MANIFESTS; do
    [ -f "$manifest" ] || continue
    # ACF files have: "appid"		"123456"
    appid=$(sed -n 's/.*"appid".*"\([0-9]*\)".*/\1/p' "$manifest" | head -1)
    name=$(sed -n 's/.*"name".*"\(.*\)".*/\1/p' "$manifest" | head -1)
    if [ -n "$appid" ]; then
        echo "$appid $name" >> "$INSTALLED_FILE"
    fi
done

# --- Show installed games ---
echo "=== Installed Apps ==="
cat "$INSTALLED_FILE" | while read -r appid name; do
    echo "  $appid: $name"
done
echo ""

# --- Check each compatdata folder ---
echo "=== Compatdata Analysis ==="
TOTAL_ORPHAN_KB=0
ORPHAN_COUNT=0
KEEP_COUNT=0

for dir in "$COMPATDATA"/*/; do
    [ -d "$dir" ] || continue
    appid=$(basename "$dir")
    size_h=$(du -sh "$dir" 2>/dev/null | cut -f1)
    size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
    size_kb=${size_kb:-0}

    # Is this appid in our installed list?
    if grep -qx "$appid .*" "$INSTALLED_FILE" 2>/dev/null; then
        echo "  KEEP  $appid ($size_h)"
        KEEP_COUNT=$((KEEP_COUNT + 1))
    else
        echo "  ORPHAN  $appid ($size_h)"
        TOTAL_ORPHAN_KB=$((TOTAL_ORPHAN_KB + size_kb))
        ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
done

rm -f "$INSTALLED_FILE"
echo ""

echo "=== Summary ==="
echo "  $KEEP_COUNT compatdata entries for installed apps (kept)"
echo "  $ORPHAN_COUNT orphaned compatdata entries"
if [ "$ORPHAN_COUNT" -gt 0 ]; then
    if [ "$TOTAL_ORPHAN_KB" -ge 1048576 ] 2>/dev/null; then
        echo "  Reclaimable: $((TOTAL_ORPHAN_KB / 1048576)).$((TOTAL_ORPHAN_KB % 1048576 * 10 / 1048576)) GB"
    elif [ "$TOTAL_ORPHAN_KB" -ge 1024 ] 2>/dev/null; then
        echo "  Reclaimable: $((TOTAL_ORPHAN_KB / 1024)) MB"
    fi
    echo ""
    echo "=== DELETE COMMANDS (review first, then paste to run) ==="
    # Rebuild installed list for delete command generation
    for dir in "$COMPATDATA"/*/; do
        [ -d "$dir" ] || continue
        appid=$(basename "$dir")
        # Check if manifest exists for this appid in ANY library
        FOUND=""
        for manifest in $MANIFESTS; do
            manifest_appid=$(sed -n 's/.*"appid".*"\([0-9]*\)".*/\1/p' "$manifest" | head -1)
            if [ "$manifest_appid" = "$appid" ]; then
                FOUND="yes"
                break
            fi
        done
        [ -z "$FOUND" ] && echo "rm -rf \"$COMPATDATA/$appid\""
    done
fi
