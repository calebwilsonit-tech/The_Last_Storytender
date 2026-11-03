"""Builds the Storytender's in-game frames from the chosen generated pictures (art/picks.json): each direction is cut out of
its parchment, scaled to the size the game draws him at, and animated as a paper puppet (the walk moves the feet and bobs the
body; nothing is redrawn, so he looks the same in every frame). The left-facing directions are mirrors of the right-facing
ones. Writes <work>/art/pose_storytender_<FACING>_<step>.png and poses.json (the porter makes the sprite from them).
    python3 -I tools/art/sd_hero.py <repo> <work>"""
import json, os, sys
import numpy as np
from PIL import Image, ImageOps

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(REPO, 'tools', 'art'))
from cutout import cut  # noqa: E402

FRAME, FEET = (160, 150), (80, 128)
# screen direction of each pick -> engine facing; the mirrors give the other three
MIRRORS = {'E': 'S', 'NE': 'SW', 'N': 'W'}
# the walk: (lift of the left foot, lift of the right foot, stride of the left foot, stride of the right, bob of the whole figure)
FRONT_WALK = [(0, 3, 0, 0, 0), (0, 0, 0, 0, 1), (3, 0, 0, 0, 0), (0, 0, 0, 0, 1)]
SIDE_WALK = [(0, 2, -2, 2, 0), (0, 0, 0, 0, 1), (2, 0, 2, -2, 0), (0, 0, 0, 0, 1)]


def solid_box(im, level=200):
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def target_height():
    ref = os.path.join(WORK, 'art', 'pose_storytender_SE_0.png')
    if os.path.exists(ref):
        b = solid_box(Image.open(ref).convert('RGBA'))
        if b:
            return b[3] - b[1]
    return 64


def standing(path, height):
    """The figure, cut out and scaled so its solid part is `height` px tall, on a frame with its feet at FEET."""
    im = cut(path)
    b = solid_box(im)
    im = im.crop(im.getbbox())
    b = solid_box(im)
    scale = height / max(1, b[3] - b[1])
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    b = solid_box(im)
    frame = Image.new('RGBA', FRAME, (0, 0, 0, 0))
    frame.alpha_composite(im, (round(FEET[0] - (b[0] + b[2]) / 2), FEET[1] - b[3]))
    return frame


def walk_frame(stand, step, side):
    """The standing frame with the feet moved: the legs below the knee line are split into a left and a right half."""
    b = solid_box(stand)
    knee = b[3] - round((b[3] - b[1]) * 0.17)
    mid = (b[0] + b[2]) // 2
    lift_l, lift_r, stride_l, stride_r, bob = (SIDE_WALK if side else FRONT_WALK)[step - 1]
    body = stand.copy()
    body.paste((0, 0, 0, 0), (0, knee, FRAME[0], FRAME[1]))
    left = Image.new('RGBA', FRAME, (0, 0, 0, 0))
    right = Image.new('RGBA', FRAME, (0, 0, 0, 0))
    left.alpha_composite(stand.crop((0, knee, mid, FRAME[1])), (0, knee))
    right.alpha_composite(stand.crop((mid, knee, FRAME[0], FRAME[1])), (mid, knee))
    out = Image.new('RGBA', FRAME, (0, 0, 0, 0))
    # legs first (shifted), then the body over them so a lifted foot tucks under the coat
    out.alpha_composite(left, (stride_l, -lift_l))
    out.alpha_composite(right, (stride_r, -lift_r))
    # the knee line itself stays put, so a lifted leg does not leave a gap
    out.alpha_composite(stand.crop((0, knee - 2, FRAME[0], knee + 1)), (0, knee - 2))
    out.alpha_composite(body)
    if bob:
        shifted = Image.new('RGBA', FRAME, (0, 0, 0, 0))
        shifted.alpha_composite(out, (0, -bob))
        out = shifted
    return out


# ---- the quill strike: the quill cut from the side-view strike picture, swung from the hand in three frames
QUILL_BOX = (652, 385, 762, 598)      # the feather and the top of the handle, above the glove, in the 1024 px picture
QUILL_GRIP = (668 - 652, 598 - 385)   # where the hand holds it, in the box
# each source direction: the angle the Storytender faces on the screen (degrees, 0 = right, 90 = down)
SCREEN_ANGLE = {'SE': 90, 'E': 27, 'NE': 0, 'N': -27, 'NW': -90}
STRIKE = [(-130, False), (-35, True), (35, False)]   # wind-up, the swing (with its swoosh), follow-through, from the facing


def quill_sprite(path, scale):
    im = cut(path).crop(QUILL_BOX)
    w, h = im.size
    # a short handle below the grip, drawn in the handle's brown
    from PIL import ImageDraw
    canvas = Image.new('RGBA', (w, h + 40), (0, 0, 0, 0))
    canvas.alpha_composite(im, (0, 0))
    d = ImageDraw.Draw(canvas)
    gx, gy = QUILL_GRIP
    d.line([(gx + 2, gy - 6), (gx - 6, gy + 34)], fill=(26, 18, 16, 255), width=12)
    d.line([(gx + 2, gy - 6), (gx - 6, gy + 34)], fill=(124, 72, 38, 255), width=7)
    canvas = canvas.resize((max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale))), Image.LANCZOS)
    return canvas, (QUILL_GRIP[0] * scale, QUILL_GRIP[1] * scale)


