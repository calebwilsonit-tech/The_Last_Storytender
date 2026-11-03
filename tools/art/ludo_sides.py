"""Cliff and ledge faces for every floor of the game, from the Ludo.ai wall pictures (art/incoming2/tiles/side_earth, side_stone, side_wood).

The pictures are flat wall textures. The game's tile faces are slanted: under a 64 x 32 diamond the left face is a 32 x 44 parallelogram
(its top edge runs from the left corner down to the bottom corner, 28 px thick) and the right face is its mirror. So for each floor
  - the wall picture that suits it (earth, stone, wood; a stack of paper for the pages) is shrunk to the game's pixel size and cut to a
    32 px wide strip that repeats without a seam (neighbouring tiles carry the wall on into each other),
  - it is coloured from the floor's own picture (its darks and lights), so a face and the floor above it belong together,
  - sheared into the left and right faces, lit like the rest of the game (the left face lighter, the right darker, both darker toward the
    foot), and given a lip along the top where the floor carries on over the edge (grass, moss, a pale cap).
Each face is outlined in a dark shade of its own floor along the ledge (the top rim, where the floor ends), up the corner where the two faces
meet, and along the foot, so the edge of a raised floor is easy to see in the game; the open floor itself has no outline (it would draw a grid).
Written to <out>/<name>_left.png and _right.png (32 x 44, transparent) with a preview sheet of every set.

    python3 -I tools/art/ludo_sides.py <repo> [out dir, default art/generated/tile_sides]
Pillow and numpy only."""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

REPO = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, 'art', 'generated', 'tile_sides')
SRC = os.path.join(REPO, 'art', 'incoming2', 'tiles')
W, H, THICK = 32, 44, 28          # the face sprite, and how tall the wall is

# the wall pictures: how much each is shrunk to reach the game's pixel size
WALLS = {'earth': 0.085, 'stone': 0.105, 'wood': 0.13}

# Every floor, and the face that goes under it.
#   wall: which wall picture (or 'paper': a stack of pages drawn here), at: where in it the strip is cut (so variants differ)
#   body: the floor picture (or three RGB triples: dark, middle, light) the wall takes its colours from
#   top:  the floor picture its lip takes its colour from; lip: 'grass' (a green edge that hangs down), 'cap' (a pale rim) or 'none'
HOLE = ((16, 14, 22), (28, 24, 36), (60, 52, 74))
FACES = {
    'meadow_1': dict(wall='earth', at=(0.30, 0.28), body='floor_dirt', top='floor_meadow_1', lip='grass'),
    'meadow_2': dict(wall='earth', at=(0.55, 0.40), body='floor_dirt', top='floor_meadow_2', lip='grass'),
    'meadow_3': dict(wall='earth', at=(0.12, 0.45), body='floor_dirt', top='floor_meadow_3', lip='grass'),
    'dirt': dict(wall='earth', at=(0.70, 0.30), body='floor_dirt', top='floor_dirt', lip='cap'),
    'moss': dict(wall='earth', at=(0.40, 0.55), body='floor_dirt', top='floor_moss', lip='grass'),
    'cobble': dict(wall='stone', at=(0.30, 0.30), body='floor_cobble', top='floor_cobble', lip='cap'),
    'flagstone': dict(wall='stone', at=(0.55, 0.20), body='floor_flagstone', top='floor_flagstone', lip='cap'),
    'slate': dict(wall='stone', at=(0.20, 0.50), body='floor_slate', top='floor_slate', lip='cap'),
    'planks': dict(wall='wood', at=(0.30, 0.30), body='floor_planks', top='floor_planks', lip='cap'),
    'parchment': dict(wall='paper', at=(0, 0), body='floor_parchment', top='floor_parchment', lip='cap'),
    # a pit: the dark inside of a hole (the game's pit colours), no lip
    'pit': dict(wall='stone', at=(0.45, 0.55), body=HOLE, top=HOLE, lip='none'),
    # the edge of the page: the game's paper, in a stack of leaves
    'page_edge': dict(wall='paper', at=(0, 0), body=((150, 128, 96), (201, 181, 138), (230, 214, 172)), top=((150, 128, 96), (222, 206, 166), (240, 228, 196)), lip='cap'),
}


