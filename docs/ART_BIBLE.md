# Art Bible: Ink Cel

Status: **candidate style**, not yet gospel. Once the style is chosen in-game (F7 cycles character art), this document is copied into the GDD as the law. Everything here is code-drawn (no image assets) and lives in `scripts/art/`.

Reference sheets: `docs/art_reference/*.jpg`. Live comparison: the Art Lab (`scenes/art_lab.tscn`; A/D style, W/S sheet, Q/E zoom, Space background).

## 1. The look in one sentence

A hand-inked storybook cartoon: heavy near-black contour, flat muted colour, **one** hard cel shadow per shape, a thin rim light, chunky readable proportions, solemn faces.

## 2. Rules (apply to every figure, prop and tile)

1. **Contour.** One heavy outline around the whole object (outer ~1.9 to 2.3 px at 1x), a thinner line (~1.0 to 1.1) between inner parts. Colour `#14111a` (`CelKit.OUT`). Never pure black, never coloured outlines except the exceptions in section 5.
2. **Flat fills.** No gradients on solid things. Colour comes from the palette in section 4.
3. **One cel shadow.** A hard-edged crescent along the edges that face away from the light. The light is fixed at the **upper left** (`CelKit.LIGHT`). Shadow colour is the fill darkened and shifted cool (`CelKit.shade_of`).
4. **Rim light.** A thin pale line just inside edges that face the light (`CelKit._rim`).
5. **Silhouette first.** Every object must read from its outline alone at game scale. Big simple shapes, small details only where they carry meaning.
6. **Height must read.** Cliffs get a hard shadow band at the foot, a pale lip along the top and a heavy contour; higher ground is a touch lighter; stairs outline every step.
7. **Faces are solemn.** Dot eyes, short brows, level mouths. Smiles are rare and earned. The Storytender's face is a dark hood with two pale cyan glints.
8. **Glow is the only soft thing.** Magic (cyan), memory (cyan, translucent), warmth/fire (gold/orange) may glow with soft discs behind the outline. Nothing else is soft.
9. **Draw order is painter's order.** Parts are recorded (`CelKit.Rec`), the silhouette backing is drawn once behind everything, then parts by depth. This is what keeps the contour clean.

## 3. Proportions

| Figure | Height (px at 1x) | Notes |
| --- | --- | --- |
| Storytender | ~58 | Hooded, backpack and bedroll, lantern in the near hand. Eight facing directions via a 3D paper-doll projection. |
| Garrick | ~64 | Broad, grey beard, apron, hammer. |
| Maud | ~66 with hat | Round, chef's hat, loaf. |
| Pip | ~50 (scale 0.82) | Big head, tuft, book. |
| Errors | 30 to 60 | Redacted kinds are lavender-outlined; Typos are near-black outlined. |
| Bosses | 100 to 150 | Same rules, larger; each keeps its identifying silhouette. |

## 4. Palette (muted)

- Ink `#14111a`. Paper `#e8d6ae`. Pencil/graphite `#3b3e4d`.
- Wood `#93633d` (dark `#5e3d28`). Stone `#8f95a4` (dark `#636b7e`). Iron `#5d6373`.
- Leaf `#6a9a50` (dark `#4c7d42`). Grass `#86b45c`/`#7fae57`.
- Roofs: brick `#a4493e`, slate `#5f7b8f`. Walls: cream `#e8d6ae`, tan `#dfbf8c`.
- Gold `#e6b94a`. Cyan (memory/lantern) `Palette.CYAN`. Critic red `Palette.CRITIC_RED`. Glitch violet `Palette.GLITCH`.

## 5. Meaning through colour (exceptions to rule 1)

- **Missing / unrestored**: colours drained toward static grey, outline lightened to graphite grey; fills become paper-pale and a black censor bar covers the door. Restoration lerps back to full colour and the ink outline.
- **Redacted enemies** (Mite, Dangler, Censor, Ellipsis): pale lavender `#e4dcf7` outline on dark void bodies. Proofreading lerps the outline pale to ink.
- **Typos** (Bare, Slug): near-black outline like everyone else.
- **Memories** (young Garrick, Wren, Pip, Maud as remembered): same cel rig washed 42% toward cyan, cyan-blue outline, translucent with a slow shimmer, faint scanline gaps and a cyan halo.

## 6. Where each thing lives

| Thing | File |
| --- | --- |
| Primitives and recorder | `scripts/art/cel_kit.gd` |
| Style entry and plumbing | `scripts/art/style_cel.gd` |
| Storytender | `style_cel.gd` (`_storytender`, `_doll`) |
| NPCs, memories, guests | `scripts/art/cel_people.gd` |
| Errors | `scripts/art/cel_enemies.gd` |
| Bosses | `scripts/art/cel_bosses.gd` |
| Props and puzzle furniture | `scripts/art/cel_props.gd` |
| Terrain, cliffs, stairs, pits | `scripts/iso_slice.gd` (`_cel()` branches) |
| Item icons | `item_icon.gd`, `item_shapes.gd` (`_o` uses `CelKit.piece`) |

Gameplay overlays (telegraph rings, word labels, health bars, jam timer, pools of ink) stay in the entity scripts so a style change never changes how a fight plays.

## 7. Adding something new

1. Pick the nearest existing piece and copy its construction.
2. Build it with `K.Rec`: `piece()` for solids, `op()` for strokes, `glow()` for halos, `depth` for ordering.
3. Obey rules 1 to 5. If it has states (restored, hurt, lit), express them through colour and outline, not extra shapes.
4. Add it to an Art Lab sheet and look at it beside its neighbours on the paper, grass and dark backgrounds before wiring it into the game.

## 8. Known gaps (as of this writing)

- UI panels, menus and the HUD still use the original paper/book look with their own outlines.
- The Storytender's ghost-echo, word bolts and a few effects are still original art.
- Collage and Pixel styles are stubs.
- Performance: Ink Cel issues roughly 1.5x the canvas commands of the original art (draw calls are similar). Plan if needed: bake static figures (NPCs, bosses at rest) to textures the way trees already are.

## Overworld puzzle props: weathered storybook
Chests are leather-bound tomes with a gilt clasp strap (open: cover swung up, warm light off the pages). Gates and spine walls are upright books with gilt bands and a ribbon-and-seal lock. Sentence stones are loose pages with a folded corner on a small lectern of stacked books. Palette: oxblood, navy, moss, ochre leather; cream pages; gilt accents.
