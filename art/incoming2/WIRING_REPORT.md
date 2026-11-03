# Wiring report: the Ludo.ai pictures in the game (branch `ludo-art-wired`)

Everything in `art/incoming2` that the porter has a place for is now in the Tilewright project (`tilewright/`), made by
`tools/port/run_porter.sh` end to end. No Ludo.ai API was called. `tools/art/sd_hero.py` and `art/picks.json` "storytender" were not touched.

## How it works

* `tools/art/ludo.py` (new): reads `art/incoming2` pictures (already transparent single subjects): crop to the solid part, scale to a height,
  at most 255 RGBA values per picture (the engine re-quantizes anything with more, which showed as speckles). `NO_LUDO=1` ignores the
  folder; `LUDO_PARTS=tiles,objects,errors,bosses,characters,items` uses only some of it (that is how each step was checked on its own).
* (a) `sheet_tiles.py` reads `tiles/floor_*.png` instead of cutting blocks out of `art/incoming/tiles_sheet.jpg`; 6x6-cell texture, same 64x32
  diamonds one pixel wider all round (no gaps), one shared palette per floor.
* (b) `sd_objects.py` (two-state objects, both states scaled alike) and new `ludo_props.py` (every other captured object, at the capture's
  height or width; mirrored where an axis needs it). (c) `sd_errors.py`. (d) `sd_people.py`, guests/figure. (e) new `ludo_icons.py`.
* `porter.ts` + scripts: pressure plate goes down when the cold door opens; the Errors, Critic, Spoiler and Cold Shoulder switch to
  their attack / reckoning / read / slam picture during that move (new script settings, empty = unchanged).
* New `tools/port/art_shots.mjs` takes the screenshots (game viewport at chosen spots).

## Setup on the cloud machine (what was missing)

python `scipy` (pip), Godot 4.3 (binary from the godot releases, `/usr/local/bin/godot`), Tilewright engine cloned to
`/home/user/calebwilsonit-tech/tilewrite` + `npm ci` **and `npm run build -w @tilewright/editor`** (the tests start the built editor), and
`godot --headless --path . --import` once (about 2.5 min; without it the snapshot step cannot see the game's classes and the porter hangs).
One fix in the porter itself: Godot 4.3's PNG encoder fails on an empty capture ("compressed_size <= png_size_estimate"), which left a
picture missing and made `apply_art.py` crash; `capture_art.gd` now skips empty captures and pads the few pictures that fail.
The regenerated `tilewright/` differs from the one in the repo by renderer differences alone (first commit).

## What is in the game

| step | pictures | in the game |
|---|---|---|
| (a) floors | meadow_1..3 (mixed in patches), cobble, slate, parchment, planks, moss | Prologue plains, Thistledown, forge memory, Pip's memory, Maud's memory, Cutting Room |
| (b) objects | chest, post, forge, oven, echo plate, pressure plate, first sword, wide sign, small sign, margin gate, storygate, redaction bar, blocks, anvil, bellows/hammer/tongs, shard, torn page, storybook, table, chair, portal, crystal, dummy, trees 1-6, houses 1-3 | as the old pictures (two-state ones switch on the same flags as before) |
| (c) Errors, bosses | `err_*_idle/_attack/_friendly`, Critic (idle/attack/reckoning), Spoiler (idle/read/attack), Cold Shoulder (idle/slam), Scissor-Man idle | idle in the world, attack/friendly/read/slam pictures swapped in while the move happens |
| (d) people | Garrick, Pip, Maud (SE view) + graphite ghost made from it; `figure_memory`; `guest_standing/_seated` | villagers turn from ghost to colour when restored |
| (e) items | all 69 `icon_<id>.png` | binder, quick slots, and pickups lying in the world |

## Tests

Every `tools/port/*_test.mjs` after each step (checks printed as PASS/FAIL; the scripts exit 0 even when a check fails, so the logs were
searched for FAIL). Logs of the final run: `screens/test_logs/`.

| run | play | forge | pip | maud | combat | editor errors |
|---|---|---|---|---|---|---|
| baseline (project regenerated here, before any change) | 12/12 | 11/11 | 12/12 | 12/12 | 12/12 | 0 |
| (a) floors | 12/12 | 11/11 | 12/12 (alone) | 12/12 (alone) | 12/12 | 0 |
| (b) objects | 12/12 | 11/11 | 12/12 | 12/12 | 12/12 | 0 |
| (c) Errors, bosses | 12/12 | 11/11 | 12/12 alone, 11/12 beside other runs | 12/12 | 12/12 | 0 |
| (d)(e) everything (the committed project) | 12/12 | 11/11 | 12/12 | 12/12 | 12/12 | 0 |

Notes: with three editor instances at once two tests died with "Target crashed" (run (a): pip and maud; re-run alone, both pass), and with
two in parallel the pip check "the river FREEZES for 12 seconds, then the words wear off" failed once on timing (run (c)); alone it passes.
Run the tests one or two at a time. The (b) tests ran just before a small fix to where box-like objects stand (blocks, plate); the final
run covers it. One run of the editor needs ~4 min to load the art.

## Screenshots (`art/incoming2/screens/`)

`a1/a2` floors, `b1..b8` objects (b8: every converted sprite at game size), `c1..c4` Errors and bosses, `d1` villagers (ghost then colour),
`d2` Maud's hall with guests (from the maud test), `e1` pickups in the world and the binder with the new icons. All taken in the running game
with `tools/port/art_shots.mjs`, zoomed 3x where marked by a label-only crop.

Looked at in the game: size right next to the Storytender and the trees; feet on the ground (the blocks and plate stood a half diamond too
high until the footprint fix); no halos (the see-through edge keeps the dark outline colour); style matches the old art around it.

## Pictures that need redoing or do not fit

1. **`tiles/floor_parchment`**: a grid of pages with thick dark gutters, each page shaded lighter in the middle; it does not tile. Used only the
   inside of one page, evened out and blended to wrap, so Pip's floor is plain paper with faint print. Redo as a seamless paper texture.
2. **`tiles/floor_cobble`**: its edges do not meet (1.7x the normal pixel change), so the middle half is mirrored; the mirror shows as a
   symmetric pattern if you look for it. Redo seamless.
3. **Meadows**: yellow-olive (mean about 140/125/60), noticeably duller than the bright green of the trees; the little grass tufts mostly fade
   away at the game's scale. Old tuft/flower/pebble details are not laid over them (the pictures have their own). Consider a greener, bolder meadow.
4. **`floor_dirt`, `floor_flagstone`, `side_earth/stone/wood`**: the game has no floor kind or cliff side for them (floors are plains, town, pit, memory,
   page, wood, mat), so they are unused; cliff sides stay the game's own.
5. **`objects/storygate`**: plain planks. The old gate picture carried the gate's word (SENTENCE, WEIGHED...), which is lost. Needs a version
   per word, or the word added in the engine.
6. **`word_bread/_salt/_dough/_serve` and `word_bread_underline/_bold/_italic`**: not wired. Tilewright's `textBlock` draws the word itself (in
   its formatting); putting the letter blocks under it would show every word twice. The slabs in Maud's kitchen are still the captured ones.
