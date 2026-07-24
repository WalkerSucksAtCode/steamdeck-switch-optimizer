# Switch-on-Deck sources

| Claim | Method | Scope | Result | Date | Source |
|---|---|---|---|---|---|
| Vulkan > OpenGL on Deck | Side-by-side video | Deck; Dread, Strikers, Kirby, Smash | Vulkan overall; biggest on Smash; Dread even | Undated | [linuxgamingcentral.org](https://linuxgamingcentral.org/posts/switch-emulation-on-deck-opengl-vs-vulkan/) |
| Default Vulkan, 1× | Install guide | Deck + Ryujinx x64 | Vulkan; 1×; OpenGL if broken | 2026-07-23 | [ryujinxcanary.org](https://www.ryujinxcanary.org/install/steam-deck) |
| OpenGL fallback | Troubleshooting | Canary / Deck | Swap backend; clear shaders; update keys/firmware | 2026-07-23 | [graphics-enhancements](https://ryujinxcanary.com/graphics-enhancements/) |
| PPTC load cut about 90–95% | Emulator docs + timings | Ryujinx | Without: 2–5 min. 3rd+ launch: 5–15 s. Large RPG: 4–5 min → 10–15 s | 2026-07-23 | [PTC docs](https://mintlify.wiki/yakushabb/mirror-ryujinx/features/ptc) |
| PPTC needs 2–3 title launches | Same | Ryujinx | 1 builds; 2 profiles; 3+ full. Quit-before-title does not count | Same | [same](https://mintlify.wiki/yakushabb/mirror-ryujinx/features/ptc) |
| PPTC disk | Same | Ryujinx | 50–200 MB/game | Same | [same](https://mintlify.wiki/yakushabb/mirror-ryujinx/features/ptc) |
| Low-power PTC | Same | Battery / dual-core | Fewer threads; slower cache build | Same | [same](https://mintlify.wiki/yakushabb/mirror-ryujinx/features/ptc) |
| SMT off + GPU 1200 | EmuDeck Power Tools | Deck + Decky | SMT off; GPU 1200 MHz | Legacy wiki | [EmuDeck Application 101](https://github.com/dragoonDorise/EmuDeck/wiki/EmuDeck-Application-101#power-tools) |
| Violet default FPS | Author FPS | Deck + Ryujinx | About 15 FPS | 2024-03-26 | [stealthoptional.com](https://stealthoptional.com/article/pokemon-violet-steam-deck-can-you-play) |
| Violet tuned FPS | Same + settings listed | SMT off, 4 threads, handheld, no VSync/AA, 1× | About 20–25 FPS; native 30 hard | Same | [same](https://stealthoptional.com/article/pokemon-violet-steam-deck-can-you-play) |
| Fast GPU Time | Same | Violet handheld | Disable (forces higher internal res) | Same | [same](https://stealthoptional.com/article/pokemon-violet-steam-deck-can-you-play) |
| x64 only | Install guide | Deck | ARM64 will not run | 2026-07-23 | [ryujinxcanary.org](https://www.ryujinxcanary.org/install/steam-deck) |
| Power Tools for Ryujinx | EmuDeck wiki | SteamOS | Defers perf to Power Tools | 2026-07-23 | [emudeck.github.io](https://emudeck.github.io/emulators/steamos/ryujinx/) |

## Conflicts

| Topic | A | B | Pick |
|---|---|---|---|
| VSync | Canary: On ([link](https://www.ryujinxcanary.org/install/steam-deck)) | Violet: Off ([link](https://stealthoptional.com/article/pokemon-violet-steam-deck-can-you-play)) | Off for FPS; On if tearing |
| Violet emu | Ryujinx over Yuzu (2024) | Eden videos; no FPS table here | Measure your build |

## This repo

| Setting | Backed by |
|---|---|
| Vulkan | Deck A/B + Canary |
| `docked_mode: false` | Violet handheld; 800p panel |
| PTC + low-power PTC | PTC docs |
| Eden `resolution_setup=1` | FPS trade; no Eden Scarlet FPS table here |
| `enable_vsync: false` | Violet guide |
| TDP tip | Not in findings table |
| PowerTools SMT / 1200 | EmuDeck (manual) |

## Omitted

| Topic | Why |
|---|---|
| LSFG 30→60 | No controlled Deck FPS + latency numbers |
| Docked = better FPS | Desktop advice; wrong for Deck |
| `tick_scalar: 150` universal | Timing/audio tweak; no public Deck A/B |

Add rows only with Method + Result + Source.
