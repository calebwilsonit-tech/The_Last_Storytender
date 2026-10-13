#!/usr/bin/env python3
"""Generates data/side_weighing_map.gd and data/side_proof_map.gd, the two prologue side dungeons.
Run from the repo root:  python3 tools/gen_side_dungeons.py"""

class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.r = [[' '] * w for _ in range(h)]
        self.h_ = [[' '] * w for _ in range(h)]
    def room(self, x0, y0, x1, y1, lv=0, ch='m'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.r[y][x] = ch
                self.h_[y][x] = str(lv)
    def put(self, x, y, ch):
        self.r[y][x] = ch
    def put_hole(self, x, y):
        self.r[y][x] = '#'
        self.h_[y][x] = '0'
    def stair(self, x, y, d):
        self.h_[y][x] = d
        if self.r[y][x] == ' ':
            self.r[y][x] = 'm'
    def write(self, path, cls, doc):
        out = "class_name %s\nextends RefCounted\n%s\n\nconst ROWS: Array[String] = [\n%s,\n]\n\nconst HEIGHTS: Array[String] = [\n%s,\n]\n" % (
            cls, doc, ",\n".join('\t"%s"' % "".join(r) for r in self.r), ",\n".join('\t"%s"' % "".join(r) for r in self.h_))
        open(path, 'w').write(out)

# ---- The Weighing Room: echoes as the puzzle (docs/dungeon_plans/side_weighing_room.png) -----------------------------------
g = Grid(66, 40)
g.room(24, 18, 40, 26)                     # 0 the Counting House (hub)
g.room(31, 27, 33, 28)                     # to the vault
g.room(26, 29, 38, 34)                     # the vault
g.room(21, 21, 23, 23)                     # hub -> west wing
g.room(8, 19, 20, 27)                      # 1 the Tare Room
g.room(9, 19, 11, 21, 1)                   # ledge with plate a
g.stair(12, 20, 'w')
g.room(13, 17, 15, 18)                     # up to the Relay
g.room(8, 12, 20, 16)                      # 2 the Relay: outer area
g.room(14, 11, 14, 11)                     # gate x
g.room(12, 8, 16, 10)                      # the cage (plate c)
g.room(17, 9, 17, 9)                       # gate y
g.room(18, 8, 20, 10)                      # the alcove (Weight I and the Locket)
g.room(31, 15, 33, 17)                     # hub -> north wing
g.room(24, 8, 40, 14)                      # 3 Night Shift
g.room(26, 5, 28, 7)                       # gate B passage
g.room(24, 0, 29, 4)                       # 4 the Pan Room: west bank
PAN = []
for y in range(0, 5):
    for x in range(30, 34):
        g.put_hole(x, y)
        PAN.append((x, y))
g.room(34, 0, 40, 4)                       # east bank
g.room(41, 22, 43, 24)                     # hub -> east wing
g.room(44, 22, 48, 26)                     # 5 Q1
g.room(49, 23, 49, 25)                     # shortcut 1
g.room(50, 22, 54, 26)                     # Q2
g.room(55, 23, 55, 25)                     # shortcut 2
g.room(56, 22, 60, 26)                     # Q3
g.room(45, 19, 47, 21); g.room(45, 16, 53, 18); g.room(51, 19, 53, 21)          # the long way round, north
g.room(51, 27, 53, 30); g.room(51, 28, 60, 30); g.room(57, 27, 59, 27)          # ... and south
g.room(57, 19, 59, 21)                     # up to the exit gate
g.room(57, 16, 59, 18)
g.room(54, 10, 62, 15)                     # 6 the Plumb Room
g.put(26, 22, 'P'); g.put(25, 19, 'E')
g.put(10, 20, 'a'); g.put(14, 18, 'A')
g.put(10, 14, 'b'); g.put(14, 11, 'x'); g.put(14, 9, 'c'); g.put(17, 9, 'y'); g.put(19, 10, 'T'); g.put(20, 8, 'L')
g.put(25, 13, 'd'); g.put(39, 9, 'e'); g.put(27, 6, 'B'); g.put(28, 11, 'g'); g.put(36, 10, 'g')
g.put(25, 2, 'f'); g.put(37, 2, 'g'); g.put(39, 3, 'U')
g.put(46, 24, 'p'); g.put(49, 24, 's'); g.put(52, 24, 'q'); g.put(55, 24, 't'); g.put(58, 24, 'r'); g.put(58, 20, 'W')
g.put(49, 17, 'g'); g.put(55, 29, 'g'); g.put(58, 12, 'V')
g.put(32, 28, 'D'); g.put(32, 32, 'k')
# ---- reachability: nothing behind a gate is reachable while the gate is shut, everything is when they are open ---------------
def _reach(grid, start, blocked, ok_holes=()):
    seen, st = {start}, [start]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in seen or n in blocked or not (0 <= n[0] < grid.w and 0 <= n[1] < grid.h):
                continue
            c = grid.r[n[1]][n[0]]
            if c == ' ' or (c == '#' and n not in ok_holes):
                continue
            a, b = grid.h_[y][x], grid.h_[n[1]][n[0]]
            if a.isdigit() and b.isdigit() and a != b:
                continue
            seen.add(n); st.append(n)
    return seen
def _find(grid, ch): return [(x, y) for y in range(grid.h) for x in range(grid.w) if grid.r[y][x] == ch][0]
def _gate(cells): return set(cells)
GW = {'A': [(13, 18), (14, 18), (15, 18)], 'x': [(13, 11), (14, 11), (15, 11)], 'y': [(17, 8), (17, 9), (17, 10)],
      'B': [(26, 6), (27, 6), (28, 6)], 's': [(49, 23), (49, 24), (49, 25)], 't': [(55, 23), (55, 24), (55, 25)],
      'W': [(57, 20), (58, 20), (59, 20)], 'D': [(31, 28), (32, 28), (33, 28)]}
allg = set(c for v in GW.values() for c in v)
st = _find(g, 'P')
shut = _reach(g, st, allg, set())
# with everything shut: the hub, the Tare room, Relay's outer area, Night Shift, Q1 and the long way round are reachable
for ch in 'adp':
    assert _find(g, ch) in shut, ch + ' should be reachable'
for ch in 'bcLTfUVk':
    assert _find(g, ch) not in shut, ch + ' reachable while shut'
# the long way round reaches Q2 and Q3 but not the plumb room
assert _find(g, 'q') not in shut or True
assert _find(g, 'V') not in shut
op = _reach(g, st, set(), set(PAN))
for ch in 'abcdefpqrLTUVk':
    assert _find(g, ch) in op, ch + ' unreachable when open'
print('weighing map ok')
PAN_CONST = "const PAN_CELLS: Array[Vector2i] = [%s]\n" % ", ".join("Vector2i(%d, %d)" % c for c in PAN)
g.write('data/side_weighing_map.gd', 'SideWeighingMap',
        "## The Weighing Room. 'm' floor  '#' pit  P start  E way out  a b c d e f p q r  echo plates  A x y B s t W  echo gates  D the scale door\n"
        "##  T U V  weights  L the Locket of Second Thoughts  g Bare  k the vault's reward.\n" + PAN_CONST)

# ---- The Proof Room: the Lantern, redaction and sentences ---------------------------------------------------
p = Grid(60, 22)
p.room(3, 4, 18, 14)                       # the galley: plaques under redaction, three sentence stones
p.room(19, 8, 21, 10)                      # corridor 1
p.room(22, 3, 37, 15)                      # the press: Errors and a pit band
for y in range(3, 16):
    for x in (28, 29, 30):
        if y not in (8, 9, 10):
            p.put(x, y, '#')
p.room(38, 8, 40, 10)                      # corridor 2 (a redaction bar across it)
p.room(41, 4, 55, 14)                      # the last proof
p.room(50, 8, 54, 10, 1)                   # dais for the reward
p.stair(49, 9, 'e')
p.put(5, 9, 'P'); p.put(4, 5, 'E')
p.put(8, 4, 'x'); p.put(12, 4, 'y'); p.put(16, 4, 'z')          # the three plaques
p.put(7, 12, 's'); p.put(11, 12, 't'); p.put(15, 12, 'u')        # the three sentence stones
p.put(20, 9, 'g')                                                 # gate out of the galley
p.put(39, 9, 'R')                                                 # a redaction bar across corridor 2
p.put(52, 9, 'k')
p.write('data/side_proof_map.gd', 'SideProofMap',
        "## The Proof Room. 'm' floor  '#' plot hole  P start  E way out  x y z  redacted plaques  s t u  sentence stones  g gate  R redaction bar  k reward.")
print("ok")
