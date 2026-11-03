"""Thistledown's people from the chosen generated pictures (art/picks.json "people"): each is cut out and scaled to their size
in the game, and also drawn as the unfinished placeholder they are before their restoration: the same picture in faded
graphite (palette.gd ghostify with nothing restored, then 35% of the static grey), so the outline matches exactly when they
come back. Writes <work>/people/<who>.png and <who>_ghost.png, with people.json giving each one's feet.
    python3 -I tools/art/sd_people.py <repo> <work>"""
import json, os, sys
import numpy as np
from PIL import Image

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(REPO, 'tools', 'art'))
from cutout import cut  # noqa: E402

# how tall each stands in the game (px of solid figure; the Storytender is 63)
HEIGHT = {'garrick': 82, 'maud': 76, 'pip': 62}
STATIC_GRAY = np.array([0x9c, 0x9c, 0xa8], np.float32)


def solid_box(im, level=200):
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def ghost(im):
    a = np.asarray(im).astype(np.float32)
    rgb = a[..., :3]
    lum = (rgb * np.array([0.2126, 0.7152, 0.0722])).sum(axis=2, keepdims=True)
    grey = np.repeat(lum, 3, axis=2)
    grey = grey + (255 - grey) * 0.25          # lighter, like pencil
    grey = grey * 0.65 + STATIC_GRAY * 0.35
    out = a.copy()
    out[..., :3] = grey
    out[..., 3] = a[..., 3] * 0.85             # a little see-through: not quite there yet
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), 'RGBA')


def main():
    picks = json.load(open(os.path.join(REPO, 'art', 'picks.json'))).get('people', {})
    out_dir = os.path.join(WORK, 'people')
    os.makedirs(out_dir, exist_ok=True)
    feet = {}
    for who, pick in picks.items():
        im = cut(os.path.join(REPO, 'art', 'generated', 'people', pick + '.png'))
        im = im.crop(im.getbbox())
        b = solid_box(im)
        s = HEIGHT.get(who, 70) / max(1, b[3] - b[1])
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        b = solid_box(im)
        # a little room all round, the feet at the bottom middle of the solid figure
        pad = 4
        canvas = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
        canvas.alpha_composite(im, (pad, pad))
        f = [pad + round((b[0] + b[2]) / 2), pad + b[3]]
        for name, pic in ((who, canvas), (who + '_ghost', ghost(canvas))):
            q = pic.convert('RGB').quantize(colors=254, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
            qa = np.asarray(q).copy()
            qa[..., 3] = np.asarray(pic.getchannel('A'))
            Image.fromarray(qa, 'RGBA').save(os.path.join(out_dir, name + '.png'))
            feet[name] = f
    json.dump(feet, open(os.path.join(out_dir, 'people.json'), 'w'), indent=1)
    print('people', ', '.join(picks))


main()
