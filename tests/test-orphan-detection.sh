#!/bin/bash
# Self-test for orphan detection helpers (no real Steam required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT

STEAM="$FIX/Steam"
SD="$FIX/sdcard"
mkdir -p \
    "$STEAM/steamapps/compatdata/111" \
    "$STEAM/steamapps/compatdata/222" \
    "$STEAM/steamapps/compatdata/999" \
    "$STEAM/userdata/123456/config" \
    "$SD/steamapps/compatdata/333" \
    "$SD/steamapps/compatdata/888"

# Installed on internal: 111; on SD: 333
: > "$STEAM/steamapps/appmanifest_111.acf"
: > "$SD/steamapps/appmanifest_333.acf"

# libraryfolders.vdf points at SD + (duplicate) Steam root
cat > "$STEAM/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
	"0"
	{
		"path"		"$STEAM"
	}
	"1"
	{
		"path"		"$SD"
	}
}
EOF

export STEAM_HOME="$STEAM"

# Binary shortcuts.vdf with Non-Steam appid 222 (type 0x02 + appid + uint32 LE)
python3 - <<'PY'
from pathlib import Path
import os
appid = 222
steam = os.environ["STEAM_HOME"]
blob = (
    b"\x00shortcuts\x00"
    b"\x00"
    b"0\x00"
    b"\x02appid\x00"
    + appid.to_bytes(4, "little")
    + b"\x08\x08"
)
Path(steam, "userdata/123456/config/shortcuts.vdf").write_bytes(blob)
PY

# shellcheck source=../steam-common.sh
source "$ROOT/steam-common.sh"

echo "Steam home: $STEAM_HOME"
echo "Libraries:"
list_library_roots

INSTALLED=$(collect_installed_appids)
echo "Installed:"
echo "$INSTALLED"

echo "$INSTALLED" | grep -qx 111 || { echo "FAIL: missing manifest 111"; exit 1; }
echo "$INSTALLED" | grep -qx 333 || { echo "FAIL: missing SD manifest 333"; exit 1; }
echo "$INSTALLED" | grep -qx 222 || { echo "FAIL: missing shortcut 222"; exit 1; }

# Orphan walk (same rules as find-orphans)
ORPHANS=()
KEEPS=()
while IFS= read -r CD; do
    for dir in "$CD"/*/; do
        [ -d "$dir" ] || continue
        id=$(basename "$dir")
        if echo "$INSTALLED" | grep -qx "$id"; then
            KEEPS+=("$id")
        else
            ORPHANS+=("$id")
        fi
    done
done < <(list_compatdata_roots)

printf 'Keep: %s\n' "${KEEPS[*]}"
printf 'Orphans: %s\n' "${ORPHANS[*]}"

echo "${KEEPS[*]}" | grep -q 111 || { echo "FAIL: 111 should KEEP"; exit 1; }
echo "${KEEPS[*]}" | grep -q 222 || { echo "FAIL: shortcut 222 should KEEP"; exit 1; }
echo "${KEEPS[*]}" | grep -q 333 || { echo "FAIL: 333 should KEEP"; exit 1; }
echo "${ORPHANS[*]}" | grep -q 999 || { echo "FAIL: 999 should be ORPHAN"; exit 1; }
echo "${ORPHANS[*]}" | grep -q 888 || { echo "FAIL: 888 should be ORPHAN"; exit 1; }
echo "${ORPHANS[*]}" | grep -q 111 && { echo "FAIL: 111 must not be orphan"; exit 1; }
echo "${ORPHANS[*]}" | grep -q 222 && { echo "FAIL: 222 must not be orphan"; exit 1; }

# Shader/download roots
mkdir -p "$STEAM/steamapps/shadercache" "$SD/steamapps/shadercache"
SC=$(list_shadercache_roots | wc -l | tr -d ' ')
[ "$SC" -eq 2 ] || { echo "FAIL: expected 2 shadercache roots, got $SC"; exit 1; }

echo "PASS: orphan + multi-library + shortcut detection"
