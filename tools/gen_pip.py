#!/usr/bin/env python3
"""Generates data/memory_pip_map.gd: Pip's memory as "The Unfinished Library", a hub of connected rooms.
The Last Page (the boss arena and its vestibule, columns 30-45, rows 0-10) is kept exactly as it was
(tools/pip_arena.json). Run from the repo root:  python3 tools/gen_pip.py

Rooms: Front Matter (start, the bridge) -> the Reading Hall (hub) -> three wings: the Dark Wood (south, wolves and a
river), the Tall Tower (north-west, bars and a missing floor) and the Margin Archive (east, guards and a locked door).
Each wing holds one Torn Page; three pages open the door to The Last Page."""
import json
W, HT = 60, 36
arena = json.load(open('tools/pip_arena.json'))
R = [[' '] * W for _ in range(HT)]
H = [[' '] * W for _ in range(HT)]
for y, (r, h) in enumerate(zip(arena['rows'], arena['heights'])):
    for x, (c, e) in enumerate(zip(r, h)):
        c = 'p' if (y >= 6 and c in 'xgf') else c
        R[y][30 + x] = c
        H[y][30 + x] = e

def room(x0, y0, x1, y1, lv=0):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            R[y][x] = 'p'
            H[y][x] = str(lv)
def put(x, y, ch):
    assert R[y][x] != ' ', (x, y, ch)
    R[y][x] = ch
def stair(x, y, d):
    H[y][x] = d
    R[y][x] = 'p'
def hole(x0, y0, x1, y1):
    cells = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            R[y][x] = '#'; H[y][x] = '0'; cells.append((x, y))
    return cells

# Front Matter (start) and the chasm
room(2, 13, 10, 19)
CHASM = hole(11, 13, 13, 19)
BRIDGE = [(11, 16), (12, 16), (13, 16)]
# the Reading Hall
room(14, 11, 44, 19)
# Dark Wood
room(20, 20, 22, 21)
room(14, 22, 28, 26)
room(16, 27, 18, 27)
room(14, 28, 20, 34)
room(24, 28, 28, 31)
room(26, 32, 28, 32)
room(24, 33, 28, 34)
RIVER = hole(21, 28, 23, 31)
room(26, 28, 28, 29, 1)
stair(27, 30, 'n')
# Tall Tower
room(18, 4, 20, 10)
room(14, 0, 28, 3)
FLOOR = hole(22, 0, 23, 3)
# Margin Archive
room(45, 14, 47, 16)
room(48, 12, 57, 18)
room(51, 7, 53, 11)
room(50, 3, 57, 6)
room(47, 4, 49, 6)
room(55, 7, 57, 7)
room(55, 8, 57, 9)

put(3, 16, 'E'); put(4, 16, 'P'); put(9, 14, 'a')
put(15, 23, 'b'); put(27, 23, 'c'); put(17, 27, 'G')
for x, y in [(19, 24), (23, 23), (21, 25)]: put(x, y, 'g')
put(17, 33, 'd'); put(27, 28, 'k'); put(27, 32, 'u'); put(26, 34, 'f'); put(16, 31, 'x')
put(19, 9, 'R'); put(19, 7, 'R'); put(19, 8, 'x'); put(19, 5, 'e'); put(19, 4, 'v')
put(16, 1, 'h'); put(25, 2, 'g'); put(27, 1, 'F')
put(49, 17, 'i'); put(56, 13, 'l'); put(52, 9, 'w'); put(51, 14, 'g'); put(54, 17, 'g')
put(53, 4, 'm'); put(56, 4, 'n'); put(49, 5, 'S'); put(47, 5, 'j'); put(56, 7, 'y'); put(56, 9, 'N')
for x, y in [(16, 13), (30, 15), (40, 17), (6, 15), (6, 18)]:
    if R[y][x] == 'p': R[y][x] = 'T'
for x, y in [(24, 14), (36, 16), (8, 18), (21, 3)]:
    if R[y][x] == 'p': R[y][x] = 'C'

