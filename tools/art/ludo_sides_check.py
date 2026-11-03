"""A look at the Ludo floor tiles (ludo_tops.py) and the cliff faces made from them (ludo_sides.py) together: a raised 4 x 4 platform of each
floor on a lower ground, at the game's size (64 x 32 cells, one 28 px step). Each cell has the faces made from its own tile, and the back
ledges of the floors that are outlined (stone, planks, pages) are drawn with ludo_ledges.py. For judging whether a top and its side belong
together; the game does not use it.

    python3 -I tools/art/ludo_sides_check.py <repo> <out.png> [zoom, default 1]"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_ledges import outline_edges  # noqa: E402

REPO, OUT = sys.argv[1], sys.argv[2]
ZOOM = int(sys.argv[3]) if len(sys.argv) > 3 else 1
TOPS = os.path.join(REPO, 'art', 'generated', 'tile_tops')
SIDES = os.path.join(REPO, 'art', 'generated', 'tile_sides')
PERIOD = 4
W, H, N = 520, 330, 9
OX, OY, STEP = W // 2, 60, 28
OUTLINED = {'cobble', 'flagstone', 'slate', 'planks', 'parchment'}   # the floors whose ledges are outlined (not the grass and earth)
_cache = {}


def load(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert('RGBA')
    return _cache[path]


def tile(floor, i, j):
    return load(os.path.join(TOPS, f'{floor}_{i % PERIOD}{j % PERIOD}.png'))


def platform(floor, ground, n=4):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for s in range(2 * N):                   # the lower ground, back to front
        for i in range(N):
            j = s - i
            if 0 <= j < N:
                img.alpha_composite(tile(ground, i, j), (OX + (i - j) * 32 - 32, OY + (i + j) * 16 + STEP - 16))
    i0, j0 = 3, 2
    cells = sorted(((i, j) for i in range(i0, i0 + n) for j in range(j0, j0 + n)), key=lambda c: c[0] + c[1])
    for i, j in cells:
        t = tile(floor, i, j)
        if floor in OUTLINED:                # the far edges: the ground drops away behind them
            t = outline_edges(t, nw=(i == i0), ne=(j == j0))
        img.alpha_composite(t, (OX + (i - j) * 32 - 32, OY + (i + j) * 16 - 16))
    for i, j in cells:
        cx, cy = OX + (i - j) * 32, OY + (i + j) * 16
        v = f'{floor}_{i % PERIOD}{j % PERIOD}'
        if j == j0 + n - 1:
            img.alpha_composite(load(os.path.join(SIDES, f'{v}_left.png')), (cx - 32, cy))
        if i == i0 + n - 1:
            img.alpha_composite(load(os.path.join(SIDES, f'{v}_right.png')), (cx, cy))
    return img


# every floor, and a different floor to stand on
SETS = [('meadow_1', 'dirt'), ('meadow_2', 'cobble'), ('meadow_3', 'dirt'), ('dirt', 'meadow_1'), ('moss', 'slate'), ('cobble', 'meadow_2'),
        ('flagstone', 'cobble'), ('slate', 'flagstone'), ('planks', 'dirt'), ('parchment', 'planks')]
COLS = 2
rows = (len(SETS) + COLS - 1) // COLS
sheet = Image.new('RGBA', (W * COLS, H * rows), (40, 40, 48, 255))
for k, args in enumerate(SETS):
    sheet.alpha_composite(platform(*args), ((k % COLS) * W, (k // COLS) * H))
sheet = sheet.convert('RGB')
if ZOOM > 1:
    sheet = sheet.resize((sheet.width * ZOOM, sheet.height * ZOOM), Image.NEAREST)
sheet.save(OUT)
print('wrote', OUT)
