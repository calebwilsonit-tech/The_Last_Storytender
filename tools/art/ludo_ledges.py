"""The back ledges: a thin outline along the far edges of a raised floor, where its cliff is hidden behind it and nothing else shows that the
ground drops away. (The front edges are outlined on the cliff faces, ludo_sides.py.)

A 64 x 32 floor tile has two back edges, the upper-left one (it borders the cell up and to the left, x - 1) and the upper-right one (the cell up
and to the right, y - 1). A tile that has a drop behind it on one side, or both, gets the line on that edge only; tiles in the open floor
and tiles with ground of the same height behind them stay as they are, so a flat meadow is not drawn as a grid. The line is one pixel, in a
dark shade of the tile's own floor, so it belongs to the ground it is on.

    python3 -I tools/art/ludo_ledges.py edge <tile.png> <out.png> <nw|ne|both> [r,g,b]   outline one tile (the dark is worked out from the tile if not given)
    python3 -I tools/art/ludo_ledges.py check <repo> <out.png>                           a picture of raised floors with their back and front ledges
In code: outline_edges(tile, nw, ne, dark=None) -> a new RGBA image. Pillow and numpy only."""
import os
import sys
import numpy as np
from PIL import Image

STRENGTH = 0.8   # how far the line goes from the ground's own colour toward its dark


def dark_of(tile):
    """A dark shade of a floor: the mean of the darkest 8% of its pixels, halved."""
    a = np.asarray(tile.convert('RGBA'))
    px = a[a[..., 3] > 0][:, :3].astype(np.float32)
    k = max(1, len(px) // 12)
    return px[np.argsort(px.mean(axis=1))[:k]].mean(axis=0) * 0.5


def outline_edges(tile, nw, ne, dark=None, strength=STRENGTH):
    """The tile with a one pixel line on its upper-left edge (nw), its upper-right edge (ne), or both."""
    a = np.asarray(tile.convert('RGBA')).copy()
    h, w = a.shape[:2]
    inside = a[..., 3] > 0
    above = np.zeros_like(inside)
    above[1:] = inside[:-1]
    top = inside & ~above                              # the topmost pixel of every column: both upper edges
    cols = np.arange(w)[None, :]
    rim = top & (((cols < w // 2) & nw) | ((cols >= w // 2) & ne))
    d = dark_of(tile) if dark is None else np.array(dark, np.float32)
    for c in range(3):
        a[..., c] = np.where(rim, a[..., c] * (1 - strength) + d[c] * strength, a[..., c])
    return Image.fromarray(a, 'RGBA')


# ---- the picture (for looking at it; the game does not use any of this)

PERIOD, W, H, N = 4, 520, 330, 9
OX, OY, STEP = W // 2, 60, 28
FLOORS = [('meadow_1', 'dirt'), ('meadow_2', 'cobble'), ('moss', 'slate'), ('dirt', 'meadow_1'), ('cobble', 'meadow_2'), ('flagstone', 'cobble'),
          ('slate', 'flagstone'), ('planks', 'dirt')]


def rough_tile(rgb, i, j):
    """A stand-in floor tile: the floor picture laid over 4 x 4 cells, the cell (i, j) of it cut as a diamond."""
    size = rgb.shape[0]
    y, x = np.mgrid[0:32, 0:64]
    du, dv = (x - 31.5) / 32, (y - 15.5) / 16
    u, v = (du + dv) / 2 + 0.5, (dv - du) / 2 + 0.5
    sx = (((i % PERIOD) + u) / PERIOD * (size - 1)).astype(int) % size
    sy = (((j % PERIOD) + v) / PERIOD * (size - 1)).astype(int) % size
    out = np.zeros((32, 64, 4), np.uint8)
    out[..., :3] = rgb[sy, sx]
    out[..., 3] = np.where((np.abs(x - 31.5) / 32 + np.abs(y - 15.5) / 16) <= 1.0, 255, 0)
    return Image.fromarray(out, 'RGBA')


def platform(repo, floor, ground, n=4):
    load = lambda nm: np.asarray(Image.open(os.path.join(repo, 'art', 'incoming2', 'tiles', f'floor_{nm}.png')).convert('RGB').resize((256, 256), Image.LANCZOS))
    t_floor, t_ground = load(floor), load(ground)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for s in range(2 * N):
        for i in range(N):
            j = s - i
            if 0 <= j < N:
                img.alpha_composite(rough_tile(t_ground, i, j), (OX + (i - j) * 32 - 32, OY + (i + j) * 16 + STEP - 16))
    sides = os.path.join(repo, 'art', 'generated', 'tile_sides')
    left, right = (Image.open(os.path.join(sides, f'{floor}_{k}.png')) for k in ('left', 'right'))
    i0, j0 = 3, 2
    cells = sorted(((i, j) for i in range(i0, i0 + n) for j in range(j0, j0 + n)), key=lambda c: c[0] + c[1])
    for i, j in cells:
        tile = rough_tile(t_floor, i, j)
        tile = outline_edges(tile, nw=(i == i0), ne=(j == j0))        # a drop behind: the cell up-left is off the platform (i == i0), up-right (j == j0)
        img.alpha_composite(tile, (OX + (i - j) * 32 - 32, OY + (i + j) * 16 - 16))
    for i, j in cells:
        cx, cy = OX + (i - j) * 32, OY + (i + j) * 16
        if j == j0 + n - 1:
            img.alpha_composite(left, (cx - 32, cy))
        if i == i0 + n - 1:
            img.alpha_composite(right, (cx, cy))
    return img


def main():
    if sys.argv[1] == 'edge':
        tile = Image.open(sys.argv[2])
        mode = sys.argv[4]
        dark = [float(v) for v in sys.argv[5].split(',')] if len(sys.argv) > 5 else None
        outline_edges(tile, mode in ('nw', 'both'), mode in ('ne', 'both'), dark).save(sys.argv[3])
    else:
        repo, out = sys.argv[2], sys.argv[3]
        cols = 2
        rows = (len(FLOORS) + cols - 1) // cols
        sheet = Image.new('RGBA', (W * cols, H * rows), (40, 40, 48, 255))
        for k, (floor, ground) in enumerate(FLOORS):
            sheet.alpha_composite(platform(repo, floor, ground), ((k % cols) * W, (k // cols) * H))
        sheet.convert('RGB').save(out)
        print('wrote', out)


if __name__ == '__main__':
    main()
