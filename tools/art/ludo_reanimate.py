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
TARGETS['post_lit_flame'] = 'obj_post_lit'   # the lit lantern post's flame
TARGETS['boss_scissor_attack'] = 'boss_scissor_cut'
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


# the other views of a creature (ludo_directions.py): camera angle -> (the engine's facing, mirrored?). S, the front, is the picture the sprite was made from.
VIEWS = {'SE': ('045', False), 'E': ('090', False), 'NE': ('135', False), 'N': ('180', False), 'SW': ('045', True), 'W': ('090', True), 'NW': ('135', True)}


def have_anim(anim):
    return os.path.exists(os.path.join(ANIM, anim + '.json'))


def views_of(anim):
    """The animation `anim` ('err_bare_idle') seen from the other directions ('err_bare_045_idle' ...): {facing: frames}; the left-hand views are the
    right-hand ones turned round."""
    stem, kind = anim.rsplit('_', 1)
    out = {}
    for facing, (view, flip) in VIEWS.items():
        name = f'{stem}_{view}_{kind}'
        if have_anim(name):
            fs, _ = frames_of(name)
            out[facing] = [np.ascontiguousarray(f[:, ::-1]) for f in fs] if flip else fs
    return out


def villager_views(who):
    """A villager's idle from every direction: the four views made earlier (S, SE, NE, N), the side view (090), and their mirror images."""
    have = {f: f'{who}_{f}_idle' for f in ('S', 'SE', 'NE', 'N')}
    have['E'] = f'{who}_090_idle'
    out = {}
    for facing, name in have.items():
        if have_anim(name):
            out[facing] = frames_of(name)[0]
    if 'E' not in out and 'SE' in out:
        out['E'] = out['SE']          # (no side view was made: the front corner stands in for it)
    for facing, src in (('SW', 'SE'), ('NW', 'NE'), ('W', 'E')):
        if src in out:
            out[facing] = [np.ascontiguousarray(f[:, ::-1]) for f in out[src]]
    return out


def animate(anim, target, like, make_ghost=False, views=None):
    """The animation `anim` as the sprite `target`, replacing it. `like` is what measure() said of the still picture it is made from: the figure is scaled to
    that height (the first frame of an animation is the still pose) and stands on the same feet point. `views` are the same animation seen from other
    directions ({facing: frames}, the front being `anim` itself unless it has an "S" of its own): they become the directions of the "idle" clip, so the
    sprite shows the way its entity faces."""
    base, seconds = frames_of(anim)
    sets = {'S': base, **(views or {})}
    height, off = like
    # one scale for the front (as before); the other views are scaled the same way, each to the front's height, a little less than that for the ones that
    # are much flatter or taller from the side (a book seen edge on)
    bx0, by0, bx1, by1 = solid_box(sets['S'][0])
    factor = height / (by1 - by0)
    scaled, tags = [], []
    for facing, fs in sets.items():
        x0, y0, x1, y1 = solid_box(fs[0])
        k = min(max(height / (y1 - y0), 0.8 * factor), 1.25 * factor) if facing != 'S' else factor
        ax, ay = (x0 + x1) / 2 * k, y1 * k                                  # this view's first frame's bottom centre, in scaled pixels
        for f in fs:
            im = Image.fromarray(f).resize((max(1, round(f.shape[1] * k)), max(1, round(f.shape[0] * k))), Image.LANCZOS)
            scaled.append((np.asarray(im), ax, ay))
            tags.append(facing)
    boxes = []
    for a, ax, ay in scaled:
        ys, xs = np.nonzero(a[..., 3] > 0)
        boxes.append((xs.min() - ax, ys.min() - ay, xs.max() + 1 - ax, ys.max() + 1 - ay))
    x0, y0 = int(np.floor(min(b[0] for b in boxes))) - PAD, int(np.floor(min(b[1] for b in boxes))) - PAD
    x1, y1 = int(np.ceil(max(b[2] for b in boxes))) + PAD, int(np.ceil(max(b[3] for b in boxes))) + PAD
    w, h = x1 - x0, y1 - y0
    canvas = []
    for a, ax, ay in scaled:
        c = np.zeros((h, w, 4), np.uint8)
        ox, oy = round(-ax - x0), round(-ay - y0)
        ys, xs = a.shape[0], a.shape[1]
        c[max(0, oy):min(h, oy + ys), max(0, ox):min(w, ox + xs)] = a[max(0, -oy):min(ys, h - oy), max(0, -ox):min(xs, w - ox)]
        canvas.append(ghost(c) if make_ghost else c)
    canvas = quantize(canvas)
    origin = (round(-x0 + off[0]), round(-y0 + off[1]))
    ms = max(10, round(seconds * 1000 / len(sets['S'])))
    dirs = {f: [i for i, t in enumerate(tags) if t == f] for f in sets}
    clips = [{'name': 'idle', 'loop': True, 'mirror': False, 'all': dirs['S'], 'dirs': dirs if len(dirs) > 1 else {}, 'events': []}]
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

    jobs = []   # (animation, the sprite it replaces, the still sprite whose size it takes, ghost?, its views from other directions)
    for anim, target in TARGETS.items():
        name = resolve(target)
        if not have(anim) or not name or not os.path.exists(os.path.join(SPRITES, name + '.sprite.json')):
            print('skipped', anim, target)
            continue
        idle = resolve(TARGETS.get(anim.replace('_attack', '_idle'), target)) if anim.endswith('_attack') else name
        jobs.append((anim, name, idle if idle and os.path.exists(os.path.join(SPRITES, idle + '.sprite.json')) else name, False, views_of(anim)))
    for anim, (colour, ghosted) in VILLAGERS.items():
        who = anim.split('_')[0]
        if have(anim):
            vv = villager_views(who)
            jobs += [(anim, colour, colour, False, vv), (anim, ghosted, colour, True, vv)]
    like = {j[2]: measure(j[2]) for j in jobs}       # (before any of them is replaced)
    animated = set()
    for anim, name, size_of, as_ghost, views in jobs:
        animate(anim, name, like[size_of], as_ghost, views)
        animated.add(name)
    n = 0
    for p, s in data.items():
        for e in s['entities']:
            asset = (e['components'].get('sprite') or {}).get('asset')
            # (also what changes into one: an unlit lantern post that will be lit has to be ready to play the flame)
            becomes = (e['components'].get('script_Flagged') or {}).get('look')
            if asset in animated or becomes in animated:
                e['components']['animator'] = {'asset': asset, 'clip': 'idle', 'time': 0, 'speed': 1, 'playing': True, 'frame': 0, 'flip': False, 'pos': 0, 'done': False,
                                               'controller': None, 'state': '', 'params': {}, 'follow': True}
                n += 1
        with open(p, 'w', encoding='utf8', newline='\n') as f:
            json.dump(s, f, separators=(',', ':'), ensure_ascii=False)
            f.write('\n')
    print(f'reanimate: {len(animated)} sprites animated, {n} entities')


if __name__ == '__main__':
    main()
