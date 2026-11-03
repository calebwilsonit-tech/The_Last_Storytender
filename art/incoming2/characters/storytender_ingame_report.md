# The Storytender from Ludo.ai, in the ported game — porter, tests and screenshots

Branch `ludo-storytender`. Picks: SE, E, NE, N, NW = `art/generated/storytender/ludo_<DIR>.png`; quill from `3_right_f_strike_s0`.

## What was run
- Set up: Godot 4.3 (`/usr/local/bin/godot`), xvfb, scipy/numpy/Pillow, Tilewright (`/home/user/calebwilsonit-tech/tilewrite`, `npm ci`, Electron binary installed by hand, `npm run build`). The Godot project needs one `godot --headless --import` before the capture scripts work in a fresh checkout.
- `tools/port/run_porter.sh`: exit 0. `sd_hero.py` printed `storytender frames (generated art) 64 height 63` (5 directions + 3 mirrors, each idle, 4 walk, 3 strike).
- **Tests (all pass, `errors 0` in each):** combat_test 12/12, forge_test 11/11, pip_test 12/12, maud_test 12/12, play_test 12/12. These are the only `*_test.mjs` files in the repo.

## One fix that was needed (not caused by the art)
`tools/port/capture_art.gd`: the first porter run crashed in `apply_art.py` (`FileNotFoundError ... overworld_55d9ad67f7_13.png`). Over the per-picture limit the index named the slot's file, but when that picture was identical to an earlier one it had been saved under the earlier name, so the file did not exist. The index now points at the file that was really saved (`_saved_as`). The capture is not deterministic between runs (120 vs 122 new pictures), which is why it showed up now. Nothing in `sd_hero.py` or the picks needed to change, and no test was loosened.

## How he looks (screenshots in `storytender_ingame/`)
Taken by the new `tools/port/hero_shots.mjs` (the real editor's Play, 1:1 pixels, then 2x for the sheets).
- **Size and feet:** same as before. Solid part is rows 65–128 of the 160x150 frame in all eight facings (old Storytender: 65–128), feet at row 128, mirrored facings keep their feet (E/NE/N and S/SW/W agree to 1 px). He is a few px wider than the old one (backpack, wrench, lantern).
- **Reads at game size:** yes. Front and side views read at once from the cyan eyes, the cream coat and the brown pack. Back views (N, NW, and W/A walking) have no eyes and a dark hood, so they are the least readable; they still hold up against grass and stone, but against dark trees they are darkest. This is the only thing I would raise with the owner.
- **Cut-out fringe / white halo:** none. Over all 7,474 edge pixels of the idle and walk frames there is not one light pixel (luminance > 200), and the soft shadow under the feet is the only semi-transparent area. No parchment colour survives anywhere.
- **Walk:** the legs-split puppet walk works with the new art: feet lift 1–3 px, the coat stays whole, no gap at the knee. The backpack and lantern sit on the right half of the split in side views, so they do not wobble separately, which looks fine.
- **Quill strike:** plays through (`strike/strike` in the animator) and returns to idle. The old quill is pale against his darker coat, so the feather reads as a small pale shape with the cyan swoosh arc; it is easy to see on grass but small. The hit-zone diamond under him is the engine's own.
- **Style vs the world:** darker and chunkier than the old sprite and with a heavier outline, but sits well on the grass and the rest of the owner's drawn art.

Files: `ingame_WASD_x4dirs_idle_walk_strike.png` (columns W, A, S, D; rows idle, walk x3, strike x3), `ingame_diagonals_idle_walk_strike.png` (WA, WD, SA, SD), `before_after_idle.png` (top old, bottom new), `all_64_frames_on_parchment.png`, `editor_play_combat.png`.
