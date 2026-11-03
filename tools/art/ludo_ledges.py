"""The back ledges: a thin outline along the far edges of a raised floor, where its cliff is hidden behind it and nothing else shows that the
ground drops away. (The front edges are outlined on the cliff faces, ludo_sides.py.)

A 64 x 32 floor tile has two back edges, the upper-left one (it borders the cell up and to the left, x - 1) and the upper-right one (the cell up
and to the right, y - 1). A tile that has a drop behind it on one side, or both, gets the line on that edge only; tiles in the open floor
and tiles with ground of the same height behind them stay as they are, so a flat meadow is not drawn as a grid. The line is one pixel, in a
dark shade of the tile's own floor, so it belongs to the ground it is on.

    python3 -I tools/art/ludo_ledges.py edge <tile.png> <out.png> <nw|ne|both> [r,g,b]   outline one tile (the dark is worked out from the tile if not given)
In code: outline_edges(tile, nw, ne, dark=None) -> a new RGBA image. Pillow and numpy only."""
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


def main():
    tile = Image.open(sys.argv[2])
    mode = sys.argv[4]
    dark = [float(v) for v in sys.argv[5].split(',')] if len(sys.argv) > 5 else None
    outline_edges(tile, mode in ('nw', 'both'), mode in ('ne', 'both'), dark).save(sys.argv[3])


if __name__ == '__main__':
    main()
