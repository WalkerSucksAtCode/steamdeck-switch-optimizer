#!/bin/bash
# Steam Deck Switch Emulation Config Optimizer
# Run this on the Steam Deck in Desktop Mode via Konsole
# Backs up existing configs and applies optimized versions

set -euo pipefail

echo "=== Steam Deck Switch Emulation Optimizer ==="
echo ""

BACKUP_DIR="$HOME/.config/emulation-backups-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backups will be saved to: $BACKUP_DIR"
echo ""

CHANGED=0

# === RYUBING ===
RYU_CONFIG="$HOME/.config/Ryujinx/Config.json"
RYU_GAMES_DIR="$HOME/.config/Ryujinx/games"

if [ -f "$RYU_CONFIG" ]; then
    echo "--- Backing up Ryubing/Ryujinx config ---"
    cp "$RYU_CONFIG" "$BACKUP_DIR/Config.json.bak"
    CHANGED=1

    echo "--- Applying Ryubing optimizations ---"

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
            echo "Ryubing config optimized via jq"
        else
            echo "ERROR: jq patch failed — original left intact (backup in $BACKUP_DIR)" >&2
            rm -f "$tmp"
            exit 1
        fi
    else
        echo "jq not found, using sed fallback (subset of settings)..."

        # GNU sed -i on Steam Deck; avoid creating empty suffix backup
        sed -i \
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
            -e 's/"hide_cursor": [0-9]*/"hide_cursor": 1/' \
            "$RYU_CONFIG"

        echo "Ryubing config optimized via sed"
    fi
else
    echo "Ryubing/Ryujinx config not found at $RYU_CONFIG"
    echo "  Make sure Ryubing is installed and has been run at least once."
fi

echo ""

# === EDEN ===
EDEN_CONFIG="$HOME/.config/eden/qt-config.ini"

if [ -f "$EDEN_CONFIG" ]; then
    echo "--- Backing up Eden config ---"
    cp "$EDEN_CONFIG" "$BACKUP_DIR/qt-config.ini.bak"
    CHANGED=1

    echo "--- Applying Eden optimizations ---"

    sed -i \
        -e 's/^resolution_setup=[0-9]*/resolution_setup=1/' \
        -e 's/^resolution_setup\\default=.*/resolution_setup\\default=false/' \
        -e 's/^fsr_sharpening_slider=[0-9]*/fsr_sharpening_slider=40/' \
        -e 's/^fsr_sharpening_slider\\default=.*/fsr_sharpening_slider\\default=false/' \
        -e 's/^force_max_clock=false/force_max_clock=true/' \
        -e 's/^force_max_clock\\default=.*/force_max_clock\\default=false/' \
        -e 's/^use_asynchronous_shaders=false/use_asynchronous_shaders=true/' \
        -e 's/^use_asynchronous_shaders\\default=.*/use_asynchronous_shaders\\default=false/' \
        "$EDEN_CONFIG"

    echo "Eden config optimized"
else
    echo "Eden config not found at $EDEN_CONFIG"
    echo "  (Fine if you only use Ryubing)"
fi

echo ""

echo "--- Steam Deck Power Tips ---"
echo "For best battery life with Switch games:"
echo "  Game Mode → game Properties → Power Management"
echo "  Set TDP Limit to 10-13W for Pokemon games"
echo "  (Stock is 15W — Pokemon often doesn't need full power)"
echo ""

echo "--- Shader Cache Status ---"
if [ -d "$RYU_GAMES_DIR" ]; then
    shopt -s nullglob
    caches=("$RYU_GAMES_DIR"/*/)
    if [ ${#caches[@]} -eq 0 ]; then
        echo "  No per-game cache folders yet."
    else
        for dir in "${caches[@]}"; do
            title_id=$(basename "$dir")
            cache_size=$(du -sh "${dir}cache/" 2>/dev/null | cut -f1 || true)
            if [ -n "${cache_size:-}" ]; then
                echo "  $title_id: ${cache_size} shader cache"
            fi
        done
    fi
    shopt -u nullglob
else
    echo "  No Ryubing game cache directory found yet."
    echo "  Shader caches build up as you play — first session will stutter."
fi

echo ""
if [ "$CHANGED" -eq 0 ]; then
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    echo "=== Nothing to optimize (no configs found) ==="
else
    echo "=== Optimization complete ==="
    echo "Backups saved to: $BACKUP_DIR"
    echo ""
    echo "If anything breaks, restore with:"
    [ -f "$BACKUP_DIR/Config.json.bak" ] && \
        echo "  cp \"$BACKUP_DIR/Config.json.bak\" ~/.config/Ryujinx/Config.json"
    [ -f "$BACKUP_DIR/qt-config.ini.bak" ] && \
        echo "  cp \"$BACKUP_DIR/qt-config.ini.bak\" ~/.config/eden/qt-config.ini"
fi