def palette(src):
    """The darks, middle and lights of a floor picture: mean colours of its darkest 8%, all of it and its lightest 8% (by brightness).
    A set of three RGB triples is taken as it is."""
    if not isinstance(src, str):
        return tuple(np.array(c, np.float32) for c in src)
    img = Image.open(os.path.join(SRC, src + '.png')).convert('RGB').resize((96, 96), Image.LANCZOS)
    px = np.asarray(img).reshape(-1, 3).astype(np.float32)
    order = np.argsort(px.mean(axis=1))
    k = max(1, len(px) // 12)
    return px[order[:k]].mean(axis=0), px.mean(axis=0), px[order[-k:]].mean(axis=0)


def ramp(img, dark, light):
    """The picture's brightness turned into a ramp from `dark` to `light` (so a pink earth becomes the floor's brown)."""
    g = img.mean(axis=2, keepdims=True)
    lo, hi = np.percentile(g, 3), np.percentile(g, 97)
    t = np.clip((g - lo) / max(hi - lo, 1), 0, 1)
    return np.array(dark) * (1 - t) + np.array(light) * t


def seamless_strip(rgb, x0, y0, w, h):
    """A w x h piece that wraps sideways: the first columns are blended with the columns just past the end."""
    over = w // 3
    x0 = max(0, min(x0, rgb.shape[1] - w - over))   # the cut stays inside the picture
    y0 = max(0, min(y0, rgb.shape[0] - h))
    a = rgb[y0:y0 + h, x0:x0 + w].astype(np.float32)
    b = rgb[y0:y0 + h, x0 + w:x0 + w + over].astype(np.float32)
    blend = np.linspace(0, 1, over)[None, :, None]
    a[:, :over] = b * (1 - blend) + a[:, :over] * blend
    return a


def paper_strip(dark, mid, light):
    """A stack of pages seen edge on: leaves two pixels thick that alternate a little in tone, now and then a crease, and a small wobble
    along the length (the same every 32 px, so it joins up)."""
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
            strip[k, x] = base * (1.0 + 0.035 * np.sin((x / W) * 2 * np.pi * (1 + leaf % 3) + leaf))
    return strip


def face(strip, left, lip, outline):
    """The strip sheared into a left (or right) face, lit, with its lip and its outline. Returns an H x W x 4 float array."""
    out = np.zeros((H, W, 4), np.float32)
    shade_x = 1.0 if left else 0.74            # the light comes from the top left
    cap, green = lip
    for x in range(W):
        sx = x if left else W - 1 - x           # the right face is the left one turned round
        y0 = round(sx * 16 / (W - 1))
        # where the two faces meet (the corner of the block) the wall turns away: a gentle shade, a few pixels wide
        corner = x >= W - 3 if left else x <= 2
        for k in range(THICK):
            y = y0 + k
            if y >= H:
                continue
            tone = shade_x * (1.0 - 0.22 * k / THICK)           # darker toward the foot
            if k >= THICK - 2:
                tone *= 0.8                                       # the last rows sit in shadow (no outline: tone only)
            if corner:
                tone *= 0.86
            out[y, x, :3] = strip[k % strip.shape[0], x] * tone
            out[y, x, 3] = 255
        # the lip: the floor carries on over the edge: a pale cap, and over the earth a green edge that hangs down in a ragged line
        rows = []
        if cap is not None:
            rows += [(1, cap), (2, cap)]
            if green is not None:
                drip = 2 + int((x * 7 + 3) % 5 in (0, 1)) + int((x * 3) % 4 == 0)
                rows += [(r, green) for r in range(3, 4 + drip)]
            else:
                rows += [(3, tuple(int(v * 0.9) for v in cap))]
        for r, col in rows:
            y = y0 + r
            if y < H:
                out[y, x, :3] = np.array(col) * (shade_x if r > 1 else min(1.0, shade_x + 0.05)) * (0.9 if corner else 1.0)
        # the outline: the ledge along the top, and the foot
        for r in (0, THICK - 1):
            y = y0 + r
            if y < H:
                out[y, x, :3] = outline
    # and the corner where the two faces meet (the far ends are left open, so a long wall does not look cut into panels)
    c = W - 1 if left else 0
    out[:, c, :3] = np.where(out[:, c:c + 1, 3] > 0, outline, out[:, c, :3])
    return out


def build(name, m):
    dark, mid, light = palette(m['body'])
    if m['wall'] == 'paper':
        strip = paper_strip(dark * 0.9, mid * 0.96, light)      # (pages are already light; a little darker under their own edge)
    else:
        img = Image.open(os.path.join(SRC, f'side_{m["wall"]}.png')).convert('RGB')
        s = WALLS[m['wall']]
        small = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        # the wall is a little darker than the floor it holds up (it is in the shade of its own top edge)
        rgb = ramp(np.asarray(small).astype(np.float32), dark * 0.82, light * 0.92)
        strip = seamless_strip(rgb, int(rgb.shape[1] * m['at'][0]), int(rgb.shape[0] * m['at'][1]), W, THICK)
    t_dark, t_mid, t_light = palette(m['top'])
    cream = np.array([244, 238, 214], np.float32)
    if m['lip'] == 'grass':
        cap = tuple(int(v) for v in np.clip(t_light * 0.6 + cream * 0.4, 0, 255))
        green = tuple(int(v) for v in np.clip(t_mid * 1.04, 0, 255))
    elif m['lip'] == 'cap':
        cap, green = tuple(int(v) for v in np.clip(t_light * 1.08, 0, 255)), None
    else:
        cap, green = None, None
    outline = np.clip(dark * 0.45, 0, 255)
    return {side: Image.fromarray(np.clip(face(strip, side == 'left', (cap, green), outline), 0, 255).astype(np.uint8), 'RGBA') for side in ('left', 'right')}


def block(faces, top_colour):
    """A raised block at the real size: its top diamond (64 x 32, no outline, like the floors), and the faces under it, one level of wall."""
    img = Image.new('RGBA', (64, 15 + H), (0, 0, 0, 0))
    ImageDraw.Draw(img).polygon([(32, 0), (63, 15), (32, 31), (0, 15)], fill=top_colour + (255,))   # (the floor has no outline of its own; the ledge is outlined on the faces)
    img.alpha_composite(faces['left'], (0, 15))
    img.alpha_composite(faces['right'], (32, 15))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    sets = {}
    for name, m in FACES.items():
        sets[name] = build(name, m)
        for side, im in sets[name].items():
            im.save(os.path.join(OUT, f'{name}_{side}.png'))
    # the preview: every set as a run of three blocks at the real size, enlarged, in a grid
    cols, cell_w, cell_h = 3, 250, 150
    rows = (len(sets) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cell_w, rows * cell_h), (150, 190, 120, 255))
    d = ImageDraw.Draw(sheet)
    for n, (name, faces) in enumerate(sets.items()):
        top = tuple(int(v) for v in palette(FACES[name]['top'])[1])
        run = Image.new('RGBA', (160, 96), (0, 0, 0, 0))
        b = block(faces, top)
        for cx, cy in ((0, 0), (32, 16), (64, 32)):
            run.alpha_composite(b, (cx, cy))
        ox, oy = (n % cols) * cell_w, (n // cols) * cell_h
        sheet.alpha_composite(run.resize((run.width * 3 // 2, run.height * 3 // 2), Image.NEAREST), (ox + 6, oy + 24))
        d.text((ox + 8, oy + 6), name, fill=(20, 20, 20, 255))
    sheet.convert('RGB').save(os.path.join(OUT, 'preview.png'))
    print('wrote', len(sets) * 2, 'faces to', OUT)


main()
