"""Small details for the meadow, drawn in the tile sheet's style (an even dark-green ink outline, flat colour with one lighter
tone): tufts of grass, little clusters of flowers and pebbles. They are drawn in the game's own view (sheet_tiles.py lays them
over the finished floor), at the game's pixel size."""
import numpy as np
from PIL import Image, ImageDraw

INK = (34, 44, 24, 255)


def tuft(rng):
    """3 to 5 blades from one root, about 12 px tall."""
    w, h = 16, 15
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    fill = Image.new('L', (w, h), 0)
    tips = Image.new('L', (w, h), 0)
    df, dt = ImageDraw.Draw(fill), ImageDraw.Draw(tips)
    n = int(rng.integers(3, 6))
    for k in range(n):
        off = (k - (n - 1) / 2)
        x0 = w / 2 + off * 1.6
        tip = (x0 + off * 2.2 + rng.normal(0, 0.6), h - 2 - rng.uniform(7, 11))
        df.polygon([(x0 - 1.4, h - 2), (x0 + 1.4, h - 2), tip], fill=255)
        dt.polygon([(x0 - 0.5, h - 6), (x0 + 0.6, h - 6), tip], fill=255)
    f = np.asarray(fill) > 0
    t = np.asarray(tips) > 0
    from scipy import ndimage
    edge = ndimage.binary_dilation(f) & ~f
    a = np.zeros((h, w, 4), np.uint8)
    a[f] = (88, 128, 46, 255)
    a[f & t] = (140, 182, 74, 255)
    a[edge] = INK
    return Image.fromarray(a, 'RGBA')


def flowers(rng):
    """A few small flowers (four petals and a yellow heart) on a scrap of leaf, about 12 x 8 px."""
    w, h = 16, 11
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((3, 5, 12, 10), fill=(70, 112, 40, 255), outline=INK)            # the leaves under them
    colours = [(232, 140, 182), (246, 214, 92), (246, 240, 226), (186, 140, 222)]
    c = colours[int(rng.integers(0, len(colours)))]
    for _ in range(int(rng.integers(2, 4))):
        x, y = rng.uniform(4, w - 5), rng.uniform(3, h - 4)
        d.ellipse((x - 2.5, y - 1.8, x + 2.5, y + 1.8), fill=c + (255,), outline=INK)
        d.point((round(x), round(y)), fill=(250, 196, 60, 255))
    return im


def pebble(rng):
    """A grey pebble with a light top, 5 to 8 px across."""
    w = int(rng.integers(5, 9))
    h = max(3, round(w * 0.6))
    im = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    g = int(rng.integers(140, 175))
    d.ellipse((0, 0, w + 1, h + 1), fill=(g, g - 4, g - 12, 255), outline=(52, 50, 46, 255))
    d.line((2, 1, w - 1, 1), fill=(min(255, g + 45), min(255, g + 42), min(255, g + 34), 255))
    return im


def scatter(rng, period, counts):
    """Where the details go on one period of the floor (in cells), and what each is."""
    out = []
    for kind, n in counts.items():
        for _ in range(n):
            out.append((kind, rng.uniform(0, period), rng.uniform(0, period)))
    return out


MAKERS = {'tuft': tuft, 'flowers': flowers, 'pebble': pebble}
