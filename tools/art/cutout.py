"""Cuts a generated picture (one figure on textured parchment) out of its background.

The background is flooded in from the edges: a pixel joins it when its colour is close to the background near it. The thick
dark outline of the figure stops the flood. Pixels the flood reaches that are a darker shade of the parchment (the soft
shadow under the feet) become see-through black, as dark as they were darker than the paper. A white "sticker" rim
right outside the outline is removed too.
    python3 -I cutout.py <in.png> <out.png>"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def cut_all(path):
    return cut(path, keep_all=True)


def cut(path, keep_all=False):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    h, w, _ = im.shape
    # the parchment around the figure: a heavy blur of the border colours stands for the local paper colour everywhere
    paper = ndimage.uniform_filter(im, size=(61, 61, 1))
    edge = np.zeros((h, w), bool)
    edge[:8, :] = edge[-8:, :] = edge[:, :8] = edge[:, -8:] = True
    # estimate the paper colour from the border, smoothly, by diffusing border colours inward (median of the frame works well)
    border = np.concatenate([im[:8].reshape(-1, 3), im[-8:].reshape(-1, 3), im[:, :8].reshape(-1, 3), im[:, -8:].reshape(-1, 3)])
    base = np.median(border, axis=0)
    lum = im.mean(axis=2)
    base_l = base.mean()
    # chroma: the colour with its brightness taken out, compared with the paper's
    chroma = im / np.maximum(lum[..., None], 1)
    pchroma = base / max(base_l, 1)
    cdist = np.abs(chroma - pchroma).sum(axis=2)
    ratio = lum / base_l
    paperish = (cdist < 0.16) & (ratio > 0.82)          # the paper itself, its texture and lighter rings
    shadowish = (cdist < 0.30) & (ratio > 0.45) & (ratio <= 0.82)  # a darker shade of the paper: the soft shadow
    whiteish = (lum > 225) & (im.std(axis=2) < 14)       # a white sticker rim
    can = paperish | shadowish | whiteish
    lab, _ = ndimage.label(can)
    seeds = np.unique(lab[edge & can])
    bg = np.isin(lab, seeds[seeds > 0])
    # what is left of the background inside: small specks of paper enclosed by nothing (keep the figure's own light parts)
    fig = ~bg
    fig = ndimage.binary_opening(fig, iterations=1)
    lab2, n = ndimage.label(fig)
    if n > 1 and not keep_all:
        sizes = ndimage.sum(fig, lab2, range(1, n + 1))
        fig = lab2 == (1 + int(np.argmax(sizes)))
    fig = ndimage.binary_fill_holes(fig)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = im.astype(np.uint8)
    out[..., 3] = np.where(fig, 255, 0)
    # the shadow: see-through black under the figure, as dark as it was darker than the paper
    sh = bg & shadowish & ~fig
    lab3, n3 = ndimage.label(sh)
    if n3:
        sizes = ndimage.sum(sh, lab3, range(1, n3 + 1))
        big = 1 + int(np.argmax(sizes))
        sh = lab3 == big
        alpha = np.clip((1 - ratio) * 1.6, 0, 0.6) * 255
        out[sh, :3] = 30
        out[sh, 3] = alpha[sh].astype(np.uint8)
    # soften the cut edge by one pixel
    a = out[..., 3].astype(np.float32)
    rim = fig & ~ndimage.binary_erosion(fig)
    a[rim] = a[rim] * 0.75
    out[..., 3] = a.astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


if __name__ == '__main__':
    cut(sys.argv[1]).save(sys.argv[2])
