#!/usr/bin/env python3
"""Generates data/prologue_map.gd, the overworld (Prologue Plains + Thistledown and the lands
around them). The original hand-made 40x26 core (tools/prologue_core.json) is embedded at
(OX, OY); everything around it is built here. Run:  python3 tools/gen_overworld.py
It checks that every landmark can be reached on foot (stairs, cliffs and pits respected)."""
import json, math, random, sys
from collections import deque

W, H = 132, 104
OX, OY = 64, 40
rnd = random.Random(7)

rows = [[' '] * W for _ in range(H)]
hts = [[' '] * W for _ in range(H)]
reg = [[' '] * W for _ in range(H)]

REGIONS = {
    "m": "The Margins Meadow", "s": "The Page's Edge", "o": "The Old Meadow", "t": "Thistledown",
    "r": "The Whispering Orchard", "i": "The Ink-Wells", "h": "Mill Ridge", "g": "Graveyard of Deleted Scenes",
    "e": "The Margin Gate", "x": "The Hushed Glade", "n": "The Footnote Hollow",
}

def land(x, y, r, h, ch='.'):
    if 0 <= x < W and 0 <= y < H:
        rows[y][x] = ch
        hts[y][x] = str(h)
        reg[y][x] = r

def blob(cx, cy, rx, ry, h, r, ch='.', wob=1.0):
    p1, p2, p3 = rnd.uniform(0, 6.28), rnd.uniform(0, 6.28), rnd.uniform(0, 6.28)
    for y in range(int(cy - ry * 1.5), int(cy + ry * 1.5) + 1):
        for x in range(int(cx - rx * 1.5), int(cx + rx * 1.5) + 1):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            th = math.atan2(dy, dx)
            k = 1 + wob * (0.15 * math.sin(3 * th + p1) + 0.09 * math.sin(5 * th + p2) + 0.05 * math.sin(7 * th + p3))
            if dx * dx + dy * dy < k * k:
                land(x, y, r, h, ch)

