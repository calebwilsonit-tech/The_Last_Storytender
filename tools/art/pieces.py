"""Pulls every separate figure out of a generated picture that drew many of them (a sheet of small creatures): the background
is cut away (cutout.py), each connected figure becomes its own picture, and the biggest come first.
    python3 -I pieces.py <in.png> <out_dir> [how many]  -> <out_dir>/<name>_p<k>.png"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cutout import cut_all  # noqa: E402


def pieces(path, out_dir, n=8):
    im = cut_all(path)
    a = np.asarray(im)[..., 3] > 128
    lab, k = ndimage.label(ndimage.binary_closing(a, iterations=2))
    if k == 0:
        return []
    sizes = ndimage.sum(a, lab, range(1, k + 1))
    order = np.argsort(-sizes)[:n]
    base = os.path.splitext(os.path.basename(path))[0]
    out = []
    for r, i in enumerate(order):
        if sizes[i] < 600:
            break
        sl = ndimage.find_objects((lab == i + 1).astype(np.int32))[0]
        mask = (lab[sl] == i + 1)
        crop = np.asarray(im)[sl].copy()
        crop[..., 3] = np.where(ndimage.binary_dilation(mask, iterations=2), crop[..., 3], 0)
        p = os.path.join(out_dir, f'{base}_p{r}.png')
        Image.fromarray(crop, 'RGBA').save(p)
        out.append(p)
    return out


if __name__ == '__main__':
    os.makedirs(sys.argv[2], exist_ok=True)
    print(len(pieces(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 8)))
