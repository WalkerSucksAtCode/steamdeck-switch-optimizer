# Steam Deck Switch optimizer

Patches Ryubing / Eden configs on Steam Deck. Cleans Steam leftover caches.

Not an installer. You need EmuDeck (or an AppImage), keys, and firmware.

Sources: [docs/verified-optimizations.md](docs/verified-optimizations.md)

## Use (Desktop Mode)

```bash
git clone https://github.com/WalkerSucksAtCode/steamdeck-switch-optimizer.git
cd steamdeck-switch-optimizer
chmod +x *.sh

./gui.sh                 # menu (zenity or kdialog)
./diagnostic.sh
./apply-configs.sh       # backup + patch (tables below)
./storage-diagnostic.sh
./cleanup.sh             # dry-run
./cleanup.sh --apply
./find-orphans.sh
```

Backups: `~/.config/emulation-backups-<timestamp>/`  
GUI log: `/tmp/steamdeck-switch-optimizer.log` (or `$TMPDIR`)

## What `apply-configs.sh` changes

Patches keys in place. Does not replace the whole file. “From” = typical EmuDeck / first-run defaults.

### Ryubing (`~/.config/Ryujinx/Config.json`)

| Setting | Controls | From → To | Why |
|---|---|---|---|
| `docked_mode` | Docked (about 1080p) vs handheld (about 720p) | `false` → `false` | Deck panel is about 800p; docked costs GPU for nothing |
| `enable_ptc` | Persist translated CPU code | `true` → `true` | After 2–3 full runs, later loads skip most ARM→x86 work |
| `enable_low_power_ptc` | PTC with fewer translator threads | `false` → `true` | Slower cache build; less CPU / better battery |
| `enable_shader_cache` | Persist GPU shaders | `true` → `true` | Less stutter after first session |
| `tick_scalar` | Guest timing catch-up | `200` → `150` | Milder timing; can fix audio glitches |
| `enable_vsync` | Cap to refresh | `false` → `false` | Uncapped FPS; set true if tearing |
| `enable_texture_recompression` | Re-encode textures | `false` → `false` | Deck has RAM; costs CPU/GPU |
| `memory_manager_mode` | Guest memory mapping | (varies) → `HostMappedUnsafe` | Faster on Linux; revert on weird crashes |
| `enable_macro_hle` | HLE for GPU macros | (varies) → `true` | Skips some low-level GPU work |
| `audio_backend` | Host audio | (varies) → `SDL3` | Works on SteamOS |
| `logging_enable_info` / `_guest` | Verbose logs | often `true` → `false` | Less I/O |
| `check_updates_on_start` | Update prompt | often `true` → `false` | Less Game Mode noise |
| `hide_cursor` | Mouse cursor | (varies) → `1` | Hidden in play |

Use Vulkan in the emu GUI. OpenGL for black screens / bad textures.

### Eden (`~/.config/eden/qt-config.ini`)

| Setting | Controls | From → To | Why |
|---|---|---|---|
| `resolution_setup` | Internal res scale | `2` → `1` (0.5× handheld) | FPS over sharpness; use with FSR |
| `fsr_sharpening_slider` | FSR sharpen | `25` → `40` | Edge detail after lower res |
| `force_max_clock` | Hold max GPU clock | `false` → `true` | Less throttle stutter |
| `use_asynchronous_shaders` | Background shader compile | often `false` → `true` | Avoids main-thread freezes |

Not patched: `scaling_filter=5` (FSR), `use_vsync=2` (Mailbox).

## PowerTools (Game Mode)

- SMT off
- GPU clock 1200 MHz
- Lower TDP for battery (stock 15W is often high)

First sessions stutter while caches build.

## Tools

| Script | Does |
|---|---|
| `gui.sh` | Menu (zenity or kdialog) |
| `apply-configs.sh` | Tables above |
| `diagnostic.sh` | System / emu / keys |
| `storage-diagnostic.sh` / `cleanup.sh` | Disk report / safe wipe (orphans never auto-deleted) |
| `find-orphans.sh` | Compatdata vs manifests + Non-Steam shortcuts |
| `ryubing-config.json` | Reference config (set `game_dirs`) |

Helpers: `steam-common.sh`. Test: `tests/test-orphan-detection.sh`.

## Restore

```bash
cp ~/.config/emulation-backups-TIMESTAMP/Config.json.bak ~/.config/Ryujinx/Config.json
cp ~/.config/emulation-backups-TIMESTAMP/qt-config.ini.bak ~/.config/eden/qt-config.ini
```

## License

MIT. See [LICENSE](LICENSE).
