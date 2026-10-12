#!/usr/bin/env python3
"""Draws schematic dungeon plans (docs/dungeon_plans/*.png) from the data below: rooms, what is in them, what
opens what. These are design drawings, not the in-game maps. Run from the repo root: python3 tools/draw_plans.py"""
import math
from PIL import Image, ImageDraw, ImageFont

F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FS = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
def font(sz, b=False): return ImageFont.truetype(FB if b else F, sz)
BG, INK, GOLD, RED, BLUE, GREEN = "#f3ead3", "#3a2a18", "#d9a62e", "#b8443a", "#2f6a8a", "#4f8a3a"
WING = {"hub": "#ece0bf", "a": "#dbe8d0", "b": "#d3e0ee", "c": "#eed6d0", "boss": "#e2c9c9", "start": "#e6e0c8"}

class Plan:
    def __init__(self, title, skills, W=1760, H=1060, map_w=1180):
        self.t, self.skills, self.W, self.H, self.mw = title, skills, W, H, map_w
        self.im = Image.new("RGB", (W, H), BG)
        self.d = ImageDraw.Draw(self.im)
        self.rooms, self.pos, self.notes = {}, {}, []
    def room(self, rid, name, x, y, w, h, wing="hub", num=None):
        x, y = x + 30, y + 120
        self.rooms[rid] = (x, y, w, h)
        d = self.d
        d.rounded_rectangle((x, y, x + w, y + h), 14, fill=WING[wing], outline=INK, width=3)
        d.text((x + 10, y + 6), name, font=font(15, True), fill=INK)
        if num:
            d.ellipse((x - 12, y - 12, x + 14, y + 14), fill=INK)
            d.text((x + 2, y + 1), str(num), font=font(15, True), fill="white", anchor="mm")
    def link(self, a, b, pts=None, label=None, lock=None):
        """pts: explicit polyline (map coords); lock: gate label drawn mid-way"""
        d = self.d
        pts = [(x + 30, y + 120) for x, y in pts]
        d.line(pts, fill=INK, width=12)
        d.line(pts, fill="#f7f1df", width=7)
        if lock:
            mx = (pts[0][0] + pts[-1][0]) // 2; my = (pts[0][1] + pts[-1][1]) // 2
            self.gate_icon(mx, my, lock, vertical=abs(pts[0][0] - pts[-1][0]) > abs(pts[0][1] - pts[-1][1]))
    def gate_icon(self, x, y, label, vertical=True):
        d = self.d
        if vertical: d.rectangle((x - 6, y - 22, x + 6, y + 22), fill=RED, outline=INK, width=2)
        else: d.rectangle((x - 22, y - 6, x + 22, y + 6), fill=RED, outline=INK, width=2)
        if label:
            d.text((x + 16, y) if vertical else (x + 30, y), label, font=font(12, True), fill=RED, anchor="lm")
    def item(self, rid, iid, kind, fx, fy, label=""):
        rx, ry, rw, rh = self.rooms[rid]
        x, y = rx + fx * rw, ry + fy * rh
        self.pos[iid] = (x, y)
        d = self.d
        if kind == "start":
            d.polygon([(x, y - 14), (x + 12, y + 10), (x - 12, y + 10)], fill=GREEN, outline=INK)
        elif kind == "plate":
            d.ellipse((x - 14, y - 9, x + 14, y + 9), outline=BLUE, width=3, fill="#cfe3ef"); d.ellipse((x - 6, y - 4, x + 6, y + 4), outline=BLUE, width=2)
        elif kind == "gate":
            self.gate_icon(x, y, "", vertical=True)
        elif kind == "token":
            d.ellipse((x - 14, y - 14, x + 14, y + 14), fill=GOLD, outline=INK, width=3); d.text((x, y), "★", font=font(16, True), fill=INK, anchor="mm")
        elif kind == "stone":
            d.rectangle((x - 18, y - 12, x + 18, y + 8), fill="#fbe9dc", outline=INK, width=2); d.line((x, y + 8, x, y + 20), fill=INK, width=3)
            d.line((x - 11, y - 3, x + 11, y - 3), fill=RED, width=3)
        elif kind == "redactor":
            d.rectangle((x - 24, y - 7, x + 24, y + 7), fill="#15101c", outline=INK, width=1)
        elif kind == "enemy":
            d.ellipse((x - 10, y - 10, x + 10, y + 10), fill=RED, outline=INK, width=2); d.text((x, y), "!", font=font(14, True), fill="white", anchor="mm")
        elif kind == "sleep":
            d.ellipse((x - 10, y - 10, x + 10, y + 10), fill="#c9908a", outline=INK, width=2); d.text((x, y), "z", font=font(14, True), fill="white", anchor="mm")
        elif kind == "echo":
            d.ellipse((x - 10, y - 14, x + 10, y + 10), outline=BLUE, width=3, fill="#dff0fa")
        elif kind == "stair":
            for i in range(4): d.line((x - 16, y - 10 + i * 6, x + 16, y - 10 + i * 6), fill=INK, width=2)
        elif kind == "hole":
            d.rectangle((x - 34, y - 12, x + 34, y + 12), fill="#2d2147", outline=INK, width=2)
        elif kind == "block":
            d.rectangle((x - 12, y - 12, x + 12, y + 12), fill="#b79b6a", outline=INK, width=2); d.text((x, y), "B", font=font(13, True), fill=INK, anchor="mm")
        elif kind == "lamp":
            d.ellipse((x - 11, y - 11, x + 11, y + 11), fill="#fff3a8", outline=INK, width=2)
        elif kind == "boss":
            d.polygon([(x, y - 20), (x + 22, y), (x, y + 20), (x - 22, y)], fill=RED, outline=INK)
        elif kind == "look":
            d.ellipse((x - 9, y - 9, x + 9, y + 9), outline=INK, width=2); d.text((x, y), "?", font=font(13, True), fill=INK, anchor="mm")
        if label:
            ly = y + 24 if kind not in ("stone",) else y + 30
            if fx < 0.3: d.text((x - 20, ly), label, font=font(12), fill=INK, anchor="lm")
            elif fx > 0.7: d.text((x + 20, ly), label, font=font(12), fill=INK, anchor="rm")
            else: d.text((x, ly), label, font=font(12), fill=INK, anchor="mm")
    def dep(self, a, b, color=BLUE, label=None, bend=0):
        (x1, y1), (x2, y2) = self.pos[a], self.pos[b]
        n = 24
        pts = []
        for i in range(n + 1):
            t = i / n
            px = x1 + (x2 - x1) * t; py = y1 + (y2 - y1) * t
            off = math.sin(t * math.pi) * bend
            nx, ny = (y2 - y1), -(x2 - x1)
            L = math.hypot(nx, ny) or 1
            pts.append((px + nx / L * off, py + ny / L * off))
        for i in range(0, n, 2):
            self.d.line((pts[i], pts[i + 1]), fill=color, width=3)
        ex, ey = pts[-1]; px, py = pts[-3]
        ang = math.atan2(ey - py, ex - px)
        self.d.polygon([(ex, ey), (ex - 12 * math.cos(ang - .4), ey - 12 * math.sin(ang - .4)), (ex - 12 * math.cos(ang + .4), ey - 12 * math.sin(ang + .4))], fill=color)
        if label:
            mx, my = pts[n // 2]
            tw = self.d.textlength(label, font=font(12, True))
            self.d.rectangle((mx - tw / 2 - 3, my - 9, mx + tw / 2 + 3, my + 8), fill=BG)
            self.d.text((mx, my), label, font=font(12, True), fill=color, anchor="mm")
    def note(self, head, text): self.notes.append((head, text))
    def finish(self, path, door_note=""):
        d = self.d
        d.text((30, 22), self.t, font=ImageFont.truetype(FS, 34), fill=INK)
        d.text((32, 70), "Skills in play: " + self.skills, font=font(17), fill="#6a5a3c")
        # legend
        lx, ly = 30, self.H - 70
        d.rectangle((24, ly - 14, self.mw + 36, ly + 56), fill="#ece0bf", outline=INK, width=1)
        items = [("start", "start"), ("plate", "plate"), ("gate", "gate"), ("token", "token"), ("stone", "rewrite stone"), ("redactor", "Lantern bar"), ("enemy", "guard"), ("sleep", "asleep"), ("echo", "your echo"), ("stair", "stair/ledge"), ("hole", "plot hole"), ("block", "word block")]
        x, row = lx + 30, 0
        for k, lab in items:
            if k == "enemy": x, row = lx + 30, 1
            tmp = Plan.__new__(Plan); tmp.d = d; tmp.pos = {}; tmp.rooms = {"_": (x, ly + row * 36, 1, 1)}
            tmp.item("_", "i", k, 0, 0)
            d.text((x + 26, ly + row * 36), lab, font=font(12), fill=INK, anchor="lm")
            x += 60 + int(d.textlength(lab, font=font(12))) + 20
        # notes panel
        nx = self.mw + 60
        d.rounded_rectangle((nx, 110, self.W - 24, self.H - 24), 12, fill="#f9f3e2", outline=INK, width=2)
        y = 126
        for head, text in self.notes:
            d.text((nx + 16, y), head, font=font(15, True), fill=RED if head.startswith("★") else INK)
            y += 22
            for line in wrap(text, 62, d):
                d.text((nx + 16, y), line, font=font(13), fill=INK); y += 18
            y += 10
        self.im.save(path)

def wrap(text, width, d):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if d.textlength(cur + " " + w, font=font(13)) > 470 and cur:
            lines.append(cur); cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur: lines.append(cur)
    return lines

# ---- shared three-wing frame ------------------------------------------------------------------------------------------
def frame(p, names, boss_name, door_label):
    p.room("hub", names["hub"], 420, 330, 340, 190, "hub", 1)
    p.room("a1", names["a1"], 40, 330, 300, 190, "a", 2); p.room("a2", names["a2"], 40, 90, 300, 190, "a", 3)
    p.room("b1", names["b1"], 420, 160, 340, 130, "b", 4); p.room("b2", names["b2"], 420, 0, 340, 120, "b", 5)
    p.room("c1", names["c1"], 840, 330, 300, 190, "c", 6); p.room("c2", names["c2"], 840, 90, 300, 190, "c", 7)
    p.room("boss", boss_name, 420, 600, 340, 130, "boss")
    p.link("hub", "a1", [(340, 425), (420, 425)])
    p.link("a1", "a2", [(190, 330), (190, 280)], lock=names.get("la"))
    p.link("hub", "b1", [(590, 330), (590, 290)])
    p.link("b1", "b2", [(590, 160), (590, 120)], lock=names.get("lb"))
    p.link("hub", "c1", [(760, 425), (840, 425)])
    p.link("c1", "c2", [(990, 330), (990, 280)], lock=names.get("lc"))
    p.link("hub", "boss", [(590, 520), (590, 600)], lock=door_label)
    p.item("boss", "bossmark", "boss", 0.5, 0.55, "boss fight (unchanged)")

# ---- PIP: The Unfinished Library ------------------------------------------------------------------------------------
def pip():
    p = Plan("Pip's memory: The Unfinished Library", "Echo, Lantern, Rewrite (new here)")
    frame(p, {"hub": "1  Front Matter (hub)", "a1": "2  The Dark Wood", "a2": "3  The Drowned Shelf", "b1": "4  Tall Tower: stairs", "b2": "5  Tower Top",
              "c1": "6  Margin Archive", "c2": "7  The Reading Room", "la": "gate OPEN", "lb": "stairs PRESENT", "lc": "gate"}, "The Last Page", "PAGES 0/3")
    p.item("hub", "start", "start", 0.12, 0.6)
    p.item("hub", "h0", "hole", 0.5, 0.62, "chasm")
    p.item("hub", "s0", "stone", 0.5, 0.25, "bridge BREAKS > HOLDS")
    p.dep("s0", "h0", RED, "bridge", 0)
    p.item("a1", "w1", "stone", 0.14, 0.45, "wolves ASLEEP (18s)")
    for i, (fx, fy) in enumerate([(0.38, 0.3), (0.5, 0.7), (0.66, 0.4)]): p.item("a1", "z%d" % i, "sleep", fx, fy)
    p.item("a1", "g1", "stone", 0.88, 0.2, "gate OPEN")
    p.item("a2", "r1", "stone", 0.2, 0.82, "river FROZEN (12s)")
    p.item("a2", "rv", "hole", 0.45, 0.5, "river")
    p.item("a2", "pl", "plate", 0.78, 0.22, "ledge plate"); p.item("a2", "st", "stair", 0.62, 0.22)
    p.item("a2", "eh", "echo", 0.9, 0.22)
    p.item("a2", "gt", "gate", 0.83, 0.6, ""); p.item("a2", "pg1", "token", 0.92, 0.85, "Page I")
    p.dep("r1", "rv", RED, "ice", 0); p.dep("pl", "gt", BLUE, "holds", 0)
    p.item("b1", "x1", "redactor", 0.28, 0.5); p.item("b1", "x2", "redactor", 0.72, 0.5)
    p.item("b1", "s4", "stone", 0.5, 0.78, "stairs MISSING > PRESENT"); p.item("b1", "mi", "enemy", 0.5, 0.3, "ambush")
    p.item("b2", "h5", "hole", 0.5, 0.55, "floor GONE"); p.item("b2", "s5", "stone", 0.15, 0.4, "floor SOLID (10s)")
    p.item("b2", "pg2", "token", 0.5, 0.88, "Page II"); p.item("b2", "e5", "enemy", 0.78, 0.35, "patrol"); p.item("b2", "ec", "echo", 0.9, 0.72, "decoy")
    p.dep("ec", "e5", BLUE, "lure", 0)
    p.item("c1", "g6a", "enemy", 0.38, 0.32); p.item("c1", "g6b", "enemy", 0.62, 0.68); p.item("c1", "s6", "stone", 0.14, 0.62, "guards ASLEEP (18s)")
    p.item("c1", "pl6", "plate", 0.86, 0.72, "plate"); p.item("c1", "lk", "look", 0.2, 0.22)
    p.item("c2", "xr", "redactor", 0.2, 0.3); p.item("c2", "s7", "stone", 0.2, 0.55, "door LOCKED > OPEN")
    p.item("c2", "pa", "plate", 0.58, 0.25, "plate A"); p.item("c2", "pb", "plate", 0.8, 0.25, "plate B")
    p.item("c2", "g7", "gate", 0.68, 0.72); p.item("c2", "pg3", "token", 0.9, 0.85, "Page III")
    p.item("hub", "tk", "token", 0.9, 0.2, "Pages: 0/3")
    p.note("The idea", "Pip's memory is about a boy afraid of how it ends. The library is a place you can reread: the room sentences are written, and you change them. Three torn pages, one from each wing, in any order, open The Last Page. The Spoiler fight is unchanged.")
    p.note("1  Front Matter", "Hub. The chasm splits the hall. Rewrite BREAKS into HOLDS (the tutorial) and a bridge forms. All three wings open off here.")
    p.note("2  Dark Wood", "Wolves sleep only for 18 s after you rewrite ASLEEP. Sneak past all three to the far stone and rewrite the gate OPEN. Fight or proofread them if you botch it.")
    p.note("3  Drowned Shelf (Rewrite + Echo)", "A river blocks the way to a ledge plate. Rewrite it FROZEN (12 s), then record an Echo across the ice and onto the plate. The ice melts but the echo keeps the thicket gate open. Page I.")
    p.note("4  Tall Tower: stairs (Lantern + Rewrite)", "Two black bars cross the stair: read them with the Lantern. A missing flight needs the sentence rewritten PRESENT while a Mite ambushes the landing.")
    p.note("5  Tower Top (Rewrite + Echo + enemy)", "The floor is gone. Rewrite it SOLID (10 s) while a patrol walks the ledge: send an Echo to the far side to draw the patrol off. Page II.")
    p.note("6  Margin Archive (Rewrite + stealth)", "Awake guards walk the aisles. Rewrite them ASLEEP, cross, hold the plate. The way into room 7.")
    p.note("7  Reading Room (all three)", "The lock sentence sits behind a black bar (Lantern). Two plates, you and one echo; rewrite the door OPEN, and the gate to Page III opens.")
    p.finish("docs/dungeon_plans/pip_library.png")

# ---- MAUD: The Back of House ----------------------------------------------------------------------------------------
def maud():
    p = Plan("Maud's memory: The Back of House", "Echo, Lantern, Rewrite, Format (new here), stealth")
    frame(p, {"hub": "1  The Dining Passage (hub)", "a1": "2  The Pantry", "a2": "3  The Spice Closet", "b1": "4  The Kitchen", "b2": "5  The Oven Alcove",
              "c1": "6  The Cellar", "c2": "7  The Wine Racks", "la": "bold plate", "lb": "two plates", "lc": "bar"}, "The Hall (The Empty Table)", "COURSES 0/3")
    p.item("hub", "start", "start", 0.12, 0.6); p.item("hub", "tk", "token", 0.9, 0.2, "Courses: 0/3"); p.item("hub", "lk", "look", 0.5, 0.25)
    p.item("a1", "hA", "hole", 0.4, 0.5, "plot hole"); p.item("a1", "bA", "block", 0.2, 0.75, "BREAD"); p.item("a1", "sA", "stone", 0.7, 0.2, "shelf HIGH > LOW")
    p.dep("bA", "hA", GREEN, "", 0)
    p.item("a2", "pw", "plate", 0.75, 0.3, "weight 2"); p.item("a2", "bS", "block", 0.3, 0.6, "SALT"); p.item("a2", "tS", "token", 0.9, 0.8, "Salt")
    p.dep("bS", "pw", GREEN, "bold", -30)
    p.item("b1", "k1", "enemy", 0.3, 0.3, "cook"); p.item("b1", "k2", "enemy", 0.7, 0.6, "cook"); p.item("b1", "hK", "hole", 0.5, 0.82, "")
    p.item("b1", "bK", "block", 0.15, 0.78, "SERVE"); p.dep("bK", "hK", GREEN, "italic slide", -20)
    p.item("b2", "pB", "plate", 0.3, 0.55, "bold plate"); p.item("b2", "pE", "plate", 0.55, 0.55, "echo"); p.item("b2", "tD", "token", 0.9, 0.62, "Dough")
    p.item("b2", "bB", "block", 0.12, 0.3, "BUTTER")
    p.item("c1", "g1", "enemy", 0.35, 0.3); p.item("c1", "g2", "enemy", 0.62, 0.7); p.item("c1", "ec", "echo", 0.12, 0.8, "lure"); p.dep("ec", "g2", BLUE, "", -15)
    p.item("c1", "xb", "redactor", 0.88, 0.5)
    p.item("c2", "hw", "hole", 0.5, 0.55, "spilled wine"); p.item("c2", "bw", "block", 0.2, 0.3, "GLASS"); p.item("c2", "tW", "token", 0.85, 0.8, "Wine")
    p.dep("bw", "hw", GREEN, "", 0)
    p.note("The idea", "Maud lost the reason, not the recipe. Behind the dining room is the back of house: three courses, one from each wing, must be sent out to open the Hall. Format is the star: bold weighs, italic slides, underline bridges. Boss fight unchanged.")
    p.note("1  Dining Passage", "Hub with a serving hatch counter showing Courses 0/3. Wings off three sides; the Hall door opens when all three courses are on the counter.")
    p.note("2  Pantry (Format)", "Underline BREAD into a bridge over the plot hole; rewrite the shelf LOW to reach the cupboard. Teaches the verb gently.")
    p.note("3  Spice Closet (Format: bold)", "Bold the SALT block until it is heavy enough to hold a plate (weight 2). Gate opens, take the Salt.")
    p.note("4  Kitchen (Format italic + stealth)", "Two cooks patrol. Slide the SERVE block with italic into the gap, creeping past the cones. A second table across the way needs the Lantern to make bread rise.")
    p.note("5  Oven Alcove (Format + Echo)", "Two plates: one needs a bold word (weight), the other an Echo (weight 1). Hold both and the oven gate opens: the Dough, which must rise (wait, Lantern warmth) before you can take it.")
    p.note("6  Cellar (stealth + Echo + Lantern)", "Dark, with two guards on rounds. Lure one away with an Echo, sneak the other. A black bar guards the stair down, read it with the Lantern.")
    p.note("7  Wine Racks (Format + stealth)", "Spilled wine is a plot hole. Underline a glass into a bridge. The Wine is across it.")
    p.finish("docs/dungeon_plans/maud_back_of_house.png")

# ---- SCISSOR-MAN: The Editorial Floor ------------------------------------------------------------------------------
def scissor():
    p = Plan("The Scissor-Man: The Editorial Floor (new approach, before the Cutting Room)", "Echo, Lantern, Rewrite, Format, stealth, three at a time")
    frame(p, {"hub": "1  Reception (hub)", "a1": "2  Typesetting", "a2": "3  The Proof Press", "b1": "4  Archive of Cut Scenes", "b2": "5  The Restored Reel",
              "c1": "6  The Mail Room", "c2": "7  The Dead-Letter Office", "la": "press gate", "lb": "KEPT", "lc": "3 plates"}, "The Cutting Room", "STAMPS 0/3")
    p.item("hub", "start", "start", 0.12, 0.6); p.item("hub", "tk", "token", 0.9, 0.2, "Stamps: 0/3")
    p.item("a1", "bA", "block", 0.2, 0.7, "TYPE"); p.item("a1", "hA", "hole", 0.5, 0.45, "pit"); p.item("a1", "hB", "hole", 0.5, 0.8, "pit"); p.item("a1", "pl", "plate", 0.85, 0.3, "weight 2")
    p.dep("bA", "hA", GREEN, "slide", 0)
    p.item("a2", "e1", "enemy", 0.4, 0.4, "foreman"); p.item("a2", "ec", "echo", 0.15, 0.7, "lure"); p.item("a2", "xa", "redactor", 0.75, 0.5); p.item("a2", "tA", "token", 0.9, 0.8, "APPROVED")
    p.item("b1", "s1", "stone", 0.2, 0.55, "scene CUT > KEPT"); p.item("b1", "x1", "redactor", 0.5, 0.35); p.item("b1", "x2", "redactor", 0.8, 0.35); p.item("b1", "mi", "enemy", 0.65, 0.78)
    p.item("b2", "s2", "stone", 0.2, 0.5, "door LOCKED > OPEN (8s)"); p.item("b2", "pb", "plate", 0.6, 0.3, "plate"); p.item("b2", "tR", "token", 0.9, 0.7, "REVISED")
    p.item("c1", "g1", "enemy", 0.3, 0.35); p.item("c1", "g2", "enemy", 0.6, 0.65); p.item("c1", "g3", "enemy", 0.8, 0.3); p.item("c1", "ea", "echo", 0.12, 0.8)
    p.item("c2", "p1", "plate", 0.25, 0.3, "A"); p.item("c2", "p2", "plate", 0.5, 0.3, "B"); p.item("c2", "p3", "plate", 0.75, 0.3, "C")
    p.item("c2", "bd", "block", 0.2, 0.75, "BOLD"); p.item("c2", "tP", "token", 0.9, 0.8, "PUBLISHED")
    p.note("The idea", "The Scissor-Man has no memory dungeon today, just a fight. This adds a short approach so the Cutting Room is earned: the Editorial Floor, the hardest puzzles in the Prologue, each room mixing two or three skills. The clipboard stays boss-only, as the design law says. Collect three stamps to open the Cutting Room.")
    p.note("2  Typesetting (Format + plate)", "Italic-slide the TYPE block into the pit to cross; bold a second block to weigh the press plate.")
    p.note("3  Proof Press (Echo + stealth + Lantern)", "A foreman walks the press. Lure him with an Echo, read the black bar with the Lantern, take APPROVED.")
    p.note("4  Archive of Cut Scenes (Lantern + Rewrite)", "Black bars across the aisles; under them, a sentence about the scene: rewrite CUT into KEPT to restore the aisle. A Mite jumps you on the way.")
    p.note("5  Restored Reel (Rewrite + Echo, timed)", "The door sentence holds only 8 s. An Echo holds the plate while you run through. REVISED.")
    p.note("6  Mail Room (stealth)", "Three guards on overlapping routes. Echo lures one, creep past the others.")
    p.note("7  Dead-Letter Office (Echo x2 + Format)", "Three plates, three weights: you, an Echo, and a bold word. PUBLISHED.")
    p.finish("docs/dungeon_plans/scissor_editorial_floor.png")

# ---- WEIGHING ROOM (side) ---------------------------------------------------------------------------------------------
def weighing():
    p = Plan("Side dungeon: The Weighing Room (rebuilt)", "Echo only. Optional, reached by the portal in the Smudge")
    frame(p, {"hub": "1  The Counting House (hub)", "a1": "2  The Sample Room", "a2": "3  The Light Scale", "b1": "4  The Long Beam", "b2": "5  The Heavy Scale",
              "c1": "6  The Counterweights", "c2": "7  The Plumb Room", "la": "2 plates", "lb": "plate", "lc": "3 plates"}, "The Vault (Hourglass of Drafts)", "WEIGHTS 0/3")
    p.item("hub", "start", "start", 0.12, 0.6); p.item("hub", "tk", "token", 0.9, 0.2, "Weights: 0/3")
    p.item("a1", "p1", "plate", 0.2, 0.3, "ledge"); p.item("a1", "p2", "plate", 0.8, 0.7, ""); p.item("a1", "st", "stair", 0.35, 0.3)
    p.item("a2", "tL", "token", 0.85, 0.7, "Weight I"); p.item("a2", "e", "enemy", 0.4, 0.4)
    p.item("b1", "p3", "plate", 0.5, 0.5, "pressure timed"); p.item("b1", "eg", "enemy", 0.2, 0.5, "guard")
    p.item("b2", "tH", "token", 0.85, 0.6, "Weight II"); p.item("b2", "pc", "plate", 0.3, 0.5, "")
    p.item("c1", "q1", "plate", 0.2, 0.3, "A"); p.item("c1", "q2", "plate", 0.5, 0.7, "B"); p.item("c1", "q3", "plate", 0.8, 0.3, "C")
    p.item("c2", "ps", "plate", 0.3, 0.5, "plumb"); p.item("c2", "tP", "token", 0.85, 0.7, "Weight III")
    p.note("The idea", "A little treasure house run on Echo alone. Three weights; place them on the scale (the hub door) to open the vault. Replaces the current three-room chain. Optional, so it should be hard-ish.")
    p.note("Room ideas", "Two plates at once (ledge via stair + floor); a plate that stays down only 6 s (echo-relay: leave one echo, record a second while the first holds); a guard on the beam (lure it); three plates needing two echoes plus you (the hub of the beam is a walkway that sinks while you stand on it).")
    p.finish("docs/dungeon_plans/side_weighing_room.png")

# ---- PROOF ROOM (side) ------------------------------------------------------------------------------------------------
def proof():
    p = Plan("Side dungeon: The Proof Room (rebuilt)", "Lantern + Rewrite. Optional, reached by the portal in the Lost Margin")
    frame(p, {"hub": "1  The Proofing Desk (hub)", "a1": "2  Galley One", "a2": "3  Galley Two", "b1": "4  The Margins", "b2": "5  The Errata Shelf",
              "c1": "6  The Index", "c2": "7  The Stet Closet", "la": "bar", "lb": "bar", "lc": "STET"}, "The Final Proof (Censor's Monocle)", "MARKS 0/3")
    p.item("hub", "start", "start", 0.12, 0.6); p.item("hub", "tk", "token", 0.9, 0.2, "Marks: 0/3")
    p.item("a1", "x1", "redactor", 0.4, 0.4); p.item("a1", "x2", "redactor", 0.4, 0.7); p.item("a1", "s1", "stone", 0.75, 0.5, "word ALIVE")
    p.item("a2", "tD", "token", 0.85, 0.7, "dele mark"); p.item("a2", "c1", "enemy", 0.45, 0.4, "censor")
    p.item("b1", "x3", "redactor", 0.3, 0.5); p.item("b1", "s2", "stone", 0.75, 0.5, "word UNWRITTEN")
    p.item("b2", "tC", "token", 0.8, 0.6, "caret mark"); p.item("b2", "mi", "enemy", 0.4, 0.5)
    p.item("c1", "s3", "stone", 0.2, 0.3, "WELCOME"); p.item("c1", "s4", "stone", 0.5, 0.7, "clue plaque"); p.item("c1", "x4", "redactor", 0.8, 0.4)
    p.item("c2", "tS", "token", 0.85, 0.7, "stet mark")
    p.note("The idea", "Reading rooms: the Lantern reveals what was redacted, and Rewrite changes what is true. Three proofreader's marks (dele, caret, stet) open The Final Proof. Replaces the current three-room chain.")
    p.note("Room ideas", "Each plaque's hidden sentence is a clue to which word to write on a stone elsewhere (read here, write there); censors patrol and re-black the bars unless you proofread them; the stet closet needs a word kept (do not rewrite) under a timer.")
    p.finish("docs/dungeon_plans/side_proof_room.png")

if __name__ == "__main__":
    for fn in (pip, maud, scissor, weighing, proof): fn()
    print("drawn")
