"""Puts the Ludo.ai floors, their cliff faces and their stairs into the Tilewright project the porter has made (<repo>/tilewright), as a last step of
tools/port/run_porter.sh (after porter.mjs; it needs no Godot and can be run on the committed project too).

  - Each hard floor (Thistledown's cobbles, the slate of the memories, the pages, Maud's planks) gets the new tops (ludo_tops.py, made to match the walls)
    in place of the porter's floor: 16 tiles (x and y mod 4), and for the floors whose ledges are outlined (all four) a variant of each with a line on its
    upper-left edge, its upper-right edge or both, chosen per cell by whether the ground behind it is lower (ludo_ledges.py). The meadow and the moss keep the
    porter's tops (the Ludo meadows in patches, the moss).
  - Every tile of every one of those floors gets its own left and right cliff face (ludo_sides.py), made from that tile, so the wall carries on the top's
    own lines and colours; and its flight of stairs in the four ways it can rise (ludo_stairs.py; the engine's tile `stairArt`).
  - The scenes are rewritten for the new tile ids. Sprites no tile uses any more are deleted.

    python3 -I tools/art/ludo_retile.py <repo>        (the project is <repo>/tilewright)
Pillow and numpy; it uses the other ludo_ tools. Running it again on a project it has already changed does nothing."""
import json
import os
import re
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '.')
sys.argv = [sys.argv[0], REPO]
import ludo_ledges as LEDGES   # noqa: E402
import ludo_sides as SIDES     # noqa: E402
import ludo_stairs as STAIRS   # noqa: E402
import ludo_tops as TOPS       # noqa: E402

PROJECT = os.path.join(REPO, 'tilewright')
SPRITES = os.path.join(PROJECT, 'assets', 'sprites')
PIC = os.path.join(REPO, 'art', 'incoming2', 'tiles')
NEW = {'overworld_town': 'cobble', 'forge_memory': 'slate', 'proof_memory': 'slate', 'weighing_memory': 'slate', 'pip_page': 'parchment', 'maud_wood': 'planks'}
KEEP = {'overworld_plains': 'meadow_1', 'scissor_mat': 'moss'}   # the porter's own tops stay; faces and stairs are made from them
OUTLINED = {'cobble', 'slate', 'flagstone', 'planks', 'parchment'}
VARIANTS = ['', 'nw', 'ne', 'nwne']                              # the back ledges a top has outlined (bit 0: upper left, bit 1: upper right)
NAME = re.compile(r'^(?P<k>.+) (?P<x>\d+),(?P<y>\d+)$')


# ---------------------------------------------------------------- sprites
def read_sprite(name):
    d = json.load(open(os.path.join(SPRITES, name + '.sprite.json'), encoding='utf8'))
    pal = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5, 7)) for c in d['palette']]
    flat = []
    for run in d['frames'][0]['cels']['l1'].split():
        n, i = run.split('x')
        flat += [pal[int(i)]] * int(n)
    return np.array(flat, np.uint8).reshape(d['height'], d['width'], 4)


def write_sheet(name, frames, origin):
    """One sprite file of several frames (RGBA arrays of one size, at most 255 colours in all; transparent pixels are palette entry 0). A tile names a
    frame as "<sprite>#<n>"; a floor's tops, faces and stairs are three sprites, not a hundred (the engine draws the map again every time a sprite the map
    uses is loaded, so a hundred sprites per floor is minutes of loading)."""
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
              'frames': [{'duration': 100, 'cels': {'l1': c}} for c in cels], 'origin': {'x': origin[0], 'y': origin[1]}, 'clips': [], 'procedural': None}
    json.dump(sprite, open(os.path.join(SPRITES, name + '.sprite.json'), 'w', encoding='utf8'), indent=2)


def quantized(images, colors=250):
    """The pictures (name -> RGBA image) in one shared palette of `colors`, with hard edges (the engine keeps a sprite to 255 colours; one palette for
    a whole floor means no tile differs a little in colour from its neighbour)."""
    keys = sorted(images)
    w = max(images[k].width for k in keys)
    sheet = Image.new('RGB', (w * len(keys), max(images[k].height for k in keys)))
    for i, k in enumerate(keys):
        sheet.paste(images[k].convert('RGB'), (w * i, 0))
    q = sheet.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    out = {}
    for i, k in enumerate(keys):
        im = images[k]
        alpha = np.where(np.asarray(im.convert('RGBA'))[..., 3] >= 96, 255, 0).astype(np.uint8)
        rgb = np.asarray(q.crop((w * i, 0, w * i + im.width, im.height))).copy()
        rgb[alpha == 0] = 0
        out[k] = np.dstack([rgb, alpha])
    return out


