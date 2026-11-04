"""Reading and writing the Tilewright project's sprite files (<project>/assets/sprites/<name>.sprite.json), for the ludo_ tools that change a
finished project (ludo_retile.py, ludo_reanimate.py). A sprite is a palette of up to 256 colours (entry 0 transparent) and, per frame, one layer of
run-length coded palette indices ("29x0 1x16 ..."), row by row."""
import json
import os

import numpy as np


def read_sprite(sprites_dir, name):
    """(RGBA array of the first frame, the sprite's JSON)."""
    d = json.load(open(os.path.join(sprites_dir, name + '.sprite.json'), encoding='utf8'))
    pal = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5, 7)) for c in d['palette']]
    flat = []
    for run in d['frames'][0]['cels']['l1'].split():
        n, i = run.split('x')
        flat += [pal[int(i)]] * int(n)
    return np.array(flat, np.uint8).reshape(d['height'], d['width'], 4), d


def write_sheet(sprites_dir, name, frames, origin, durations=None, clips=None):
    """One sprite file of several frames (RGBA arrays of one size, at most 255 colours in all; transparent pixels are palette entry 0).
    `durations` are milliseconds per frame (default 100), `clips` the sprite's clips (default none)."""
    h, w = frames[0].shape[:2]
    pal, index, cels = ['#00000000'], {}, []
    for rgba in frames:
        runs, last, n = [], None, 0
        for p in rgba.reshape(-1, 4):
            if p[3] == 0:
                i = 0
            else:
                p = tuple(int(v) for v in p)
                i = index.get(p)
                if i is None:
                    i = index[p] = len(pal)
                    pal.append('#%02x%02x%02x%02x' % p)
            if i == last:
                n += 1
            else:
                if last is not None:
                    runs.append(f'{n}x{last}')
                last, n = i, 1
        runs.append(f'{n}x{last}')
        cels.append(' '.join(runs))
    assert len(pal) <= 256, (name, len(pal))
    sprite = {'schemaVersion': 1, 'name': name, 'width': w, 'height': h, 'palette': pal, 'layers': [{'id': 'l1', 'name': 'Layer 1', 'visible': True}],
              'frames': [{'duration': (durations or [100] * len(frames))[i], 'cels': {'l1': c}} for i, c in enumerate(cels)],
              'origin': {'x': int(origin[0]), 'y': int(origin[1])}, 'clips': clips or [], 'procedural': None}
    json.dump(sprite, open(os.path.join(sprites_dir, name + '.sprite.json'), 'w', encoding='utf8'), indent=2)
