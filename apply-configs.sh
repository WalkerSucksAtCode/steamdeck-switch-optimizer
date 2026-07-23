#!/bin/bash
# Steam Deck Switch Emulation Config Optimizer
# Run this on the Steam Deck in Desktop Mode via Konsole
# Backs up existing configs and applies optimized versions

set -e

echo "=== Steam Deck Switch Emulation Optimizer ==="
echo ""

# Create backup directory
BACKUP_DIR="$HOME/.config/emulation-backups-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backups will be saved to: $BACKUP_DIR"
echo ""

# === RYUBING ===
RYU_CONFIG="$HOME/.config/Ryujinx/Config.json"
RYU_GAMES_DIR="$HOME/.config/Ryujinx/games"

if [ -f "$RYU_CONFIG" ]; then
    echo "--- Backing up Ryubing/Ryujinx config ---"
    cp "$RYU_CONFIG" "$BACKUP_DIR/Config.json.bak"

    echo "--- Applying Ryubing optimizations ---"

    # Check if jq is available
    if command -v jq &>/dev/null; then
        tmp=$(mktemp)

        jq '
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
        ' "$RYU_CONFIG" > "$tmp" && mv "$tmp" "$RYU_CONFIG"

        echo "✅ Ryubing config optimized via jq"
    else
        echo "⚠️  jq not found, using sed fallback..."

        # tick_scalar: 200 → 150
        sed -i 's/"tick_scalar": [0-9]*/"tick_scalar": 150/' "$RYU_CONFIG"
        # enable_low_power_ptc: false → true
        sed -i 's/"enable_low_power_ptc": false/"enable_low_power_ptc": true/' "$RYU_CONFIG"
        # Reduce logging
        sed -i 's/"logging_enable_info": true/"logging_enable_info": false/' "$RYU_CONFIG"
        sed -i 's/"logging_enable_guest": true/"logging_enable_guest": false/' "$RYU_CONFIG"
        # Disable update checks
        sed -i 's/"check_updates_on_start": true/"check_updates_on_start": false/' "$RYU_CONFIG"
        # Hide cursor
        sed -i 's/"hide_cursor": [0-9]*/"hide_cursor": 1/' "$RYU_CONFIG"

        echo "✅ Ryubing config optimized via sed (jq not available)"
    fi
else
    echo "⚠️  Ryubing/Ryujinx config not found at $RYU_CONFIG"
    echo "    Make sure Ryubing is installed and has been run at least once."
fi

echo ""

# === EDEN ===
EDEN_CONFIG="$HOME/.config/eden/qt-config.ini"

if [ -f "$EDEN_CONFIG" ]; then
    echo "--- Backing up Eden config ---"
    cp "$EDEN_CONFIG" "$BACKUP_DIR/qt-config.ini.bak"

    echo "--- Applying Eden optimizations ---"

    # Resolution: 2 → 1 (lower internal res for Pokemon performance)
    sed -i 's/^resolution_setup=[0-9]*/resolution_setup=1/' "$EDEN_CONFIG"
    sed -i 's/^resolution_setup\\default=.*/resolution_setup\\default=false/' "$EDEN_CONFIG"

    # FSR sharpening: 25 → 40
    sed -i 's/^fsr_sharpening_slider=[0-9]*/fsr_sharpening_slider=40/' "$EDEN_CONFIG"
    sed -i 's/^fsr_sharpening_slider\\default=.*/fsr_sharpening_slider\\default=false/' "$EDEN_CONFIG"

    # Force max GPU clock (reduces throttling stutter)
    sed -i 's/^force_max_clock=false/force_max_clock=true/' "$EDEN_CONFIG"
    sed -i 's/^force_max_clock\\default=.*/force_max_clock\\default=false/' "$EDEN_CONFIG"

    # Keep async shaders on
    sed -i 's/^use_asynchronous_shaders=false/use_asynchronous_shaders=true/' "$EDEN_CONFIG"
    sed -i 's/^use_asynchronous_shaders\\default=.*/use_asynchronous_shaders\\default=false/' "$EDEN_CONFIG"

    echo "✅ Eden config optimized"
else
    echo "⚠️  Eden config not found at $EDEN_CONFIG"
    echo "    (This is fine if you only use Ryubing)"
fi

echo ""

# === STEAM DECK TDP / POWER SETTINGS ===
echo "--- Steam Deck Power Tips ---"
echo "For best battery life with Switch games:"
echo "  Game Mode → game Properties → Power Management"
echo "  Set TDP Limit to 10-13W for Pokemon games"
echo "  (Stock is 15W — Pokemon doesn't need full power)"
echo ""

# === SHADER CACHE STATUS ===
echo "--- Shader Cache Status ---"
if [ -d "$RYU_GAMES_DIR" ]; then
    for dir in "$RYU_GAMES_DIR"/*/; do
        title_id=$(basename "$dir")
        cache_size=$(du -sh "${dir}cache/" 2>/dev/null | cut -f1)
        if [ -n "$cache_size" ]; then
            echo "  $title_id: ${cache_size} shader cache"
        fi
    done
else
    echo "  No Ryubing game cache directory found yet."
    echo "  Shader caches build up as you play — first session will stutter."
fi

echo ""
echo "=== Optimization complete! ==="
echo "Backups saved to: $BACKUP_DIR"
echo ""
echo "If anything breaks, restore with:"
echo "  cp $BACKUP_DIR/Config.json.bak ~/.config/Ryujinx/Config.json"
echo "  cp $BACKUP_DIR/qt-config.ini.bak ~/.config/eden/qt-config.ini"
