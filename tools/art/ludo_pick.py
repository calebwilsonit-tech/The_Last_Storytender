"""Copies the chosen try of each picture to its final name:  ludo_pick.py <picks.json> ...
picks.json maps a final path (art/incoming2/items/icon_ink_blot) to the try number; the file <path>_s<N>.png is copied to <path>.png."""
import json, shutil, sys
for f in sys.argv[1:]:
    for out, n in json.load(open(f)).items():
        if out.startswith('_'):
            continue
        shutil.copyfile(f'{out}_s{n}.png', f'{out}.png')
        print('picked', out, n)
