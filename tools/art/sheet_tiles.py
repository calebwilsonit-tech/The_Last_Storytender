"""The floor tiles from the user's tile sheet (art/incoming/tiles_sheet.jpg: blocks drawn in rows of six). Each chosen block's
top face is cut out as a 64 x 32 diamond, the game's tile size. Every pick is used as drawn and mirrored, and the darker
half of the checkerboard (the "dark" parity the game has always had) is the same picture a shade darker. The cliff sides stay
the game's own. Writes <work>/tiles_sheet/ with an index.json in the porter's format (the sides copied from <work>/tiles_q).
    python3 -I tools/art/sheet_tiles.py <repo> <work>"""
import json, os, shutil, sys
import numpy as np
from PIL import Image, ImageDraw, ImageOps

REPO, WORK = sys.argv[1], sys.argv[2]
SHEET = os.path.join(REPO, 'art', 'incoming', 'tiles_sheet.jpg')
KIND = {'.': 'plains', ',': 'town', 'm': 'memory', 'p': 'page', 'w': 'wood', 'c': 'mat'}
COLS = [(20, 164), (168, 312), (317, 460), (466, 609), (614, 757), (763, 906)]

# which blocks (row, column) make each floor of each place
PICKS = {
    ('overworld', '.'): [(9, 2)],                    # meadow grass
    ('overworld', ','): [(2, 2), (1, 4), (0, 5)],    # Thistledown: cobbles, a pale stone path, flagstones
    ('forge', 'm'): [(1, 1), (2, 3)],                # the cold forge memory: dark slate, purple stone
    ('pip', 'p'): [(4, 4), (4, 5), (4, 0)],          # the storybook: parchment, a torn page
    ('maud', 'w'): [(3, 1), (3, 2), (3, 3)],         # Maud's kitchen: planks
    ('scissor', 'c'): [(11, 4), (11, 5)],            # the cutting room: dark moss
}


def rows(fg):
    on = fg.sum(axis=1) > 3
    out, start = [], None
    for i, x in enumerate(on):
        if x and start is None:
            start = i
        if not x and start is not None:
            if i - start >= 40:
                out.append([start, i])
            start = None
    # two rows of tall pieces run together: split them at their thinnest line
    fixed = []
    for a, b in out:
        if b - a > 250:
            mid = a + 100 + int(np.argmin(fg[a + 100:b - 100].sum(axis=1)))
            fixed += [[a, mid], [mid, b]]
        else:
            fixed.append([a, b])
    return fixed


def top_face(sheet, fg, r, c, rws):
    (y0, y1), (x0, x1) = rws[r], COLS[c]
    m = fg[y0:y1, x0:x1]
    ys, xs = np.nonzero(m)
    left, right, top = xs.min(), xs.max(), ys.min()
    w = right - left
    # the top face: a diamond as wide as the block, half as tall, from the block's top corner (a little inside the outline)
    inset = 0.13 * w   # well inside the outline and the light bevel along the block's top edges
    box = (x0 + left + inset, y0 + top + inset / 2, x0 + right - inset, y0 + top + w / 2 - inset / 2)
    face = sheet.crop(tuple(round(v) for v in box)).resize((64, 32), Image.LANCZOS).convert('RGBA')
    mask = Image.new('L', (64, 32), 0)
    ImageDraw.Draw(mask).polygon([(32, -1), (65, 16), (32, 33), (-1, 16)], fill=255)   # a hair past the edge: no gaps between tiles
    face.putalpha(mask)
    return face


def main():
    sheet = Image.open(SHEET).convert('RGB')
    a = np.asarray(sheet).astype(int)
    fg = a.min(axis=2) < 225
    rws = rows(fg)
    out = os.path.join(WORK, 'tiles_sheet')
    os.makedirs(out, exist_ok=True)
    old = json.load(open(os.path.join(WORK, 'tiles_q', 'index.json')))
    index = []
    for e in old:   # the sides (and any floor not picked here) stay the game's own
        if e['what'] != 'top' or (e['scene'], e['kind']) not in PICKS:
            shutil.copy(os.path.join(WORK, 'tiles_q', e['file']), os.path.join(out, e['file']))
            index.append(e)
    for (scene, kind), picks in PICKS.items():
        n = 0
        for r, c in picks:
            face = top_face(sheet, fg, r, c, rws)
            for v in (face, ImageOps.mirror(face)):
                for parity in (0, 1):
                    pic = v
                    if parity:
                        arr = np.asarray(v).astype(np.float32)
                        arr[..., :3] *= 0.92
                        pic = Image.fromarray(arr.astype(np.uint8), 'RGBA')
                    name = f'{scene}_{KIND[kind]}_sheet_{parity}_{n}.png'
                    pic.save(os.path.join(out, name))
                    index.append({'cell': [0, 0], 'file': name, 'kind': kind, 'parity': parity, 'scene': scene, 'what': 'top'})
                n += 1
    json.dump(index, open(os.path.join(out, 'index.json'), 'w'), indent=1)
    print('sheet tiles', sum(1 for e in index if '_sheet_' in e['file']))


main()
