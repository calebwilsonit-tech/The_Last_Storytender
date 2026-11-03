"""The floor tiles from the user's tile sheet (art/incoming/tiles_sheet.jpg: blocks drawn in rows of six), made into floors
that run on without seams.

Each block on the sheet is drawn on its own: its top is lit in the middle and shaded at the edges, so laid side by side the
blocks show a diamond grid. So the top face of each chosen block is turned flat (seen from straight above), its edges are
trimmed off, its lighting is evened out, and it is made to wrap: organic floors (grass, parchment, moss) by blending it with
itself shifted by half, built floors (cobbles, slate, planks) by mirroring. That gives a ground texture 4 x 4 cells big with
a gentle colour drift over it, and the tile of each cell (x mod 4, y mod 4) is the 64 x 32 diamond of that texture seen in the
game's view, so neighbouring tiles meet exactly. Each diamond is a pixel wider than the cell all round, so no gap shows
where their corners meet. The cliff sides stay the game's own.

Writes <work>/tiles_sheet/ with an index.json in the porter's format (each new tile has "grid": [x, y] and "period": 4).

The Ludo.ai floors (art/incoming2/tiles/floor_*.png, see LUDO_FLOORS below) take the place of the sheet's blocks where there is one:
they are already flat views from above, so no face has to be cut out of a block; the picture is made to wrap (as it is when its
edges already meet, otherwise by the blend or mirror below), laid over the same 6 x 6 cells and cut into the same 64 x 32 diamonds.
    python3 -I tools/art/sheet_tiles.py <repo> <work>"""
import json, os, shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ludo  # noqa: E402
SHEET = os.path.join(REPO, 'art', 'incoming', 'tiles_sheet.jpg')
COLS = [(20, 164), (168, 312), (317, 460), (466, 609), (614, 757), (763, 906)]
KIND = {'.': 'plains', ',': 'town', 'm': 'memory', 'p': 'page', 'w': 'wood', 'c': 'mat'}
PERIOD = 6          # the ground texture is this many cells across
G = 56              # its pixels per cell

# which block (row, column) makes each floor, and how it is made to wrap
PICKS = {
    ('overworld', '.'): ((9, 2), 'blend'),    # meadow grass
    ('overworld', ','): ((2, 2), 'slab'),     # Thistledown's cobbles
    ('forge', 'm'): ((1, 1), 'slab'),         # the cold forge memory: dark slate
    ('pip', 'p'): ((4, 5), 'blend'),          # the storybook: parchment
    ('maud', 'w'): ((3, 1), 'planks'),       # Maud's kitchen: planks
    ('scissor', 'c'): ((11, 5), 'blend'),     # the cutting room: dark moss
}

# the Ludo.ai floors: the pictures of art/incoming2/tiles that make each floor ("mix": several are laid over each other in soft patches).
# "wrap" says how to make a picture wrap when its edges do not meet already (blend: organic ground, mirror: stones and boards),
# "crop" is how much of the picture's middle is used (1 = all of it), "box" a part of it to use instead (x0, y0, x1, y1), "even"
# takes out the picture's own light and shade (a page that is lighter in the middle than at its edges).
LUDO_FLOORS = {
    ('overworld', '.'): dict(mix=['meadow_1', 'meadow_2', 'meadow_3'], wrap='blend'),   # the three meadows, in patches
    ('overworld', ','): dict(mix=['cobble'], wrap='mirror', crop=0.5),                  # Thistledown's cobbles
    ('forge', 'm'): dict(mix=['slate'], wrap='mirror'),                                 # the cold forge memory
    ('pip', 'p'): dict(mix=['parchment'], wrap='blend', box=(375, 215, 760, 640), even=True),   # the storybook: inside one page
    ('maud', 'w'): dict(mix=['planks'], wrap='mirror'),                                 # Maud's kitchen
    ('scissor', 'c'): dict(mix=['moss'], wrap='blend'),                                 # the cutting room
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
    fixed = []
    for a, b in out:   # two rows of tall pieces run together: split them at their thinnest line
        if b - a > 250:
            mid = a + 100 + int(np.argmin(fg[a + 100:b - 100].sum(axis=1)))
            fixed += [[a, mid], [mid, b]]
        else:
            fixed.append([a, b])
    return fixed


def sample(img, x, y):
    """Bilinear sample of an H x W x 3 float image at float coordinates (wrapping)."""
    h, w, _ = img.shape
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    x0 %= w
    y0 %= h
    x1 = (x0 + 1) % w
    y1 = (y0 + 1) % h
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy) + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def flat_face(sheet, fg, r, c, rws, size=128):
    """The block's top face seen from straight above, as a size x size square (u across, v down)."""
    (y0, y1), (x0, x1) = rws[r], COLS[c]
    ys, xs = np.nonzero(fg[y0:y1, x0:x1])
    left, right, top = xs.min() + x0, xs.max() + x0, ys.min() + y0
    w = right - left
    cx, ty = (left + right) / 2, top            # the face's top corner
    u, v = np.meshgrid((np.arange(size) + 0.5) / size, (np.arange(size) + 0.5) / size)
    sx = cx + (u - v) * w / 2
    sy = ty + (u + v) * w / 4
    return sample(sheet, sx, sy)


