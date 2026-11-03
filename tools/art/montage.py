"""Contact sheet for choosing between generated pictures: montage.py <out.png> <columns> <cell px> <file>...
Each picture is shrunk into a cell on a mid-grey background (so transparent ones show) and labelled with its file name."""
import os, sys
from PIL import Image, ImageDraw

out, cols, cell = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
files = sys.argv[4:]
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (cols * cell, rows * (cell + 16)), (120, 120, 120))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).convert('RGBA')
    im.thumbnail((cell, cell), Image.LANCZOS)
    x, y = (i % cols) * cell, (i // cols) * (cell + 16)
    sheet.paste(im, (x + (cell - im.width) // 2, y + 16 + (cell - im.height) // 2), im)
    d.text((x + 2, y + 2), os.path.basename(f)[:cell // 6], fill=(255, 255, 255))
sheet.save(out)
