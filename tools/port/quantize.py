"""Port tool: copies captured PNGs, reduced to at most 255 colours (with their alpha), so the engine's PNG import keeps
every colour exactly (its sprites hold a palette of 255 colours plus transparent).
Usage: python3 quantize.py <in_dir> <out_dir>"""
import os, sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for f in sorted(os.listdir(src)):
    if not f.endswith('.png'):
        continue
    im = Image.open(os.path.join(src, f)).convert('RGBA')
    # fully transparent pixels all become the same colour, so they do not use up palette entries
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] < 8:
                px[x, y] = (0, 0, 0, 0)
    if len(im.getcolors(1 << 24) or range(300)) > 255:
        im = im.quantize(colors=255, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert('RGBA')
    im.save(os.path.join(dst, f))
print('quantized', len(os.listdir(dst)))
