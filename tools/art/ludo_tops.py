"""Floor tiles from the Ludo.ai floor pictures (art/incoming2/tiles/floor_*.png), the tops that the cliff faces of ludo_sides.py are built from.

Each flat picture is made to wrap (blended with itself shifted by half), laid over a 4 x 4 block of cells and cut into the game's 64 x 32
diamonds, one per cell (x mod 4, y mod 4), so neighbouring tiles carry the ground on into each other. No outline: the ledges are outlined
by ludo_ledges.py (back edges) and the faces (front edges).

    python3 -I tools/art/ludo_tops.py <repo> [out dir, default art/generated/tile_tops]
writes <floor>_<x><y>.png (64 x 32, x and y 0 to 3) and index.json. The faces can also be built from tops made some other way: any folder of
tiles with the same names (ludo_sides.py --tops). Pillow, numpy and scipy only."""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

PERIOD = 4          # the ground wraps every 4 x 4 cells
TW, TH = 64, 32     # the game's tile
FLOORS = ['meadow_1', 'meadow_2', 'meadow_3', 'dirt', 'moss', 'cobble', 'flagstone', 'slate', 'planks', 'parchment']


def wrap(rgb):
    """The picture made to repeat without seams: blended with itself shifted by half, the blend peaking where the picture is least cut."""
    n = rgb.shape[0]
    t = np.sin(np.linspace(0, np.pi, n, endpoint=False)) ** 2
    w = (t[:, None] * t[None, :])[..., None]
    return rgb * w + np.roll(rgb, (n // 2, n // 2), axis=(0, 1)) * (1 - w)


def diamond_mask():
    y, x = np.mgrid[0:TH, 0:TW]
    return (np.abs(x - 31.5) / 32 + np.abs(y - 15.5) / 16) <= 1.0


def tiles_of(picture, size=256):
    """The 16 tiles of one floor picture: {(x, y): RGBA image}."""
    rgb = wrap(np.asarray(Image.open(picture).convert('RGB').resize((size, size), Image.LANCZOS)).astype(np.float32))
    mask = diamond_mask()
    y, x = np.mgrid[0:TH, 0:TW]
    du, dv = (x - 31.5) / 32, (y - 15.5) / 16
    u, v = (du + dv) / 2 + 0.5, (dv - du) / 2 + 0.5     # where each pixel sits on the ground, in cells
    out = {}
    for j in range(PERIOD):
        for i in range(PERIOD):
            sx = ((i + u) / PERIOD * size) % size
            sy = ((j + v) / PERIOD * size) % size
            tile = np.zeros((TH, TW, 4), np.float32)
            for c in range(3):
                tile[..., c] = ndimage.map_coordinates(rgb[..., c], [sy, sx], order=1, mode='wrap')
            tile[..., 3] = np.where(mask, 255, 0)
            out[(i, j)] = Image.fromarray(np.clip(tile, 0, 255).astype(np.uint8), 'RGBA')
    return out


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else '.'
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(repo, 'art', 'generated', 'tile_tops')
    os.makedirs(out, exist_ok=True)
    index = {}
    for name in FLOORS:
        files = {}
        pic = os.path.join(repo, 'art', 'incoming2', 'tiles', f'top_{name}.png')      # a top made to match its wall (tops_from_walls*.json) wins
        if not os.path.exists(pic):
            pic = os.path.join(repo, 'art', 'incoming2', 'tiles', f'floor_{name}.png')
        for (i, j), im in tiles_of(pic).items():
            f = f'{name}_{i}{j}.png'
            im.save(os.path.join(out, f))
            files[f'{i},{j}'] = f
        index[name] = {'period': PERIOD, 'tiles': files}
    json.dump(index, open(os.path.join(out, 'index.json'), 'w'), indent=1)
    print('wrote', len(FLOORS) * PERIOD * PERIOD, 'tiles to', out)


if __name__ == '__main__':
    main()