def mean_colour(rgba):
    px = rgba[rgba[..., 3] > 200][:, :3]
    return int(px[:, 0].mean()) << 16 | int(px[:, 1].mean()) << 8 | int(px[:, 2].mean()) if len(px) else 0x888888


def faces_for(tile, floor):
    """(left, right) 32 x 44 RGBA images of the cliff faces of one top tile (a PIL RGBA image) of a floor."""
    m = dict(SIDES.FLOORS[floor], top='floor_' + floor)
    return SIDES.faces_of(tile, m, SIDES.palette(m.get('body') or m['top'])[0])


# ---------------------------------------------------------------- one floor's pictures
def picture_of(floor):
    new = os.path.join(PIC, f'top_{floor}.png')
    return new if os.path.exists(new) else os.path.join(PIC, f'floor_{floor}.png')


def pack(name, images, origin):
    """The pictures (a dict, in sorted key order) as the frames of one sprite in one palette; returns {key: frame number} and {key: RGBA array}."""
    q = quantized(images)
    keys = sorted(q)
    write_sheet(name, [q[k] for k in keys], origin)
    return {k: i for i, k in enumerate(keys)}, q


def stair_images(tile, left, right):
    return {d: STAIRS.build_from(tile, np.asarray(left), np.asarray(right), d) for d in STAIRS.DIRS}


def pack_stairs(name, tile, left, right):
    """The four flights as one sprite (frames n, e, s, w); returns the stairArt names."""
    idx, _ = pack(name, stair_images(tile, left, right), (32, 44))
    return {d: f'{name}#{idx[d]}' for d in STAIRS.DIRS}


def make_new_floor(floor):
    """Sprites of a hard floor: tops with their ledge variants, the faces of each tile, the stairs. Returns, by (i, j) and ledge variant, the frame names
    and mean colours of the tops, the names of the faces and the stairArt names."""
    tiles = TOPS.tiles_of(picture_of(floor))
    dark = np.mean([LEDGES.dark_of(t) for t in tiles.values()], axis=0)
    tops = {}
    for (i, j), t in tiles.items():
        for v in range(len(VARIANTS) if floor in OUTLINED else 1):
            tops[(i, j, v)] = LEDGES.outline_edges(t, bool(v & 1), bool(v & 2), dark) if v else t
    top_idx, top_rgba = pack(f't_{floor}_tops', tops, (32, 31))
    faces = {}
    for (i, j), t in tiles.items():
        faces[(i, j, 'left')], faces[(i, j, 'right')] = faces_for(t, floor)
    face_idx, _ = pack(f't_{floor}_faces', faces, (16, 43))
    stairs = pack_stairs(f't_{floor}_stairs', np.asarray(tiles[(0, 0)]), faces[(0, 0, 'left')], faces[(0, 0, 'right')])
    return {'top': {k: f't_{floor}_tops#{i}' for k, i in top_idx.items()}, 'colour': {k: mean_colour(a) for k, a in top_rgba.items()},
            'face': {k: f't_{floor}_faces#{i}' for k, i in face_idx.items()}, 'stairs': stairs}


def make_kept_faces(kname, floor, entries):
    """Faces for the tiles the porter made (each entry is a tile of the floor's 6 x 6 cells), and the stairs from the first of them. Sets the tiles' art names."""
    tiles = {e['id']: Image.fromarray(read_sprite(e['art'])) for e in entries}
    faces = {}
    for e in entries:
        faces[(e['id'], 'left')], faces[(e['id'], 'right')] = faces_for(tiles[e['id']], floor)
    idx, _ = pack(f't_{kname}_faces', faces, (16, 43))
    first = min(entries, key=lambda e: (e['gy'], e['gx']))
    stairs = pack_stairs(f't_{kname}_stairs', np.asarray(tiles[first['id']]), faces[(first['id'], 'left')], faces[(first['id'], 'right')])
    return {e['id']: (f't_{kname}_faces#{idx[(e["id"], "left")]}', f't_{kname}_faces#{idx[(e["id"], "right")]}') for e in entries}, stairs


