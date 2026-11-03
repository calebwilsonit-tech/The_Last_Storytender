"""Cliff and ledge faces from the Ludo.ai wall pictures (art/incoming2/tiles/side_earth, side_stone, side_wood).

The pictures are flat wall textures. The game's tile faces are slanted: under a 64 x 32 diamond the left face is a 32 x 44 parallelogram
(its top edge runs from the left corner down to the bottom corner, 28 px thick) and the right face is its mirror. So each picture is
  - shrunk to the game's pixel size and cut to a 32 px wide strip that repeats without a seam (the faces of neighbouring tiles carry
    the wall on into each other),
  - sheared into the left and right faces,
  - lit like the rest of the game: the left face lighter, the right darker, both darker toward the foot,
  - given a lip along the top (grass over the earth, a cap over the stone and the wood) and a dark outline,
and written to <out>/<material>_left.png and _right.png (32 x 44, transparent), plus a preview sheet and a small cliff built from them.

    python3 -I tools/art/ludo_sides.py <repo> [out dir, default art/generated/tile_sides]
Pillow and numpy only."""
import os
import sys
import numpy as np
from PIL import Image

REPO = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, 'art', 'generated', 'tile_sides')
SRC = os.path.join(REPO, 'art', 'incoming2', 'tiles')
W, H, THICK = 32, 44, 28          # the face sprite, and how tall the wall is
OUTLINE = np.array([34, 24, 18])

# per material: how much the picture is shrunk, where the strip is cut (fractions of the shrunk picture), the colours the light and dark
# of the picture are turned into (None keeps the picture's own), and the lip drawn along the top
MATERIALS = {
    'earth': dict(scale=0.085, at=(0.30, 0.28), ramp=((58, 36, 22), (206, 152, 96)), lip=((246, 240, 214), (112, 148, 64))),
    'stone': dict(scale=0.105, at=(0.30, 0.30), ramp=((52, 50, 58), (190, 188, 192)), lip=((236, 232, 220), None)),
    'wood': dict(scale=0.13, at=(0.30, 0.30), ramp=((70, 44, 26), (200, 148, 92)), lip=((226, 190, 140), None)),
}


def ramp(img, dark, light):
    """The picture's brightness turned into a ramp from `dark` to `light` (so a pink earth becomes brown)."""
    g = img.mean(axis=2, keepdims=True)
    lo, hi = np.percentile(g, 3), np.percentile(g, 97)
    t = np.clip((g - lo) / max(hi - lo, 1), 0, 1)
    return np.array(dark) * (1 - t) + np.array(light) * t


def seamless_strip(rgb, x0, y0, w, h):
    """A w x h piece that wraps sideways: the first columns are blended with the columns just past the end."""
    over = w // 3
    a = rgb[y0:y0 + h, x0:x0 + w].astype(np.float32)
    b = rgb[y0:y0 + h, x0 + w:x0 + w + over].astype(np.float32)
    ramp_in = np.linspace(0, 1, over)[None, :, None]
    a[:, :over] = b * (1 - ramp_in) + a[:, :over] * ramp_in
    return a


def face(strip, left, lip):
    """The strip sheared into a left (or right) face, lit, with its lip and outline. Returns an H x W x 4 float array."""
    out = np.zeros((H, W, 4), np.float32)
    shade_x = 1.0 if left else 0.74            # the light comes from the top left
    for x in range(W):
        sx = x if left else W - 1 - x           # the right face is the left one turned round
        y0 = round(sx * 16 / (W - 1))
        for k in range(THICK):
            y = y0 + k
            if y >= H:
                continue
            c = strip[k % strip.shape[0], x] * shade_x
            c = c * (1.0 - 0.28 * k / THICK)    # darker toward the foot
            out[y, x, :3] = c
            out[y, x, 3] = 255
        # the lip: a pale cap, and over the earth a green edge that hangs down in a ragged line
        cap, green = lip
        rows = [(0, cap)]
        rows += [(1, cap)]
        if green is not None:
            drip = 2 + int((x * 7 + 3) % 5 in (0, 1)) + int((x * 3) % 4 == 0)
            rows += [(r, green) for r in range(2, 3 + drip)]
        else:
            rows += [(2, tuple(int(v * 0.85) for v in cap))]
        for r, col in rows:
            y = y0 + r
            if y < H:
                out[y, x, :3] = np.array(col) * (shade_x if r else min(1.0, shade_x + 0.05))
        # the foot is outlined twice as dark
        for r in (THICK - 2, THICK - 1):
            y = y0 + r
            if y < H:
                out[y, x, :3] = OUTLINE
    out[:, 0, :3] = np.where(out[:, 0:1, 3] > 0, OUTLINE, out[:, 0, :3])
    out[:, W - 1, :3] = np.where(out[:, W - 1:W, 3] > 0, OUTLINE, out[:, W - 1, :3])
    return out


def build(name, m):
    img = Image.open(os.path.join(SRC, f'side_{name}.png')).convert('RGB')
    small = img.resize((max(1, round(img.width * m['scale'])), max(1, round(img.height * m['scale']))), Image.LANCZOS)
    rgb = ramp(np.asarray(small).astype(np.float32), *m['ramp'])
    x0 = int(rgb.shape[1] * m['at'][0])
    y0 = int(rgb.shape[0] * m['at'][1])
    strip = seamless_strip(rgb, x0, y0, W, THICK)
    return {side: Image.fromarray(np.clip(face(strip, side == 'left', m['lip']), 0, 255).astype(np.uint8), 'RGBA') for side in ('left', 'right')}


def block(faces, top_colour):
    """A raised block at the real size: its top diamond (64 x 32), and the left and right faces under it, one level of wall."""
    from PIL import ImageDraw
    img = Image.new('RGBA', (64, 15 + H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(32, 0), (63, 15), (32, 31), (0, 15)], fill=top_colour + (255,), outline=(34, 24, 18, 255))
    img.alpha_composite(faces['left'], (0, 15))
    img.alpha_composite(faces['right'], (32, 15))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for name, m in MATERIALS.items():
        faces = build(name, m)
        for side, im in faces.items():
            im.save(os.path.join(OUT, f'{name}_{side}.png'))
        rows.append((name, faces))
    # the preview: each pair of faces large, and a block and a two-block step at the real size, enlarged, beside it
    scale = 8
    ph = (H * scale) + 20
    tops = {'earth': (122, 170, 70), 'stone': (170, 168, 164), 'wood': (176, 130, 80)}
    sheet = Image.new('RGBA', (W * 2 * scale + 60 + 460, ph * len(rows)), (150, 190, 120, 255))
    for i, (name, faces) in enumerate(rows):
        for j, side in enumerate(('left', 'right')):
            sheet.alpha_composite(faces[side].resize((W * scale, H * scale), Image.NEAREST), (j * (W * scale + 20), i * ph))
        step = Image.new('RGBA', (160, 110), (0, 0, 0, 0))
        b = block(faces, tops[name])
        for cx, cy in ((0, 0), (32, 16), (64, 32)):
            step.alpha_composite(b, (cx, cy))
        sheet.alpha_composite(step.resize((160 * 3, 110 * 3), Image.NEAREST), (W * 2 * scale + 40, i * ph + 20))
    sheet.convert('RGB').save(os.path.join(OUT, 'preview.png'))
    print('wrote', len(rows) * 2, 'faces to', OUT)


main()
