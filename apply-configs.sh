#!/bin/bash
# Backup + patch Ryubing/Eden configs for Steam Deck.

set -euo pipefail

# Portable in-place sed (GNU on Deck, BSD on macOS).
sed_inplace() {
    local file=$1
    shift
    local tmp
    tmp=$(mktemp)
    sed "$@" "$file" >"$tmp"
    mv "$tmp" "$file"
}

echo "=== apply-configs ==="
echo ""

BACKUP_DIR="$HOME/.config/emulation-backups-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup: $BACKUP_DIR"
echo ""

CHANGED=0

RYU_CONFIG="$HOME/.config/Ryujinx/Config.json"
RYU_GAMES_DIR="$HOME/.config/Ryujinx/games"

if [ -f "$RYU_CONFIG" ]; then
    echo "--- Ryubing ---"
    cp "$RYU_CONFIG" "$BACKUP_DIR/Config.json.bak"
    CHANGED=1

    if command -v jq &>/dev/null; then
        tmp=$(mktemp)
        if jq '
            .tick_scalar = 150 |
            .enable_low_power_ptc = true |
            .docked_mode = false |
            .enable_shader_cache = true |
            .enable_ptc = true |
            .enable_texture_recompression = false |
            .enable_vsync = false |
            .memory_manager_mode = "HostMappedUnsafe" |
            .enable_macro_hle = true |
            .audio_backend = "SDL3" |
            .logging_enable_info = false |
            .logging_enable_guest = false |
            .check_updates_on_start = false |
            .hide_cursor = 1
        ' "$RYU_CONFIG" > "$tmp" \
            && jq empty "$tmp" 2>/dev/null \
            && mv "$tmp" "$RYU_CONFIG"; then
            echo "patched (jq)"
        else
            echo "ERROR: jq patch failed; original unchanged. Backup: $BACKUP_DIR" >&2
            rm -f "$tmp"
            exit 1
        fi
    else
        echo "jq missing; sed fallback (fewer keys)"
        sed_inplace "$RYU_CONFIG" \
            -e 's/"tick_scalar": [0-9]*/"tick_scalar": 150/' \
            -e 's/"enable_low_power_ptc": false/"enable_low_power_ptc": true/' \
            -e 's/"docked_mode": true/"docked_mode": false/' \
            -e 's/"enable_texture_recompression": true/"enable_texture_recompression": false/' \
            -e 's/"enable_vsync": true/"enable_vsync": false/' \
            -e 's/"memory_manager_mode": "[^"]*"/"memory_manager_mode": "HostMappedUnsafe"/' \
            -e 's/"audio_backend": "[^"]*"/"audio_backend": "SDL3"/' \
            -e 's/"logging_enable_info": true/"logging_enable_info": false/' \
            -e 's/"logging_enable_guest": true/"logging_enable_guest": false/' \
            -e 's/"check_updates_on_start": true/"check_updates_on_start": false/' \
            -e 's/"hide_cursor": [0-9]*/"hide_cursor": 1/'
        echo "patched (sed)"
    fi
else
    echo "Ryubing config missing: $RYU_CONFIG"
    echo "  Install/run Ryubing once first."
fi

echo ""

EDEN_CONFIG="$HOME/.config/eden/qt-config.ini"

if [ -f "$EDEN_CONFIG" ]; then
    echo "--- Eden ---"
    cp "$EDEN_CONFIG" "$BACKUP_DIR/qt-config.ini.bak"
    CHANGED=1

    sed_inplace "$EDEN_CONFIG" \
        -e 's/^resolution_setup=[0-9]*/resolution_setup=1/' \
        -e 's/^resolution_setup\\default=.*/resolution_setup\\default=false/' \
        -e 's/^fsr_sharpening_slider=[0-9]*/fsr_sharpening_slider=40/' \
        -e 's/^fsr_sharpening_slider\\default=.*/fsr_sharpening_slider\\default=false/' \
        -e 's/^force_max_clock=false/force_max_clock=true/' \
        -e 's/^force_max_clock\\default=.*/force_max_clock\\default=false/' \
        -e 's/^use_asynchronous_shaders=false/use_asynchronous_shaders=true/' \
        -e 's/^use_asynchronous_shaders\\default=.*/use_asynchronous_shaders\\default=false/'

    echo "patched"
else
    echo "Eden config missing: $EDEN_CONFIG (ok if Ryubing-only)"
fi

echo ""
echo "--- PowerTools / TDP ---"
echo "  SMT off, GPU 1200 MHz (Decky PowerTools)"
echo "  Lower TDP for battery (stock 15W is often more than needed)"
echo ""

echo "--- Ryubing shader caches ---"
if [ -d "$RYU_GAMES_DIR" ]; then
    shopt -s nullglob
    caches=("$RYU_GAMES_DIR"/*/)
    if [ ${#caches[@]} -eq 0 ]; then
        echo "  none yet"
    else
        for dir in "${caches[@]}"; do
            title_id=$(basename "$dir")
            cache_size=$(du -sh "${dir}cache/" 2>/dev/null | cut -f1 || true)
            if [ -n "${cache_size:-}" ]; then
                echo "  $title_id: $cache_size"
            fi
        done
    fi
    shopt -u nullglob
else
    echo "  no games/ cache dir (first session will stutter)"
fi

echo ""
if [ "$CHANGED" -eq 0 ]; then
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    echo "=== no configs found ==="
else
    echo "=== done ==="
    echo "Backup: $BACKUP_DIR"
    echo "Restore:"
    [ -f "$BACKUP_DIR/Config.json.bak" ] && \
        echo "  cp \"$BACKUP_DIR/Config.json.bak\" ~/.config/Ryujinx/Config.json"
    [ -f "$BACKUP_DIR/qt-config.ini.bak" ] && \
        echo "  cp \"$BACKUP_DIR/qt-config.ini.bak\" ~/.config/eden/qt-config.ini"
fi