def place_quill(frame, quill, grip, hand, tip_angle):
    """The quill with its grip at `hand`, its tip pointing at `tip_angle` (screen degrees)."""
    import math
    rot = -(tip_angle - (-75))            # the cut quill points about 75 degrees up and to the right
    w, h = quill.size
    big = Image.new('RGBA', (w * 3, h * 3), (0, 0, 0, 0))
    big.alpha_composite(quill, (w, h))
    pivot = (w + grip[0], h + grip[1])
    r = big.rotate(rot, resample=Image.BICUBIC, center=pivot)
    frame.alpha_composite(r, (round(hand[0] - pivot[0]), round(hand[1] - pivot[1])))


def swoosh(frame, hand, a0, a1, radius):
    """A pale arc where the quill has just swept."""
    from PIL import ImageDraw
    layer = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    box = (hand[0] - radius, hand[1] - radius, hand[0] + radius, hand[1] + radius)
    d.arc(box, start=min(a0, a1), end=max(a0, a1), fill=(236, 250, 255, 210), width=4)
    d.arc(box, start=min(a0, a1) + 15, end=max(a0, a1), fill=(160, 230, 245, 150), width=2)
    frame.alpha_composite(layer)


def strike_frames(stand, facing, quill, grip):
    b = solid_box(stand)
    hgt = b[3] - b[1]
    a = SCREEN_ANGLE[facing]
    import math
    side = 1 if math.cos(math.radians(a)) >= -0.1 else -1
    hand = ((b[0] + b[2]) / 2 + side * hgt * 0.16, b[3] - hgt * 0.42)
    out = []
    for i, (off, sweep) in enumerate(STRIKE):
        f = Image.new('RGBA', FRAME, (0, 0, 0, 0))
        behind = facing in ('NW', 'N') and i == 0
        lean = [0, 2, 1][i]
        body = Image.new('RGBA', FRAME, (0, 0, 0, 0))
        body.alpha_composite(stand, (round(math.cos(math.radians(a)) * lean), round(math.sin(math.radians(a)) * lean * 0.5)))
        q = Image.new('RGBA', FRAME, (0, 0, 0, 0))
        place_quill(q, quill, grip, hand, a + off)
        if sweep:
            swoosh(q, hand, a - 130, a - 35, quill.height * 0.85)
        for layer in ([q, body] if behind else [body, q]):
            f.alpha_composite(layer)
        out.append(f)
    return out


def main():
    picks = json.load(open(os.path.join(REPO, 'art', 'picks.json')))['storytender']
    height = target_height()
    frames = []
    out_dir = os.path.join(WORK, 'art')
    quill = None
    if picks.get('quill'):
        src = os.path.join(REPO, 'art', 'generated', 'storytender', picks['quill'] + '.png')
        q_stand = cut(src)
        qb = solid_box(q_stand)
        # drawn 1.7 times its size in the picture, so it reads at game size
        quill, grip = quill_sprite(src, 1.7 * height / max(1, qb[3] - qb[1]))
    for facing in ['SE', 'E', 'NE', 'N', 'NW']:
        stand = standing(os.path.join(REPO, 'art', 'generated', 'storytender', picks[facing] + '.png'), height)
        side = facing in ('NE',)
        poses = [stand] + [walk_frame(stand, k, side) for k in range(1, 5)]
        if quill is not None:
            poses += strike_frames(stand, facing, quill, grip)
        for facing_out, mirror in [(facing, False)] + ([(MIRRORS[facing], True)] if facing in MIRRORS else []):
            for step, im in enumerate(poses):
                im = ImageOps.mirror(im) if mirror else im
                if mirror:  # keep the feet at FEET after the mirror
                    shifted = Image.new('RGBA', FRAME, (0, 0, 0, 0))
                    shifted.alpha_composite(im, (FRAME[0] - 2 * FEET[0], 0))
                    im = shifted
                name = f'pose_storytender_{facing_out}_{step}.png'
                im.save(os.path.join(out_dir, name))
                pose = 'idle' if step == 0 else 'walk' if step <= 4 else 'strike'
                frames.append({'figure': 'storytender', 'facing': facing_out, 'pose': pose, 'step': step, 'file': name})
    # one palette for every frame (the engine's sprite has one palette of 255 colours)
    fw, fh = FRAME
    sheet = Image.new('RGBA', (fw, fh * len(frames)), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(Image.open(os.path.join(out_dir, fr['file'])), (0, i * fh))
    alpha = np.asarray(sheet.getchannel('A'))
    q = sheet.convert('RGB').quantize(colors=254, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
    qa = np.asarray(q).copy()
    qa[..., 3] = alpha
    q = Image.fromarray(qa, 'RGBA')
    for i, fr in enumerate(frames):
        q.crop((0, i * fh, fw, (i + 1) * fh)).save(os.path.join(out_dir, fr['file']))
    json.dump({'frame': list(FRAME), 'feet': list(FEET), 'frames': frames}, open(os.path.join(out_dir, 'poses.json'), 'w'), indent=1)
    print('storytender frames (generated art)', len(frames), 'height', height)


main()