def rect(x0, y0, x1, y1, h, r, ch='.'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            land(x, y, r, h, ch)

def put(x, y, ch):
    rows[y][x] = ch

def ramp(x, y, d):
    """A stair cell at (x,y) climbing toward direction d in 'e','w','s','n'."""
    hts[y][x] = d
    if rows[y][x] == ' ':
        rows[y][x] = '.'

DIRS = {'e': (1, 0), 'w': (-1, 0), 's': (0, 1), 'n': (0, -1)}

# ---- the old core -------------------------------------------------------------------------------
core = json.load(open('tools/prologue_core.json'))
for j, line in enumerate(core['rows']):
    for i, ch in enumerate(line):
        if ch == ' ':
            continue
        x, y = OX + i, OY + j
        if ch in 'PW':
            ch = '.'
        rows[y][x] = ch
        hts[y][x] = core['heights'][j][i]
        reg[y][x] = 'o' if i < 22 else 't'

# ---- the lands --------------------------------------------------------------------------------
blob(34, 54, 27, 15, 0, 'm')                    # Margins Meadow (start)
blob(10, 55, 5, 8, 0, 's')                      # Page's Edge (far west shore)
rect(8, 48, 12, 62, 0, 's')
rect(58, 49, 67, 58, 0, 'm')                    # meadow neck into the old plains
blob(46, 20, 21, 11, 1, 'r')                    # Whispering Orchard (raised, level 1)
rect(41, 32, 49, 44, 0, 'm')                    # neck from meadow toward the orchard stairs
rect(43, 24, 49, 30, 1, 'r')                    # orchard foot, above the stairs
blob(40, 83, 20, 11, 0, 'i')                    # Ink-Wells
rect(36, 66, 46, 74, 0, 'm')                    # neck south
blob(31, 36, 5, 4, 0, 'x')                      # Hushed Glade (hidden, behind a redaction)
rect(30, 38, 32, 41, 0, 'm')
rect(61, 44, 70, 49, 0, 'm')                    # extra shoulder north of the old plains join
blob(94, 28, 17, 9, 2, 'h')                     # Mill Ridge, level 2 above the town
rect(93, 36, 99, 44, 1, 't')                    # town north extension (level 1) up to the ridge stairs
blob(79, 78, 14, 9, 0, 'g')                     # Graveyard of Deleted Scenes
rect(72, 63, 80, 70, 0, 'o')                    # neck from the old plains south edge
blob(122, 53, 7, 6, 1, 'e')                     # Margin Gate yard (level 1, same as the town's east)
rect(102, 50, 116, 52, 1, 'e')                  # road east from the town
blob(60, 94, 10, 6, 0, 'n')                     # Footnote Hollow (far south east of the wells)
rect(52, 82, 62, 90, 0, 'i')                    # link wells -> hollow

# stairs: orchard (level 1) from the neck; mill ridge (level 2) from the town extension
for x in range(44, 49):
    ramp(x, 31, 'n')                            # low (x,32) level 0 -> high (x,30) level 1
for x in range(94, 99):
    ramp(x, 35, 'n')                            # low (x,36) level 1 -> high (x,34) level 2
# a little raised island in the Ink-Wells (level 1) with a stair
blob(42, 84, 5, 3, 1, 'i')
ramp(42, 88, 'n')
# a knoll in the meadow and an inner hill in the orchard
blob(24, 62, 5, 3, 1, 'm')
ramp(24, 66, 'n') if False else None
# orchard hill (level 2 inside level 1)
blob(52, 17, 6, 4, 2, 'r')
rect(50, 18, 54, 21, 2, 'r')
ramp(52, 22, 'n')

# ---- ravines: a line of plot holes with crossings --------------------------------------------------
for y in range(62, 76):
    if rows[y][51] == '.' and (y % 7) not in (0, 1, 2):
        put(51, y, '#')

def solid(x, y):
    return rows[y][x] not in ' #T' and rows[y][x] != 'R'

# ---- landmarks -------------------------------------------------------------------------------------
START = (16, 54)
put(*START, 'P')
put(19, 53, 'W')

WAYPOINTS = [
    ("meadow", "Margins Lantern Post", (28, 52), 'm'),
    ("orchard", "Orchard Lantern Post", (46, 27), 'r'),
    ("wells", "Ink-Well Lantern Post", (38, 70), 'i'),
    ("oldmeadow", "Old Meadow Lantern Post", (76, 50), 'o'),
    ("square", "Thistledown Square", (95, 52), 't'),
    ("ridge", "Mill Ridge Lantern Post", (92, 31), 'h'),
    ("graves", "Graveyard Lantern Post", (79, 70), 'g'),
    ("gate", "Margin Gate Lantern Post", (118, 52), 'e'),
]
for wid, name, (x, y), r in WAYPOINTS:
    put(x, y, 'Y')

# lore stones: id -> cell
LORE = {
    "edge_1": (12, 52), "edge_2": (12, 58),
    "meadow_1": (22, 49), "meadow_2": (36, 60), "meadow_3": (50, 52),
    "orchard_1": (40, 14), "orchard_2": (56, 22), "orchard_3": (52, 15),
    "wells_1": (34, 80), "wells_2": (48, 86),
    "hollow_1": (60, 93),
    "glade_1": (31, 35),
    "ridge_1": (88, 26), "ridge_2": (100, 30),
    "graves_1": (74, 76), "graves_2": (82, 80), "graves_3": (86, 74), "graves_4": (78, 83),
    "gate_1": (120, 55),
}
for k, (x, y) in LORE.items():
    put(x, y, 'L')

# pickups: char -> item
PICKS = {'k': [(60, 94), (53, 14)], 'o': [(31, 38 - 2)], 'e': [(36, 74), (97, 24), (84, 78)], 'v': [(53, 16 + 1), (42, 84)]}
for ch, cells in PICKS.items():
    for x, y in cells:
        put(x, y, ch)

# the Margin Gate
put(125, 53, 'G')
# a locked Redactor across the Glade neck (3 wide, spanning x), and one across the ridge shortcut
put(31, 40, 'R')
# bars: R occupies (30..32,40)
for x in (31, 32):
    pass

# ---- things to find: chests, riddle vaults, hidden caches ---------------------------------------------
CHESTS = {}          # "x,y" -> reward ("mnemo:N" or "item:id:n")
RIDDLES = {}         # id -> sentence stone + gate + chest
RING = set()         # cells of the tree rings around vaults (never carved through)
REWARDS = ["item:ink_vial:2", "mnemo:30", "item:warm_loaf:2", "item:eraser_crumbs:3", "mnemo:25", "item:void_ink:1",
           "item:ink_vial:1", "mnemo:40", "item:warm_loaf:1", "item:eraser_crumbs:2", "mnemo:20", "item:ink_vial:2",
           "mnemo:35", "item:void_ink:2"]
_reward_i = [0]

def next_reward():
    r = REWARDS[_reward_i[0] % len(REWARDS)]
    _reward_i[0] += 1
    return r

def area_ok(x, y, rad=5):
    if x - rad < 1 or y - rad < 1 or x + rad >= W - 1 or y + rad >= H - 1:
        return False
    lv = hts[y][x]
    if not lv.isdigit():
        return False
    for yy in range(y - rad, y + rad + 1):
        for xx in range(x - rad, x + rad + 1):
            if rows[yy][xx] != '.' or hts[yy][xx] != lv:
                return False
    return True

def stamp_site(cx, cy, rad=4, search=30):
    for d in range(search):
        for dy in range(-d, d + 1):
            for dx in range(-d, d + 1):
                if max(abs(dx), abs(dy)) != d:
                    continue
                if area_ok(cx + dx, cy + dy, rad):
                    return (cx + dx, cy + dy)
    return None

def make_ring(x, y, side):
    """A 5x5 clearing ringed by trees, with a 3-wide opening on `side` (e/w/n/s)."""
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            cx_, cy_ = x + dx, y + dy
            if max(abs(dx), abs(dy)) == 3:
                rows[cy_][cx_] = 'T'
                RING.add((cx_, cy_))
            else:
                rows[cy_][cx_] = '.'
    ox, oy = {'e': (3, 0), 'w': (-3, 0), 's': (0, 3), 'n': (0, -3)}[side]
    for k in (-1, 0, 1):
        px, py = (x + ox, y + oy + k) if side in 'ew' else (x + ox + k, y + oy)
        rows[py][px] = '.'
        RING.discard((px, py))
    return (x + ox, y + oy)

def riddle_vault(cx, cy, side, prefix, options, suffix, tier=1):
    site = stamp_site(cx, cy)
    if not site:
        print("no site for riddle near", cx, cy)
        return
    x, y = site
    gate = make_ring(x, y, side)
    rows[y][x] = 'q'
    CHESTS["%d,%d" % (x, y)] = "tier:%d" % tier
    rows[gate[1]][gate[0]] = 'U'
    # the stone stands outside the opening, off to one side
    sx, sy = {'e': (gate[0] + 2, gate[1] + 2), 'w': (gate[0] - 2, gate[1] + 2), 's': (gate[0] + 2, gate[1] + 2), 'n': (gate[0] + 2, gate[1] - 2)}[side]
    if rows[sy][sx] != '.':
        for ddx, ddy in ((2, 2), (-2, 2), (2, -2), (-2, -2), (3, 0), (-3, 0)):
            if rows[gate[1] + ddy][gate[0] + ddx] == '.':
                sx, sy = gate[0] + ddx, gate[1] + ddy
                break
    rows[sy][sx] = 'S'
    axis = [0, 1] if side in 'ew' else [1, 0]
    RIDDLES["r%d" % len(RIDDLES)] = {"stone": [sx, sy], "gate": list(gate), "axis": axis, "chest": [x, y],
                                       "prefix": prefix, "options": options, "suffix": suffix, "tier": tier}

def hidden_cache(cx, cy, side):
    """Same clearing, but its opening is covered by a Redaction bar: hold the Lantern to read it away."""
    site = stamp_site(cx, cy)
    if not site:
        print("no site for cache near", cx, cy)
        return
    x, y = site
    gate = make_ring(x, y, side)
    rows[y][x] = 'q'
    CHESTS["%d,%d" % (x, y)] = next_reward()
    rows[gate[1]][gate[0]] = 'R'

riddle_vault(34, 62, 'e', "The gate is", ["LOCKED", "RUSTED", "UNLATCHED"], ".", 1)
riddle_vault(58, 27, 'w', "Behind this gate is", ["NOTHING", "A TRAP", "TREASURE"], ".", 2)
riddle_vault(32, 87, 'e', "The lock was never", ["FIXED", "BROKEN", "INSTALLED"], ".", 2)
riddle_vault(92, 83, 'w', "Whoever lives here is", ["OUT", "ASLEEP", "EXPECTING YOU"], ".", 3)
riddle_vault(98, 22, 's', "The wall is", ["SOLID", "PAINTED ON", "A DOOR"], ".", 3)
riddle_vault(80, 52, 'w', "The last page is", ["BLANK", "TORN OUT", "STILL BEING WRITTEN"], ".", 4)
hidden_cache(22, 44, 's')
hidden_cache(34, 15, 'n')
hidden_cache(46, 92, 'n')
hidden_cache(84, 31, 's')
hidden_cache(60, 59, 'n')

# crystals (Mnemosynth): clusters
def cluster(cx, cy, n, spread=3):
    placed = 0
    tries = 0
    while placed < n and tries < 60:
        tries += 1
        x, y = cx + rnd.randint(-spread, spread), cy + rnd.randint(-spread, spread)
        if 0 <= x < W and 0 <= y < H and rows[y][x] == '.':
            put(x, y, 'C')
            placed += 1

for cx, cy, n in [(22, 58, 3), (30, 46, 3), (44, 58, 3), (54, 48, 2), (40, 12, 4), (50, 24, 3), (58, 14, 3),
                  (33, 78, 3), (46, 80, 3), (44, 86, 2), (62, 90, 3), (90, 30, 3), (102, 26, 3), (78, 74, 3),
                  (84, 84, 3), (31, 36, 5), (118, 50, 2), (56, 60, 2), (72, 58, 2)]:
    cluster(cx, cy, n)

# ---- enemies (they appear after Garrick's lesson, streamed by distance) -----------------------------
# g Bare (lunger)   x Mite (swarm)   l Run-on (sticky trail)   d Dangler (ranged)
# n Censor (shielded)   z Ellipsis (blinks).  Which kinds appear grows with the story (see main.gd).
def camp(cx, cy, kinds, spread=3):
    for ch, n in kinds.items():
        for _ in range(n):
            for _t in range(40):
                x, y = cx + rnd.randint(-spread, spread), cy + rnd.randint(-spread, spread)
                if 0 <= x < W and 0 <= y < H and rows[y][x] == '.' and hts[y][x].isdigit():
                    put(x, y, ch)
                    break

CAMPS = [
    (36, 50, {'g': 1, 'x': 1}), (47, 58, {'g': 1, 'x': 1}),
    (40, 15, {'d': 2, 'g': 1}), (54, 24, {'d': 1, 'x': 1}), (50, 14, {'g': 1}),
    (36, 80, {'l': 2, 'x': 1}), (46, 82, {'l': 1, 'x': 1}), (60, 92, {'l': 1, 'd': 1}),
    (92, 27, {'n': 1, 'g': 1, 'x': 1}), (100, 31, {'n': 1, 'g': 1}),
    (76, 76, {'z': 2, 'x': 1, 'g': 1}), (84, 80, {'z': 1, 'x': 1}),
]
for cx, cy, kinds in CAMPS:
    camp(cx, cy, kinds)
    # the bigger camps guard a chest
    if sum(kinds.values()) >= 3 or any(k in kinds for k in 'ldnz'):
        for _t in range(40):
            x, y = cx + rnd.randint(-2, 2), cy + rnd.randint(-2, 2)
            if 0 <= x < W and 0 <= y < H and rows[y][x] == '.':
                rows[y][x] = 'q'
                CHESTS["%d,%d" % (x, y)] = next_reward()
                break

# ---- reachability + trees -----------------------------------------------------------------------------
def level(x, y):
    c = hts[y][x]
    if c in DIRS:
        # stair cell: height is the low side
        dx, dy = DIRS[c]
        lc = hts[y - dy][x - dx]
        return int(lc) if lc.isdigit() else 0
    return int(c) if c.isdigit() else 0

def stairs_dir(x, y):
    c = hts[y][x]
    return DIRS.get(c)

def walkable_cell(x, y, trees_block):
    if not (0 <= x < W and 0 <= y < H):
        return False
    ch = rows[y][x]
    if ch in ' #':
        return False
    if ch == 'T' and (trees_block or (x, y) in RING):
        return False
    if ch in 'HFVQ' or ch == 'R' or ch == 'L' and False:
        return ch not in 'HFVQ'
    return True

def can_step(a, b, trees_block):
    (ax, ay), (bx, by) = a, b
    if not (walkable_cell(ax, ay, trees_block) and walkable_cell(bx, by, trees_block)):
        return False
    sa, sb = stairs_dir(ax, ay), stairs_dir(bx, by)
    la, lb = level(ax, ay), level(bx, by)
    dx, dy = bx - ax, by - ay
    if sb:
        if (dx, dy) == sb:   # climbing up the stair
            return lb == la or lb + 1 == la or la == lb
        if (dx, dy) == (-sb[0], -sb[1]):
            return True
        return False
    if sa:
        if (dx, dy) == sa:
            return True
        if (dx, dy) == (-sa[0], -sa[1]):
            return True
        return False
    return la == lb

def bfs(start, trees_block=True):
    seen = {start: None}
    q = deque([start])
    while q:
        c = q.popleft()
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + d[0], c[1] + d[1])
            if n in seen:
                continue
            if can_step(c, n, trees_block):
                seen[n] = c
                q.append(n)
    return seen

