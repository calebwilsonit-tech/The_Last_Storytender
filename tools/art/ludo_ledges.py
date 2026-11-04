"""The back ledges: a thin outline along the far edges of a raised floor, where its cliff is hidden behind it and nothing else shows that the
ground drops away. (The front edges are outlined on the cliff faces, ludo_sides.py.)

A 64 x 32 floor tile has two back edges, the upper-left one (it borders the cell up and to the left, x - 1) and the upper-right one (the cell up
and to the right, y - 1). A tile that has a drop (or nothing at all) behind it on one side, or both, gets the line on that edge only; tiles in the
open floor and tiles with ground of the same height behind them stay as they are, so a flat meadow is not drawn as a grid. The line is three pixels
thick: two of a near-black ink brown (INK) and, just inside them, one of the ground's own colour made lighter, so it reads on every floor.

    python3 -I tools/art/ludo_ledges.py edge <tile.png> <out.png> <nw|ne|both> [r,g,b]   outline one tile (INK if no colour is given)
In code: outline_edges(tile, nw, ne, dark=None) -> a new RGBA image. Pillow and numpy only."""
import sys
import numpy as np
from PIL import Image

STRENGTH = 1.0   # how far the line goes from the ground's own colour toward the ink (all the way)
INK = (0x2b, 0x1d, 0x12)   # the near-black ink brown of the line, the same on every floor
THICK = 2        # pixels of ink (a lighter highlight pixel follows them inside)
LIGHTEN = 0.35   # how far the highlight goes from the ground's own colour toward white


def dark_of(tile):
    """A dark shade of a floor: the mean of the darkest 8% of its pixels, halved."""
    a = np.asarray(tile.convert('RGBA'))
    px = a[a[..., 3] > 0][:, :3].astype(np.float32)
    k = max(1, len(px) // 12)
    return px[np.argsort(px.mean(axis=1))[:k]].mean(axis=0) * 0.5


def outline_edges(tile, nw, ne, dark=None, strength=STRENGTH):
    """The tile with a three pixel line on its upper-left edge (nw), its upper-right edge (ne), or both: THICK pixels of ink along the rim, then one
    lighter pixel inside them. `dark` is the ink (default INK)."""
    a = np.asarray(tile.convert('RGBA')).copy()
    h, w = a.shape[:2]
    inside = a[..., 3] > 0
    # how many pixels of the tile lie above each pixel in its column: 0 for the topmost pixel of a column (the rim), 1 for the next, ...
    depth = np.cumsum(inside, axis=0) - 1
    cols = np.arange(w)[None, :]
    side = ((cols < w // 2) & nw) | ((cols >= w // 2) & ne)
    ink = inside & side & (depth < THICK)
    light = inside & side & (depth == THICK)
    d = np.array(INK if dark is None else dark, np.float32)
    for c in range(3):
        a[..., c] = np.where(ink, a[..., c] * (1 - strength) + d[c] * strength, a[..., c])
        a[..., c] = np.where(light, a[..., c] * (1 - LIGHTEN) + 255 * LIGHTEN, a[..., c])
    return Image.fromarray(a, 'RGBA')


def main():
    tile = Image.open(sys.argv[2])
    mode = sys.argv[4]
    dark = [float(v) for v in sys.argv[5].split(',')] if len(sys.argv) > 5 else None
    outline_edges(tile, mode in ('nw', 'both'), mode in ('ne', 'both'), dark).save(sys.argv[3])


if __name__ == '__main__':
    main()
