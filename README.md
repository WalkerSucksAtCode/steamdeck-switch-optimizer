# Steam Deck Switch Emulation — Optimized Configs

Based on EmuDeck defaults + community best practices for **Ryubing** (Ryujinx fork) and **Eden** on Steam Deck.

## Quick start (on the Deck, Desktop Mode)

```bash
git clone https://github.com/WalkerSucksAtCode/steamdeck-switch-optimizer.git
cd steamdeck-switch-optimizer
chmod +x *.sh

# See current emulator / system state
./diagnostic.sh

# Backup + patch Ryubing/Eden configs in place
./apply-configs.sh

# Storage: inspect first, then reclaim
./storage-diagnostic.sh
./cleanup.sh              # dry-run (default)
./cleanup.sh --apply      # delete safe caches (shader, incomplete downloads, thumbnails)
./find-orphans.sh         # list orphaned Steam compatdata + paste-ready rm commands
```

## Files

| File | Purpose |
|---|---|
| `apply-configs.sh` | Backs up and patches live Ryubing/Eden configs |
| `diagnostic.sh` | Emulation / firmware / keys report (paste output for help) |
| `storage-diagnostic.sh` | What’s eating `/home` space |
| `cleanup.sh` | Safe reclaim (`--apply` to delete; orphans never auto-deleted) |
| `find-orphans.sh` | Compatdata vs manifests + Non-Steam shortcuts (all libraries) |
| `steam-common.sh` | Shared Steam path / size helpers (sourced by other scripts) |
| `tests/test-orphan-detection.sh` | Fixture test for multi-library + shortcut orphan logic |
| `ryubing-config.json` | Reference Ryubing settings (sanitized — set `game_dirs` yourself) |

Orphan detection treats **Non-Steam shortcuts** (EmuDeck/Ryubing entries, etc.) as installed by reading `userdata/*/config/shortcuts.vdf`, and scans `compatdata` / shader caches on **every** Steam library (internal + SD).

Eden is optimized by patching `~/.config/eden/qt-config.ini` in place via `apply-configs.sh` (no separate INI in the repo).

## What `apply-configs.sh` changes

### Ryubing (`~/.config/Ryujinx/Config.json`)

| Setting | EmuDeck-ish default | Optimized | Why |
|---|---|---|---|
| `tick_scalar` | 200 | 150 | Less aggressive; helps audio crackling in Pokemon |
| `docked_mode` | false | false | Handheld 720p fits the Deck screen |
| `enable_ptc` | true | true | Profiled Translation Cache |
| `enable_low_power_ptc` | false | **true** | Lower CPU use / better battery |
| `enable_vsync` | false | false | Uncapped |
| `enable_texture_recompression` | false | false | Deck has enough RAM |

Also: quieter logging, no update check on start, hide cursor, SDL3 audio, `HostMappedUnsafe` memory mode.

### Eden (`~/.config/eden/qt-config.ini`)

| Setting | Typical default | Optimized | Why |
|---|---|---|---|
| `resolution_setup` | 2 | **1** (0.5× handheld) | Trade res for FPS in heavy titles |
| `scaling_filter` | 5 (FSR) | **5** (FSR) | Looks good at low internal res |
| `fsr_sharpening_slider` | 25 | **40** | Slightly sharper to compensate |
| `use_asynchronous_shaders` | true | true | Avoids compile freezes |
| `use_vsync` | 2 (Mailbox) | **2** | Latency / tear tradeoff |
| `force_max_clock` | false | **true** | Reduces throttling stutter |

Backups go to `~/.config/emulation-backups-<timestamp>/`. Restore with:

```bash
cp ~/.config/emulation-backups-TIMESTAMP/Config.json.bak ~/.config/Ryujinx/Config.json
cp ~/.config/emulation-backups-TIMESTAMP/qt-config.ini.bak ~/.config/eden/qt-config.ini
```

## Pokemon Scarlet notes

- **Ryubing is the safer choice for Scarlet** — better compatibility with Game Freak’s engine.
- First ~30 minutes = shader compilation stutter; normal, then smoother.
- Power tip: Game Mode → game Properties → Power Management → TDP **10–13W** (stock 15W is often more than needed).

## Manual edit fallback

If you prefer not to run the script:

```bash
cp ~/.config/Ryujinx/Config.json ~/.config/Ryujinx/Config.json.bak
cp ~/.config/eden/qt-config.ini ~/.config/eden/qt-config.ini.bak 2>/dev/null
# then edit with nano, or copy values from ryubing-config.json
```

## License

MIT — see [LICENSE](LICENSE).
