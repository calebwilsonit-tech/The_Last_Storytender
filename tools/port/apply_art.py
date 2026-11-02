"""Port tool: puts the owner's drawn art (art/incoming, cut by cut_sheet.py) in place of the pictures captured from the
Godot game, before the porter builds the Tilewright project. Every new drawing is scaled so it stands as tall as the
picture it replaces, so nothing changes size in the world.

Usage: python3 apply_art.py <work_dir>
Reads  <work>/cut/{props,icons,hero}, <work>/art_q (captured pictures + index.json), <work>/icons, <work>/art (poses).
Writes the replacements over those files and updates the indexes."""
import glob, json, os, re, sys
from PIL import Image, ImageOps

WORK = sys.argv[1]
CUT = os.path.join(WORK, 'cut')


def opaque_box(im, level=128):
    a = im.getchannel('A').point(lambda v: 255 if v >= level else 0)
    return a.getbbox()


def fit(new_path, ref_path):
    """The new drawing, scaled to the opaque height of the picture it replaces; returns it and where its feet are."""
    new = Image.open(new_path).convert('RGBA')
    ref = Image.open(ref_path).convert('RGBA')
    nb, rb = opaque_box(new), opaque_box(ref)
    if not nb or not rb:
        return None, None
    scale = (rb[3] - rb[1]) / max(1, nb[3] - nb[1])
    new = new.resize((max(1, round(new.width * scale)), max(1, round(new.height * scale))), Image.LANCZOS)
    nb = opaque_box(new)
    return new, [round((nb[0] + nb[2]) / 2), nb[3]]


def piece(kind, n):
    return os.path.join(CUT, kind, f'{kind[:-1] if kind != "hero" else "hero"}_{n:03d}.png')


# ---- world props (world_props_sheet.jpg, the 10 x 4 grid laid out like the contact sheet of the game's objects)
TREES = [1, 35, 36, 37, 39]
SIGNS_TEXT = {13: 'OUT', 18: 'LOCKED', 21: 'BROKEN', 24: 'STRAIGHT', 25: 'WIDE', 26: 'STEEP', 27: 'STORMY',
              28: 'FIERCE', 29: 'WARM', 30: 'EMPTY', 31: 'GUILTY', 32: 'AWAKE'}


def prop_piece(entry):
    """Which drawing replaces this captured object, or None to keep the game's own picture."""
    cls, key = entry['cls'], entry['key']
    kind = re.search(r'\|kind=(\d+)', key)
    k = int(kind.group(1)) if kind else -1
    if cls == 'Prop':
        if k == 0:
            slot = int(re.search(r'_(\d+)\.png$', entry['file']).group(1)) if entry['file'] else 0
            return TREES[slot % len(TREES)]
        return {4: 0, 3: 2, 18: 3, 16: 4, 10: 5, 1: 7, 17: 10, 2: 14, 14: 15, 8: 33}.get(k)
    if cls == 'Redactor':
        return 6
    if cls == 'StoryGate':
        return 11
    if cls == 'Dummy':
        return 17
    if cls == 'EchoPlate':
        return 20
    if cls == 'Enemy' and k == 0:
        return 34   # the Bare
    if cls == 'Npc' and k == 0:
        return 12   # Garrick as a placeholder ghost
    if cls == 'SentenceStone':
        # a sign whose drawn sentence is exactly the stone's starting sentence (the others keep the game's picture
        # until the words can be drawn on the board for every choice)
        opts = re.search(r'options=\["([A-Z ]+)"', key)
        for n, word in SIGNS_TEXT.items():
            if opts and opts.group(1) == word:
                return n
    return None


def apply_props():
    idx_path = os.path.join(WORK, 'art_q', 'index.json')
    index = json.load(open(idx_path))
    done, count = {}, 0
    for e in index:
        if not e.get('file'):
            continue
        n = prop_piece(e)
        if n is None or not os.path.exists(piece('props', n)):
            continue
        f = os.path.join(WORK, 'art_q', e['file'])
        if e['file'] not in done:
            ref = os.path.join(WORK, 'art', e['file'])   # the original capture (art_q may already hold a replacement)
            new, feet = fit(piece('props', n), ref if os.path.exists(ref) else f)
            if new is None:
                continue
            new.save(f)
            done[e['file']] = (feet, [new.width, new.height])
            count += 1
        e['feet'], e['size'] = done[e['file']]
    json.dump(index, open(idx_path, 'w'), indent=1)
    print('props replaced', count)


# ---- item icons (item_icons_sheet.jpg, 12 x 6, in the order of the game's icon files sorted by name)
def apply_icons():
    files = sorted(glob.glob(os.path.join(WORK, 'icons', 'icon_*.png')))
    count = 0
    for i, f in enumerate(files):
        p = piece('icons', i)
        if not os.path.exists(p):
            continue
        new = Image.open(p).convert('RGBA')
        new.thumbnail((84, 84), Image.LANCZOS)
        canvas = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
        canvas.alpha_composite(new, ((96 - new.width) // 2, (96 - new.height) // 2))
        canvas.save(f)
        count += 1
    print('icons replaced', count)


# ---- the Storytender (storytender_sheet.jpg): rows of five, cut by their gaps
# band -> (engine facing, mirrored). The sheet's rows are front, front, back (large), back, (two rows run together:
# not used), back, front-left, front.
BANDS = {0: [('E', False)], 1: [('NE', False), ('SW', True)], 2: [('NW', False)], 3: [('N', False)],
         5: [('W', False)], 6: [('S', False)], 7: [('SE', False)]}


def apply_hero():
    pose_path = os.path.join(WORK, 'art', 'poses.json')
    if not os.path.exists(pose_path):
        return
    poses = json.load(open(pose_path))
    fw, fh = poses['frame']
    fx, fy = poses['feet']
    ref = Image.open(os.path.join(WORK, 'art', 'pose_storytender_SE_0.png')).convert('RGBA')
    rb = opaque_box(ref, 200)
    target = (rb[3] - rb[1]) if rb else 60
    frames = []
    for band, dirs in BANDS.items():
        for step in range(5):
            p = piece('hero', band * 5 + step)
            if not os.path.exists(p):
                continue
            src = Image.open(p).convert('RGBA')
            nb = opaque_box(src, 200)
            scale = target / max(1, nb[3] - nb[1])
            src = src.resize((max(1, round(src.width * scale)), max(1, round(src.height * scale))), Image.LANCZOS)
            nb = opaque_box(src, 200)
            for facing, mirror in dirs:
                im = ImageOps.mirror(src) if mirror else src
                b = opaque_box(im, 200)
                canvas = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
                canvas.alpha_composite(im, (round(fx - (b[0] + b[2]) / 2), fy - b[3]))
                name = f'pose_storytender_{facing}_{step}.png'
                canvas.save(os.path.join(WORK, 'art', name))
                frames.append({'figure': 'storytender', 'facing': facing, 'pose': 'idle' if step == 0 else 'walk', 'step': step, 'file': name})
    if frames:
        # one palette for every frame (the engine's sprite has one palette of 255 colours for all its frames)
        sheet = Image.new('RGBA', (fw, fh * len(frames)), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(Image.open(os.path.join(WORK, 'art', fr['file'])), (0, i * fh))
        q = sheet.quantize(colors=255, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert('RGBA')
        for i, fr in enumerate(frames):
            q.crop((0, i * fh, fw, (i + 1) * fh)).save(os.path.join(WORK, 'art', fr['file']))
        poses['frames'] = frames
        json.dump(poses, open(pose_path, 'w'), indent=1)
    print('storytender frames', len(frames))


apply_props()
apply_icons()
apply_hero()
