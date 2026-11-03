"""The Errors from the chosen generated pictures (art/picks.json "errors"). Most of those pictures are sheets of many small
creatures, so a pick names the picture and which figure in it (pieces.py, biggest first). Each is scaled to its size in the
game; the Censor gets the black redaction bar it hides behind (no generated try drew one). The proofread kinds have a friendly
look too. Writes <work>/errors/<name>.png and errors.json (each one's feet).
    python3 -I tools/art/sd_errors.py <repo> <work>"""
import json, os, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(REPO, 'tools', 'art'))
from pieces import pieces  # noqa: E402

# how tall each stands in the game (px of solid figure; the Storytender is 63)
HEIGHT = {'bare': 56, 'mite': 26, 'runon': 30, 'dangler': 50, 'censor': 60, 'ellipsis': 40}


def solid_box(im, level=200):
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def piece(pick):
    name, k = pick.split(':')
    kind = name.split('_')[0]
    with tempfile.TemporaryDirectory() as tmp:
        files = pieces(os.path.join(REPO, 'art', 'generated', 'errors', name + '.png'), tmp, int(k) + 1)
        return Image.open(files[int(k)]).convert('RGBA').copy(), kind


def redaction_bar(im):
    """A thick black bar held across the front, at the chest."""
    b = solid_box(im)
    w, h = b[2] - b[0], b[3] - b[1]
    layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    y = b[1] + round(h * 0.48)
    x0, x1 = b[0] - round(w * 0.12), b[2] + round(w * 0.12)
    d.polygon([(x0, y - 3), (x1, y - 7), (x1, y + h * 0.16 - 4), (x0, y + h * 0.16)], fill=(14, 12, 18, 255), outline=(60, 58, 70, 255))
    out = Image.new('RGBA', (im.width + 2 * round(w * 0.12) + 4, im.height), (0, 0, 0, 0))
    pad = round(w * 0.12) + 2
    out.alpha_composite(im, (pad, 0))
    layer2 = Image.new('RGBA', out.size, (0, 0, 0, 0))
    layer2.alpha_composite(layer, (pad, 0))
    out.alpha_composite(layer2)
    return out


def main():
    picks = {k: v for k, v in json.load(open(os.path.join(REPO, 'art', 'picks.json'))).get('errors', {}).items() if not k.startswith('_')}
    out_dir = os.path.join(WORK, 'errors')
    os.makedirs(out_dir, exist_ok=True)
    feet = {}
    for name, pick in picks.items():
        im, kind = piece(pick)
        im = im.crop(im.getbbox())
        b = solid_box(im)
        s = HEIGHT[kind] / max(1, b[3] - b[1])
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        if name == 'censor':
            im = redaction_bar(im)
        b = solid_box(im)
        pad = 3
        canvas = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
        canvas.alpha_composite(im, (pad, pad))
        q = canvas.convert('RGB').quantize(colors=254, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
        qa = np.asarray(q).copy()
        qa[..., 3] = np.asarray(canvas.getchannel('A'))
        Image.fromarray(qa, 'RGBA').save(os.path.join(out_dir, name + '.png'))
        feet[name] = [pad + round((b[0] + b[2]) / 2), pad + b[3]]
    json.dump(feet, open(os.path.join(out_dir, 'errors.json'), 'w'), indent=1)
    print('errors', ', '.join(picks))


main()
