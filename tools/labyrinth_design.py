#!/usr/bin/env python3
"""Design sheets for "The Labyrinth of Echoes" (from the overview the designer drew on the template).
Rooms are built here with rect()/put() so the same maps can later feed the real generator, and every drawn
echo walk is checked to stay on floor. Output: docs/dungeon_plans/labyrinth_*.png
Run from the repo root:  python3 tools/labyrinth_design.py"""
import math
from PIL import Image, ImageDraw, ImageFont

F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FS = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
def font(sz, b=False): return ImageFont.truetype(FB if b else F, sz)
BG, INK, GOLD, RED, BLUE, GREEN, GREY = "#f3ead3", "#2a2218", "#d9a62e", "#b8443a", "#2f6a8a", "#4f8a3a", "#c9bd98"
PATH_COLORS = {"E1": "#2f6a8a", "E2": "#7a4ab0", "E3": "#1f8a7a", "E4": "#b06a1a", "you": "#d4572a"}


class Room:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [['#'] * w for _ in range(h)]
        self.labels = []      # (x, y, text, color)
        self.paths = []       # (who, [(x, y)...], note)
        self.marks = []       # (x, y, text) small circled notes on the map, e.g. "wait 4 s"

    def rect(self, x0, y0, x1, y1, ch='.'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def put(self, x, y, ch):
        self.g[y][x] = ch

    def label(self, x, y, text, color=RED):
        self.labels.append((x, y, text, color))

    def path(self, who, pts, note=""):
        for x, y in pts:
            assert self.g[y][x] != '#', "%s walks into void at %d,%d" % (who, x, y)
        self.paths.append((who, pts, note))

    def mark(self, x, y, text):
        self.marks.append((x, y, text))


def draw_room(d, room, ox, oy, cell):
    fill = {'#': "#2b2a38", '.': "#e8dfc2", '^': "#f1dca0", '%': "#f7ecc6", 'S': "#cdb980", '~': "#2d2147",
            'L': "#bfe8f2", 'F': "#7fb2d6", 'W': "#9a7652", '_': "#15101c", 'D': "#7a2a24"}
    for y in range(room.h):
        for x in range(room.w):
            ch = room.g[y][x]
            r = (ox + x * cell, oy + y * cell, ox + (x + 1) * cell, oy + (y + 1) * cell)
            cx, cy = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
            base = fill.get(ch, "#e8dfc2")
            d.rectangle(r, fill=base, outline="#2b2a38" if ch == '#' else "#c9bd98")
            s = cell / 30.0
            if ch == 'S':
                for i in range(4):
                    d.line((r[0] + 3, r[1] + (5 + i * 6) * s, r[2] - 3, r[1] + (5 + i * 6) * s), fill=INK, width=2)
            elif ch == 'L':
                for i in range(3):
                    d.line((r[0] + 3, r[1] + (6 + i * 8) * s, r[2] - 3, r[1] + (6 + i * 8) * s), fill="#3aa0c0", width=1)
            elif ch == 'F':
                d.arc((r[0] + 3, cy - 5, r[2] - 3, cy + 5), 200, 340, fill="white", width=2)
            elif ch == 'W':
                for i in range(-2, 3):
                    d.line((r[0] + i * 8 * s, r[3], r[0] + (i * 8 + 16) * s, r[1]), fill="#5e4428", width=2)
            elif ch == '=':
                d.rectangle((r[0] + 2, r[1] + 2, r[2] - 2, r[3] - 2), fill=RED, outline=INK, width=2)
            elif ch == 'D':
                d.text((cx, cy), "▣", font=font(int(14 * s) + 4, True), fill=GOLD, anchor="mm")
            elif ch == 'E':
                d.polygon([(cx, cy - 10 * s), (cx + 10 * s, cy + 8 * s), (cx - 10 * s, cy + 8 * s)], fill=GREEN, outline=INK)
            elif ch == 'X':
                d.ellipse((cx - 11 * s, cy - 11 * s, cx + 11 * s, cy + 11 * s), outline=INK, width=3); d.text((cx, cy), "X", font=font(int(12 * s) + 2, True), fill=INK, anchor="mm")
            elif ch == 'K':
                d.ellipse((cx - 11 * s, cy - 11 * s, cx + 11 * s, cy + 11 * s), fill=GOLD, outline=INK, width=2); d.text((cx, cy), "K", font=font(int(12 * s) + 2, True), fill=INK, anchor="mm")
            elif ch == 'k':
                d.ellipse((cx - 9 * s, cy - 9 * s, cx + 9 * s, cy + 9 * s), outline=GOLD, width=3)
            elif ch == 'R':
                d.rectangle((cx - 11 * s, cy - 8 * s, cx + 11 * s, cy + 8 * s), fill="#a9743f", outline=INK, width=2); d.text((cx, cy), "R", font=font(int(11 * s) + 2, True), fill="white", anchor="mm")
            elif ch == 'B':
                d.ellipse((cx - 11 * s, cy - 11 * s, cx + 11 * s, cy + 11 * s), fill="#fff3a8", outline=INK, width=2)
                for a in range(0, 360, 45):
                    d.line((cx + math.cos(math.radians(a)) * 12 * s, cy + math.sin(math.radians(a)) * 12 * s,
                            cx + math.cos(math.radians(a)) * 15 * s, cy + math.sin(math.radians(a)) * 15 * s), fill=GOLD, width=2)
            elif ch == '$':
                d.rectangle((cx - 12 * s, cy - 9 * s, cx + 12 * s, cy + 5 * s), fill="#fbe9dc", outline=INK, width=2)
                d.line((cx - 7 * s, cy - 2 * s, cx + 7 * s, cy - 2 * s), fill=RED, width=2)
            elif ch == '?':
                d.ellipse((cx - 9 * s, cy - 9 * s, cx + 9 * s, cy + 9 * s), outline=INK, width=2); d.text((cx, cy), "?", font=font(int(11 * s) + 2, True), fill=INK, anchor="mm")
            elif ch in "HY":
                col = BLUE if ch == 'H' else "#7a4ab0"
                d.ellipse((cx - 13 * s, cy - 9 * s, cx + 13 * s, cy + 9 * s), outline=col, width=4, fill="#cfe3ef")
                d.text((cx, cy), "x2", font=font(int(10 * s) + 2, True), fill=col, anchor="mm")
            elif ch.islower() and ch not in "k":
                d.ellipse((cx - 11 * s, cy - 7 * s, cx + 11 * s, cy + 7 * s), outline=BLUE, width=3, fill="#cfe3ef")
                d.text((cx, cy), ch, font=font(int(10 * s) + 2, True), fill=BLUE, anchor="mm")
    # paths
    for who, pts, note in room.paths:
        col = PATH_COLORS[who]
        P = [(ox + (x + 0.5) * cell, oy + (y + 0.5) * cell) for x, y in pts]
        off = {"E1": -4, "E2": 4, "E3": -8, "E4": 8, "you": 0}[who] * cell / 30
        P = [(x + off, y + off) for x, y in P]
        for i in range(len(P) - 1):
            x1, y1 = P[i]; x2, y2 = P[i + 1]
            n = max(int(math.hypot(x2 - x1, y2 - y1) // 9), 1)
            for j in range(0, n, 2):
                a, b = j / n, min((j + 1) / n, 1.0)
                d.line((x1 + (x2 - x1) * a, y1 + (y2 - y1) * a, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b), fill=col, width=4)
        if len(P) > 1:
            ex, ey = P[-1]; px, py = P[-2]
            ang = math.atan2(ey - py, ex - px)
            d.polygon([(ex, ey), (ex - 13 * math.cos(ang - .45), ey - 13 * math.sin(ang - .45)), (ex - 13 * math.cos(ang + .45), ey - 13 * math.sin(ang + .45))], fill=col)
        sx, sy = P[0]
        d.rounded_rectangle((sx - 15, sy - 9, sx + 15, sy + 9), 5, fill=col)
        d.text((sx, sy), who, font=font(11, True), fill="white", anchor="mm")
    for x, y, text in room.marks:
        cx, cy = ox + (x + 0.5) * cell, oy + (y + 0.5) * cell
        tw = d.textlength(text, font=font(12, True))
        d.rounded_rectangle((cx - tw / 2 - 5, cy - 30, cx + tw / 2 + 5, cy - 12), 5, fill="#fff8e0", outline=INK)
        d.text((cx, cy - 21), text, font=font(12, True), fill=INK, anchor="mm")
    for x, y, text, color in room.labels:
        cx, cy = ox + (x + 0.5) * cell, oy + (y + 0.5) * cell
        tw = d.textlength(text, font=font(13, True))
        d.rounded_rectangle((cx - tw / 2 - 4, cy - 10, cx + tw / 2 + 4, cy + 10), 4, fill="#fff8e0", outline=color)
        d.text((cx, cy), text, font=font(13, True), fill=color, anchor="mm")


def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if d.textlength((cur + " " + w).strip(), font=f) > width and cur:
            lines.append(cur); cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur: lines.append(cur)
    return lines


# =================================================================================================================
# The rooms
# =================================================================================================================
ROOMS = []

def hub():
    r = Room(17, 12)
    r.rect(1, 1, 15, 9)
    r.rect(7, 0, 9, 0)                       # north: to room 4
    r.rect(0, 4, 0, 6); r.rect(16, 4, 16, 6)  # west: room 2, east: room 6
    r.put(8, 5, 'E')
    r.put(3, 2, '?'); r.put(13, 2, '?'); r.put(8, 2, '?')
    r.put(7, 8, 'k'); r.put(8, 8, 'k'); r.put(9, 8, 'k')
    for x in (7, 8, 9): r.put(x, 10, 'D')
    r.rect(7, 11, 9, 11)
    r.label(8, 11, "LAST DOOR: K1 + K2 + K3", RED)
    r.label(1, 5, "to 2", INK); r.label(15, 5, "to 6", INK); r.label(8, 1, "to 4", INK)
    return ("1  HUB  (start)", "difficulty 1 · 0 echoes", r,
            ["The hub has three signs, one per new rule you will meet: 'An echo walks your walk, pauses where you paused, and stays where you stopped.' 'A gate will not shut on you while you stand in it.' 'Some plates are heavy: they need two.'",
             "Three key sockets beside the last door show K1 K2 K3 as you bring them. Wings: west (2-3), north (4-5), east (6-7). The last door leads down to 8."])

def split_gate():
    r = Room(26, 9)
    r.rect(1, 1, 24, 3); r.rect(1, 5, 24, 7); r.rect(22, 1, 24, 7)
    for y in (1, 2, 3):
        r.put(0, y, '='); r.put(10, y, '='); r.put(17, y, '=')
    r.rect(25, 5, 25, 7); r.put(25, 6, 'E')
    r.put(12, 6, 'a'); r.put(6, 6, 'b'); r.put(20, 6, 'c')
    r.label(17, 0, "N1 <- a", RED); r.label(10, 0, "N2 <- b", RED); r.label(1, 0, "G1 <- c", RED)
    r.label(12, 4, "wall", INK)
    r.path("E1", [(23, 6), (6, 6)])
    r.path("E2", [(23, 7), (12, 7), (12, 6), (20, 6)])
    r.mark(12, 6, "E2 waits ~4 s")
    r.path("you", [(20, 5), (23, 5), (23, 2), (17, 2), (10, 2), (0, 2)])
    return ("2  The Split Gate", "difficulty 3 · 2 echoes · teaches: timed split routing", r,
            ["Two lanes with a wall between them. You walk the north lane; the plates are in the south lane. North gate N1 opens while plate a is held, N2 while b is held, and the exit G1 while c is held.",
             "Three plates, two echoes. The idea: an echo replays your timing. Echo 1 stands on b for good. Echo 2 walks to a, WAITS about 4 seconds, then walks on to c and stays.",
             "When you stop recording you are standing on c. Run up and through N1 while echo 2 is still waiting on a. N2 is held by echo 1. By the time you reach G1, echo 2 has arrived on c and G1 is open.",
             "Trap: two echoes standing still on a and b leaves G1 shut, and you cannot hold c and walk to G1."])

def vault_k1():
    r = Room(22, 11)
    r.rect(3, 1, 10, 9); r.rect(1, 4, 1, 6)
    for y in (4, 5, 6):
        r.put(2, y, '='); r.put(11, y, '=')
    r.put(1, 5, 'K')
    r.rect(12, 1, 20, 9); r.rect(21, 4, 21, 6); r.put(21, 5, 'E')
    r.put(19, 1, 'o'); r.put(10, 5, 'i'); r.put(6, 1, 'p'); r.put(6, 9, 'q')
    r.label(11, 3, "V <- o or i", RED); r.label(2, 3, "<- p + q", RED)
    r.path("E1", [(20, 5), (19, 2), (19, 1)])
    r.path("you", [(19, 1), (12, 5), (11, 5), (8, 5)])
    r.path("E2", [(8, 4), (6, 2), (6, 1)])
    r.path("E3", [(8, 6), (6, 8), (6, 9)])
    r.mark(6, 9, "E1 is dropped: V shuts")
    return ("3  Vault of Key K1", "difficulty 3 · 2 echoes · teaches: plates in and out (back-and-forth)", r,
            ["The vault door V opens while plate o (far out in the hall) OR plate i (just inside the door) is held. The key sits behind a grille that needs BOTH p and q.",
             "Echo 1 on o, walk in. Echo 2 on p. Echo 3 on q: you only keep two, so echo 1 vanishes and V slams shut with you inside. The grille opens: take K1.",
             "The idea: you are not trapped. Step on i, then step into the doorway (a gate will not shut on you while you stand in it) and walk out.",
             "Trap: trying to keep echo 1 outside. The puzzle wants you to let it go."])

def bridge():
    r = Room(20, 13)
    r.rect(1, 9, 18, 11); r.rect(1, 4, 18, 8, '~'); r.rect(1, 1, 18, 3)
    r.rect(9, 4, 11, 8, 'L')
    r.rect(9, 12, 11, 12); r.put(10, 12, 'E')
    r.put(2, 10, 'B')
    for y in (1, 2, 3): r.put(13, y, '_')
    for x in (15, 16, 17): r.put(x, 0, '_')
    r.label(10, 6, "light bridge: solid while the beacon is lit", "#2a7a95")
    r.label(16, 0, "G2 (Lantern bar)", RED)
    r.path("E1", [(10, 11), (3, 11), (3, 10)])
    r.mark(3, 10, "E1 ends with the Lantern ON, facing B")
    r.path("you", [(3, 9), (10, 9), (10, 3), (12, 2)])
    r.path("you", [(14, 2), (16, 1)])
    return ("4  Luminescent Bridge", "difficulty 3 · 1 echo · teaches: crossing Lantern barriers", r,
            ["A pit with a bridge of light that only exists while the beacon B is lit by a Lantern. You cannot light it and walk across at the same time.",
             "The idea (new): an echo remembers your Lantern. Record yourself walking to the beacon and holding the Lantern on it, then stop. The echo stands there shining it for good.",
             "Cross the bridge. On the far bank two Lantern bars block the way; read them away with your own Lantern. The second one is G2, the door to room 5.",
             "Trap: stopping the recording with the Lantern off, or facing away: the echo copies exactly what you did."])

def vault_k2():
    r = Room(20, 12)
    r.rect(1, 8, 14, 10); r.rect(8, 1, 14, 10); r.rect(2, 2, 6, 6)
    for y in (3, 4, 5): r.put(7, y, '='); r.put(15, y, '=')
    r.rect(16, 3, 18, 5); r.put(17, 4, 'K')
    r.rect(7, 11, 9, 11); r.put(8, 11, 'E')
    r.put(8, 4, 'l'); r.put(6, 4, 'm'); r.put(3, 4, 'H')
    r.label(7, 1, "C <- l or m", RED); r.label(15, 2, "V <- heavy H", RED); r.label(4, 7, "cage", INK)
    r.path("E1", [(9, 8), (8, 4), (7, 4), (3, 4)])
    r.mark(3, 3, "E2: stand still on H")
    r.path("you", [(4, 5), (6, 5), (6, 4), (7, 4), (10, 4), (14, 4), (17, 4)])
    return ("5  Vault of Key K2", "difficulty 3 · 2 echoes · teaches: echo stacking", r,
            ["The vault door V needs the heavy plate H, and H only goes down under TWO bodies. H sits in a cage. The cage gate C opens while plate l (outside) or m (inside) is held.",
             "Record echo 1: step on l, step into the gateway (it stays open while you are in it), walk on to H, stop. You are now in the cage, standing on H.",
             "The idea: an echo can be a recording of you standing still. Record echo 2 right there on H for a second. Two echoes on H: V opens.",
             "Leave the cage the way you learned in room 3: step on m, into the gateway, out. Take K2."])

def scribe():
    r = Room(24, 13)
    r.rect(1, 4, 6, 8); r.rect(0, 5, 0, 7); r.put(0, 6, 'E')
    for y in range(4, 9): r.put(7, y, 'W')
    r.rect(8, 2, 14, 10)
    r.rect(15, 2, 16, 10, 'F')
    r.rect(17, 2, 22, 10)
    for x in (18, 19, 20): r.put(x, 1, '=')
    r.rect(18, 0, 20, 0)
    r.put(2, 4, '$'); r.put(9, 2, '$'); r.put(22, 4, '$')
    r.put(12, 9, 'a'); r.put(21, 9, 'b')
    r.label(3, 3, "The wall STANDS / FALLS", "#8a5a2a"); r.label(10, 1, "The river FLOWS / FREEZES", "#2a5a8a")
    r.label(19, 0, "G3 <- a + b", RED); r.label(7, 11, "wall: down 10 s", INK); r.label(16, 11, "river: frozen 10 s", INK)
    r.path("E1", [(3, 6), (7, 6), (10, 8), (12, 9)])
    r.mark(3, 6, "rewrite: wall FALLS")
    r.path("you", [(12, 8), (9, 3)])
    r.path("E2", [(10, 4), (15, 5), (18, 7), (21, 9)])
    r.mark(10, 4, "rewrite: river FREEZES")
    r.path("you", [(21, 8), (19, 3), (19, 1), (19, 0)])
    return ("6  The Sentence Scribe", "difficulty 3 · 2 echoes · teaches: rewrite coordination", r,
            ["The exit G3 needs plates a and b. Plate a is behind a wall; plate b is across a river. Rewriting the wall FALLS or the river FREEZES lasts only 10 seconds.",
             "The river's stone is behind the wall. So: rewrite the wall, then record echo 1 walking through the gap onto a. You are now inside the walled yard.",
             "Rewrite the river, record echo 2 walking across the ice onto b. The ice melts and the wall stands again, but echoes stay where they stopped. G3 opens.",
             "The idea: an echo can be left somewhere you can no longer reach. A third stone on the far bank lets you cross back later."])

def vault_k3():
    r = Room(22, 11)
    r.rect(1, 1, 15, 9)
    for y in (4, 5, 6): r.put(16, y, '=')
    r.rect(17, 4, 19, 6); r.put(18, 5, 'K'); r.put(17, 5, 'n')
    r.rect(7, 10, 9, 10); r.put(8, 10, 'E')
    r.put(3, 5, 'Y'); r.put(11, 5, 'Y')
    r.label(3, 7, "Y1", "#7a4ab0"); r.label(11, 7, "Y2", "#7a4ab0"); r.label(16, 3, "D <- Y1 + Y2 down", RED)
    r.path("E1", [(8, 9), (3, 6), (3, 5)])
    r.path("E2", [(8, 8), (4, 5), (11, 5)])
    r.mark(4, 4, "E2 waits ~3 s with E1")
    r.path("you", [(11, 4), (15, 5), (18, 5)])
    return ("7  Vault of Key K3", "difficulty 3.5 · 2 echoes · teaches: synchronized heavy switches", r,
            ["Two heavy switches, Y1 and Y2. Each goes down under two bodies and springs back up 6 seconds after one steps off. The vault door D is open only while BOTH are down.",
             "You have three bodies: echo 1, echo 2 and you. Echo 1 stands on Y1. Echo 2 stands on Y1 for about 3 seconds (Y1 goes down), then walks to Y2 and stops. Stop recording there: you are on Y2.",
             "Wait on Y2. Echo 2 replays: Y1 goes down with echo 1, then echo 2 walks over to you, Y2 goes down too. Both down: D opens. Step off and walk through before Y1 springs back.",
             "The idea: you are in step with your own echo. Plate n inside lets you out."])

def descent():
    r = Room(24, 21)
    r.rect(10, 0, 12, 0); r.put(11, 0, 'E')
    r.rect(1, 1, 22, 3, '%')
    r.put(4, 2, 'H')
    for x in (19, 20, 21): r.put(x, 3, '='); r.put(x, 4, 'S')
    r.rect(1, 5, 22, 8, '^'); r.put(17, 7, 'B')
    r.rect(1, 9, 22, 10, '~'); r.rect(2, 9, 4, 10, 'L')
    r.rect(1, 11, 22, 12, '^')
    for x in (19, 20, 21): r.put(x, 13, 'S')
    r.rect(1, 14, 22, 18)
    for y in range(14, 19): r.put(12, y, 'W')
    r.put(20, 15, '$'); r.put(5, 14, '$'); r.put(3, 16, 'p'); r.put(21, 17, 'X')
    for x in (16, 17, 18): r.put(x, 19, '=')
    r.rect(16, 20, 18, 20); r.put(17, 20, 'R')
    r.label(20, 2, "stair gate <- H (x2)", RED); r.label(11, 6, "level 1", INK); r.label(11, 2, "level 2", INK)
    r.label(8, 16, "level 0", INK); r.label(17, 18, "<- p", RED)
    r.path("E1", [(10, 1), (4, 1), (4, 2)])
    r.path("E2", [(12, 2), (5, 2), (4, 2)])
    r.path("you", [(6, 3), (20, 2), (20, 5)])
    r.path("E3", [(20, 6), (16, 7)])
    r.mark(16, 7, "E3: Lantern on B")
    r.path("you", [(15, 8), (3, 8), (3, 11), (20, 11), (20, 14)])
    r.path("E4", [(19, 16), (12, 16), (3, 16)])
    r.mark(19, 16, "rewrite: wall FALLS")
    r.path("you", [(4, 15), (5, 15)])
    r.path("you", [(13, 17), (17, 18), (17, 20)])
    return ("8  The Final Descent", "difficulty 3.5 · 2 echoes at a time · teaches: the multi-task final solve", r,
            ["Three levels down to the reward. Each step uses something from a wing, and each new echo pushes out your oldest one, which is fine: you are already past what it held.",
             "Level 2: two echoes stand on the heavy plate H, the stair gate opens, go down. Level 1: echo 3 shines your Lantern on the beacon (echo 1 vanishes, the stair shuts behind you, no matter). Cross the light bridge, go down.",
             "Level 0: rewrite the wall FALLS and record echo 4 through it onto plate p (echo 2 vanishes). The reward door opens. Rewrite the wall again from the inside stone to come back out. Take the reward, leave by X.",
             "The idea: count your echoes and spend them in order."])


ROOM_FUNCS = [hub, split_gate, vault_k1, bridge, vault_k2, scribe, vault_k3, descent]


def page(rooms, path, title, sub):
    W = 2000
    panels = []
    for fn in rooms:
        t, diff, room, notes = fn()
        panels.append((t, diff, room, notes))
    def cell_of(room): return min(34, 900 // room.w)
    def ph_of(room): return max(room.h * cell_of(room) + 100, 70 + 22 * 15)
    H = 140 + sum(ph_of(p[2]) + 30 for p in panels)
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.text((30, 20), title, font=ImageFont.truetype(FS, 34), fill=INK)
    d.text((32, 68), sub, font=font(16), fill="#6a5a3c")
    y = 120
    for t, diff, room, notes in panels:
        cell = cell_of(room)
        ph = ph_of(room)
        d.rounded_rectangle((20, y, W - 20, y + ph), 12, fill="#f9f3e2", outline=INK, width=2)
        d.text((40, y + 12), t, font=font(22, True), fill=INK)
        d.text((40, y + 42), diff, font=font(15, True), fill=RED)
        draw_room(d, room, 40, y + 70 + 10, cell)
        nx = 40 + room.w * cell + 40
        ty = y + 20
        for i, n in enumerate(notes):
            for line in wrap(d, n, font(15, i == 1), W - nx - 50):
                d.text((nx, ty), line, font=font(15, i == 1), fill=INK); ty += 21
            ty += 12
        y += ph + 30
    im = im.crop((0, 0, W, y + 10))
    im.save(path)


def overview():
    W, H = 2000, 990
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.text((30, 20), "The Labyrinth of Echoes: the dungeon, built from your overview", font=ImageFont.truetype(FS, 34), fill=INK)
    d.text((32, 68), "Your layout and room list, unchanged. Each room now has one idea you must notice. Skills: echo / Lantern / rewrite. Difficulty 3 means you have to stop and think.", font=font(16), fill="#6a5a3c")
    boxes = {1: (720, 520), 2: (380, 520), 3: (130, 300), 4: (720, 300), 5: (720, 110), 6: (1060, 520), 7: (1310, 300), 8: (720, 790)}
    info = {1: ("HUB (start)", "0 echoes · signs teach the 3 rules"),
            2: ("The Split Gate", "an echo pauses on one plate,\nthen walks on to another"),
            3: ("Vault of Key K1", "let your outside echo go;\nthe inside plate lets you out"),
            4: ("Luminescent Bridge", "an echo keeps your Lantern lit\n(new)"),
            5: ("Vault of Key K2", "two echoes on one heavy plate\n(new heavy plate)"),
            6: ("The Sentence Scribe", "leave echoes beyond a wall\nand a river that close again"),
            7: ("Vault of Key K3", "walk in step with your echo:\ntwo spring switches (new)"),
            8: ("The Final Descent", "three levels; spend your\nechoes in order. Reward R")}
    bw, bh = 300, 150
    def c(n): x, y = boxes[n]; return (x + bw / 2, y + bh / 2)
    for a, b, lab in [(1, 2, ""), (2, 3, "G1"), (1, 4, ""), (4, 5, "G2"), (1, 6, ""), (6, 7, "G3"), (1, 8, "LAST DOOR K1+K2+K3")]:
        (x1, y1), (x2, y2) = c(a), c(b)
        d.line((x1, y1, x2, y2), fill=INK, width=10); d.line((x1, y1, x2, y2), fill="#f7f1df", width=5)
        if lab:
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            d.rectangle((mx - 8, my - 8, mx + 8, my + 8), fill=RED, outline=INK)
            d.text((mx + 14, my), lab, font=font(14, True), fill=RED, anchor="lm")
    for n, (x, y) in boxes.items():
        fillc = {1: "#ece0bf", 2: "#dbe8d0", 3: "#dbe8d0", 4: "#d3e0ee", 5: "#d3e0ee", 6: "#eed6d0", 7: "#eed6d0", 8: "#e2c9c9"}[n]
        d.rounded_rectangle((x, y, x + bw, y + bh), 14, fill=fillc, outline=INK, width=3)
        d.text((x + 14, y + 12), "%d  %s" % (n, info[n][0]), font=font(18, True), fill=INK)
        for k, line in enumerate(info[n][1].split("\n")):
            d.text((x + 14, y + 50 + k * 22), line, font=font(15), fill=INK)
        if n in (3, 5, 7):
            d.text((x + bw - 16, y + 14), "K%d" % {3: 1, 5: 2, 7: 3}[n], font=font(18, True), fill="#9a6a10", anchor="ra")
    nx = 1660
    d.rounded_rectangle((nx - 20, 110, W - 20, H - 20), 12, fill="#f9f3e2", outline=INK, width=2)
    y = 126
    blocks = [
        ("New parts I would build", "Heavy plate (needs two bodies). Spring switch (a heavy plate that stays down 6 s after you step off). Echo Lantern (an echo copies your Lantern and keeps it lit). Beacon + light bridge. Wall and river sentences that last 10 s. Gates that open from either of two plates."),
        ("Rules that stop you getting stuck", "Wing gates G1-G3 stay open once you are through. Every vault has an inside plate next to its door. Every timed wall or river has a stone on both sides. Dying clears your echoes and resets the room."),
        ("How the difficulty climbs", "2 and 4 each teach one new trick. 3, 5 and 6 add a second step to it. 7 needs timing. 8 needs all of it, in order."),
        ("What I need from you", "Is each idea the right weight? Anything to cut or swap? Then I build it and play every room with the bot before pushing."),
    ]
    for head, text in blocks:
        d.text((nx, y), head, font=font(16, True), fill=RED); y += 26
        for line in wrap(d, text, font(14), W - nx - 40):
            d.text((nx, y), line, font=font(14), fill=INK); y += 19
        y += 16
    im.save("docs/dungeon_plans/labyrinth_overview.png")


if __name__ == "__main__":
    overview()
    page([hub, split_gate, vault_k1, bridge], "docs/dungeon_plans/labyrinth_rooms_1.png", "The Labyrinth of Echoes: rooms 1 to 4",
         "Dotted arrows: E1, E2... are the echo walks in the order you record them; orange is you. Red bars are gates; 'x2' plates need two bodies.")
    page([vault_k2, scribe, vault_k3, descent], "docs/dungeon_plans/labyrinth_rooms_2.png", "The Labyrinth of Echoes: rooms 5 to 8",
         "Dotted arrows: E1, E2... are the echo walks in the order you record them; orange is you. Red bars are gates; 'x2' plates need two bodies.")
    print("drawn")
