"""Port tool: cuts a sheet of drawings on a flat background (Gemini sheets) into separate transparent PNGs.
The background colour is read from the sheet; each drawing is found as a block of pixels unlike it, the sheet is split
into rows and then columns at the empty gaps, and the soft ground shadow (background, only darker) is kept faint.
Usage: python3 cut_sheet.py <sheet> <out_dir> <prefix> [--crop x0,y0,x1,y1] [--gap N]"""
import os, sys
import numpy as np
from scipy import ndimage
from PIL import Image

def outside(nearbg):
    """The background of a cell: paper-like pixels that connect to the cell's edge (a geodesic flood from the border).
    Paper-coloured parts inside a drawing (a sign board) stay, because an outline closes them off."""
    reach = np.zeros_like(nearbg)
    reach[0, :] = nearbg[0, :]; reach[-1, :] = nearbg[-1, :]; reach[:, 0] = nearbg[:, 0]; reach[:, -1] = nearbg[:, -1]
    while True:
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]; grown[:-1, :] |= reach[1:, :]; grown[:, 1:] |= reach[:, :-1]; grown[:, :-1] |= reach[:, 1:]
        grown &= nearbg
        if (grown == reach).all():
            return reach
        reach = grown

def bands(profile, gap, min_size):
    out, start, empty = [], None, 0
    for i, v in enumerate(profile):
        if v:
            if start is None:
                start = i
            empty = 0
        elif start is not None:
            empty += 1
            if empty >= gap:
                if i - empty - start + 1 >= min_size:
                    out.append((start, i - empty + 1))
                start, empty = None, 0
    if start is not None and len(profile) - start >= min_size:
        out.append((start, len(profile)))
    return out

def main():
    args = sys.argv[1:]
    sheet, out, prefix = args[0], args[1], args[2]
    crop = None
    gap = 6
    if '--crop' in args:
        crop = tuple(int(v) for v in args[args.index('--crop') + 1].split(','))
    if '--gap' in args:
        gap = int(args[args.index('--gap') + 1])
    os.makedirs(out, exist_ok=True)
    im = Image.open(sheet).convert('RGB')
    if crop:
        im = im.crop(crop)
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    lum_bg = bg.mean()
    lum = a.mean(axis=2)
    # a pixel is part of a drawing when it is clearly unlike the paper; a shadow is the paper, only darker and the same hue
    hue = a / np.maximum(a.sum(axis=2, keepdims=True), 1) - bg / max(bg.sum(), 1)
    shadowish = (np.abs(hue).sum(axis=2) < 0.035) & (lum < lum_bg)
    solid = (dist > 38) & ~(shadowish & (dist < 90))
    if '--grid' in args:
        gc, gr = (int(v) for v in args[args.index('--grid') + 1].split(','))
        rows = [(round(i * h / gr), round((i + 1) * h / gr)) for i in range(gr)]
        cells = [[(round(j * w / gc), round((j + 1) * w / gc)) for j in range(gc)] for _ in rows]
    else:
        rows = bands(solid.any(axis=1), gap, 12)
        cells = [bands(solid[y0:y1].any(axis=0), gap, 12) for (y0, y1) in rows]
    n = 0
    for (y0, y1), cols in zip(rows, cells):
        for (x0, x1) in cols:
            m = solid[y0:y1, x0:x1]
            ys, xs = np.nonzero(m)
            if len(xs) < 40:
                if '--grid' in args:
                    n += 1   # an empty grid cell keeps its number, so the numbers stay the cells' order
                continue
            by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            # keep a margin below for the shadow, which sits under the feet
            pad = 3
            cy0, cy1 = max(0, y0 + by0 - pad), min(h, y0 + by1 + 14)
            cx0, cx1 = max(0, x0 + bx0 - pad), min(w, x0 + bx1 + pad)
            rgb = a[cy0:cy1, cx0:cx1]
            d = dist[cy0:cy1, cx0:cx1]
            sh = shadowish[cy0:cy1, cx0:cx1]
            bgmask = outside((d < 38) | (sh & (d < 90)))
            # keep the drawing, drop strays: pieces of a neighbouring cell, a name label floating above a figure
            lab, nl = ndimage.label(~bgmask & (d >= 38))
            if nl > 1:
                sizes = ndimage.sum(np.ones_like(lab), lab, index=range(1, nl + 1))
                big = int(np.argmax(sizes)) + 1
                ys2, xs2 = np.nonzero(lab == big)
                top, bot = ys2.min(), ys2.max()
                keep = np.zeros_like(bgmask)
                for i in range(1, nl + 1):
                    yi, xi = np.nonzero(lab == i)
                    if yi.max() >= top - 4 and yi.min() <= bot + 4 and sizes[i - 1] >= 6:
                        keep |= lab == i
                # what is not kept and not near the kept part becomes background
                near = ndimage.binary_dilation(keep, iterations=3)
                bgmask = bgmask | ~near
            # a drawing is one closed shape: small gaps in its outline must not let the paper show through inside it
            shape = ndimage.binary_fill_holes(ndimage.binary_closing(~bgmask, iterations=4))
            bgmask = bgmask & ~shape
            # outside: a soft edge where the paper meets the drawing, and the ground shadow kept faint; inside: solid
            alpha = np.where(bgmask, np.clip((d - 22) / 30, 0, 1), 1.0)
            alpha = np.where(bgmask & sh & (d < 90), np.clip((d - 10) / 60, 0, 0.35), alpha)
            rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
            Image.fromarray(rgba, 'RGBA').save(os.path.join(out, f'{prefix}_{n:03d}.png'))
            # where the feet are: the bottom of the solid part, in the middle of it
            feet_x = (bx0 + bx1) / 2 + x0 - cx0
            feet_y = by1 + y0 - cy0
            with open(os.path.join(out, f'{prefix}_{n:03d}.txt'), 'w') as f:
                f.write(f'{feet_x:.0f} {feet_y:.0f} {len(rows)} {rows.index((y0, y1))} {cols.index((x0, x1))}\n')
            n += 1
    print(prefix, 'rows', len(rows), 'pieces', n)

main()