def fill_background(t):
    """Any of the sheet's white background still in the face (near its corners) is filled from the nearest face pixel."""
    bad = (t.min(axis=2) > 222)
    if not bad.any():
        return t
    _, (iy, ix) = ndimage.distance_transform_edt(bad, return_indices=True)
    return t[iy, ix]


def even_light(t):
    """Takes out the face's own shading (lighter middle, darker edges), keeping its detail and colour."""
    lum = t.mean(axis=2)
    low = ndimage.gaussian_filter(lum, sigma=t.shape[0] / 5, mode='reflect')
    return np.clip(t * (lum.mean() / np.maximum(low, 1))[..., None], 0, 255)


def wrap_blend(t):
    """Seamless by blending with itself shifted half way: the shifted copy covers the edges, the original the middle."""
    n = t.shape[0]
    s = np.roll(np.roll(t, n // 2, 0), n // 2, 1)
    d = np.abs(np.linspace(-1, 1, n))
    wgt = np.clip(1.6 * np.maximum(d[None, :], d[:, None]) - 0.6, 0, 1) ** 1.5
    return t * (1 - wgt[..., None]) + s * wgt[..., None]


def wrap_mirror(t):
    """Seamless by mirroring into a 2 x 2 block (for stones and planks, which a blend would ghost)."""
    top = np.concatenate([t, t[:, ::-1]], axis=1)
    return np.concatenate([top, top[::-1]], axis=0)


def ground(face, how, rng):
    inner = fill_background(face[16:112, 16:112])  # trim the edge (outline, bevel, shading)
    inner = even_light(inner)
    patch = wrap_blend(inner) if how == 'blend' else wrap_mirror(inner)
    cells = 2                                      # the patch covers 2 x 2 cells (the detail at the size it was drawn)
    n = PERIOD * G
    reps = PERIOD // cells
    big = np.tile(patch, (reps, reps, 1))
    big = np.asarray(Image.fromarray(big.clip(0, 255).astype(np.uint8)).resize((n, n), Image.LANCZOS)).astype(np.float32)
    # a gentle, wrapping drift of brightness over the 4 x 4 cells, so the repeats do not line up
    noise = rng.normal(size=(PERIOD * 2, PERIOD * 2))
    noise = ndimage.zoom(np.tile(noise, (3, 3)), n / (PERIOD * 2), order=3)[n:2 * n, n:2 * n]
    noise = noise / (np.abs(noise).max() + 1e-6)
    return np.clip(big * (1 + 0.06 * noise[..., None]), 0, 255)


def seamless_already(a):
    """True when the picture's edges meet as well as its neighbouring columns and rows do (so it can be laid side by side as it is)."""
    seam = max(np.abs(a[:, 0] - a[:, -1]).mean(), np.abs(a[0] - a[-1]).mean())
    typical = (np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean()) / 2
    return seam <= 1.35 * typical


def periodic_noise(rng, n, k):
    """Smooth noise of n x n pixels that wraps at its edges (k blobs across), scaled to -1..1."""
    noise = ndimage.zoom(np.tile(rng.normal(size=(k, k)), (3, 3)), n / k, order=3)[n:2 * n, n:2 * n]
    return noise / (np.abs(noise).max() + 1e-6)


def ludo_texture(path, n, wrap='blend', crop=1.0, box=None, even=False):
    """One Ludo.ai floor picture as an n x n texture that wraps: used as it is when its edges meet already, else (or when only a
    part of it is used) made to wrap by the blend or mirror above."""
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    seamless = crop >= 1 and box is None and seamless_already(a)
    if box:
        a = a[box[1]:box[3], box[0]:box[2]]
    elif crop < 1:
        m = int(a.shape[0] * (1 - crop) / 2)
        a = a[m:a.shape[0] - m, m:a.shape[1] - m]
    if even:
        lum = a.mean(axis=2)
        low = ndimage.gaussian_filter(lum, sigma=a.shape[0] / 4, mode='reflect')
        a = np.clip(a * (lum.mean() / np.maximum(low, 1))[..., None], 0, 255)
    if not seamless:
        if a.shape[0] != a.shape[1]:   # the wrap functions want a square
            side = min(a.shape[:2])
            a = np.asarray(Image.fromarray(a.clip(0, 255).astype(np.uint8)).resize((side, side), Image.LANCZOS)).astype(np.float32)
        a = wrap_mirror(a) if wrap == 'mirror' else wrap_blend(a)
    return np.asarray(Image.fromarray(a.clip(0, 255).astype(np.uint8)).resize((n, n), Image.LANCZOS)).astype(np.float32)


def ludo_ground(cfg, rng):
    """The ground texture (PERIOD x PERIOD cells) of a Ludo.ai floor; several pictures are laid over each other in soft patches."""
    n = PERIOD * G
    opts = {k: v for k, v in cfg.items() if k in ('wrap', 'crop', 'box', 'even')}
    texs = [ludo_texture(ludo.find('tiles', 'floor_' + name), n, **opts) for name in cfg['mix']]
    if len(texs) == 1:
        big = texs[0]
    else:
        f = np.stack([periodic_noise(rng, n, 3) for _ in texs])
        w = np.exp(3.0 * f)
        w /= w.sum(axis=0, keepdims=True)
        big = sum(w[i][..., None] * t for i, t in enumerate(texs))
    # the same gentle drift of brightness as the sheet floors, so the repeats do not line up
    noise = periodic_noise(rng, n, PERIOD * 2)
    return np.clip(big * (1 + 0.05 * noise[..., None]), 0, 255)


def slab_variants(face, how):
    """Built floors: each cell one clean slab (the face without its outline and shading), turned so the slabs do not repeat in
    lines: stones every quarter turn and mirrored, planks only half turns (the boards keep running one way)."""
    inner = fill_background(face[20:108, 20:108])
    inner = even_light(inner)
    turns = [0, 2] if how == 'planks' else [0, 1, 2, 3]
    out = []
    for k in turns:
        t = np.rot90(inner, k)
        out.append(t)
        if how != 'planks':
            out.append(t[:, ::-1])
    return out


def slab_tile(t):
    """One slab seen in the game's view, as a 64 x 32 diamond."""
    n = t.shape[0]
    sx, sy = np.meshgrid(np.arange(64) + 0.5, np.arange(32) + 0.5)
    X, Y = sx - 32, sy
    u = np.clip((X / 32 + Y / 16) / 2, 0, 0.999)
    v = np.clip((Y / 16 - X / 32) / 2, 0, 0.999)
    rgb = sample(t, u * (n - 1), v * (n - 1))
    dist = np.abs(X) / 32 + np.abs(Y - 16) / 16
    alpha = np.clip((1 + 1.4 / 16 - dist) * 16, 0, 1) * 255
    return Image.fromarray(np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8), 'RGBA')


def cell_tile(big, gx, gy):
    """The 64 x 32 diamond of cell (gx, gy) of the ground texture, as the game draws it, a pixel wider all round."""
    sx, sy = np.meshgrid(np.arange(64) + 0.5, np.arange(32) + 0.5)
    X, Y = sx - 32, sy
    u = (X / 32 + Y / 16) / 2
    v = (Y / 16 - X / 32) / 2
    rgb = sample(big, (gx + u) * G, (gy + v) * G)
    # the diamond, grown by a little over a pixel, with a soft edge
    dist = np.abs(X) / 32 + np.abs(Y - 16) / 16       # 1 on the diamond's edge
    alpha = np.clip((1 + 1.4 / 16 - dist) * 16, 0, 1) * 255
    out = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


# details laid over a floor, per period of cells
DETAILS = {('overworld', '.'): {'tuft': 22, 'flowers': 6, 'pebble': 5}}


def with_details(tiles, gd, counts, rng):
    """Lays small details over the finished floor, in the game's view. The floor is drawn out over three periods each way, every
    detail is put down at its place in each copy (so one crossing the edge of the period carries on in the next), and each
    cell's tile is cut back out of the middle copy."""
    P = PERIOD
    W, H = 64 * 3 * P + 128, 32 * 3 * P + 64
    ox, oy = W // 2, 16
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    at = lambda u, v: (ox + (u - v) * 32, oy + (u + v) * 16)
    for cy in range(-P, 2 * P):
        for cx in range(-P, 2 * P):
            x, y = at(cx, cy)
            canvas.alpha_composite(tiles[(cx % P, cy % P)], (round(x - 32), round(y)))
    spots = sorted(gd.scatter(rng, P, counts), key=lambda s: s[1] + s[2])   # drawn back to front
    for kind, u, v in spots:
        pic = gd.MAKERS[kind](rng)
        for k in (-1, 0, 1):
            for l in (-1, 0, 1):
                x, y = at(u + k * P, v + l * P)
                canvas.alpha_composite(pic, (round(x - pic.width / 2), round(y - pic.height + 2)))
    out = {}
    for (gx, gy), t in tiles.items():
        x, y = at(gx + P, gy + P)
        cut = canvas.crop((round(x - 32), round(y), round(x + 32), round(y + 32)))
        cut.putalpha(t.getchannel('A'))
        out[(gx, gy)] = cut
    return out


def save_tile(img, path):
    """The engine keeps a sprite in at most 255 colours: each tile gets its own palette of 200, and a hard edge (no half-see-through
    pixels, which would each need a colour of their own)."""
    a = np.asarray(img)
    alpha = np.where(a[..., 3] >= 96, 255, 0).astype(np.uint8)
    q = img.convert('RGB').quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    Image.fromarray(np.dstack([np.asarray(q), alpha]), 'RGBA').save(path)


def save_tiles_shared(tiles, out, make_entry):
    """The tiles of one floor in one shared palette (so no tile differs a little in colour from its neighbour, which would show as a
    faint grid), each with a hard edge as in save_tile. Returns the index entries."""
    keys = sorted(tiles)
    sheet = Image.new('RGB', (64 * len(keys), 32))
    for i, k in enumerate(keys):
        sheet.paste(tiles[k].convert('RGB'), (64 * i, 0))
    q = sheet.quantize(colors=250, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    entries = []
    for i, k in enumerate(keys):
        alpha = np.where(np.asarray(tiles[k])[..., 3] >= 96, 255, 0).astype(np.uint8)
        rgb = np.asarray(q.crop((64 * i, 0, 64 * i + 64, 32))).copy()
        rgb[alpha == 0] = 0   # (all see-through pixels one value, so the tile holds at most 251 different RGBA values)
        e = make_entry(k)
        Image.fromarray(np.dstack([rgb, alpha]), 'RGBA').save(os.path.join(out, e['file']))
        entries.append(e)
    return entries


def main():
    needs_sheet = any(not (k in LUDO_FLOORS and ludo.find('tiles', 'floor_' + LUDO_FLOORS[k]['mix'][0])) for k in PICKS)
    if needs_sheet:
        sheet = np.asarray(Image.open(SHEET).convert('RGB')).astype(np.float32)
        fg = sheet.min(axis=2) < 225
        rws = rows(fg)
    out = os.path.join(WORK, 'tiles_sheet')
    os.makedirs(out, exist_ok=True)
    old = json.load(open(os.path.join(WORK, 'tiles_q', 'index.json')))
    index = []
    for e in old:   # the sides (and any floor not picked here) stay the game's own
        if e['what'] != 'top' or ((e['scene'], e['kind']) not in PICKS and (e['scene'], e['kind']) not in LUDO_FLOORS):
            shutil.copy(os.path.join(WORK, 'tiles_q', e['file']), os.path.join(out, e['file']))
            index.append(e)
    rng = np.random.default_rng(7)
    made = 0
    import grass_details as gd
    for (scene, kind), ((r, c), how) in PICKS.items():
        lf = LUDO_FLOORS.get((scene, kind))
        if lf and ludo.find('tiles', 'floor_' + lf['mix'][0]):   # a Ludo.ai floor: no face to cut, no details to add
            big = ludo_ground(lf, rng)
            tiles = {(gx, gy): cell_tile(big, gx, gy) for gy in range(PERIOD) for gx in range(PERIOD)}
            entries = save_tiles_shared(tiles, out, lambda k: {'cell': [0, 0], 'file': f'{scene}_{KIND[kind]}_floor_{k[0]}_{k[1]}.png', 'kind': kind, 'parity': 0, 'scene': scene, 'what': 'top', 'grid': list(k), 'period': PERIOD})
            index += entries
            made += len(entries)
            continue
        face = flat_face(sheet, fg, r, c, rws)
        if how in ('slab', 'planks'):
            for i, t in enumerate(slab_variants(face, how)):
                for parity in (0, 1):
                    name = f'{scene}_{KIND[kind]}_slab_{parity}_{i}.png'
                    save_tile(slab_tile(t), os.path.join(out, name))
                    index.append({'cell': [0, 0], 'file': name, 'kind': kind, 'parity': parity, 'scene': scene, 'what': 'top'})
                    made += 1
            continue
        big = ground(face, how, rng)
        tiles = {(gx, gy): cell_tile(big, gx, gy) for gy in range(PERIOD) for gx in range(PERIOD)}
        if (scene, kind) in DETAILS:
            tiles = with_details(tiles, gd, DETAILS[(scene, kind)], rng)
        for gy in range(PERIOD):
            for gx in range(PERIOD):
                name = f'{scene}_{KIND[kind]}_floor_{gx}_{gy}.png'
                save_tile(tiles[(gx, gy)], os.path.join(out, name))
                index.append({'cell': [0, 0], 'file': name, 'kind': kind, 'parity': 0, 'scene': scene, 'what': 'top', 'grid': [gx, gy], 'period': PERIOD})
                made += 1
    json.dump(index, open(os.path.join(out, 'index.json'), 'w'), indent=1)
    print('sheet tiles', made)


main()