7. **`objects/gate_open`**: unused (the Margin Gate has no open state in the port; the story gates fade). **`house_N_ghost`**: unused; the port shows
   the houses in colour, as the owner's sheet did, and has no restoration state for them.
8. **`redaction_bar`**: a low slab (57 px) instead of the old tall dark wall (86 px); it reads as a beam on the floor rather than a blocker.
   Mirrored for bars along the x axis. A taller wall-like bar would fit the game better.
9. **`block_stone`**: beige, on a blue-slate floor it clashes (the porter's slate colour for forge blocks does not show). A slate-grey block would fit.
10. **`table_long`**: chunkier than the old table, so it is 196x138 px for a table five cells long (the old one was long and thin).
11. **`dough_1..3`, `patch`, `scissors`**: no object for them in the port (dough appears only as a word block; patch and scissors belong to
    the Cutting Room's story, which is not ported). `torn_page` is used only as Pip's page token.
12. **Villagers**: only the SE view is used (the porter has one still picture per villager, no turning); `_S/_NE/_N` are unused. Garrick, Pip,
    Maud, the Errors all stand facing down-right and do not mirror, as the game's walking Errors did.
13. **Scissor-Man `_cut`/`_jammed`**, the Weighing Room tokens (weight, locket): nothing in the port uses them yet (no boss script / room not ported);
    only `boss_scissor_idle` is in the Cutting Room.
14. **`err_ellipsis_*`**: the three dots float above the body as separate pieces, so the crop is tall and the body looks small; **`err_dangler_*`**:
    the string above it is part of the picture, thin and mostly lost at 50 px.
15. **Not seen in the game**: the First Sword on the anvil. Its picture is in the project, the forge test checks that it appears once the
    Critic is beaten (passes), but the shortcut I used (setting `critic_down`) did not show it in a screenshot; look at `screens/b8` for the sprite.
16. Faint diamond outlines can be seen between meadow tiles at 3x zoom; the tiles share one palette and overlap by a pixel, so it is probably the
    engine's scaling, not the tiles.

## Re-running

```bash
tools/port/run_porter.sh                         # everything (~3.5 min + ~2.5 min the first time Godot imports)
SKIP_CAPTURE=1 tools/port/run_porter.sh          # reuse the captures
LUDO_PARTS=tiles,objects tools/port/run_porter.sh # only some of the Ludo.ai folders; NO_LUDO=1 for none
TILEWRIGHT=... xvfb-run -a node tools/port/art_shots.mjs tilewright out spec.json
```
