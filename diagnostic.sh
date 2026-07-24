#!/bin/bash
# Print system / emu / keys snapshot (paste if asking for help).

set -u

json_get() {
    # json_get <file> <key>
    local file=$1 key=$2
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null
    else
        # Minimal fallback for flat string/bool/number keys
        sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p; s/.*\"${key}\"[[:space:]]*:[[:space:]]*\\(true\\|false\\|[0-9][0-9]*\\).*/\\1/p" "$file" 2>/dev/null | head -1
    fi
}

ini_get() {
    local file=$1 key=$2
    grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-
}

echo "=== diagnostic ==="
echo ""
echo "--- system ---"
uname -a 2>/dev/null || true
if [ -f /etc/os-release ]; then
    echo "SteamOS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
else
    echo "SteamOS: (no /etc/os-release)"
fi
if command -v lscpu >/dev/null 2>&1; then
    echo "CPU: $(lscpu 2>/dev/null | grep 'Model name' | cut -d: -f2 | sed 's/^ *//')"
else
    echo "CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
fi
if command -v free >/dev/null 2>&1; then
    echo "RAM: $(free -h | awk '/Mem:/ {print $2}') total, $(free -h | awk '/Mem:/ {print $7}') available"
else
    echo "RAM: unknown"
fi
echo "Storage: $(df -h /home 2>/dev/null | awk 'NR==2 {print $4}') free on /home"
echo ""

echo "--- Ryubing/Ryujinx ---"
RYU_CONFIG="$HOME/.config/Ryujinx/Config.json"
if [ -f "$RYU_CONFIG" ]; then
    echo "Config found: $RYU_CONFIG"
    for key in version graphics_backend docked_mode tick_scalar enable_low_power_ptc enable_vsync memory_manager_mode; do
        val=$(json_get "$RYU_CONFIG" "$key")
        echo "$key: ${val:-unknown}"
    done
    echo ""
    echo "Game dirs:"
    if command -v jq >/dev/null 2>&1; then
        jq -r '.game_dirs[]?' "$RYU_CONFIG" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
    else
        echo "  (install jq for game_dirs listing)"
    fi
    echo ""
    echo "Shader caches:"
    shopt -s nullglob
    found=0
    for dir in "$HOME/.config/Ryujinx/games"/*/; do
        found=1
        title_id=$(basename "$dir")
        cache_size=$(du -sh "${dir}cache/" 2>/dev/null | cut -f1 || true)
        echo "  $title_id: ${cache_size:-none}"
    done
    shopt -u nullglob
    [ "$found" -eq 0 ] && echo "  (none)"
else
    echo "No Ryubing/Ryujinx config found"
fi
echo ""

echo "--- Eden ---"
EDEN_CONFIG="$HOME/.config/eden/qt-config.ini"
if [ -f "$EDEN_CONFIG" ]; then
    echo "Config found: $EDEN_CONFIG"
    for key in resolution_setup use_docked_mode scaling_filter fsr_sharpening_slider \
               use_asynchronous_shaders use_vsync force_max_clock; do
        echo "$key: $(ini_get "$EDEN_CONFIG" "$key")"
    done
else
    echo "No Eden config found"
fi
echo ""

echo "--- Firmware & Keys ---"
echo "Ryubing keys:"
shopt -s nullglob
keys=("$HOME/.config/Ryujinx/system/"*.keys)
if [ ${#keys[@]} -gt 0 ]; then
    ls -la "${keys[@]}"
else
    echo "  No keys found"
fi
shopt -u nullglob

fw_dir="$HOME/.config/Ryujinx/bis/system/Contents/registered"
if [ -d "$fw_dir" ]; then
    echo "Ryubing firmware: $(find "$fw_dir" -type f 2>/dev/null | wc -l | tr -d ' ') files"
else
    echo "Ryubing firmware: 0 files"
fi
echo ""

echo "Eden keys:"
shopt -s nullglob
keys=("$HOME/.local/share/eden/keys/"*.keys)
if [ ${#keys[@]} -gt 0 ]; then
    ls -la "${keys[@]}"
else
    echo "  No keys found"
fi
shopt -u nullglob

fw_dir="$HOME/.local/share/eden/nand/system/Contents/registered"
if [ -d "$fw_dir" ]; then
    echo "Eden firmware: $(find "$fw_dir" -type f 2>/dev/null | wc -l | tr -d ' ') files"
else
    echo "Eden firmware: 0 files"
fi
echo ""

echo "--- Swap ---"
if command -v swapon >/dev/null 2>&1; then
    swapon --show 2>/dev/null || echo "  No swap configured"
else
    echo "  swapon not available"
fi
echo ""

echo "--- EmuDeck ---"
if [ -d "$HOME/.config/EmuDeck" ] || [ -d "$HOME/emudeck" ] || [ -d "$HOME/Emulation" ]; then
    echo "EmuDeck: yes"
else
    echo "EmuDeck: no"
fi
echo ""
echo "=== end ==="
