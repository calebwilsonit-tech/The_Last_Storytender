"""Puts the Ludo.ai animations (art/incoming2/anim, made by ludo_animate.py from the still pictures) into the Tilewright project the porter has made
(<repo>/tilewright), as a step of tools/port/run_porter.sh after ludo_retile.py. It needs no Godot.

  - Each animation replaces the still sprite it was made from, under the same name, so every script that swaps pictures (an Error's attack or friendly
    look, a boss's attack, a villager's ghost turning to colour) keeps working: a swapped-in sprite that has frames just plays them. The frames are
    scaled so the figure is as tall as the still one was (the first frame of an animation is the still pose) and stand on the same feet point; the
    sprite gets one looping clip, "idle" (the engine's animator plays the clip of that name).
  - The villagers' graphite ghosts are the same animation put through the same graphite filter (sd_people.py ghost()).
  - Every entity that shows one of these gets an `animator` component with `follow`, which plays whatever sprite its Sprite names (engine: Animator.follow).

    python3 -I tools/art/ludo_reanimate.py <repo>        (the project is <repo>/tilewright)
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
PROJECT = os.path.join(REPO, 'tilewright')
SPRITES = os.path.join(PROJECT, 'assets', 'sprites')
ANIM = os.path.join(REPO, 'art', 'incoming2', 'anim')
PAD = 10
STATIC_GRAY = np.array([0x9c, 0x9c, 0xa8], np.float32)

# animation -> the sprite it replaces ('script_X': the sprite of the first entity that has that script; 'name:X': the entity called X)
ERRORS = ['bare', 'censor', 'dangler', 'ellipsis', 'mite', 'runon']
TARGETS = {f'err_{k}_idle': f'err_{k}' for k in ERRORS}
TARGETS.update({f'err_{k}_attack': f'err_{k}_attack' for k in ERRORS})
TARGETS.update({'boss_cold_idle': 'boss_cold_shoulder', 'boss_cold_attack': 'boss_cold_slam', 'boss_critic_idle': 'script_Critic', 'boss_critic_attack': 'boss_critic_attack',
                'boss_spoiler_idle': 'script_Spoiler', 'boss_spoiler_attack': 'boss_spoiler_attack', 'boss_scissor_idle': 'name:Scissor', 'guest_standing_idle': 'obj_guest_standing'})
VILLAGERS = {'garrick_SE_idle': ('npc_garrick', 'npc_garrick_ghost'), 'pip_SE_idle': ('npc_pip', 'npc_pip_ghost'), 'maud_SE_idle': ('npc_maud', 'npc_maud_ghost')}


def ghost(a):
    """The graphite look of a colour picture (sd_people.py ghost())."""
    a = a.astype(np.float32)
    lum = (a[..., :3] * np.array([0.2126, 0.7152, 0.0722])).sum(axis=2, keepdims=True)
    grey = np.repeat(lum, 3, axis=2)
    grey = grey + (255 - grey) * 0.25
    grey = grey * 0.65 + STATIC_GRAY * 0.35
    out = a.copy()
    out[..., :3] = grey
    out[..., 3] = a[..., 3] * 0.85
    return out.clip(0, 255).astype(np.uint8)


def solid_box(a, level=200):
    ys, xs = np.nonzero(a[..., 3] >= level)
    return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1) if len(xs) else (0, 0, a.shape[1], a.shape[0])


def frames_of(name):
    fs = sorted(glob.glob(os.path.join(ANIM, name + '_f*.png')), key=lambda p: int(p.rsplit('_f', 1)[1][:-4]))
    meta = json.load(open(os.path.join(ANIM, name + '.json')))
    return [np.asarray(Image.open(f).convert('RGBA')) for f in fs], meta['job']['duration']


def quantize(frames, colors=250):
    """The frames in one shared palette with hard edges (the engine keeps a sprite to 255 colours)."""
    w, h = frames[0].shape[1], frames[0].shape[0]
    sheet = Image.new('RGB', (w * len(frames), h))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f[..., :3]), (w * i, 0))
    q = sheet.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    out = []
    for i, f in enumerate(frames):
        alpha = np.where(f[..., 3] >= 96, 255, 0).astype(np.uint8)
        rgb = np.asarray(q.crop((w * i, 0, w * i + w, h))).copy()
        rgb[alpha == 0] = 0
        out.append(np.dstack([rgb, alpha]))
    return out


def measure(name):
    """How tall the still sprite's figure is, and where its feet are relative to the bottom centre of the figure (measured before it is replaced)."""
    static, d = sprite_io.read_sprite(SPRITES, name)
    x0, y0, x1, y1 = solid_box(static)
    return y1 - y0, (d['origin']['x'] - (x0 + x1) / 2, d['origin']['y'] - y1)


