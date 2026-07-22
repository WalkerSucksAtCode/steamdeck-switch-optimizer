# Steam Deck Switch Emulation — Optimized Configs

Based on EmuDeck defaults + community best practices for Ryubing (Ryujinx fork) and Eden on Steam Deck.

## How to Apply

### Via Konsole on the Deck (Desktop Mode):
```bash
# Backup current configs first
cp ~/.config/Ryujinx/Config.json ~/.config/Ryujinx/Config.json.bak
cp ~/.config/eden/qt-config.ini ~/.config/eden/qt-config.ini.bak 2>/dev/null

# Then manually edit with nano:
nano ~/.config/Ryujinx/Config.json
nano ~/.config/eden/qt-config.ini
```

### Via KDE Connect clipboard:
Copy the JSON/INI from the files in this folder → paste into Konsole on the Deck.

## Files

- `ryubing-config.json` — Optimized Ryubing config for Steam Deck
- `eden-config.ini` — Optimized Eden config for Steam Deck
- `apply-configs.sh` — One-shot script to backup and apply both

## Key Changes from EmuDeck Defaults

### Ryubing
| Setting | EmuDeck Default | Optimized | Why |
|---|---|---|---|
| `tick_scalar` | 200 | 150 | Less aggressive, fixes audio crackling in Pokemon |
| `docked_mode` | false | false | Handheld 720p is correct for Deck screen |
| `enable_ptc` | true | true | Keep — Profiled Translation Cache |
| `enable_low_power_ptc` | false | **true** | Less CPU usage, great for battery |
| `enable_vsync` | false | false | Keep uncapped |
| `enable_texture_recompression` | false | false | Deck has 16GB, no need |

### Eden
| Setting | EmuDeck Default | Optimized | Why |
|---|---|---|---|
| `resolution_setup` | 2 | **1** (0.5x handheld) | Pokemon Scarlet is heavy — trade resolution for FPS |
| `scaling_filter` | 5 (FSR) | **5** (FSR) | Keep — FSR looks good at low res |
| `fsr_sharpening_slider` | 25 | **40** | Slightly sharper to compensate for lower res |
| `use_asynchronous_shaders` | true | true | Keep — prevents compile freezes |
| `use_vsync` | 2 (Mailbox) | **2** (Mailbox) | Keep — best latency/tear tradeoff |
| `force_max_clock` | false | **true** | Locks GPU to max clock, reduces throttling stutter |

## Pokemon Scarlet Specific Issues

- **Eden on Mac**: Shader issues are likely MoltenVK artifacts, may not appear on Deck (native Vulkan)
- **Ryubing is the safer choice for Scarlet** — better compatibility with Game Freak's engine
- First 30 min of play = shader compilation stutter. This is normal. After that it's smooth.
