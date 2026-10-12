# Art Direction: Living Parchment

The emotional spine of the game is **forgotten vs. remembered**. Everything the
Redaction touches is told in cold graphite pencil; everything a Storytender
restores is told in warm ink and watercolor. The player should *feel* the color
come back.

## Reference sheets
The target look is in `docs/art_reference/` (character sheets, NPC missing/restored pairs, enemies, tiles, props). Key rules pulled from them:
- **Characters:** thick near-black outline, muted cel colors, chunky simplified proportions, solemn faces. The Storytender is a hooded wanderer with a shadowed face, scroll-topped backpack and a glowing cyan lantern. "Cool, not silly."
- **Missing vs restored NPCs:** *missing* = grainy static-filled gray silhouette with purple glitch; *restored* = full color with a soft **cyan glow** around the figure. Implemented in `scripts/npc.gd`.
- **Corruption:** purple swirls and tearing glitch; **memory / the Lantern:** cyan.
- **Paper-doll pieces:** characters are built from separate parts (head, torso, arms, legs, cloak, backpack, lantern) so gear can be swapped (hardcover/softcover armor, alternate outfits). The procedural character already draws in those layers.
- **Environment:** 32x32 paper-cutout tiles, blocky trees and rocks, corrupted variants.

## Visual language
| State | Line | Fill | Feel |
|---|---|---|---|
| Forgotten (ghost town, Redacted) | Gray graphite `Palette.PENCIL`, wobbly | None / white | Hollow, quiet, cold |
| Remembered (restored, Plains) | Dark ink `Palette.INK` / brown, heavy | Warm washes | Humming, lived-in |
| The Glitch | Hard pixel blocks, white noise, tearing | Black bars `[REDACTED]` | Wrong, mechanical |
| The Silence | White / pale violet, whispered | — | Gentle, which is the horror |

- **Tone:** semi-emotional storybook. Silly on the surface (a Typo-Ghoul "Bare", the Narrator parrot), sincere underneath (Garrick's sister Wren). Humor and heartbreak share the same page.
- **Line:** every stroke wobbles (`DrawKit`), like pen on paper. No perfect geometry.
- **Depth:** 2:1 isometric. The world is a physical sheet of stacked paper; the page edge shows its layered thickness. Void pits are tears in the sheet.
- **Typography:** IM Fell English (OFL) for all text, with italic for the Narrator and action lines.
- **Rule of restoration:** color always radiates outward from the restored person, never fades in globally (`GameState.restored_at`).

## Palette
Defined in `scripts/palette.gd`. Key colors: ink `#1b1722`, paper `#e8d6ad`, grass `#7aa35a`, Mnemosynth gold `#f2b84b`, forge flame `#ff9a3c`, frozen flame `#bfe8f0`, ink-tear blue `#7fb3e0`.

## Current status: procedural stand-ins
All art is currently drawn in code so the game is playable and the *look* is
locked in. It is **not** final art. To replace it with real assets:

- **Tiles:** 128x64 px diamond (2x the logical 64x32), transparent PNG.
- **Characters / props:** drawn at 2x, ~128 px tall for the player, 8 facing directions (or 4 mirrored), with a separate pencil-sketch version of each ghost-town sprite. Restoration cross-fades pencil → color along the wave, so keep the two aligned.
- **Pipeline idea:** swap each `_draw_*` in `prop.gd` / `npc.gd` for a `Sprite2D` pair (pencil + color) and drive `modulate`/a shader mix with `GameState.restored_at(position)`.
- Keep the wobbly ink outline and paper-grain look; the parchment shader sits underneath everything.