# forests
FOREST = {'r': 0.34, 'm': 0.07, 'i': 0.03, 'h': 0.12, 'g': 0.05, 'x': 0.16, 'o': 0.0, 'e': 0.05, 's': 0.06, 'n': 0.14}
for y in range(H):
    for x in range(W):
        if rows[y][x] == '.' and hts[y][x].isdigit():
            d = FOREST.get(reg[y][x], 0.0)
            if d and rnd.random() < d:
                rows[y][x] = 'T'
# keep clearings around landmarks
POI = [(x, y) for y in range(H) for x in range(W) if rows[y][x] in 'PWYLGkoevRNKBVQqSU']
for (px, py) in POI:
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if rows[py + dy][px + dx] == 'T' and (px + dx, py + dy) not in RING:
                rows[py + dy][px + dx] = '.'
# make sure every landmark is reachable: carve the shortest route through trees when needed
reach = bfs(START, True)
problems = []
for (px, py) in POI:
    if (px, py) in reach or rows[py][px] in 'VQ':
        continue
    anyreach = bfs(START, False)
    if (px, py) not in anyreach:
        problems.append((px, py, rows[py][px]))
        continue
    c = (px, py)
    while c is not None:
        x, y = c
        if rows[y][x] == 'T' and (x, y) not in RING:
            rows[y][x] = '.'
        c = anyreach[c]
