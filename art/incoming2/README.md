# art/incoming2: the Ludo.ai art (November 2026)

Final pictures, named as in `art/ART_GUIDE.pdf`: transparent PNG, about 1024 px, one subject each. The tries that were not chosen are
not kept (`*_s<N>.png` is git-ignored); `art/ludo_manifests/` has every request (prompts, style references, which try was picked).
Made with `tools/art/ludo_batch.py` (manifests from `tools/art/ludo_make_manifests.py`).

| folder | what |
|---|---|
| `tiles/` | `floor_*` flat seamless-ish textures seen from above (3 meadows, dirt, cobble, flagstone, slate, parchment, planks, moss) and `side_earth/stone/wood` (16:9 side faces) |
| `objects/` | trees 1-6, houses 1-3 with `_ghost` pencil versions, chest/post/forge/oven/plate/echo plate/gate in two states, signs, storygate, redaction bar, blocks, blacksmith tools, shard, sword, page, storybook, BREAD/SALT/DOUGH/SERVE blocks (BREAD also `_underline/_bold/_italic`), dough 1-3, table, chair, portal, crystal, dummy, scissors, patch |
| `errors/` | `err_<name>_idle`, `_attack` for all six, `_friendly` for bare, runon, dangler (facing down-right) |
| `bosses/` | `boss_critic_idle/_attack/_reckoning`, `boss_spoiler_idle/_read/_attack`, `boss_cold_idle/_slam`, `boss_scissor_idle/_cut/_jammed` |
| `characters/` | `garrick_`, `pip_`, `maud_` in `S, SE, NE, N`; `figure_memory`; `guest_standing/_seated`; `storytender_idle/` (8 views, webp, `idle_<camera angle>`; `m` = minus); `storytender_extras/` (dash, lantern, creep, crumple, front and back) |
| `items/` | `icon_<id>.png` for the 69 items in `tilewright/assets/items.json` |

Directions: the camera angle of a `rotateSprite` call: 0 = facing the viewer, 45 = turned to the right, 90 = side, 135 = three-quarter back, 180 = back.