def animate(anim, target, like, make_ghost=False):
    """The animation `anim` as the sprite `target`, replacing it. `like` is what measure() said of the still picture it is made from: the figure is scaled to
    that height (the first frame of an animation is the still pose) and stands on the same feet point."""
    frames, seconds = frames_of(anim)
    height, off = like
    rx0, ry0, rx1, ry1 = solid_box(frames[0])
    factor = height / (ry1 - ry0)
    fx0, fy0, fx1, fy1 = solid_box(frames[0])
    anchor = ((fx0 + fx1) / 2, fy1)                                          # the first frame's bottom centre, in the animation's own pixels
    scaled = []
    for f in frames:
        im = Image.fromarray(f).resize((max(1, round(f.shape[1] * factor)), max(1, round(f.shape[0] * factor))), Image.LANCZOS)
        scaled.append(np.asarray(im))
    # the canvas holds every frame, with the anchor where it was
    ax, ay = anchor[0] * factor, anchor[1] * factor
    boxes = []
    for a in scaled:
        ys, xs = np.nonzero(a[..., 3] > 0)
        boxes.append((xs.min() - ax, ys.min() - ay, xs.max() + 1 - ax, ys.max() + 1 - ay))
    x0, y0 = int(np.floor(min(b[0] for b in boxes))) - PAD, int(np.floor(min(b[1] for b in boxes))) - PAD
    x1, y1 = int(np.ceil(max(b[2] for b in boxes))) + PAD, int(np.ceil(max(b[3] for b in boxes))) + PAD
    w, h = x1 - x0, y1 - y0
    canvas = []
    for a in scaled:
        c = np.zeros((h, w, 4), np.uint8)
        ox, oy = round(-ax - x0), round(-ay - y0)
        ys, xs = a.shape[0], a.shape[1]
        c[max(0, oy):min(h, oy + ys), max(0, ox):min(w, ox + xs)] = a[max(0, -oy):min(ys, h - oy), max(0, -ox):min(xs, w - ox)]
        canvas.append(ghost(c) if make_ghost else c)
    canvas = quantize(canvas)
    origin = (round(-x0 + off[0]), round(-y0 + off[1]))
    ms = max(10, round(seconds * 1000 / len(canvas)))
    clips = [{'name': 'idle', 'loop': True, 'mirror': False, 'all': list(range(len(canvas))), 'dirs': {}, 'events': []}]
    sprite_io.write_sheet(SPRITES, target, canvas, origin, [ms] * len(canvas), clips)


def main():
    scenes = sorted(glob.glob(os.path.join(PROJECT, 'scenes', '*.scene.json')))
    data = {p: json.load(open(p, encoding='utf8')) for p in scenes}
    if any('follow' in (e['components'].get('animator') or {}) for s in data.values() for e in s['entities']):
        print('reanimate: already done')
        return
    # the sprites named by a script or an entity's name
    by_script, by_name = {}, {}
    for s in data.values():
        for e in s['entities']:
            asset = (e['components'].get('sprite') or {}).get('asset')
            for k in e['components']:
                if k.startswith('script_') and asset:
                    by_script.setdefault(k, asset)
            if asset:
                by_name.setdefault(e['name'].split(' @')[0], asset)

    def resolve(t):
        if t.startswith('script_'):
            return by_script.get(t)
        if t.startswith('name:'):
            return next((a for n, a in by_name.items() if n.startswith(t[5:])), None)
        return t

    def have(anim):
        return os.path.exists(os.path.join(ANIM, anim + '.json'))

    jobs = []   # (animation, the sprite it replaces, the still sprite whose size it takes, ghost?)
    for anim, target in TARGETS.items():
        name = resolve(target)
        if not have(anim) or not name or not os.path.exists(os.path.join(SPRITES, name + '.sprite.json')):
            print('skipped', anim, target)
            continue
        idle = resolve(TARGETS.get(anim.replace('_attack', '_idle'), target)) if anim.endswith('_attack') else name
        jobs.append((anim, name, idle if idle and os.path.exists(os.path.join(SPRITES, idle + '.sprite.json')) else name, False))
    for anim, (colour, ghosted) in VILLAGERS.items():
        if have(anim):
            jobs += [(anim, colour, colour, False), (anim, ghosted, colour, True)]
    like = {j[2]: measure(j[2]) for j in jobs}       # (before any of them is replaced)
    animated = set()
    for anim, name, size_of, as_ghost in jobs:
        animate(anim, name, like[size_of], as_ghost)
        animated.add(name)
    n = 0
    for p, s in data.items():
        for e in s['entities']:
            asset = (e['components'].get('sprite') or {}).get('asset')
            if asset in animated:
                e['components']['animator'] = {'asset': asset, 'clip': 'idle', 'time': 0, 'speed': 1, 'playing': True, 'frame': 0, 'flip': False, 'pos': 0, 'done': False,
                                               'controller': None, 'state': '', 'params': {}, 'follow': True}
                n += 1
        with open(p, 'w', encoding='utf8', newline='\n') as f:
            json.dump(s, f, separators=(',', ':'), ensure_ascii=False)
            f.write('\n')
    print(f'reanimate: {len(animated)} sprites animated, {n} entities')


if __name__ == '__main__':
    main()
