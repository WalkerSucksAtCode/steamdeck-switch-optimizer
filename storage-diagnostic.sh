#!/bin/bash
# Steam Deck Storage Cleanup — Diagnostic & Safe Cleanup
# Run on the Deck in Konsole

echo "=========================================="
echo "  Steam Deck Storage Cleanup"
echo "=========================================="
echo ""

# --- Overall disk usage ---
echo "--- Internal Storage (/home) ---"
df -h /home | tail -1
echo ""

# --- Big space consumers ---
echo "--- Top Space Consumers in /home ---"
du -sh ~/Downloads ~/.cache ~/.local/share/Steam ~/.config 2>/dev/null | sort -rh | head -10
echo ""

# --- Proton / Compatibility Tools ---
echo "--- Proton & Compatibility Tools ---"
STEAM_COMMON="$HOME/.local/share/Steam/steamapps/common"
COMPAT_TOOLS="$HOME/.local/share/Steam/compatibilitytools.d"

if [ -d "$STEAM_COMMON" ]; then
    echo "Steam common folder:"
    du -sh "$STEAM_COMMON"/* 2>/dev/null | sort -rh | head -20
fi
echo ""

if [ -d "$COMPAT_TOOLS" ]; then
    echo "Custom Proton versions (compatibilitytools.d):"
    du -sh "$COMPAT_TOOLS"/* 2>/dev/null | sort -rh
else
    echo "No custom Proton versions installed."
fi
echo ""

# --- Shader Cache (can be MASSIVE) ---
echo "--- Shader Cache ---"
SHADER_CACHE="$HOME/.local/share/Steam/steamapps/shadercache"
if [ -d "$SHADER_CACHE" ]; then
    TOTAL=$(du -sh "$SHADER_CACHE" 2>/dev/null | cut -f1)
    echo "Total shader cache: $TOTAL"
    echo "Top games:"
    du -sh "$SHADER_CACHE"/* 2>/dev/null | sort -rh | head -10
else
    echo "No shader cache directory found."
fi
echo ""

# --- Download Cache ---
echo "--- Incomplete Downloads ---"
DL_CACHE="$HOME/.local/share/Steam/steamapps/downloading"
if [ -d "$DL_CACHE" ]; then
    du -sh "$DL_CACHE" 2>/dev/null
    ls "$DL_CACHE" 2>/dev/null | wc -l | xargs -I{} echo "{} pending download folders"
else
    echo "No download cache."
fi
echo ""

# --- Workshop Cache ---
echo "--- Workshop Cache ---"
WS_CACHE="$HOME/.local/share/Steam/steamapps/workshop"
if [ -d "$WS_CACHE" ]; then
    du -sh "$WS_CACHE" 2>/dev/null
else
    echo "No workshop cache."
fi
echo ""

# --- Pacman Cache (system packages) ---
echo "--- System Package Cache ---"
du -sh /var/cache/pacman/pkg/ 2>/dev/null || echo "Cannot access (read-only partition)"
echo ""

# --- Thumbnails ---
echo "--- Thumbnail Cache ---"
du -sh ~/.cache/thumbnails 2>/dev/null || echo "No thumbnail cache"
echo ""

echo "=========================================="
echo "  Review the above, then run cleanup.sh"
echo "  to safely reclaim space."
echo "=========================================="
