"""A look at the stairs (ludo_stairs.py) in place: for every floor and each of the four ways they rise, a flight of steps on the floor climbing onto a raised
platform of the same floor (with its cliff faces), at the game's size. For judging whether the stairs belong to the floor and the cliffs; the game does not use it.

    python3 -I tools/art/ludo_stairs_check.py <repo> <out.png> [zoom, default 1] [floor ...]"""
import os
import sys
from PIL import Image

REPO, OUT = sys.argv[1], sys.argv[2]
ZOOM = int(sys.argv[3]) if len(sys.argv) > 3 else 1
ONLY = sys.argv[4:]
G = os.path.join(REPO, 'art', 'generated')
FLOORS = ['meadow_1', 'meadow_2', 'meadow_3', 'dirt', 'moss', 'cobble', 'flagstone', 'slate', 'planks', 'parchment']
DIRS = {'n': (0, -1), 'e': (1, 0), 's': (0, 1), 'w': (-1, 0)}
CW, CH, N = 340, 250, 5
OX, OY = CW // 2, 56
_c = {}


def load(*p):
    path = os.path.join(G, *p)
    if path not in _c:
        _c[path] = Image.open(path).convert('RGBA')
    return _c[path]


def scene(floor, d):
    img = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    u = DIRS[d]
    perp = (-u[1], u[0])
    mid = (N // 2, N // 2)
    stair = mid
    plat = {(mid[0] + u[0] + t * perp[0], mid[1] + u[1] + t * perp[1]) for t in (-1, 0, 1)}
    plat |= {(x + u[0], y + u[1]) for x, y in plat}
    cells = sorted(((i, j) for i in range(N) for j in range(N)), key=lambda c: c[0] + c[1])
    for i, j in cells:
        cx, cy = OX + (i - j) * 32, OY + (i + j) * 16
        lift = 28 if (i, j) in plat else 0
        if (i, j) == stair:
            img.alpha_composite(load('tile_stairs', f'{floor}_{d}.png'), (cx - 32, cy - 44))
            continue
        img.alpha_composite(load('tile_tops', f'{floor}_{i % 4}{j % 4}.png'), (cx - 32, cy - 16 - lift))
        if lift:
            v = f'{floor}_{i % 4}{j % 4}'
            if (i, j + 1) not in plat and (i, j + 1) != stair:
                img.alpha_composite(load('tile_sides', f'{v}_left.png'), (cx - 32, cy - lift))
            if (i + 1, j) not in plat and (i + 1, j) != stair:
                img.alpha_composite(load('tile_sides', f'{v}_right.png'), (cx, cy - lift))
    return img


floors = ONLY or FLOORS
sheet = Image.new('RGBA', (CW * 4, CH * len(floors)), (40, 40, 48, 255))
for r, f in enumerate(floors):
    for c, d in enumerate(DIRS):
        sheet.alpha_composite(scene(f, d), (c * CW, r * CH))
sheet = sheet.convert('RGB')
if ZOOM > 1:
    sheet = sheet.resize((sheet.width * ZOOM, sheet.height * ZOOM), Image.NEAREST)
sheet.save(OUT)
print('wrote', OUT)
