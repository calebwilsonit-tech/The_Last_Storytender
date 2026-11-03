#!/usr/bin/env bash
# Port tool: snapshot + capture the Godot game, then build the Tilewright project in ./tilewright.
# Needs the Tilewright engine checked out (TILEWRIGHT) with `npm ci` done, Godot 4.3 (GODOT) and xvfb-run.
#   tools/port/run_porter.sh                  # everything
#   SKIP_CAPTURE=1 tools/port/run_porter.sh   # reuse the last captures, only rebuild the project
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TILEWRIGHT="${TILEWRIGHT:-/home/user/calebwilsonit-tech/tilewrite}"
GODOT="${GODOT:-godot}"
WORK="${WORK:-$REPO/.port_work}"
mkdir -p "$WORK"
if [ -z "${SKIP_CAPTURE:-}" ]; then
  "$GODOT" --headless --path "$REPO" -s tools/port/snapshot.gd -- "$WORK/snap" 2>&1 | grep '^snapshot' || true
  rm -rf "${WORK:?}/art" "${WORK:?}/tiles" "${WORK:?}/art_q" "${WORK:?}/tiles_q"
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path "$REPO" -s tools/port/capture_art.gd -- "$WORK/art" 2>&1 | grep '^art' || true
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path "$REPO" -s tools/port/capture_tiles.gd -- "$WORK/tiles" 2>&1 | grep '^tiles' || true
  "$GODOT" --headless --path "$REPO" -s tools/port/dump_data.gd -- "$WORK/data" 2>&1 | grep '^data' || true
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path "$REPO" -s tools/port/capture_icons.gd -- "$WORK/icons" 2>&1 | grep '^icons' || true
  python3 "$REPO/tools/port/quantize.py" "$WORK/art" "$WORK/art_q" && cp "$WORK/art/index.json" "$WORK/art_q/"
  python3 "$REPO/tools/port/quantize.py" "$WORK/tiles" "$WORK/tiles_q" && cp "$WORK/tiles/index.json" "$WORK/tiles_q/"
fi
# the owner's drawn art (art/incoming) in place of the captured pictures
CUT="$WORK/cut"
python3 "$REPO/tools/port/cut_sheet.py" "$REPO/art/incoming/world_props_sheet.jpg" "$CUT/props" prop --grid 10,4
python3 "$REPO/tools/port/cut_sheet.py" "$REPO/art/incoming/item_icons_sheet.jpg" "$CUT/icons" icon --crop 110,0,1905,898 --grid 12,6
python3 "$REPO/tools/port/cut_sheet.py" "$REPO/art/incoming/storytender_sheet.jpg" "$CUT/hero" hero --gap 10
python3 "$REPO/tools/port/apply_art.py" "$WORK"
# the Storytender from the generated art (art/picks.json), when it has been chosen
if [ -f "$REPO/art/picks.json" ]; then python3 -I "$REPO/tools/art/sd_hero.py" "$REPO" "$WORK"; python3 -I "$REPO/tools/art/sd_people.py" "$REPO" "$WORK"; python3 -I "$REPO/tools/art/sd_errors.py" "$REPO" "$WORK"; python3 -I "$REPO/tools/art/sd_objects.py" "$REPO" "$WORK"; fi
# the Ludo.ai pictures (art/incoming2, tools/art/ludo.py) over the world's objects in art_q and the item icons; sheet_tiles.py and the sd_ scripts read them too
python3 -I "$REPO/tools/art/ludo_props.py" "$REPO" "$WORK"
python3 -I "$REPO/tools/art/ludo_icons.py" "$REPO" "$WORK"
# the floor from the tile sheet (art/incoming/tiles_sheet.jpg) and from the Ludo.ai floors (art/incoming2/tiles; NO_LUDO=1 ignores them)
TILES_DIR="$WORK/tiles_q"
if [ -f "$REPO/art/incoming/tiles_sheet.jpg" ] || { [ -z "${NO_LUDO:-}" ] && [ -d "$REPO/art/incoming2/tiles" ]; }; then python3 -I "$REPO/tools/art/sheet_tiles.py" "$REPO" "$WORK" && TILES_DIR="$WORK/tiles_sheet"; fi
python3 "$REPO/tools/port/quantize.py" "$WORK/art_q" "$WORK/art_q"
python3 "$REPO/tools/port/quantize.py" "$WORK/icons" "$WORK/icons"
NODE_PATH="$TILEWRIGHT/node_modules" "$TILEWRIGHT/node_modules/.bin/esbuild" "$REPO/tools/port/porter.ts" --bundle --platform=node --format=esm --outfile="$WORK/porter.mjs" \
  --alias:@tw-editor="$TILEWRIGHT/packages/editor/src" --log-level=warning \
  --banner:js="import { createRequire as __cr } from 'module'; const require = __cr(import.meta.url);"
SNAP="$WORK/snap" ART="$WORK/art_q" TILES="$TILES_DIR" POSES="$WORK/art" PEOPLE="$WORK/people" ERRORS="$WORK/errors" OBJECTS="$WORK/objects" DATA="$WORK/data" ICONS="$WORK/icons" HERE="$REPO/tools/port" OUT="$REPO/tilewright" node "$WORK/porter.mjs"
# the Ludo.ai floors' new tops, their cliff faces and their stairs in the finished project (tools/art/ludo_retile.py; the engine's tile stairArt); NO_LUDO=1 skips it
if [ -z "${NO_LUDO:-}" ] && [ -d "$REPO/art/incoming2/tiles" ]; then python3 -I "$REPO/tools/art/ludo_retile.py" "$REPO"; fi
