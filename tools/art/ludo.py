"""Reading the finished Ludo.ai pictures (art/incoming2) for the porter's art scripts.

Those pictures are already transparent single subjects (about 1024 px, ~40 px of empty margin all round), so unlike the pictures
of art/generated nothing has to be cut out of parchment: a picture is cropped to its solid part and scaled to the height the
object has in the game. Set NO_LUDO=1 to make the scripts ignore art/incoming2 and use the older pictures, or LUDO_PARTS=tiles,objects
(any of tiles, objects, errors, bosses, characters, items) to use only those folders of it.

    from ludo import LUDO, find, load, fit_height, save_sprite
"""
import os
import numpy as np
from PIL import Image

REPO = os.environ.get('LUDO_REPO') or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
ROOT = os.path.join(REPO, 'art', 'incoming2')
LUDO = os.path.isdir(ROOT) and not os.environ.get('NO_LUDO')
PARTS = set(os.environ['LUDO_PARTS'].split(',')) if os.environ.get('LUDO_PARTS') else None


def find(*rel):
    """Path of a picture of art/incoming2 (e.g. find('objects', 'chest_closed')), or None if there is none (or NO_LUDO is set)."""
    if not LUDO or (PARTS is not None and rel[0] not in PARTS):
        return None
    p = os.path.join(ROOT, *rel[:-1], rel[-1] + '.png')
    return p if os.path.exists(p) else None


def load(path):
    return Image.open(path).convert('RGBA')


def solid_box(im, level=200):
    """Bounding box of the solid part (alpha >= level); a faint shadow or glow around it does not count."""
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def trim(im):
    """Cropped to the solid part, with the faint edge pixels that belong to it kept."""
    b = solid_box(im)
    return im.crop(b) if b else im


def fit_height(im, height, ref=None):
    """Cropped to its solid part and scaled so that part is `height` px tall (as tall as the picture it replaces). With `ref` (the
    other state of the same object, e.g. the closed chest for the open one) the scale is the one that makes `ref` that tall, so the
    states stay the same size and the open chest's lid rises above the closed one's."""
    im = trim(im)
    s = height / max(1, trim(ref).height if ref is not None else im.height)
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def save_sprite(im, path, pad=3):
    """The picture with a little room all round, in at most 254 colours (the engine's limit), the see-through kept as it is.
    Returns where its feet are: the bottom middle of the solid part."""
    canvas = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    canvas.alpha_composite(im, (pad, pad))
    b = solid_box(canvas)
    q = canvas.convert('RGB').quantize(colors=254, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
    qa = np.asarray(q).copy()
    qa[..., 3] = np.asarray(canvas.getchannel('A'))
    Image.fromarray(qa, 'RGBA').save(path)
    return [round((b[0] + b[2]) / 2), b[3]]
