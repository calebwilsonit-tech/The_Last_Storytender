"""A look at the Ludo floors and the cliff faces made for them (ludo_sides.py) together: a raised 4 x 4 platform of each floor on a lower
ground, with its faces along the two front edges, drawn at the game's size (64 x 32 cells, one 28 px step). It is for judging whether a top
and its side belong together, not something the game uses.

    python3 -I tools/art/ludo_sides_check.py <repo> <out.png>"""
import os
import sys
import numpy as np
from PIL import Image

REPO, OUT = sys.argv[1], sys.argv[2]
SRC = os.path.join(REPO, 'art', 'incoming2', 'tiles')
SIDES = os.path.join(REPO, 'art', 'generated', 'tile_sides')
PERIOD = 4   # a floor picture is taken to cover 4 x 4 cells, repeated
W, H, N = 520, 330, 9
OX, OY, STEP = W // 2, 60, 28


def tex(name):
    return np.asarray(Image.open(os.path.join(SRC, name + '.png')).convert('RGB').resize((256, 256), Image.LANCZOS))


def top(canvas, t, cx, cy, i, j):
    """The diamond of cell (i, j), centred at (cx, cy), filled from the floor picture by its place on the floor."""
    for dy in range(-16, 16):
        for dx in range(-32, 32):
            if abs(dx) / 32 + abs(dy + 0.5) / 16 > 1:
                continue
            u = (dx / 32 + (dy + 0.5) / 16) / 2 + 0.5
            v = (-dx / 32 + (dy + 0.5) / 16) / 2 + 0.5
            tx, ty = int((((i + u) % PERIOD) / PERIOD) * 255), int((((j + v) % PERIOD) / PERIOD) * 255)
            x, y = cx + dx, cy + dy
            if 0 <= x < canvas.shape[1] and 0 <= y < canvas.shape[0]:
                canvas[y, x, :3] = t[ty, tx]
                canvas[y, x, 3] = 255


def platform(floor, side, ground, n=4):
    canvas = np.zeros((H, W, 4), np.uint8)
    t_ground, t_floor = tex(ground), tex(floor)
    for s in range(2 * N):
        for i in range(N):
            j = s - i
            if 0 <= j < N:
                top(canvas, t_ground, OX + (i - j) * 32, OY + (i + j) * 16 + STEP, i, j)
    img = Image.fromarray(canvas, 'RGBA')
    left, right = (Image.open(os.path.join(SIDES, f'{side}_{k}.png')) for k in ('left', 'right'))
    i0, j0 = 3, 2
    cells = sorted(((i, j) for i in range(i0, i0 + n) for j in range(j0, j0 + n)), key=lambda c: c[0] + c[1])
    for i, j in cells:
        layer = np.zeros((H, W, 4), np.uint8)
        top(layer, t_floor, OX + (i - j) * 32, OY + (i + j) * 16, i, j)
        img.alpha_composite(Image.fromarray(layer, 'RGBA'))
    for i, j in cells:
        cx, cy = OX + (i - j) * 32, OY + (i + j) * 16
        if j == j0 + n - 1:
            img.alpha_composite(left, (cx - 32, cy))
        if i == i0 + n - 1:
            img.alpha_composite(right, (cx, cy))
    return img


# every floor, the face that goes under it, and a different floor to stand on
SETS = [('floor_meadow_1', 'meadow_1', 'floor_dirt'), ('floor_meadow_2', 'meadow_2', 'floor_cobble'), ('floor_meadow_3', 'meadow_3', 'floor_dirt'),
        ('floor_dirt', 'dirt', 'floor_meadow_1'), ('floor_moss', 'moss', 'floor_slate'), ('floor_cobble', 'cobble', 'floor_meadow_2'),
        ('floor_flagstone', 'flagstone', 'floor_cobble'), ('floor_slate', 'slate', 'floor_flagstone'), ('floor_planks', 'planks', 'floor_dirt'),
        ('floor_parchment', 'parchment', 'floor_planks')]
COLS = 2
rows = (len(SETS) + COLS - 1) // COLS
sheet = Image.new('RGBA', (W * COLS, H * rows), (40, 40, 48, 255))
for k, args in enumerate(SETS):
    sheet.alpha_composite(platform(*args), ((k % COLS) * W, (k // COLS) * H))
sheet.convert('RGB').save(OUT)
print('wrote', OUT)
