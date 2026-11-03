"""Objects that change with the story, from the chosen generated pictures (art/picks.json "objects"): a chest closed and open,
a lantern post unlit and lit, the forge frozen and burning, Maud's oven cold and warm. A pick is <picture>:<piece> (pieces.py),
or "from:<other>:cold|frozen" to make one state from the other's picture, so the two always match. Each is scaled to the size
the object has in the game. Writes <work>/objects/<name>.png and objects.json (each one's feet).
    python3 -I tools/art/sd_objects.py <repo> <work>"""
import colorsys, json, os, sys, tempfile
import numpy as np
from PIL import Image

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(REPO, 'tools', 'art'))
from pieces import pieces  # noqa: E402

# solid height in the game (px), as the pictures they replace
HEIGHT = {'chest': 40, 'post': 72, 'forge': 120, 'oven': 104, 'echo': 30, 'first': 30, 'sign': 62}


def solid_box(im, level=200):
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def piece(pick):
    name, k = pick.split(':')
    with tempfile.TemporaryDirectory() as tmp:
        files = pieces(os.path.join(REPO, 'art', 'generated', 'objects', name + '.png'), tmp, int(k) + 1)
        return Image.open(files[int(k)]).convert('RGBA').copy()


def fire_mask(a):
    """Bright, saturated orange and yellow: the fire and its glow."""
    rgb = a[..., :3].astype(np.float32) / 255
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r > 0.55) & (r >= g) & (g > b) & (sat > 0.45) & (mx > 0.6)


def cold(im):
    """The fire put out: its pixels become dark soot, everything a little greyer."""
    a = np.asarray(im).astype(np.float32)
    m = fire_mask(a)
    lum = a[..., :3].mean(axis=2, keepdims=True)
    a[..., :3] = a[..., :3] * 0.8 + lum * 0.2
    a[m, :3] = np.array([46, 40, 44]) + (lum[m] * 0.15)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGBA')


def frozen(im):
    """The fire turned to still blue ice, and frost over everything."""
    a = np.asarray(im).astype(np.float32)
    m = fire_mask(a)
    out = a.copy()
    for y, x in zip(*np.nonzero(m)):
        r, g, b = a[y, x, :3] / 255
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        r2, g2, b2 = colorsys.hls_to_rgb(0.55, min(0.9, l * 1.05), s)   # the same flame, in ice blue
        out[y, x, :3] = (r2 * 255, g2 * 255, b2 * 255)
    frost = np.array([200, 225, 240], np.float32)
    out[~m, :3] = out[~m, :3] * 0.78 + frost * 0.22
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), 'RGBA')


def main():
    picks = {k: v for k, v in json.load(open(os.path.join(REPO, 'art', 'picks.json'))).get('objects', {}).items() if not k.startswith('_')}
    out_dir = os.path.join(WORK, 'objects')
    os.makedirs(out_dir, exist_ok=True)
    made, feet = {}, {}
    for name, pick in sorted(picks.items(), key=lambda kv: kv[1].startswith('from:')):
        if pick.startswith('from:'):
            _, src, how = pick.split(':')
            im = {'cold': cold, 'frozen': frozen}[how](made[src])
        else:
            im = piece(pick)
            im = im.crop(im.getbbox())
            b = solid_box(im)
            s = HEIGHT[name.split('_')[0]] / max(1, b[3] - b[1])
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        made[name] = im
        b = solid_box(im)
        pad = 3
        canvas = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
        canvas.alpha_composite(im, (pad, pad))
        q = canvas.convert('RGB').quantize(colors=254, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
        qa = np.asarray(q).copy()
        qa[..., 3] = np.asarray(canvas.getchannel('A'))
        Image.fromarray(qa, 'RGBA').save(os.path.join(out_dir, name + '.png'))
        feet[name] = [pad + round((b[0] + b[2]) / 2), pad + b[3]]
    json.dump(feet, open(os.path.join(out_dir, 'objects.json'), 'w'), indent=1)
    print('objects', ', '.join(sorted(picks)))


main()
