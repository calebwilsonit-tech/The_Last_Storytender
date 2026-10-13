#!/usr/bin/env python3
"""Generates data/memory_forge_map.gd: Garrick's memory, a hub of connected rooms. The Forge (the boss arena,
columns 42+) is kept exactly as it was (tools/forge_arena.json). Run from the repo root:  python3 tools/gen_forge.py

Rooms: S the Cold Hearth (start, echo tutorial) -> H the hub. From H: the Bellows Loft (north), the Apprentice's
Bench (south-west), the Night Watch (south-east). Each wing has a gated inner room holding a Token. Three Tokens
open the Forge Door (D) at the east end of the hub."""
import json
W, HT = 60, 30
arena = json.load(open('tools/forge_arena.json'))
R = [[' '] * W for _ in range(HT)]
H = [[' '] * W for _ in range(HT)]
for y, (r, h) in enumerate(zip(arena['rows'], arena['heights'])):
    for x, (c, e) in enumerate(zip(r, h)):
        R[y][42 + x] = c
        H[y][42 + x] = e

def room(x0, y0, x1, y1, lv=0):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            R[y][x] = 'm'
            H[y][x] = str(lv)
def put(x, y, ch):
    assert R[y][x] != ' ', (x, y, ch)
    R[y][x] = ch
def stair(x, y, d):
    H[y][x] = d
    R[y][x] = 'm'

# S: the Cold Hearth
room(1, 8, 10, 14)
room(11, 10, 16, 12)                 # corridor
# H: the hub
room(17, 7, 38, 15)
room(39, 9, 41, 13)                  # forge-door corridor
# North wing: Bellows Loft
room(27, 5, 29, 6)
room(20, 1, 30, 4)                   # N1
room(31, 2, 31, 4)                   # gate l column
room(32, 1, 38, 4)                   # N2
room(36, 1, 38, 2, 1)                # ledge with plate j
stair(35, 2, 'e')
room(39, 2, 39, 4)                   # gate n column
room(40, 2, 41, 4)                   # token alcove
# South-west wing: Apprentice's Bench
room(19, 16, 21, 17)
room(8, 18, 22, 22)                  # A1
room(8, 18, 10, 20, 1)               # platform with plate b
stair(11, 19, 'w')
room(13, 23, 15, 23)                 # gate h row
room(10, 24, 18, 27)                 # A2
# South-east wing: Night Watch
room(31, 16, 33, 17)
room(25, 18, 39, 22)                 # B1
room(31, 23, 33, 23)                 # gate i row
room(28, 24, 36, 24)
room(31, 25, 33, 27)                 # token alcove (Redactor bar at y=25)

put(9, 13, 'P'); put(2, 10, 'E'); put(3, 13, 'a'); put(11, 11, 'g'); put(7, 10, 'f'); put(10, 14, 'k')
put(40, 11, 'D')
put(22, 2, 'e'); put(31, 3, 'l'); put(37, 1, 'j'); put(39, 3, 'n'); put(41, 3, 'V')
put(9, 19, 'b'); put(21, 22, 'c'); put(14, 23, 'h'); put(14, 26, 'T'); put(12, 20, 'y')
put(36, 20, 'd'); put(35, 20, 'Q'); put(32, 23, 'i'); put(32, 25, 'R'); put(32, 27, 'U'); put(27, 20, 'z')
for x, y in [(5, 12), (6, 12), (24, 12), (25, 12), (30, 9), (31, 9), (14, 21), (15, 21), (33, 21), (34, 21), (22, 3)]:
    if R[y][x] == 'm':
        R[y][x] = 'B'

# ---- checks: with the gates shut nothing behind them is reachable; with them open everything is ---------------------------
def reach(blocked):
    start = (9, 13)
    seen = {start}
    st = [start]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in seen or n in blocked or not (0 <= n[0] < W and 0 <= n[1] < HT):
                continue
            if R[n[1]][n[0]] in ' #B':
                continue
            a, b = H[y][x], H[n[1]][n[0]]
            la = int(a) if a.isdigit() else None
            lb = int(b) if b.isdigit() else None
            if la is not None and lb is not None and la != lb:
                continue
            seen.add(n)
            st.append(n)
    return seen
GATE_CELLS = {'g': [(11, 10), (11, 11), (11, 12)], 'l': [(31, 2), (31, 3), (31, 4)], 'n': [(39, 2), (39, 3), (39, 4)],
              'h': [(13, 23), (14, 23), (15, 23)], 'i': [(31, 23), (32, 23), (33, 23)], 'R': [(31, 25), (32, 25), (33, 25)],
              'D': [(40, y) for y in range(9, 14)]}
allc = [c for v in GATE_CELLS.values() for c in v]
shut = reach(set(allc))
def find(ch):
    return [(x, y) for y in range(HT) for x in range(W) if R[y][x] == ch]
for ch in 'aEPk':
    assert find(ch)[0] in shut, ch
for ch in 'bcdQ':
    pass
# hub, three wings' first rooms reachable with everything shut except the tutorial gate
tut = reach(set(c for k, v in GATE_CELLS.items() if k != 'g' for c in v))
for name, c in [('plate e', find('e')[0]), ('plate b', find('b')[0]), ('plate c', find('c')[0]), ('plate d', find('d')[0])]:
    assert c in tut, name
for name, c in [('token T', find('T')[0]), ('token U', find('U')[0]), ('token V', find('V')[0]), ('plate j', find('j')[0]), ('forge', (45, 11))]:
    assert c not in tut, name + ' reachable while shut'
full = reach(set())
for name, c in [('T', find('T')[0]), ('U', find('U')[0]), ('V', find('V')[0]), ('j', find('j')[0]), ('forge', (45, 11)), ('anvil', find('A')[0])]:
    assert c in full, name + ' unreachable when open'
for _k, _v in GATE_CELLS.items():
    assert len(full - reach(set(_v))) >= 8, "gate %s can be walked around" % _k
print("forge map ok:", len(full), "cells reachable")

doc = """## Garrick's memory, as a hub of rooms. 'm' floor  '#' plot hole  P start  E way out  B crates  k Oxford Comma
##   a b c d e j  echo plates   g h i l n  gates   D forge door (three tokens)   T U V  tokens (hammer, tongs, bellows)
##   R redactor bar (Lantern)  Q night guard   f y z  things to look at   (columns 42+ are the Forge, unchanged)
##   O frozen furnace  A anvil  Y young Garrick  w Wren  Z the Critic  1 2 3 memory shards
## HEIGHTS use the same format as PrologueMap."""
out = "class_name MemoryForgeMap\nextends RefCounted\n%s\n\nconst ROWS: Array[String] = [\n%s,\n]\n\nconst HEIGHTS: Array[String] = [\n%s,\n]\n" % (
    doc, ",\n".join('\t"%s"' % "".join(r) for r in R), ",\n".join('\t"%s"' % "".join(r) for r in H))
open('data/memory_forge_map.gd', 'w').write(out)