reach = bfs(START, True)
for (px, py) in POI:
    # landmarks sitting on a blocker (houses, oven) are checked by their neighbours instead
    if (px, py) not in reach:
        nb = any(((px + d[0], py + d[1]) in reach) for d in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if not nb:
            problems.append((px, py, rows[py][px]))
# enemies must stand on reachable ground too
bad_enemies = []
for y in range(H):
    for x in range(W):
        if rows[y][x] in 'gxldnz' and (x, y) not in reach:
            rows[y][x] = '.'
            bad_enemies.append((x, y))

print("walkable cells reachable:", len(reach))
print("unreachable landmarks:", problems)
print("enemies removed (unreachable):", len(bad_enemies))
cnt = {}
for y in range(H):
    for x in range(W):
        cnt[rows[y][x]] = cnt.get(rows[y][x], 0) + 1
print({k: v for k, v in sorted(cnt.items()) if k != ' '})

# ---- write ---------------------------------------------------------------------------------------------
def fmt(name, arr):
    return "const %s: Array[String] = [\n%s,\n]\n" % (name, ",\n".join('\t"%s"' % "".join(r) for r in arr))

out = '''class_name PrologueMap
extends RefCounted
## GENERATED by tools/gen_overworld.py: edit that script (or the core in tools/prologue_core.json),
## not this file. The overworld: the Prologue Plains, Thistledown and the lands around them.
##
## ROWS (what is on each cell)
##   ' ' void (edge of the page)   '.' plains floor   ',' town floor   '#' plot hole (pit)
##   P player start   T tree   C Mnemosynth crystal   W the tutorial sign   X town sign
##   H house (2x2 block)   F forge (2x2 block)   N Garrick   K Pip   B Maud
##   V Maud's cold oven   Q Pip's storybook   g Bare   x Mite   l Run-on   d Dangler   n Censor   z Ellipsis   R Redactor bar (3 wide)   D training dummy
##   Y lantern post (a waypoint)   L lore stone   G the Margin Gate
##   q chest   S riddle stone   U riddle gate (opens when the stone is rewritten correctly)
##   k Softcover Binding   o Oxford Comma   e Eraser Crumbs   v Void Ink  (one-time pickups)
## HEIGHTS: '0'..'9' level; letters e/w/s/n are stairs rising toward that direction.
## REGION_ROWS: one letter per cell naming the region (see REGIONS).

const OFFSET := Vector2i(%d, %d)      # where the original 40x26 core sits (old saves are shifted by this)
const START_CELL := Vector2i(%d, %d)
const REGIONS := %s
const WAYPOINTS: Array[Dictionary] = %s
const LORE := %s
const CHESTS := %s
const RIDDLES := %s

''' % (OX, OY, START[0], START[1], json.dumps(REGIONS), json.dumps([{"id": a, "name": b, "cell": [c[0], c[1]], "region": d} for a, b, c, d in WAYPOINTS]).replace('true', 'true'),
       json.dumps({k: [v[0], v[1]] for k, v in LORE.items()}), json.dumps(CHESTS), json.dumps(RIDDLES))
out += fmt('ROWS', rows) + "\n" + fmt('HEIGHTS', hts) + "\n" + fmt('REGION_ROWS', reg)
out += '''
static func region_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= REGION_ROWS.size() or cell.x < 0 or cell.x >= REGION_ROWS[cell.y].length():
		return "o"
	return REGION_ROWS[cell.y][cell.x]

static func region_name(cell: Vector2i) -> String:
	return REGIONS.get(region_at(cell), "The Prologue Plains")
'''
open('data/prologue_map.gd', 'w').write(out)
print("written", W, "x", H)
sys.exit(1 if problems else 0)
