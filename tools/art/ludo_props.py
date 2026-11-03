"""The world's objects in the Ludo.ai pictures (art/incoming2): takes the place of the pictures the Godot game's captures (or the
owner's earlier sheet, tools/port/apply_art.py) gave each kind of object in <work>/art_q, before the porter builds the project.

Each picture is cropped to its solid part and scaled so it stands as tall as the one it replaces (the solid part of the original
capture in <work>/art), or as wide (a bar or a word lying on the floor), or to a height written down in RULES where the capture
is no guide (the anvil's capture has a hammer and sparks in the air above it). The feet are the bottom middle of the solid part.
Objects the porter draws from <work>/objects (chest, lantern post, forge, oven, plates, sword, signs: sd_objects.py) are not
touched here, except in the memories, where they stand in art_q like everything else.
    python3 -I tools/art/ludo_props.py <repo> <work>"""
import json, os, re, sys
from PIL import Image, ImageOps

REPO, WORK = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ludo  # noqa: E402

# Prop kinds (scripts/prop.gd): TREE 0, HOUSE 1, FORGE 2, CRYSTAL 3, SIGN 4, SWORD 5, SHARD 6, ANVIL 7, PORTAL 8, FIGURE 9, PICKUP 10,
# BOOK 11, CHAIR 12, TABLE 13, OVEN 14, RIFT 15, POST 16, GATE 17, CHEST 18
PROP = {
    2: ('objects', 'forge_frozen', 'h', 120),    # (the forge's ghost in Garrick's memory, as it is in the Prologue)
    3: ('objects', 'crystal', 'h', None),
    4: ('objects', 'sign_small', 'h', None),
    6: ('objects', 'shard', 'h', None),
    7: ('objects', 'anvil', 'h', 46),            # (without the hammer and sparks of the capture)
    8: ('objects', 'portal', 'h', None),
    9: ('characters', 'figure_memory', 'h', None),
    11: ('objects', 'storybook', 'h', None),
    12: ('objects', 'chair', 'h', None),
    13: ('objects', 'table_long', 'w', 190),     # (five cells long: as wide as the old table, not its huge shadow)
    16: ('objects', 'post_unlit', 'h', 72),
    17: ('objects', 'gate_closed', 'h', None),
    18: ('objects', 'chest_closed', 'h', 40),
}
OTHER = {
    'StoryGate': ('objects', 'storygate', 'h', None),
    'Dummy': ('objects', 'dummy', 'h', None),
    'Redactor': ('objects', 'redaction_bar', 'w', None),
    'PressurePlate': ('objects', 'plate_up', 'h', 30),
    'Critic': ('bosses', 'boss_critic_idle', *ludo.BOSS_FIT['critic'][:2]),
    'Spoiler': ('bosses', 'boss_spoiler_idle', *ludo.BOSS_FIT['spoiler'][:2]),
    'ScissorMan': ('bosses', 'boss_scissor_idle', *ludo.BOSS_FIT['scissor'][:2]),
}
BLOCK = {'forge': 'block_stone', 'maud': 'block_wood'}
DUNGEON_KEY = {'bellows': 'bellows', 'hammer': 'hammer', 'tongs': 'tongs', 'page': 'torn_page'}   # (weight, locket: not made)
N_TREES, N_HOUSES = 6, 3
# things that lie on the floor like a box or a plate: their feet are the middle of what they stand on, not the lowest point of the
# picture, so they are put where the capture's feet were (a little above its bottom), but never higher than a third of the picture
FEET_LIKE_CAPTURE = ('IsoBlock', 'PressurePlate')
# a bar or wall lying along the x axis (axis (1, 0)) slopes down to the right on the screen; the Ludo.ai pictures of them are drawn the
# other way (along the y axis, rising to the right), so for the first they are mirrored
MIRROR_X_AXIS = ('StoryGate', 'Redactor')


def solid(im, level=128):
    return im.getchannel('A').point(lambda v: 255 if v >= level else 0).getbbox()


def rule(e, houses):
    """(folder, picture, 'h'|'w', height or None) for an object of the index, or None."""
    cls, key, scene = e['cls'], e['key'], e['scene']
    kind = re.search(r'\|kind=(-?\w+)', key)
    k = kind.group(1) if kind else ''
    if cls == 'Prop' and k.isdigit():
        k = int(k)
        slot = int(re.search(r'_(\d+)\.png$', e['file']).group(1))
        if k == 0:
            return ('objects', f'tree_{slot % N_TREES + 1}', 'h', None)
        if k == 1:   # the houses of Thistledown (the game's pencil ghosts of them are drawn in colour here, as in the owner's sheet)
            return ('objects', f'house_{houses.setdefault(e["file"], len(houses)) % N_HOUSES + 1}', 'h', None)
        if k == 10:   # a pickup lying in the world: the item's own icon, not the capture's icon in its bubble
            item = re.search(r'item_id=([^|]*)', key)
            return ('items', f'icon_{item.group(1)}', 'h', 34) if item and item.group(1) else None
        return PROP.get(k)
    if cls == 'IsoBlock':
        return ('objects', BLOCK[scene], 'h', None) if scene in BLOCK else None
    if cls == 'DungeonKey':
        return ('objects', DUNGEON_KEY[k], 'h', None) if k in DUNGEON_KEY else None
    return OTHER.get(cls)


def main():
    idx_path = os.path.join(WORK, 'art_q', 'index.json')
    index = json.load(open(idx_path))
    captured = {e['file']: e for e in json.load(open(os.path.join(WORK, 'art', 'index.json'))) if e.get('file') and e.get('feet')}
    done, houses, made = {}, {}, []
    for e in index:
        if not e.get('file'):
            continue
        r = rule(e, houses)
        pic = ludo.find(r[0], r[1]) if r else None
        if not pic:
            continue
        if e['file'] not in done:
            ref_path = os.path.join(WORK, 'art', e['file'])
            ref = Image.open(ref_path if os.path.exists(ref_path) else os.path.join(WORK, 'art_q', e['file'])).convert('RGBA')
            rb = solid(ref)
            if not rb:
                continue
            im = ludo.trim(ludo.load(pic))
            if e['cls'] in MIRROR_X_AXIS and re.search(r'axis=\(1, 0\)', e['key']):
                im = ImageOps.mirror(im)
            _, _, how, height = r
            s = (height or rb[3] - rb[1]) / im.height if how == 'h' else (height or rb[2] - rb[0]) / im.width
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            feet = ludo.save_sprite(im, os.path.join(WORK, 'art_q', e['file']))
            if e['cls'] in FEET_LIKE_CAPTURE and captured.get(e['file'], {}).get('feet'):
                lift = max(0, rb[3] - captured[e['file']]['feet'][1])
                feet[1] -= min(lift, round(im.height / 3))
            size = Image.open(os.path.join(WORK, 'art_q', e['file'])).size
            done[e['file']] = (feet, list(size))
            made.append(f'{e["cls"]}:{r[1]}')
        e['feet'], e['size'] = done[e['file']]
    json.dump(index, open(idx_path, 'w'), indent=1)
    print('ludo props replaced', len(done), 'pictures:', ', '.join(sorted(set(made))))


if ludo.LUDO:
    main()