# ---------------------------------------------------------------- the project
def variant_of(m, x, y, outlined):
    """Which ledge variant the top of a cell takes: a line on the edge that has lower ground behind it."""
    if not outlined or m['slopes'][y][x]:
        return 0
    h = m['heights'][y][x]
    nw = x > 0 and m['heights'][y][x - 1] < h and not m['slopes'][y][x - 1]
    ne = y > 0 and m['heights'][y - 1][x] < h and not m['slopes'][y - 1][x]
    return int(nw) | int(ne) << 1


def main():
    path = os.path.join(PROJECT, 'project.json')
    project = json.load(open(path, encoding='utf8'))
    tileset = project['tileset']
    if any('stairArt' in t for t in tileset):
        print('retile: already done')
        return
    groups = {}
    for t in tileset:
        m = NAME.match(t['name'])
        if m and (m['k'] in NEW or m['k'] in KEEP):
            groups.setdefault(m['k'], []).append(dict(t, gx=int(m['x']), gy=int(m['y'])))
    built = {}
    for k, floor in NEW.items():
        if k in groups and floor not in built:
            built[floor] = make_new_floor(floor)
    by_id = {t['id']: t for t in tileset}
    # the floors the porter's tops stay on: faces and stairs for every tile
    for k, floor in KEEP.items():
        if k in groups:
            faces, stairs = make_kept_faces(k, floor, groups[k])
            for e in groups[k]:
                t = by_id[e['id']]
                t['leftArt'], t['rightArt'] = faces[e['id']]
                t['stairArt'] = stairs
                t['faceLevels'] = 1
    # the floors that get new tops: new tiles (by x, y and ledge variant) in place of the porter's
    next_id = max(by_id) + 1
    new_ids, drop = {}, set()
    for k, floor in NEW.items():
        if k not in groups:
            continue
        old = groups[k]
        base = by_id[old[0]['id']]
        drop |= {e['id'] for e in old}
        n_var = len(VARIANTS) if floor in OUTLINED else 1
        b = built[floor]
        for j in range(TOPS.PERIOD):
            for i in range(TOPS.PERIOD):
                for v in range(n_var):
                    entry = {'id': next_id, 'name': f'{k} {i},{j}{" " + VARIANTS[v] if v else ""}', 'top': b['colour'][(i, j, v)], 'left': base['left'], 'right': base['right'],
                             'art': b['top'][(i, j, v)], 'leftArt': b['face'][(i, j, 'left')], 'rightArt': b['face'][(i, j, 'right')], 'faceLevels': 1,
                             'stairArt': b['stairs'], 'props': base.get('props', {})}
                    tileset.append(entry)
                    new_ids[(k, i, j, v)] = next_id
                    next_id += 1
    project['tileset'] = [t for t in tileset if t['id'] not in drop]
    owner = {e['id']: k for k, es in groups.items() if k in NEW for e in es}
    for scene in project['scenes']:
        sp = os.path.join(PROJECT, scene)
        data = json.load(open(sp, encoding='utf8'))
        m = data['map']
        for y, row in enumerate(m['tiles']):
            for x, tid in enumerate(row):
                k = owner.get(tid)
                if k:
                    row[x] = new_ids[(k, x % TOPS.PERIOD, y % TOPS.PERIOD, variant_of(m, x, y, NEW[k] in OUTLINED))]
        json.dump(data, open(sp, 'w', encoding='utf8', newline='\n'), separators=(',', ':'), ensure_ascii=False)
        open(sp, 'a', newline='\n').write('\n')
    json.dump(project, open(path, 'w', encoding='utf8', newline='\n'), indent=2, ensure_ascii=False)
    open(path, 'a', newline='\n').write('\n')
    # sprites no tile uses any more
    used = set()
    for t in project['tileset']:
        used |= {(n or '').split('#')[0] for n in [t.get('art'), t.get('leftArt'), t.get('rightArt'), *(t.get('stairArt') or {}).values()]}
    gone = 0
    for f in os.listdir(SPRITES):
        name = f[:-len('.sprite.json')]
        if f.endswith('.sprite.json') and name.startswith('t_') and name not in used:
            os.remove(os.path.join(SPRITES, f))
            gone += 1
    print(f'retile: {len(new_ids)} new tiles, {gone} old tile sprites removed, {len(project["tileset"])} tiles in all')


if __name__ == '__main__':
    main()
