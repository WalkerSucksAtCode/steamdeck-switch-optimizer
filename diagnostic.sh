#!/bin/bash
# Steam Deck Switch Emulation — Diagnostic Report
# Run on the Deck, paste output back to get specific recommendations

echo "=========================================="
echo "  Steam Deck Switch Emulation Diagnostic"
echo "=========================================="
echo ""
echo "--- System Info ---"
uname -a
echo "SteamOS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "RAM: $(free -h | grep Mem | awk '{print $2}') total, $(free -h | grep Mem | awk '{print $7}') available"
echo "Storage: $(df -h /home | tail -1 | awk '{print $4}') free on /home"
echo ""

echo "--- Ryubing/Ryujinx ---"
RYU_CONFIG="$HOME/.config/Ryujinx/Config.json"
if [ -f "$RYU_CONFIG" ]; then
    echo "Config found: $RYU_CONFIG"
    echo "Version: $(jq -r '.version' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo "Backend: $(jq -r '.graphics_backend' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo "Docked: $(jq -r '.docked_mode' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo "Tick Scalar: $(jq -r '.tick_scalar' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo "Low Power PTC: $(jq -r '.enable_low_power_ptc' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo "VSync: $(jq -r '.enable_vsync' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo "Memory Mode: $(jq -r '.memory_manager_mode' "$RYU_CONFIG" 2>/dev/null || echo 'unknown')"
    echo ""
    echo "Game dirs:"
    jq -r '.game_dirs[]' "$RYU_CONFIG" 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "Shader caches:"
    for dir in "$HOME/.config/Ryujinx/games"/*/; do
        [ -d "$dir" ] || continue
        title_id=$(basename "$dir")
        cache_size=$(du -sh "${dir}cache/" 2>/dev/null | cut -f1)
        echo "  $title_id: ${cache_size:-none}"
    done
else
    echo "No Ryubing/Ryujinx config found"
fi
echo ""

echo "--- Eden ---"
EDEN_CONFIG="$HOME/.config/eden/qt-config.ini"
if [ -f "$EDEN_CONFIG" ]; then
    echo "Config found: $EDEN_CONFIG"
    echo "Resolution: $(grep '^resolution_setup=' "$EDEN_CONFIG" | cut -d= -f2)"
    echo "Docked: $(grep '^use_docked_mode=' "$EDEN_CONFIG" | cut -d= -f2)"
    echo "Scaling: $(grep '^scaling_filter=' "$EDEN_CONFIG" | cut -d= -f2)"
    echo "FSR Sharp: $(grep '^fsr_sharpening_slider=' "$EDEN_CONFIG" | cut -d= -f2)"
    echo "Async Shaders: $(grep '^use_asynchronous_shaders=' "$EDEN_CONFIG" | cut -d= -f2)"
    echo "VSync: $(grep '^use_vsync=' "$EDEN_CONFIG" | cut -d= -f2)"
    echo "Force Max Clock: $(grep '^force_max_clock=' "$EDEN_CONFIG" | cut -d= -f2)"
else
    echo "No Eden config found"
fi
echo ""

echo "--- Firmware & Keys ---"
echo "Ryubing keys:"
ls -la "$HOME/.config/Ryujinx/system/"*.keys 2>/dev/null || echo "  No keys found"
echo "Ryubing firmware:"
ls "$HOME/.config/Ryujinx/bis/system/Contents/registered/" 2>/dev/null | wc -l | xargs -I{} echo "  {} firmware files"
echo ""
echo "Eden keys:"
ls -la "$HOME/.local/share/eden/keys/"*.keys 2>/dev/null || echo "  No keys found"
echo "Eden firmware:"
ls "$HOME/.local/share/eden/nand/system/Contents/registered/" 2>/dev/null | wc -l | xargs -I{} echo "  {} firmware files"
echo ""

echo "--- Swap ---"
swapon --show 2>/dev/null || echo "  No swap configured"
echo ""

echo "--- EmuDeck ---"
if [ -d "$HOME/.config/EmuDeck" ] || [ -d "$HOME/emudeck" ]; then
    echo "EmuDeck: installed"
else
    echo "EmuDeck: not found"
fi
echo ""

echo "=========================================="
echo "  Copy everything above and paste it back"
echo "=========================================="
