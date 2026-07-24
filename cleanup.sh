#!/bin/bash
# Safe Steam cache cleanup. Does not touch games, saves, ROMs, or orphaned compatdata.
#
#   ./cleanup.sh                 dry-run
#   ./cleanup.sh --apply         delete safe caches
#   ./cleanup.sh --apply --pacman  also pacman -Sc (sudo)

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
            echo "  (default) dry-run"
            echo "  --apply   delete shader caches, incomplete downloads, thumbnails"
            echo "  --pacman  with --apply: sudo pacman -Sc"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

echo "=== cleanup ==="
if [ "$APPLY" -eq 0 ]; then
    echo "mode: dry-run (--apply to delete)"
else
    echo "mode: apply"
fi
echo "steam: $STEAM_HOME"
echo ""

FREED=0

HOME_FREE=$(df -h /home 2>/dev/null | awk 'NR==2 {print $4}')
echo "before: ${HOME_FREE:-unknown} free on /home"
echo ""

echo "--- Proton (custom) ---"
if [ -d "$COMPAT_TOOLS" ]; then
    shopt -s nullglob
    found_proton=0
    for proton_dir in "$COMPAT_TOOLS"/*/; do
        [ -d "$proton_dir" ] || continue
        found_proton=1
        proton_name=$(basename "$proton_dir")
        size_h=$(du -sh "$proton_dir" 2>/dev/null | cut -f1)
        echo "  $proton_name ($size_h)"
    done
    shopt -u nullglob
    if [ "$found_proton" -eq 1 ]; then
        echo "  not auto-deleted; example: rm -rf \"$COMPAT_TOOLS/VERSION_NAME\""
    else
        echo "  empty"
    fi
else
    echo "  none"
fi
echo ""

echo "--- shader cache ---"
ANY_SHADER=0
while IFS= read -r SC; do
    [ -d "$SC" ] || continue
    ANY_SHADER=1
    SIZE_BEFORE=$(safe_size "$SC")
    SIZE_H=$(du -sh "$SC" 2>/dev/null | cut -f1)
    echo "  $SC ($SIZE_H)"
    if [ "$SIZE_BEFORE" -eq 0 ] 2>/dev/null; then
        continue
    fi
    if [ "$APPLY" -eq 1 ]; then
        empty_dir_contents "$SC"
        SIZE_AFTER=$(safe_size "$SC")
        SAVED=$((SIZE_BEFORE - SIZE_AFTER))
        [ "$SAVED" -lt 0 ] && SAVED=0
        FREED=$((FREED + SAVED))
        echo "    freed $(format_bytes "$SAVED")"
    else
        echo "    would free $(format_bytes "$SIZE_BEFORE")"
    fi
done < <(list_shadercache_roots)
[ "$ANY_SHADER" -eq 0 ] && echo "  none"
echo ""

echo "--- incomplete downloads ---"
ANY_DL=0
while IFS= read -r DC; do
    [ -d "$DC" ] || continue
    ANY_DL=1
    SIZE_BEFORE=$(safe_size "$DC")
    SIZE_H=$(du -sh "$DC" 2>/dev/null | cut -f1)
    if [ "${SIZE_BEFORE:-0}" -gt 10240 ] 2>/dev/null; then
        echo "  $DC ($SIZE_H)"
        if [ "$APPLY" -eq 1 ]; then
            empty_dir_contents "$DC"
            SIZE_AFTER=$(safe_size "$DC")
            SAVED=$((SIZE_BEFORE - SIZE_AFTER))
            [ "$SAVED" -lt 0 ] && SAVED=0
            FREED=$((FREED + SAVED))
            echo "    freed $(format_bytes "$SAVED")"
        else
            echo "    would free $(format_bytes "$SIZE_BEFORE")"
        fi
    else
        echo "  $DC negligible ($SIZE_H)"
    fi
done < <(list_downloading_roots)
[ "$ANY_DL" -eq 0 ] && echo "  none"
echo ""

echo "--- orphaned compatdata ---"
INSTALLED=$(collect_installed_appids)
ORPHAN_SIZE=0
ORPHAN_COUNT=0
ORPHAN_PATHS=()

COMPAT_ROOTS=$(list_compatdata_roots)
if [ -n "$COMPAT_ROOTS" ]; then
    while IFS= read -r COMPATDATA_ROOT; do
        [ -d "$COMPATDATA_ROOT" ] || continue
        shopt -s nullglob
        for appid_dir in "$COMPATDATA_ROOT"/*/; do
            [ -d "$appid_dir" ] || continue
            appid=$(basename "$appid_dir")
            [[ "$appid" =~ ^[0-9]+$ ]] || continue
            if ! echo "$INSTALLED" | grep -qx "$appid"; then
                size=$(safe_size "$appid_dir")
                size_h=$(du -sh "$appid_dir" 2>/dev/null | cut -f1)
                ORPHAN_SIZE=$((ORPHAN_SIZE + ${size:-0}))
                ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
                ORPHAN_PATHS+=("${appid_dir%/}")
                echo "  orphan $appid ($size_h) $COMPATDATA_ROOT"
            fi
        done
        shopt -u nullglob
    done <<< "$COMPAT_ROOTS"

    if [ "$ORPHAN_COUNT" -gt 0 ]; then
        echo ""
        echo "  $ORPHAN_COUNT orphans ($(format_bytes "$ORPHAN_SIZE"))"
        if [ -z "$INSTALLED" ]; then
            echo "  WARNING: empty install list; not printing rm"
        else
            echo "  not auto-deleted:"
            for path in "${ORPHAN_PATHS[@]}"; do
                echo "    rm -rf \"$path\""
            done
        fi
    else
        echo "  none"
    fi
