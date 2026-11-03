"""The Errors from the chosen generated pictures (art/picks.json "errors"). Most of those pictures are sheets of many small
creatures, so a pick names the picture and which figure in it (pieces.py, biggest first). Each is scaled to its size in the
game; the Censor gets the black redaction bar it hides behind (no generated try drew one). The proofread kinds have a friendly
look too. Where art/incoming2 (the Ludo.ai pictures, ludo.py) has the Error (LUDO below), that picture is used instead: it is a
single transparent figure, so it is only cropped to its solid part and scaled to the same height, and the Censor needs no bar
drawn on (the Ludo Censor holds its own). Writes <work>/errors/<name>.png and errors.json (each one's feet).
    python3 -I tools/art/sd_errors.py <repo> <work>"""
import json, os, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(REPO, 'tools', 'art'))
from pieces import pieces  # noqa: E402
import ludo  # noqa: E402

# how tall each stands in the game (px of solid figure; the Storytender is 63)
HEIGHT = {'bare': 56, 'mite': 26, 'runon': 30, 'dangler': 50, 'censor': 60, 'ellipsis': 40, 'cold': 120}


# the Ludo.ai picture of each (folder of art/incoming2, file); a friendly look is scaled like the Error's idle one
LUDO = {
    'bare': ('errors', 'err_bare_idle'), 'bare_friendly': ('errors', 'err_bare_friendly'),
    'mite': ('errors', 'err_mite_idle'),
    'runon': ('errors', 'err_runon_idle'), 'runon_friendly': ('errors', 'err_runon_friendly'),
    'dangler': ('errors', 'err_dangler_idle'), 'dangler_friendly': ('errors', 'err_dangler_friendly'),
    'censor': ('errors', 'err_censor_idle'), 'ellipsis': ('errors', 'err_ellipsis_idle'),
    'bare_attack': ('errors', 'err_bare_attack'), 'mite_attack': ('errors', 'err_mite_attack'), 'runon_attack': ('errors', 'err_runon_attack'),
    'dangler_attack': ('errors', 'err_dangler_attack'), 'censor_attack': ('errors', 'err_censor_attack'), 'ellipsis_attack': ('errors', 'err_ellipsis_attack'),
    'cold_shoulder': ('bosses', 'boss_cold_idle'),
}
# the other pictures of the bosses (their idle ones are scaled by ludo.BOSS_FIT, and the other pictures like them): name, boss, file
BOSS_LOOKS = {
    'critic_attack': ('critic', 'boss_critic_attack'), 'critic_reckoning': ('critic', 'boss_critic_reckoning'),
    'spoiler_read': ('spoiler', 'boss_spoiler_read'), 'spoiler_attack': ('spoiler', 'boss_spoiler_attack'),
    'cold_slam': ('cold', 'boss_cold_slam'),
    'scissor_cut': ('scissor', 'boss_scissor_cut'), 'scissor_jammed': ('scissor', 'boss_scissor_jammed'),
}


def solid_box(im, level=200):
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def piece(pick):
    group = 'errors'
    if pick.startswith('B'):
        group, pick = 'bosses', pick[1:]
    name, k = pick.split(':')
    kind = name.split('_')[0]
    with tempfile.TemporaryDirectory() as tmp:
        files = pieces(os.path.join(REPO, 'art', 'generated', group, name + '.png'), tmp, int(k) + 1)
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
    allp = json.load(open(os.path.join(REPO, 'art', 'picks.json')))
    picks = {k: v for k, v in allp.get('errors', {}).items() if not k.startswith('_')}
    # bosses that live in no snapshot (made mid-fight), from the boss pictures
    picks.update({k: 'B' + v for k, v in allp.get('bosses', {}).items()})
    ludo_names = {n for n, (f, p) in LUDO.items() if ludo.find(f, p)}
    picks.update({n: 'ludo' for n in ludo_names})
    boss_looks = {n for n, (who, f) in BOSS_LOOKS.items() if ludo.find('bosses', f)}
    picks.update({n: 'ludo_boss' for n in boss_looks})
    out_dir = os.path.join(WORK, 'errors')
    os.makedirs(out_dir, exist_ok=True)
    feet = {}
    for name, pick in picks.items():
        if pick == 'ludo_boss':
            im = ludo.trim(ludo.load(ludo.find('bosses', BOSS_LOOKS[name][1])))
            s = ludo.boss_scale(BOSS_LOOKS[name][0])
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        elif pick == 'ludo':
            kind = name.split('_')[0]
            ref = ludo.load(ludo.find(*LUDO[kind])) if name != kind and not name.startswith('cold') else None
            im = ludo.fit_height(ludo.load(ludo.find(*LUDO[name])), HEIGHT[kind], ref)
        else:
            im, kind = piece(pick)
            im = im.crop(im.getbbox())
            b = solid_box(im)
            s = HEIGHT[kind] / max(1, b[3] - b[1])
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        if name == 'censor' and pick != 'ludo':
            im = redaction_bar(im)
        b = solid_box(im)
        pad = 3
        canvas = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
        canvas.alpha_composite(im, (pad, pad))
        if pick.startswith('ludo'):
            ludo.quantize_rgba(canvas).save(os.path.join(out_dir, name + '.png'))
        else:
            q = canvas.convert('RGB').quantize(colors=254, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
            qa = np.asarray(q).copy()
            qa[..., 3] = np.asarray(canvas.getchannel('A'))
            Image.fromarray(qa, 'RGBA').save(os.path.join(out_dir, name + '.png'))
        feet[name] = [pad + round((b[0] + b[2]) / 2), pad + b[3]]
    json.dump(feet, open(os.path.join(out_dir, 'errors.json'), 'w'), indent=1)
    print('errors', ', '.join(picks))


main()
