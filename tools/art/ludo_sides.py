"""Cliff and ledge faces for every floor of the game, built from the floor tiles themselves (ludo_tops.py) and the Ludo.ai wall pictures
(art/incoming2/tiles/side_earth, side_stone).

A face is slanted: under a 64 x 32 diamond the left face is a 32 x 44 parallelogram (its top edge runs from the left corner down to the
bottom corner, 28 px thick) and the right face is its mirror. Each face here is made from the tile above it, so the two belong together:
  - the colours along the tile's edge are carried straight down the wall: a plank line, a stone joint, a blade of grass on the top continues
    as the same line down the side, because the side is made from the top,
  - then each kind of floor finishes the wall its own way: earth gets Ludo's cracked earth under a lip that is the top's own grass, stone
    gets courses, planks get grain, pages get leaves,
  - lit like the rest of the game (the left face lighter, the right darker, both darker toward the foot).
(Round cobbles are smoothed first, so their gaps do not turn into bars.) Stone, wood and paper are outlined in a dark shade of their floor along the ledge and the foot (not up the sides: a tile cannot know where a wall ends, and a bar at every tile would cut the wall into panels; the right face is darker than the left, which is what shows the corner); earth and grass are not (their
lip already shows where the ground ends).
Every tile of a floor (x and y 0 to 3) has its own pair of faces, because the top is different at each, written as
<out>/<floor>_<x><y>_left.png and _right.png (32 x 44, transparent); plus pit and page_edge, which have no top picture (one pair each).

    python3 -I tools/art/ludo_sides.py <repo> [out dir, default art/generated/tile_sides] [--tops <folder of <floor>_<x><y>.png tiles>]
Pillow and numpy only."""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:] if not a.startswith('--')]
REPO = args[0] if args else '.'
OUT = args[1] if len(args) > 1 else os.path.join(REPO, 'art', 'generated', 'tile_sides')
TOPS = sys.argv[sys.argv.index('--tops') + 1] if '--tops' in sys.argv else os.path.join(REPO, 'art', 'generated', 'tile_tops')
SRC = os.path.join(REPO, 'art', 'incoming2', 'tiles')
W, H, THICK, PERIOD = 32, 44, 28, 4

# kind: how the wall is finished. outline: dark line along the ledge, corner and foot. wall: the Ludo picture the earth is made from.
# Each floor's wall is a Ludo picture made with that floor as its style reference (art/ludo_manifests/sides_matched.json, side_cobble2.json), so the
# wall has the floor's own stones, colours and line weight. wall: the picture, scale: how much it is shrunk to the game's pixel size (the stones
# of the wall come out about the size of the floor's), at: where in it the strip is cut, lip: rows at the top that are the floor's own colours,
# drip: the lip hangs down in a ragged line (grass), recolor: bend the wall's colours onto the floor's darks and lights.
FLOORS = {
    'meadow_1': dict(kind='earth', wall='wall_earth', scale=0.15, at=(0.30, 0.28), body='floor_dirt', outline=False, drip=True),
    'meadow_2': dict(kind='earth', wall='wall_earth', scale=0.15, at=(0.55, 0.40), body='floor_dirt', outline=False, drip=True),
    'meadow_3': dict(kind='earth', wall='wall_earth', scale=0.15, at=(0.12, 0.45), body='floor_dirt', outline=False, drip=True),
    'dirt': dict(kind='earth', wall='wall_earth', scale=0.15, at=(0.70, 0.30), body='floor_dirt', outline=False, lip=2),
    'moss': dict(kind='earth', wall='wall_earth', scale=0.15, at=(0.40, 0.55), body='floor_dirt', outline=False, drip=True),
    'cobble': dict(kind='stone', wall='wall_cobble', scale=0.10, at=(0.30, 0.30), outline=True, lip=2, recolor=True),
    'flagstone': dict(kind='stone', wall='wall_flagstone', scale=0.15, at=(0.30, 0.30), outline=True, lip=2),
    'slate': dict(kind='stone', wall='wall_slate', scale=0.15, at=(0.30, 0.30), outline=True, lip=2),
    'planks': dict(kind='wood', wall='wall_planks', scale=0.15, at=(0.30, 0.30), outline=True, lip=2, recolor=True),
    'parchment': dict(kind='paper', wall='wall_paper', scale=0.20, at=(0.30, 0.30), outline=True, lip=1, recolor=True),
}
# the floors that have no picture of their own: the colours of the dark inside of a hole, and of the edge of the page
EXTRA = {
    'pit': dict(kind='stone', wall='wall_slate', scale=0.15, at=(0.30, 0.30), outline=True, lip=0, recolor=True, top=(28, 24, 36), dark=(16, 14, 22), light=(60, 52, 74)),
    'page_edge': dict(kind='paper', wall='wall_paper', scale=0.20, at=(0.30, 0.30), outline=True, lip=1, recolor=True, top=(222, 206, 166), dark=(150, 128, 96), light=(240, 228, 196)),
}


