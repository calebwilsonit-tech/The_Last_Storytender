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
  python3 "$REPO/tools/port/quantize.py" "$WORK/art" "$WORK/art_q" && cp "$WORK/art/index.json" "$WORK/art_q/"
  python3 "$REPO/tools/port/quantize.py" "$WORK/tiles" "$WORK/tiles_q" && cp "$WORK/tiles/index.json" "$WORK/tiles_q/"
fi
NODE_PATH="$TILEWRIGHT/node_modules" "$TILEWRIGHT/node_modules/.bin/esbuild" "$REPO/tools/port/porter.ts" --bundle --platform=node --format=esm --outfile="$WORK/porter.mjs" \
  --alias:@tw-editor="$TILEWRIGHT/packages/editor/src" --log-level=warning \
  --banner:js="import { createRequire as __cr } from 'module'; const require = __cr(import.meta.url);"
SNAP="$WORK/snap" ART="$WORK/art_q" TILES="$WORK/tiles_q" OUT="$REPO/tilewright" node "$WORK/porter.mjs"
