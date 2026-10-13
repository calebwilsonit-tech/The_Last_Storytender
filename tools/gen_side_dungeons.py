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
    def stair(self, x, y, d):
        self.h_[y][x] = d
        if self.r[y][x] == ' ':
            self.r[y][x] = 'm'
    def write(self, path, cls, doc):
        out = "class_name %s\nextends RefCounted\n%s\n\nconst ROWS: Array[String] = [\n%s,\n]\n\nconst HEIGHTS: Array[String] = [\n%s,\n]\n" % (
            cls, doc, ",\n".join('\t"%s"' % "".join(r) for r in self.r), ",\n".join('\t"%s"' % "".join(r) for r in self.h_))
        open(path, 'w').write(out)

# ---- The Weighing Room: echoes and plates ------------------------------------------------------------
g = Grid(64, 22)
g.room(3, 6, 14, 14)                       # room 1
g.room(10, 6, 13, 8, 1)                    # ledge with plate a
g.stair(11, 9, 'n')
g.room(15, 9, 17, 11)                      # corridor 1
g.room(18, 4, 31, 16)                      # room 2
g.room(26, 4, 30, 6, 1)                    # north ledge (plate c)
g.stair(28, 7, 'n')
g.room(20, 14, 24, 16, 1)                  # south ledge (plate d)
g.stair(22, 13, 's')
g.room(32, 9, 34, 11)                      # corridor 2
g.room(35, 5, 48, 15)                      # room 3
for y in range(5, 16):
    for x in (40, 41, 42):
        if y not in (9, 10, 11):
            g.put(x, y, '#')
g.room(49, 9, 51, 11)                      # corridor 3
g.room(52, 6, 60, 14)                      # the counting-house vault
g.put(5, 10, 'P'); g.put(4, 7, 'E')
g.put(12, 7, 'a'); g.put(6, 12, 'b'); g.put(16, 10, 'g')
g.put(28, 5, 'c'); g.put(22, 15, 'd'); g.put(25, 10, 'e'); g.put(33, 10, 'h')
g.put(38, 10, 'f'); g.put(45, 10, 'j'); g.put(50, 10, 'i')
g.put(58, 10, 'k'); g.put(20, 9, 'L')
g.write('data/side_weighing_map.gd', 'SideWeighingMap',
        "## The Weighing Room. 'm' floor  '#' plot hole  P start  E way out  a..e f j  weighing plates  g h i  gates  k reward.")

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