def palette(src):
    """The darks, middle and lights of a picture: mean colours of its darkest 8%, all of it and its lightest 8% (by brightness)."""
    if isinstance(src, str):
        new = os.path.join(SRC, 'top_' + src[len('floor_'):] + '.png')     # a top made to match its wall wins over the first floor picture
        path = new if src.startswith('floor_') and os.path.exists(new) else os.path.join(SRC, src + '.png')
        img = Image.open(path).convert('RGB').resize((96, 96), Image.LANCZOS)
        px = np.asarray(img).reshape(-1, 3).astype(np.float32)
    else:
        px = np.asarray(src, np.float32).reshape(-1, 3)
    order = np.argsort(px.mean(axis=1))
    k = max(1, len(px) // 12)
    return px[order[:k]].mean(axis=0), px.mean(axis=0), px[order[-k:]].mean(axis=0)


def ramp(img, dark, light):
    """The picture's brightness turned into a ramp from `dark` to `light` (so a pink earth becomes the floor's brown)."""
    g = img.mean(axis=2, keepdims=True)
    lo, hi = np.percentile(g, 3), np.percentile(g, 97)
    return np.array(dark) * (1 - np.clip((g - lo) / max(hi - lo, 1), 0, 1)) + np.array(light) * np.clip((g - lo) / max(hi - lo, 1), 0, 1)


def seamless_strip(rgb, x0, y0, w, h):
    """A w x h piece that wraps sideways: the first columns are blended with the columns just past the end."""
    over = w // 3
    x0 = max(0, min(x0, rgb.shape[1] - w - over))
    y0 = max(0, min(y0, rgb.shape[0] - h))
    a = rgb[y0:y0 + h, x0:x0 + w].astype(np.float32)
    b = rgb[y0:y0 + h, x0 + w:x0 + w + over].astype(np.float32)
    blend = np.linspace(0, 1, over)[None, :, None]
    a[:, :over] = b * (1 - blend) + a[:, :over] * blend
    return a


def edge_of(tile, left):
    """The colours along the tile's lower-left edge (for the left face) or lower-right edge (the right face): one colour per column, taken
    just inside the edge. Returns a 32 x 3 array."""
    a = np.asarray(tile.convert('RGBA')).astype(np.float32)
    cols = range(0, 32) if left else range(32, 64)
    out = []
    for c in cols:
        ys = np.where(a[:, c, 3] > 0)[0]
        yb = ys.max() if len(ys) else 15
        out.append(a[max(0, yb - 1):yb + 1, c, :3].mean(axis=0))
    return np.array(out)


def earth_strip(edge, wall, dark, light, at):
    """Earth: the top's own colour for the lip (a ragged edge of it hangs down), then Ludo's cracked earth in the floor's brown."""
    size = (round(wall.width * 0.085), round(wall.height * 0.085))
    rgb = ramp(np.asarray(wall.resize(size, Image.LANCZOS)).astype(np.float32), dark * 0.82, light * 0.92)
    body = seamless_strip(rgb, int(rgb.shape[1] * at[0]), int(rgb.shape[0] * at[1]), W, THICK)
    strip = body.copy()
    for x in range(W):
        lip = 3 + int((x * 7 + 3) % 5 in (0, 1)) + int((x * 3) % 4 == 0)
        for k in range(lip + 1):
            c = edge[x] * (1.12 if k == 0 else 1.0)
            strip[k, x] = c if k < lip else c * 0.5 + body[k, x] * 0.5
    return strip


def stone_strip(edge, wall, dark, light):
    """Stone: the joints and slabs of the top continue down as they are; across the wall run courses; Ludo's stone adds the texture."""
    size = (round(wall.width * 0.105), round(wall.height * 0.105))
    tex = ramp(np.asarray(wall.resize(size, Image.LANCZOS)).astype(np.float32), np.zeros(3), np.ones(3) * 255)
    tex = seamless_strip(tex, int(tex.shape[1] * 0.30), int(tex.shape[0] * 0.30), W, THICK).mean(axis=2)
    mod = 1 + 0.30 * (tex - tex.mean()) / 255
    strip = np.zeros((THICK, W, 3), np.float32)
    for k in range(THICK):
        for x in range(W):
            strip[k, x] = edge[x] * 0.86 * mod[k, x]
    for k in (13, 27):                       # the courses
        strip[k - 1:k + 1] = strip[k - 1:k + 1] * 0.45 + (dark * 0.7)[None, None, :] * 0.55
    return strip


def wood_strip(edge, dark):
    """Wood: the planks' lines on the top run on down the side; the grain runs across it."""
    strip = np.zeros((THICK, W, 3), np.float32)
    rng = np.random.RandomState(7)
    grain = 1 + 0.06 * rng.standard_normal((THICK, 8))
    for k in range(THICK):
        for x in range(W):
            line = 0.88 if (k * 5 + 3) % 7 == 0 else 1.0           # a fine grain line now and then
            strip[k, x] = edge[x] * 0.86 * line * grain[k, (x // 4) % 8]
    return strip


def paper_strip(edge, dark, light):
    """Pages: leaves two pixels thick that alternate a little in tone and now and then a crease (the first row is the top's own colour)."""
    mid = edge.mean(axis=0)
    strip = np.zeros((THICK, W, 3), np.float32)
    for k in range(THICK):
        leaf = k // 2
        tone = 0.5 + 0.25 * np.sin(leaf * 2.3) + (0.25 if k % 2 == 0 else 0.0)
        base = mid * (1 - tone * 0.5) + light * (tone * 0.5)
        if k % 2 == 1:
            base = base * 0.93
        if leaf % 6 == 5 and k % 2 == 1:
            base = mid * 0.66 + dark * 0.34
        for x in range(W):
            strip[k, x] = base * (0.94 + 0.12 * edge[x].mean() / max(mid.mean(), 1)) * (1.0 + 0.03 * np.sin((x / W) * 2 * np.pi * (1 + leaf % 3) + leaf))
    strip[0] = edge * 1.05
    return strip


def shear(strip, left, outline):
    """The strip sheared into a left (or right) face, lit; `outline` (a colour or None) along the ledge, the corner and the foot."""
    out = np.zeros((H, W, 4), np.float32)
    shade = 1.0 if left else 0.7                # the light comes from the top left
    for x in range(W):
        sx = x if left else W - 1 - x           # the right face is the left one turned round
        y0 = round(sx * 16 / (W - 1))
        for k in range(THICK):
            y = y0 + k
            if y < H:
                tone = shade * (1.0 - 0.22 * k / THICK) * (0.8 if k >= THICK - 2 else 1.0)
                out[y, x, :3] = strip[k, x] * tone
                out[y, x, 3] = 255
        if outline is not None:
            for k in (0, THICK - 1):
                if y0 + k < H:
                    out[y0 + k, x, :3] = outline
    return out


def picture_strip(edge, wall, scale, at, lip, drip, recolor):
    """A wall from a Ludo picture of the wall itself: shrunk to the game's pixel size, cut to a strip that wraps (and bent onto the floor's own
    darks and lights if `recolor`), with the first `lip` rows the top's own colours so the floor runs on over the edge (`drip`: over a ragged
    line, for grass)."""
    size = (max(1, round(wall.width * scale)), max(1, round(wall.height * scale)))
    rgb = np.asarray(wall.resize(size, Image.LANCZOS)).astype(np.float32)
    if recolor is not None:
        rgb = ramp(rgb, recolor[0], recolor[1])
    strip = seamless_strip(rgb, int(rgb.shape[1] * at[0]), int(rgb.shape[0] * at[1]), W, THICK)
    body = strip.copy()
    for x in range(W):
        n = lip
        if drip:
            n = 3 + int((x * 7 + 3) % 5 in (0, 1)) + int((x * 3) % 4 == 0)
        for k in range(n + (1 if drip else 0)):
            c = edge[x] * (1.12 if k == 0 and drip else 1.04 if k == 0 else 1.0)
            strip[k, x] = c if k < n else c * 0.5 + body[k, x] * 0.5
    return strip


def wall_for(kind, edge, top_mean, m):
    """The strip of wall for one face: `edge` is the colours along the tile above."""
    if 'dark' in m:
        dark, light = np.array(m['dark'], np.float32), np.array(m['light'], np.float32)
        mid = (dark + light) / 2
    else:
        dark, mid, light = palette(m.get('body') or m['top'])
    if m.get('wall'):
        recolor = (mid * 0.8, light * 1.0) if m.get('recolor') else None   # (from the floor's middle tone, not its darkest joints)
        return picture_strip(edge, Image.open(os.path.join(SRC, m['wall'] + '.png')).convert('RGB'), m['scale'], m['at'], m.get('lip', 2), m.get('drip', False), recolor)
    if kind == 'earth':
        return earth_strip(edge, Image.open(os.path.join(SRC, 'side_earth.png')).convert('RGB'), dark, light, m['at'])
    if kind == 'stone':
        return stone_strip(edge, Image.open(os.path.join(SRC, 'side_stone.png')).convert('RGB'), dark, light)
    if kind == 'wood':
        return wood_strip(edge, dark)
    return paper_strip(edge, dark, light)


def faces_of(tile, m, dark):
    """(left, right) face images for one top tile."""
    outline = np.clip(dark * 0.45, 0, 255) if m['outline'] else None
    res = []
    for left in (True, False):
        edge = edge_of(tile, left)
        if m.get('smooth'):
            padded = np.concatenate([edge[-4:], edge, edge[:4]])
            blurred = np.stack([np.convolve(padded[:, c], np.ones(9) / 9, mode='valid') for c in range(3)], axis=1)
            edge = blurred * 0.6 + edge.mean(axis=0) * 0.4
        strip = wall_for(m['kind'], edge, None, m)
        res.append(Image.fromarray(np.clip(shear(strip, left, outline), 0, 255).astype(np.uint8), 'RGBA'))
    return res


def flat_tile(rgb):
    """A plain 64 x 32 diamond (for pit and page_edge, which have no top picture)."""
    im = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    ImageDraw.Draw(im).polygon([(32, 0), (63, 15), (32, 31), (0, 15)], fill=tuple(int(v) for v in rgb) + (255,))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for name, m in FLOORS.items():
        m = dict(m, top='floor_' + name)
        for j in range(PERIOD):
            for i in range(PERIOD):
                tile = Image.open(os.path.join(TOPS, f'{name}_{i}{j}.png')).convert('RGBA')
                left, right = faces_of(tile, m, palette(m.get('body') or m['top'])[0])
                left.save(os.path.join(OUT, f'{name}_{i}{j}_left.png'))
                right.save(os.path.join(OUT, f'{name}_{i}{j}_right.png'))
                n += 2
    for name, m in EXTRA.items():
        left, right = faces_of(flat_tile(m['top']), m, np.array(m['dark'], np.float32))
        left.save(os.path.join(OUT, f'{name}_left.png'))
        right.save(os.path.join(OUT, f'{name}_right.png'))
        n += 2
    print('wrote', n, 'faces to', OUT)


main()
