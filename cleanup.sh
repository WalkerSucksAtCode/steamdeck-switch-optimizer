#!/bin/bash
# Steam Deck Storage Cleanup — Safe Reclaim
# Only removes things Steam regenerates or that are redundant
# Does NOT touch: games, saves, configs, ROMs, EmuDeck
#
# Usage:
#   ./cleanup.sh            # dry-run (default) — report only
#   ./cleanup.sh --apply    # actually delete safe caches
#   ./cleanup.sh --apply --pacman   # also clear pacman cache (needs sudo)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steam-common.sh
source "$SCRIPT_DIR/steam-common.sh"

APPLY=0
DO_PACMAN=0
for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=1 ;;
        --pacman) DO_PACMAN=1 ;;
        -h|--help)
            echo "Usage: $0 [--apply] [--pacman]"
            echo "  (default)  dry-run — show what would be freed"
            echo "  --apply    delete shader cache, incomplete downloads, thumbnails"
            echo "  --pacman   with --apply, also run pacman -Sc (needs sudo)"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  Steam Deck Storage Cleanup"
if [ "$APPLY" -eq 0 ]; then
    echo "  Mode: DRY-RUN (pass --apply to delete)"
else
    echo "  Mode: APPLY"
fi
echo "=========================================="
echo ""

FREED=0

echo "Before: $(df -h /home 2>/dev/null | tail -1 | awk '{print $4}') free on /home"
echo ""

# === 1. OLD PROTON VERSIONS ===
echo "--- Checking Proton versions ---"
if [ -d "$COMPAT_TOOLS" ]; then
    for proton_dir in "$COMPAT_TOOLS"/*/; do
        [ -d "$proton_dir" ] || continue
        proton_name=$(basename "$proton_dir")
        size_h=$(du -sh "$proton_dir" 2>/dev/null | cut -f1)
        echo "  Found: $proton_name ($size_h)"
    done
    echo ""
    echo "  Custom Proton versions listed above — not auto-deleted."
    echo "  To remove one:  rm -rf \"$COMPAT_TOOLS/VERSION_NAME\""
else
    echo "  No custom Proton versions found."
fi
echo ""

# === 2. SHADER CACHE (safe to delete — Steam regenerates) ===
if [ -d "$SHADER_CACHE" ]; then
    SIZE_BEFORE=$(safe_size "$SHADER_CACHE")
    SIZE_H=$(du -sh "$SHADER_CACHE" 2>/dev/null | cut -f1)
    echo "--- Shader cache ($SIZE_H) ---"
    echo "  (Safe — Steam regenerates these as you play)"
    if [ "$APPLY" -eq 1 ]; then
        rm -rf "${SHADER_CACHE:?}/"*
        SIZE_AFTER=$(safe_size "$SHADER_CACHE")
        SAVED=$((SIZE_BEFORE - SIZE_AFTER))
        FREED=$((FREED + SAVED))
        echo "  Freed $(format_bytes "$SAVED")"
    else
        echo "  Would free ~$(format_bytes "$SIZE_BEFORE")"
    fi
else
    echo "--- No shader cache ---"
fi
echo ""

# === 3. INCOMPLETE DOWNLOADS ===
if [ -d "$DL_CACHE" ]; then
    SIZE_BEFORE=$(safe_size "$DL_CACHE")
    SIZE_H=$(du -sh "$DL_CACHE" 2>/dev/null | cut -f1)

    if [ "${SIZE_BEFORE:-0}" -gt 10240 ] 2>/dev/null; then
        echo "--- Incomplete downloads ($SIZE_H) ---"
        echo "  (Safe — partial/abandoned downloads)"
        if [ "$APPLY" -eq 1 ]; then
            rm -rf "${DL_CACHE:?}/"*
            SIZE_AFTER=$(safe_size "$DL_CACHE")
            SAVED=$((SIZE_BEFORE - SIZE_AFTER))
            FREED=$((FREED + SAVED))
            echo "  Freed $(format_bytes "$SAVED")"
        else
            echo "  Would free ~$(format_bytes "$SIZE_BEFORE")"
        fi
    else
        echo "--- Incomplete downloads negligible ($SIZE_H) ---"
    fi
else
    echo "--- No download cache ---"
fi
echo ""

# === 4. ORPHANED COMPATDATA (manifest-based, all libraries) ===
echo "--- Checking for orphaned compatdata ---"
if [ -d "$COMPATDATA" ]; then
    INSTALLED=$(collect_installed_appids)
    ORPHAN_SIZE=0
    ORPHAN_COUNT=0
    ORPHAN_IDS=()

    for appid_dir in "$COMPATDATA"/*/; do
        [ -d "$appid_dir" ] || continue
        appid=$(basename "$appid_dir")
        if ! echo "$INSTALLED" | grep -qx "$appid"; then
            size=$(safe_size "$appid_dir")
            size_h=$(du -sh "$appid_dir" 2>/dev/null | cut -f1)
            ORPHAN_SIZE=$((ORPHAN_SIZE + ${size:-0}))
            ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
            ORPHAN_IDS+=("$appid")
            echo "  Orphaned: $appid ($size_h)"
        fi
    done

    if [ "$ORPHAN_COUNT" -gt 0 ]; then
        echo ""
        echo "  Found $ORPHAN_COUNT orphaned compatdata entries ($(format_bytes "$ORPHAN_SIZE"))"
        echo "  Not auto-deleted — review, then run:"
        for appid in "${ORPHAN_IDS[@]}"; do
            echo "    rm -rf \"$COMPATDATA/$appid\""
        done
        echo "  Or:  ./find-orphans.sh"
    else
        echo "  No orphaned compatdata."
    fi