else
    echo "  no compatdata dirs"
fi
echo ""

if [ -d "$HOME/.cache/thumbnails" ]; then
    SIZE_BEFORE=$(safe_size "$HOME/.cache/thumbnails")
    SIZE_H=$(du -sh "$HOME/.cache/thumbnails" 2>/dev/null | cut -f1)
    if [ "${SIZE_BEFORE:-0}" -gt 1024 ] 2>/dev/null; then
        echo "--- thumbnails ($SIZE_H) ---"
        if [ "$APPLY" -eq 1 ]; then
            empty_dir_contents "$HOME/.cache/thumbnails"
            FREED=$((FREED + SIZE_BEFORE))
            echo "  freed $SIZE_H"
        else
            echo "  would free $(format_bytes "$SIZE_BEFORE")"
        fi
        echo ""
    fi
fi

echo "--- old emulator builds ---"
FOUND_OLD=0
shopt -s nullglob
for old_emu in "$HOME"/Applications/*.old "$HOME"/.local/share/applications/*.old; do
    [ -f "$old_emu" ] || continue
    FOUND_OLD=1
    size_h=$(du -sh "$old_emu" 2>/dev/null | cut -f1)
    echo "  $old_emu ($size_h)"
    echo "    rm \"$old_emu\""
done
shopt -u nullglob
[ "$FOUND_OLD" -eq 0 ] && echo "  none"

echo ""
echo "--- emulator binaries ---"
FOUND_BIN=0
while IFS= read -r f; do
    [ -e "$f" ] || continue
    FOUND_BIN=1
    echo "  $(du -sh "$f" 2>/dev/null | cut -f1)  $f"
done < <(find "$HOME/.local" "$HOME/Applications" \( -name 'Ryujinx*' -o -name 'Ryubing*' -o -name 'eden*' -o -name 'Eden*' \) 2>/dev/null)
[ "$FOUND_BIN" -eq 0 ] && echo "  none"
echo ""

if [ "$DO_PACMAN" -eq 1 ]; then
    if [ -w /var/cache/pacman/pkg/ ] 2>/dev/null; then
        SIZE_H=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
        echo "--- pacman ($SIZE_H) ---"
        if [ "$APPLY" -eq 1 ]; then
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sc --noconfirm
                echo "  cleaned"
            else
                echo "  pacman not found"
            fi
        else
            echo "  would run: sudo pacman -Sc --noconfirm"
        fi
    else
        echo "--- pacman not writable (skip) ---"
    fi
    echo ""
elif [ "$APPLY" -eq 0 ]; then
    echo "--- pacman ---"
    echo "  skipped (add --pacman with --apply)"
    echo ""
fi

HOME_FREE_AFTER=$(df -h /home 2>/dev/null | awk 'NR==2 {print $4}')
echo "=== done ==="
if [ "$APPLY" -eq 1 ]; then
    echo "freed: $(format_bytes "$FREED")"
else
    echo "dry-run; nothing deleted"
fi
echo "after: ${HOME_FREE_AFTER:-unknown} free on /home"
