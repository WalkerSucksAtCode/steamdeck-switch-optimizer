#!/bin/bash
# Steam Deck Storage Diagnostic — inspect before cleanup
# Run on the Deck in Konsole

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steam-common.sh
source "$SCRIPT_DIR/steam-common.sh"

echo "=========================================="
echo "  Steam Deck Storage Diagnostic"
echo "  Steam: $STEAM_HOME"
echo "=========================================="
echo ""

echo "--- Internal Storage (/home) ---"
df -h /home 2>/dev/null | tail -1 || df -h "$HOME" | tail -1
echo ""

echo "--- Libraries ---"
list_library_roots | sed 's/^/  /'
echo ""

echo "--- Top Space Consumers in /home ---"
du -sh "$HOME/Downloads" "$HOME/.cache" "$HOME/.local/share/Steam" "$HOME/.config" 2>/dev/null | sort -rh | head -10
echo ""

echo "--- Proton & Compatibility Tools ---"
if [ -d "$STEAM_COMMON" ]; then
    echo "Steam common (top 20):"
    du -sh "$STEAM_COMMON"/* 2>/dev/null | sort -rh | head -20
else
    echo "No steamapps/common"
fi
echo ""

if [ -d "$COMPAT_TOOLS" ]; then
    echo "Custom Proton versions (compatibilitytools.d):"
    du -sh "$COMPAT_TOOLS"/* 2>/dev/null | sort -rh || echo "  (empty)"
else
    echo "No custom Proton versions installed."
fi
echo ""

echo "--- Shader Cache (all libraries) ---"
ANY=0
while IFS= read -r SC; do
    ANY=1
    TOTAL=$(du -sh "$SC" 2>/dev/null | cut -f1)
    echo "$SC — total $TOTAL"
    echo "  Top entries:"
    du -sh "$SC"/* 2>/dev/null | sort -rh | head -10 | sed 's/^/  /'
done < <(list_shadercache_roots)
[ "$ANY" -eq 0 ] && echo "No shader cache directories found."
echo ""

echo "--- Incomplete Downloads (all libraries) ---"
ANY=0
while IFS= read -r DC; do
    ANY=1
    du -sh "$DC" 2>/dev/null
    count=$(find "$DC" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
    echo "  $count pending download folders"
done < <(list_downloading_roots)
[ "$ANY" -eq 0 ] && echo "No download cache."
echo ""

echo "--- Workshop Cache ---"
ANY=0
while IFS= read -r root; do
    WS="$root/steamapps/workshop"
    if [ -d "$WS" ]; then
        ANY=1
        du -sh "$WS" 2>/dev/null
    fi
done < <(list_library_roots)
[ "$ANY" -eq 0 ] && echo "No workshop cache."
echo ""

echo "--- Compatdata (all libraries) ---"
ANY=0
while IFS= read -r CD; do
    ANY=1
    TOTAL=$(du -sh "$CD" 2>/dev/null | cut -f1)
    count=$(find "$CD" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "$CD — $TOTAL ($count prefixes)"
done < <(list_compatdata_roots)
[ "$ANY" -eq 0 ] && echo "No compatdata."
echo ""

echo "--- System Package Cache ---"
du -sh /var/cache/pacman/pkg/ 2>/dev/null || echo "Cannot access (read-only partition or missing)"
echo ""

echo "--- Thumbnail Cache ---"
du -sh "$HOME/.cache/thumbnails" 2>/dev/null || echo "No thumbnail cache"
echo ""

echo "=========================================="
echo "  Review the above, then:"
echo "    ./cleanup.sh           # dry-run"
echo "    ./cleanup.sh --apply   # reclaim safe caches"
echo "    ./find-orphans.sh      # orphaned compatdata"
echo "=========================================="
