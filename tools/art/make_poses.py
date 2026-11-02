"""Draws OpenPose skeleton pictures (the coloured stick figures ControlNet OpenPose reads) for the Storytender:
five directions (the game mirrors the right-facing ones for the left) x idle, a 4-frame walk and a quill strike.
Short "chibi" proportions (about 3 heads tall) seen from a little above, like the game's camera.
Usage: python3 make_poses.py <out_dir>"""
import math, os, sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
W = H = 1024
SCALE = 290          # pixels per body unit
FEET = (512, 930)

# OpenPose COCO-18 keypoints and the standard limb list and colours (as controlnet_aux draws them)
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13), (1, 0),
         (0, 14), (14, 16), (0, 15), (15, 17)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0),
          (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255),
          (170, 0, 255), (255, 0, 255), (255, 0, 170), (255, 0, 85)]


def body(phase=None, strike=False):
    """The skeleton in body space: x = the character's right, y = up, z = forward (where it faces)."""
    sw = 0.0 if phase is None else math.sin(phase)
    leg = math.radians(28) * sw      # right leg swing (left is opposite)
    arm = math.radians(24) * sw      # arms swing opposite to the legs
    bob = 0.0 if phase is None else 0.04 * abs(math.cos(phase))
    p = {}
    hip_y = 0.9 + bob
    for side, s, a_leg in (('R', 1, leg), ('L', -1, -leg)):
        hip = (0.18 * s, hip_y, 0.0)
        knee = (0.18 * s, hip_y - 0.45 * math.cos(a_leg), 0.45 * math.sin(a_leg))
        bend = 0.12 if (phase is not None and a_leg < 0) else 0.0   # the back leg bends a little
        ankle = (0.18 * s, knee[1] - 0.45 * math.cos(a_leg - bend), knee[2] + 0.45 * math.sin(a_leg - bend))
        p['hip' + side], p['knee' + side], p['ankle' + side] = hip, knee, ankle
    p['neck'] = (0.0, 1.58 + bob, 0.0)
    for side, s, a_arm in (('R', 1, -arm), ('L', -1, arm)):
        sh = (0.36 * s, 1.52 + bob, 0.0)
        el = (0.42 * s, sh[1] - 0.32 * math.cos(a_arm), 0.32 * math.sin(a_arm))
        wr = (0.44 * s, el[1] - 0.3 * math.cos(a_arm * 1.3), el[2] + 0.3 * math.sin(a_arm * 1.3))
        p['sh' + side], p['el' + side], p['wr' + side] = sh, el, wr
    if strike:   # the right hand raised high and forward, holding the quill over the head
        p['elR'] = (0.38, 1.95 + bob, 0.15)
        p['wrR'] = (0.25, 2.35 + bob, 0.45)
    p['nose'] = (0.0, 2.02 + bob, 0.46)
    p['eyeR'] = (0.17, 2.14 + bob, 0.40)
    p['eyeL'] = (-0.17, 2.14 + bob, 0.40)
    p['earR'] = (0.46, 2.08 + bob, 0.0)
    p['earL'] = (-0.46, 2.08 + bob, 0.0)
    return p


ORDER = ['nose', 'neck', 'shR', 'elR', 'wrR', 'shL', 'elL', 'wrL', 'hipR', 'kneeR', 'ankleR', 'hipL', 'kneeL', 'ankleL',
         'eyeR', 'eyeL', 'earR', 'earL']
FACE_NORMAL = {'nose': (0, 0, 1), 'eyeR': (0.4, 0, 0.9), 'eyeL': (-0.4, 0, 0.9), 'earR': (1, 0, -0.1), 'earL': (-1, 0, -0.1)}


def project(pt, yaw):
    """yaw 0 = facing the viewer, 90 = facing right, 180 = facing away. The camera looks a little down."""
    x, y, z = pt
    t = math.radians(yaw)
    sx = -x * math.cos(t) + z * math.sin(t)
    depth = x * math.sin(t) + z * math.cos(t)          # toward the viewer
    sy = -y * 0.96 + depth * 0.22
    return FEET[0] + sx * SCALE, FEET[1] + sy * SCALE, depth


def visible(name, yaw):
    n = FACE_NORMAL.get(name)
    if not n:
        return True
    t = math.radians(yaw)
    return n[0] * math.sin(t) + n[2] * math.cos(t) > -0.15


def draw(pose, yaw, path):
    img = Image.new('RGB', (W, H), (0, 0, 0))
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    pts = [project(pose[k], yaw) if visible(k, yaw) else None for k in ORDER]
    for i, (a, b) in enumerate(LIMBS):
        if pts[a] is None or pts[b] is None:
            continue
        (x1, y1, _), (x2, y2, _) = pts[a], pts[b]
        d.line((x1, y1, x2, y2), fill=COLORS[i] + (160,), width=14)
    img.paste(over, (0, 0), over)
    d2 = ImageDraw.Draw(img)
    for i, q in enumerate(pts):
        if q is not None:
            d2.ellipse((q[0] - 7, q[1] - 7, q[0] + 7, q[1] + 7), fill=COLORS[i])
    img.save(path)


DIRS = [('1_toward', 0), ('2_down_right', 45), ('3_right', 90), ('4_up_right', 135), ('5_away', 180)]
for name, yaw in DIRS:
    frames = [('a_stand', body())] + [(f'{c}_walk', body(phase=k * math.pi / 2 + math.pi / 2)) for k, c in enumerate('bcde')] + [('f_strike', body(strike=True))]
    for fname, pose in frames:
        draw(pose, yaw, os.path.join(OUT, f'{name}_{fname}.png'))
print('poses written to', OUT)
