"""The item icons in the Ludo.ai pictures (art/incoming2/items/icon_<id>.png, one for each of the items in tilewright/assets/items.json):
each replaces the icon captured from the Godot game (or drawn by the owner's sheet) in <work>/icons, fitted into the 96 x 96 canvas the
porter expects, with a little room round the picture (the binder shows it at 48-64 px). Items with no Ludo.ai picture keep theirs.
    python3 -I tools/art/ludo_icons.py <repo> <work>"""
import glob, os, sys
from PIL import Image

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ludo  # noqa: E402

SIZE, ROOM = 96, 84


def main():
    made = 0
    for f in sorted(glob.glob(os.path.join(WORK, 'icons', 'icon_*.png'))):
        name = os.path.splitext(os.path.basename(f))[0]
        pic = ludo.find('items', name)
        if not pic:
            continue
        im = ludo.trim(ludo.load(pic))
        s = ROOM / max(im.size)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
        canvas.save(f)
        made += 1
    print('ludo icons', made)


if ludo.LUDO:
    main()
