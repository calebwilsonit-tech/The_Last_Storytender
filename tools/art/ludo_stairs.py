"""Stairs for every floor of the game, built from the floor tiles (ludo_tops.py) and the cliff faces made from them (ludo_sides.py), so a flight
of steps is the same ground, wall, colours and line as the floor and the cliffs it joins.

A stair cell is one 64 x 32 cell that climbs one level (28 px) in four steps of 7 px, the way the engine draws it (iso-renderer drawStairs).
Each step is a box, drawn far to near:
  - the tread is the floor tile itself, cut to the step's part of the cell (so the stones and planks run on across the steps),
  - the riser and the sides are the cliff face of the same tile: its first rows (the lip, the ledge line) are the top of every step, then the wall
    runs down to the foot, so the sides of the flight have the stepped outline of the steps with the cliff's own picture on them,
  - lit like the cliffs (the left face lighter, the right darker), a thin shadow where a step meets the tread below, and a lighter nosing on the
    front edge of the tread.
The sprite is 64 x 60, origin (32, 44): the centre of the cell's floor diamond. `n`, `e`, `s`, `w` is the way the stairs rise (up and to the right
on screen for n, down and to the right for e, down and to the left for s, up and to the left for w), as the porter's SLOPE directions.

    python3 -I tools/art/ludo_stairs.py <repo> [out dir, default art/generated/tile_stairs] [--tops <folder>] [--sides <folder>]
writes <floor>_<n|e|s|w>.png and index.json. Pillow and numpy only."""
import json
import os
import sys
import numpy as np
from PIL import Image

args = [a for a in sys.argv[1:] if not a.startswith('--')]
REPO = args[0] if args else '.'
OUT = args[1] if len(args) > 1 else os.path.join(REPO, 'art', 'generated', 'tile_stairs')


def folder(flag, default):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else os.path.join(REPO, 'art', 'generated', default)


TOPS, SIDES = folder('--tops', 'tile_tops'), folder('--sides', 'tile_sides')
FLOORS = ['meadow_1', 'meadow_2', 'meadow_3', 'dirt', 'moss', 'cobble', 'flagstone', 'slate', 'planks', 'parchment']
OUTLINED = {'cobble', 'flagstone', 'slate', 'planks', 'parchment'}
W, H, OX, OY = 64, 60, 32, 44      # the sprite and where the centre of the floor diamond is
THICK, STEPS, RISE = 28, 4, 28     # the wall, the number of steps, the climb
LIP = 6                            # rows at the top of every riser taken from the top of the cliff face (the lip and the ledge line)
DIRS = {'n': (0, -1), 'e': (1, 0), 's': (0, 1), 'w': (-1, 0)}
VARIANT = '00'                     # which of the floor's 16 tiles the flight is made from


def face_rows(face, left, xi, k):
    """The pixel of a cliff face `xi` columns along its ledge and `k` rows below it."""
    sx = xi if left else 31 - xi
    y = round(sx * 16 / 31) + k
    return face[min(max(y, 0), face.shape[0] - 1), min(max(xi, 0), 31)]


def wall_row(h_top, h):
    """Which row of the cliff face lies at height h on a wall whose top is at h_top: the lip rows hang from the top, the rest stands on the ground."""
    k = int(h_top - h)
    return k if k < LIP else min(THICK - 1, int(THICK - 1 - h))


def build(floor, dirname):
    tile = np.asarray(Image.open(os.path.join(TOPS, f'{floor}_{VARIANT}.png')).convert('RGBA'))
    left = np.asarray(Image.open(os.path.join(SIDES, f'{floor}_{VARIANT}_left.png')).convert('RGBA'))
    right = np.asarray(Image.open(os.path.join(SIDES, f'{floor}_{VARIANT}_right.png')).convert('RGBA'))
    dx, dy = DIRS[dirname]
    out = np.zeros((H, W, 4), np.float32)

    def put(x, y, rgba, mul=1.0):
        if 0 <= x < W and 0 <= y < H and rgba[3] > 0:
            out[y, x, :3] = np.clip(rgba[:3].astype(np.float32) * mul, 0, 255)
            out[y, x, 3] = 255

    steps = []
    for i in range(STEPS):
        a0, a1 = i / STEPS, (i + 1) / STEPS
        fx0, fx1, fy0, fy1 = 0.0, 1.0, 0.0, 1.0
        if dx == 1: fx0, fx1 = a0, a1
        elif dx == -1: fx0, fx1 = 1 - a1, 1 - a0
        elif dy == 1: fy0, fy1 = a0, a1
        else: fy0, fy1 = 1 - a1, 1 - a0
        steps.append(((fx0 + fx1 + fy0 + fy1) / 2, fx0, fx1, fy0, fy1, round((i + 1) * RISE / STEPS)))
    steps.sort(key=lambda s: s[0])                       # far to near

    for _, fx0, fx1, fy0, fy1, ht in steps:
        # the tread: the floor tile over this step's part of the cell, raised ht
        for y in range(H):
            for x in range(W):
                d = (x + 0.5 - OX) / 32
                s = (y + 0.5 + ht - OY) / 16 + 1
                fx, fy = (s + d) / 2, (s - d) / 2
                if fx0 <= fx < fx1 and fy0 <= fy < fy1:
                    ty = y + ht - (OY - 16)              # the same spot on the flat tile
                    if 0 <= ty < tile.shape[0]:
                        put(x, y, tile[ty, x])
        # the left face (the edge at fy1) and the right face (the edge at fx1)
        for is_left in (True, False):
            for x in range(W):
                if is_left:
                    fy = fy1
                    fx = fy + (x + 0.5 - OX) / 32
                    if not fx0 <= fx < fx1:
                        continue
                    xi, face = round(fx * 31), left
                    yt = OY + (fx + fy - 1) * 16 - ht
                else:
                    fx = fx1
                    fy = fx - (x + 0.5 - OX) / 32
                    if not fy0 <= fy < fy1:
                        continue
                    xi, face = round((1 - fy) * 31), right
                    yt = OY + (fx + fy - 1) * 16 - ht
                for y in range(int(np.floor(yt)), int(np.ceil(yt + ht))):
                    h = ht - (y + 0.5 - yt)
                    if h < 0:
                        break
                    k = wall_row(ht, h)
                    shade = 0.82 if (is_left and ht - h > RISE / STEPS - 1.2 and ht < RISE) else 1.0
                    put(x, y, face_rows(face, is_left, xi, k), shade)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')


def main():
    os.makedirs(OUT, exist_ok=True)
    index = {}
    for floor in FLOORS:
        index[floor] = {}
        for d in DIRS:
            f = f'{floor}_{d}.png'
            build(floor, d).save(os.path.join(OUT, f))
            index[floor][d] = f
    json.dump({'size': [W, H], 'origin': [OX, OY], 'steps': STEPS, 'rise': RISE, 'stairs': index}, open(os.path.join(OUT, 'index.json'), 'w'), indent=1)
    print('wrote', len(FLOORS) * len(DIRS), 'stairs to', OUT)


if __name__ == '__main__':
    main()
