#!/bin/bash
# Steam Deck Storage Cleanup — Safe Reclaim
# Only removes things Steam regenerates or that are redundant
# Does NOT touch: games, saves, configs, ROMs, EmuDeck

echo "=========================================="
echo "  Steam Deck Storage Cleanup"
echo "=========================================="
echo ""

FREED=0
format_bytes() {
    # Input is in KB (from du -sk)
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

# Safe byte counter — handles edge cases, uses -sk (KB) for portability
safe_size() {
    local result
    result=$(du -sk "$1" 2>/dev/null | cut -f1)
    echo "${result:-0}"
}

COMPAT_TOOLS="$HOME/.local/share/Steam/compatibilitytools.d"
SHADER_CACHE="$HOME/.local/share/Steam/steamapps/shadercache"
DL_CACHE="$HOME/.local/share/Steam/steamapps/downloading"
STEAM_COMMON="$HOME/.local/share/Steam/steamapps/common"

echo "Before: $(df -h /home | tail -1 | awk '{print $4}') free"
echo ""

# === 1. OLD PROTON VERSIONS ===
echo "--- Checking Proton versions ---"
# Find which Proton versions are actually used by installed games
USED_PROTON_VERSIONS=$(grep -roh '"verb"[[:space:]]*"[^"]*"' "$HOME/.local/share/Steam/config/config.vdf" 2>/dev/null | sed 's/"verb"[[:space:]]*"//; s/"//' | sort -u)

if [ -d "$COMPAT_TOOLS" ]; then
    for proton_dir in "$COMPAT_TOOLS"/*/; do
        [ -d "$proton_dir" ] || continue
        proton_name=$(basename "$proton_dir")
        size_h=$(du -sh "$proton_dir" 2>/dev/null | cut -f1)

        echo "  Found: $proton_name ($size_h)"
    done
    echo ""
    echo "Custom Proton versions above. To remove specific ones:"
    echo "  rm -rf \"$COMPAT_TOOLS/VERSION_NAME\""
    echo "  (I won't auto-delete these — they might be needed)"
else
    echo "  No custom Proton versions found."
fi
echo ""

# === 2. SHADER CACHE (safe to delete — Steam regenerates) ===
if [ -d "$SHADER_CACHE" ]; then
    SIZE_BEFORE=$(safe_size "$SHADER_CACHE")
    SIZE_H=$(du -sh "$SHADER_CACHE" 2>/dev/null | cut -f1)
    echo "--- Clearing shader cache ($SIZE_H) ---"
    echo "  (Safe — Steam regenerates these as you play)"
    rm -rf "${SHADER_CACHE:?}/"*
    SIZE_AFTER=$(safe_size "$SHADER_CACHE")
    SAVED=$((SIZE_BEFORE - SIZE_AFTER))
    FREED=$((FREED + SAVED))
    echo "  ✅ Freed $(format_bytes $SAVED)"
else
    echo "--- No shader cache ---"
fi
echo ""

# === 3. INCOMPLETE DOWNLOADS ===
if [ -d "$DL_CACHE" ]; then
    SIZE_BEFORE=$(safe_size "$DL_CACHE")
    SIZE_H=$(du -sh "$DL_CACHE" 2>/dev/null | cut -f1)

    if [ "${SIZE_BEFORE:-0}" -gt 10240 ] 2>/dev/null; then  # only if >10MB (10*1024 KB)
        echo "--- Clearing incomplete downloads ($SIZE_H) ---"
        echo "  (Safe — these are partial/abandoned downloads)"
        rm -rf "${DL_CACHE:?}/"*
        SIZE_AFTER=$(safe_size "$DL_CACHE")
        SAVED=$((SIZE_BEFORE - SIZE_AFTER))
        FREED=$((FREED + SAVED))
        echo "  ✅ Freed $(format_bytes $SAVED)"
    else
        echo "--- Incomplete downloads negligible ($SIZE_H) ---"
    fi
else
    echo "--- No download cache ---"
fi
echo ""

# === 4. UNUSED COMPATDATA (Windows game prefix data for uninstalled games) ===
echo "--- Checking for orphaned compatdata ---"
COMPATDATA="$HOME/.local/share/Steam/steamapps/compatdata"
if [ -d "$COMPATDATA" ]; then
    # Get list of installed Steam game IDs
    INSTALLED_IDS=$(find "$STEAM_COMMON" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | xargs -I{} basename {} | grep -E '^[0-9]+$')

    ORPHAN_SIZE=0
    ORPHAN_COUNT=0
    for appid_dir in "$COMPATDATA"/*/; do
        [ -d "$appid_dir" ] || continue
        appid=$(basename "$appid_dir")
        # Check if this appid has a corresponding install
        if ! echo "$INSTALLED_IDS" | grep -qw "$appid" 2>/dev/null; then
            size=$(safe_size "$appid_dir")
            size_h=$(du -sh "$appid_dir" 2>/dev/null | cut -f1)
            ORPHAN_SIZE=$((ORPHAN_SIZE + ${size:-0}))
            ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
            echo "  Orphaned: $appid ($size_h)"
        fi
    done

    if [ "$ORPHAN_COUNT" -gt 0 ]; then
        echo ""
        echo "  Found $ORPHAN_COUNT orphaned compatdata entries ($(format_bytes $ORPHAN_SIZE))"
        echo "  To remove them, run:"
        for appid_dir in "$COMPATDATA"/*/; do
            appid=$(basename "$appid_dir")
            if ! echo "$INSTALLED_IDS" | grep -qw "$appid" 2>/dev/null; then
                echo "    rm -rf \"$COMPATDATA/$appid\""
            fi
        done
        echo "  (Not auto-deleting — review first)"
    else
        echo "  No orphaned compatdata."
    fi
else
    echo "  No compatdata directory."
fi
echo ""

# === 5. THUMBNAIL CACHE ===
if [ -d ~/.cache/thumbnails ]; then
    SIZE_BEFORE=$(safe_size ~/.cache/thumbnails)
    SIZE_H=$(du -sh ~/.cache/thumbnails 2>/dev/null | cut -f1)
    if [ "${SIZE_BEFORE:-0}" -gt 1024 ] 2>/dev/null; then
        echo "--- Clearing thumbnail cache ($SIZE_H) ---"
        rm -rf ~/.cache/thumbnails/*
        FREED=$((FREED + SIZE_BEFORE))
        echo "  ✅ Freed $SIZE_H"
    fi
fi
echo ""

# === 6. OLD EMULATOR BUILDS / APPIMAGES ===
echo "--- Checking for old emulator builds ---"
# EmuDeck often leaves old AppImages around
for old_emu in ~/Applications/*.old ~/.local/share/applications/*.old; do
    [ -f "$old_emu" ] || continue
    size_h=$(du -sh "$old_emu" 2>/dev/null | cut -f1)
    echo "  Old file: $old_emu ($size_h)"
    echo "    rm \"$old_emu\""
done

# Check for duplicate Ryubing/Ryujinx binaries
echo ""
echo "--- Checking for duplicate emulator binaries ---"
find ~/.local ~/Applications -name 'Ryujinx*' -o -name 'eden*' -o -name 'Eden*' 2>/dev/null | while read f; do
    echo "  $(du -sh "$f" 2>/dev/null | cut -f1)  $f"
done
echo ""

# === 7. PACMAN CACHE (if writable) ===
if [ -w /var/cache/pacman/pkg/ ]; then
    SIZE_H=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    echo "--- Clearing pacman cache ($SIZE_H) ---"
    sudo pacman -Sc --noconfirm 2>/dev/null
    echo "  ✅ Cleaned"
else
    echo "--- Pacman cache on read-only partition (skipping) ---"
fi
echo ""

# === RESULTS ===
echo "=========================================="
echo "  Cleanup Complete"
echo "=========================================="
echo "Total freed: $(format_bytes $FREED)"
echo "After: $(df -h /home | tail -1 | awk '{print $4}') free"
echo ""
echo "Additional manual cleanup available above —"
echo "check the orphaned compatdata and old Proton versions."
echo "=========================================="