# ---- checks ---------------------------------------------------------------------------------------------------------------
def reach(blocked, bridge_ok=()):
    start = (4, 16)
    seen = {start}; st = [start]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in seen or n in blocked or not (0 <= n[0] < W and 0 <= n[1] < HT):
                continue
            c = R[n[1]][n[0]]
            if c == ' ' or (c == '#' and n not in bridge_ok):
                continue
            a, b = H[y][x], H[n[1]][n[0]]
            if a.isdigit() and b.isdigit() and a != b:
                continue
            seen.add(n); st.append(n)
    return seen
GATES = {'G': [(16, 27), (17, 27), (18, 27)], 'u': [(26, 32), (27, 32), (28, 32)], 'v': [(18, 4), (19, 4), (20, 4)],
         'w': [(51, 9), (52, 9), (53, 9)], 'y': [(55, 7), (56, 7), (57, 7)],
         'barA': [(18, 9), (19, 9), (20, 9)], 'barB': [(18, 7), (19, 7), (20, 7)], 'barS': [(49, 4), (49, 5), (49, 6)],
         'door': [(x, 5) for x in range(33, 40)]}
allg = {c for v in GATES.values() for c in v}
def find(ch): return [(x, y) for y in range(HT) for x in range(W) if R[y][x] == ch][0]
base = reach(allg, set(BRIDGE))
def has(rs, chs): return all(find(c) in rs for c in chs)
assert has(base, 'Pabcil')
assert not any(find(c) in base for c in 'dehjkmnfFN'), 'something is reachable too early'
st2 = reach(allg - set(GATES['G']), set(BRIDGE))
assert has(st2, 'd') and not any(find(c) in st2 for c in 'kfu')
st3 = reach(allg - set(GATES['G']) - set(GATES['barA']) - set(GATES['barB']), set(BRIDGE) | set(RIVER))
assert has(st3, 'dke') and not find('f') in st3
st4 = reach(allg - set(GATES['barA']) - set(GATES['barB']) - set(GATES['v']), set(BRIDGE))
assert has(st4, 'eh') and not find('F') in st4
full = reach(set(), set(BRIDGE) | set(RIVER) | set(FLOOR))
for ch in 'bcdefhijklmnuvwyfFNEP':
    assert find(ch) in full, ch + ' unreachable when open'
assert (35, 3) in full
for _k, _v in GATES.items():
    assert len(full - reach(set(_v), set(BRIDGE) | set(RIVER) | set(FLOOR))) >= 8, "gate %s can be walked around" % _k
print("pip map ok:", len(full), "cells reachable")

def consts():
    def lst(n, cs): return "const %s: Array[Vector2i] = [%s]" % (n, ", ".join("Vector2i(%d, %d)" % c for c in cs))
    return "\n".join([lst("BRIDGE_CELLS", BRIDGE), lst("RIVER_CELLS", RIVER), lst("FLOOR_CELLS", FLOOR)])
doc = """## Pip's memory: "The Unfinished Library", a pop-up storybook as a hub of rooms.
##   'p' page floor  '#' chasm / river / missing floor (rewrites bridge them)  P start  E exit  T paper tree  C crystal
##   a b c d e h i j  sentence stones (bridge, wolves, gate, river, stairs, floor, guards, door)
##   G u v w y  gates   k l m n  echo plates   R S  Lantern bars   f F N  torn pages   g Bare  x Mite
##   H door to the Last Page   Z the Spoiler   Y Pip   (columns 30-41, rows 0-10 are the Last Page, unchanged)
## HEIGHTS use the same format as PrologueMap."""
out = "class_name MemoryPipMap\nextends RefCounted\n%s\n\n%s\n\nconst ROWS: Array[String] = [\n%s,\n]\n\nconst HEIGHTS: Array[String] = [\n%s,\n]\n" % (
    doc, consts(), ",\n".join('\t"%s"' % "".join(r) for r in R), ",\n".join('\t"%s"' % "".join(r) for r in H))
open('data/memory_pip_map.gd', 'w').write(out)
