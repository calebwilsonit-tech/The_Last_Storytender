"""The Storytender from the Ludo.ai pictures and animations, in the Tilewright project the porter has made (<repo>/tilewright), as a step of
tools/port/run_porter.sh after ludo_reanimate.py. It needs no Godot.

The porter's Storytender is five three-quarter pictures (the corners) and their mirrors, moved about like a paper puppet. This replaces the sprite
`storytender` with eight true views, front, back, both sides and the four corners, each with its own animation made by Ludo.ai (ludo_animate.py,
art/ludo_manifests/hero_animations.json): a still view for idle, a walk loop, and a strike, the quill's slash.

A view is named by the camera angle it was made at (art/incoming2/characters/hero_views/hero_<angle>.png: 000 faces the viewer, 090 faces the screen's
right, 180 faces away, m090 faces the left, 045 and m045 the front corners, 135 and m135 the back ones). The engine names a facing by its direction on the
screen (E is the screen's right, S is down it, so W moves the Storytender up the screen and its facing is N: the front view is S, and so on round, VIEW
below). (The porter's five corner pictures were named as if the names were the grid's, which is why he always faced a corner.) The porter's animator and its controller (idle, walk, strike) are left as they are: only the
sprite's frames and clips change, in the same 160 x 150 frame with the feet at (80, 128), the figure 63 px tall.

    python3 -I tools/art/ludo_hero.py <repo>        (the project is <repo>/tilewright)
Pillow and numpy. Running it again on a project it has already changed does nothing."""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_io  # noqa: E402

REPO = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '.')
SPRITES = os.path.join(REPO, 'tilewright', 'assets', 'sprites')
ANIM = os.path.join(REPO, 'art', 'incoming2', 'anim')
VIEWS = os.path.join(REPO, 'art', 'incoming2', 'characters', 'hero_views')
FRAME, FEET, HEIGHT = (160, 150), (80, 128), 63
# camera angle of the view -> the engine's facing
VIEW = {'000': 'S', '045': 'SE', '090': 'E', '135': 'NE', '180': 'N', 'm135': 'NW', 'm090': 'W', 'm045': 'SW'}
MS = {'idle': 120, 'walk': 90, 'strike': 65}   # a frame's time on screen
STRIKE_FRAMES = 8                                # at most this many frames of the slash


def solid_box(a, level=200):
    ys, xs = np.nonzero(a[..., 3] >= level)
    return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1) if len(xs) else (0, 0, a.shape[1], a.shape[0])


def place(frames, ref):
    """The frames (RGBA arrays of one size, the first like the still view `ref`) scaled so the figure is HEIGHT tall, standing on FEET, in the project's frame."""
    x0, y0, x1, y1 = solid_box(frames[0])
    factor = HEIGHT / (y1 - y0)
    ax, ay = (x0 + x1) / 2 * factor, y1 * factor
    out = []
    for f in frames:
        im = Image.fromarray(f).resize((max(1, round(f.shape[1] * factor)), max(1, round(f.shape[0] * factor))), Image.LANCZOS)
        canvas = Image.new('RGBA', FRAME, (0, 0, 0, 0))
        canvas.paste(im, (round(FEET[0] - ax), round(FEET[1] - ay)), im)
        out.append(np.asarray(canvas))
    return out


def frames_of(name):
    fs = sorted(glob.glob(os.path.join(ANIM, name + '_f*.png')), key=lambda p: int(p.rsplit('_f', 1)[1][:-4]))
    return [np.asarray(Image.open(f).convert('RGBA')) for f in fs]


def slash(frames):
    """The part of a strike that moves: from the first frame that differs from the start to the last, at most STRIKE_FRAMES of them."""
    a0 = frames[0].astype(np.float32)
    diff = np.array([np.abs(f.astype(np.float32) - a0).mean() for f in frames])
    moving = np.nonzero(diff > 0.25 * diff.max())[0]
    lo, hi = max(0, moving.min() - 1), moving.max()
    idx = np.unique(np.linspace(lo, hi, min(STRIKE_FRAMES, hi - lo + 1)).round().astype(int))
    return [frames[i] for i in idx]


def quantize(frames, colors=250):
    """The frames in one shared palette with hard edges (the engine keeps a sprite to 255 colours)."""
    w, h = FRAME
    sheet = Image.new('RGB', (w, h * len(frames)))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f[..., :3]), (0, h * i))
    q = sheet.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    out = []
    for i, f in enumerate(frames):
        alpha = np.where(f[..., 3] >= 96, 255, 0).astype(np.uint8)
        rgb = np.asarray(q.crop((0, h * i, w, h * (i + 1)))).copy()
        rgb[alpha == 0] = 0
        out.append(np.dstack([rgb, alpha]))
    return out


def main():
    path = os.path.join(SPRITES, 'storytender.sprite.json')
    old = json.load(open(path, encoding='utf8'))
    walk_se = next((c['dirs'].get('SE', []) for c in old['clips'] if c['name'] == 'walk'), [])
    if len(walk_se) != 4:   # (the porter's walk has four frames a facing)
        print('hero: already done')
        return
    frames, clips = [], {'idle': {}, 'walk': {}, 'strike': {}}
    durations = []
    for view, facing in VIEW.items():
        still = os.path.join(VIEWS, f'hero_{view}.png')
        if not os.path.exists(still):
            print('hero: no picture for', view)
            return
        ref = np.asarray(Image.open(still).convert('RGBA'))
        sets = {'idle': place([ref], ref)}
        for kind in ('walk', 'strike'):
            fr = frames_of(f'hero_{view}_{kind}')
            if not fr:
                print('hero: no', kind, 'animation for', view, '(the still view stands in)')
                sets[kind] = sets['idle']
            else:
                sets[kind] = place(slash(fr) if kind == 'strike' else fr, ref)
        for kind, fs in sets.items():
            clips[kind][facing] = list(range(len(frames), len(frames) + len(fs)))
            frames += fs
            durations += [MS[kind]] * len(fs)
    frames = quantize(frames)
    sprite_clips = [{'name': k, 'loop': k != 'strike', 'mirror': False, 'all': clips[k]['S'], 'dirs': clips[k], 'events': []} for k in ('idle', 'walk', 'strike')]
    sprite_io.write_sheet(SPRITES, 'storytender', frames, FEET, durations, sprite_clips)
    print(f'hero: {len(frames)} frames, {sum(len(v) for v in clips["walk"].values())} of them walking, {sum(len(v) for v in clips["strike"].values())} striking')


if __name__ == '__main__':
    main()
