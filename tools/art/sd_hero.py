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


def main():
    picks = json.load(open(os.path.join(REPO, 'art', 'picks.json')))['storytender']
    height = target_height()
    frames = []
    out_dir = os.path.join(WORK, 'art')
    for facing in ['SE', 'E', 'NE', 'N', 'NW']:
        stand = standing(os.path.join(REPO, 'art', 'generated', 'storytender', picks[facing] + '.png'), height)
        side = facing in ('NE',)
        poses = [stand] + [walk_frame(stand, k, side) for k in range(1, 5)]
        for facing_out, mirror in [(facing, False)] + ([(MIRRORS[facing], True)] if facing in MIRRORS else []):
            for step, im in enumerate(poses):
                im = ImageOps.mirror(im) if mirror else im
                if mirror:  # keep the feet at FEET after the mirror
                    shifted = Image.new('RGBA', FRAME, (0, 0, 0, 0))
                    shifted.alpha_composite(im, (FRAME[0] - 2 * FEET[0], 0))
                    im = shifted
                name = f'pose_storytender_{facing_out}_{step}.png'
                im.save(os.path.join(out_dir, name))
                frames.append({'figure': 'storytender', 'facing': facing_out, 'pose': 'idle' if step == 0 else 'walk', 'step': step, 'file': name})
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