else
    echo "  No compatdata directory."
fi
echo ""

# === 5. THUMBNAIL CACHE ===
if [ -d "$HOME/.cache/thumbnails" ]; then
    SIZE_BEFORE=$(safe_size "$HOME/.cache/thumbnails")
    SIZE_H=$(du -sh "$HOME/.cache/thumbnails" 2>/dev/null | cut -f1)
    if [ "${SIZE_BEFORE:-0}" -gt 1024 ] 2>/dev/null; then
        echo "--- Thumbnail cache ($SIZE_H) ---"
        if [ "$APPLY" -eq 1 ]; then
            rm -rf "$HOME/.cache/thumbnails/"*
            FREED=$((FREED + SIZE_BEFORE))
            echo "  Freed $SIZE_H"
        else
            echo "  Would free ~$(format_bytes "$SIZE_BEFORE")"
        fi
        echo ""
    fi
fi

# === 6. OLD EMULATOR BUILDS / APPIMAGES ===
echo "--- Checking for old emulator builds ---"
FOUND_OLD=0
for old_emu in "$HOME"/Applications/*.old "$HOME"/.local/share/applications/*.old; do
    [ -f "$old_emu" ] || continue
    FOUND_OLD=1
    size_h=$(du -sh "$old_emu" 2>/dev/null | cut -f1)
    echo "  Old file: $old_emu ($size_h)"
    echo "    rm \"$old_emu\""
done
[ "$FOUND_OLD" -eq 0 ] && echo "  None found."

echo ""
echo "--- Emulator binaries (for review) ---"
find "$HOME/.local" "$HOME/Applications" \( -name 'Ryujinx*' -o -name 'eden*' -o -name 'Eden*' \) 2>/dev/null \
    | while read -r f; do
        echo "  $(du -sh "$f" 2>/dev/null | cut -f1)  $f"
    done
echo ""

# === 7. PACMAN CACHE (opt-in only) ===
if [ "$DO_PACMAN" -eq 1 ]; then
    if [ -w /var/cache/pacman/pkg/ ]; then
        SIZE_H=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
        echo "--- Pacman cache ($SIZE_H) ---"
        if [ "$APPLY" -eq 1 ]; then
            sudo pacman -Sc --noconfirm 2>/dev/null
            echo "  Cleaned"
        else
            echo "  Would run: sudo pacman -Sc --noconfirm"
        fi
    else
        echo "--- Pacman cache not writable (SteamOS read-only rootfs) — skipping ---"
    fi
    echo ""
fi

# === RESULTS ===
echo "=========================================="
if [ "$APPLY" -eq 1 ]; then
    echo "  Cleanup Complete"
    echo "  Total freed: $(format_bytes "$FREED")"
else
    echo "  Dry-run complete — nothing deleted"
    echo "  Re-run with --apply to reclaim safe caches"
fi
echo "  After: $(df -h /home 2>/dev/null | tail -1 | awk '{print $4}') free on /home"
echo "=========================================="
