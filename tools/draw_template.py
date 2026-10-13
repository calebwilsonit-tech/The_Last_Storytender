#!/usr/bin/env python3
"""Draws the two fill-in sheets for designing a prologue dungeon puzzle (docs/templates/*.png):
 1. dungeon_overview_template.png  - rooms as boxes on a coarse grid
 2. room_template.png              - one room on a 1-tile grid, with a legend on the right
Run from the repo root:  python3 tools/draw_template.py"""
import os
from PIL import Image, ImageDraw, ImageFont
F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FS = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
def font(sz, b=False): return ImageFont.truetype(FB if b else F, sz)
BG, INK, GOLD, RED, BLUE, GREEN, GREY = "#fbf7ea", "#2a2218", "#d9a62e", "#b8443a", "#2f6a8a", "#4f8a3a", "#c9c0a4"
os.makedirs("docs/templates", exist_ok=True)

def icon(d, kind, x, y):
    """small drawn symbol at x,y (centre)"""
    if kind == "floor":
        d.rectangle((x - 14, y - 14, x + 14, y + 14), fill="#ece3c4", outline=INK, width=2)
    elif kind == "void":
        d.rectangle((x - 14, y - 14, x + 14, y + 14), fill="white", outline=INK, width=2)
        d.line((x - 14, y - 14, x + 14, y + 14), fill=GREY, width=1); d.line((x - 14, y + 14, x + 14, y - 14), fill=GREY, width=1)
    elif kind == "ledge":
        d.rectangle((x - 14, y - 14, x + 14, y + 14), fill="#f1dca0", outline=INK, width=2); d.text((x, y), "^", font=font(20, True), fill=INK, anchor="mm")
    elif kind == "stair":
        d.rectangle((x - 14, y - 14, x + 14, y + 14), fill="#cdb980", outline=INK, width=2)
        d.line((x - 8, y + 8, x + 8, y - 8), fill=INK, width=3); d.polygon([(x + 10, y - 10), (x + 2, y - 8), (x + 8, y - 2)], fill=INK)
    elif kind == "pit":
        d.rectangle((x - 14, y - 14, x + 14, y + 14), fill="#2d2147", outline=INK, width=2); d.text((x, y), "~", font=font(20, True), fill="white", anchor="mm")
    elif kind == "start":
        d.polygon([(x, y - 14), (x + 13, y + 11), (x - 13, y + 11)], fill=GREEN, outline=INK)
    elif kind == "exit":
        d.ellipse((x - 14, y - 14, x + 14, y + 14), outline=INK, width=3); d.text((x, y), "X", font=font(16, True), fill=INK, anchor="mm")
    elif kind == "plate":
        d.ellipse((x - 14, y - 9, x + 14, y + 9), outline=BLUE, width=3, fill="#cfe3ef"); d.text((x, y), "P", font=font(13, True), fill=BLUE, anchor="mm")
    elif kind == "heavy":
        d.ellipse((x - 14, y - 9, x + 14, y + 9), outline=BLUE, width=4, fill="#b9d3e6"); d.text((x, y), "PH", font=font(12, True), fill=BLUE, anchor="mm")
    elif kind == "latch":
        d.ellipse((x - 14, y - 9, x + 14, y + 9), outline=GOLD, width=3, fill="#f6e7b0"); d.text((x, y), "PL", font=font(12, True), fill=INK, anchor="mm")
    elif kind == "reset":
        d.ellipse((x - 14, y - 9, x + 14, y + 9), outline=RED, width=3, fill="#f0c8c0"); d.text((x, y), "PR", font=font(12, True), fill=RED, anchor="mm")
    elif kind == "gate":
        d.rectangle((x - 5, y - 14, x + 5, y + 14), fill=RED, outline=INK, width=2)
    elif kind == "key":
        d.ellipse((x - 13, y - 13, x + 13, y + 13), fill=GOLD, outline=INK, width=2); d.text((x, y), "K", font=font(15, True), fill=INK, anchor="mm")
    elif kind == "locket":
        d.ellipse((x - 13, y - 13, x + 13, y + 13), fill="#fff3a8", outline=INK, width=2); d.text((x, y), "L", font=font(15, True), fill=INK, anchor="mm")
    elif kind == "reward":
        d.rectangle((x - 13, y - 9, x + 13, y + 9), fill="#a9743f", outline=INK, width=2); d.text((x, y), "R", font=font(14, True), fill="white", anchor="mm")
    elif kind == "guard":
        d.ellipse((x - 13, y - 13, x + 13, y + 13), fill=RED, outline=INK, width=2); d.text((x, y), "B", font=font(15, True), fill="white", anchor="mm")
    elif kind == "sleepy":
        d.ellipse((x - 13, y - 13, x + 13, y + 13), fill="#c9908a", outline=INK, width=2); d.text((x, y), "Bz", font=font(13, True), fill="white", anchor="mm")
    elif kind == "mite":
        d.ellipse((x - 11, y - 11, x + 11, y + 11), fill="#6a4aa0", outline=INK, width=2); d.text((x, y), "M", font=font(14, True), fill="white", anchor="mm")
    elif kind == "bar":
        d.rectangle((x - 15, y - 6, x + 15, y + 6), fill="#15101c", outline=INK, width=1)
    elif kind == "stone":
        d.rectangle((x - 15, y - 11, x + 15, y + 6), fill="#fbe9dc", outline=INK, width=2); d.line((x, y + 6, x, y + 14), fill=INK, width=3); d.line((x - 9, y - 3, x + 9, y - 3), fill=RED, width=3)
    elif kind == "crate":
        d.rectangle((x - 12, y - 12, x + 12, y + 12), fill="#b79b6a", outline=INK, width=2); d.text((x, y), "C", font=font(14, True), fill=INK, anchor="mm")
    elif kind == "post":
        d.line((x, y + 14, x, y - 12), fill=INK, width=3); d.rectangle((x, y - 14, x + 12, y - 4), fill=GOLD, outline=INK, width=1)
    elif kind == "echo":
        d.line((x - 16, y, x + 6, y), fill=BLUE, width=4); d.polygon([(x + 16, y), (x + 6, y - 7), (x + 6, y + 7)], fill=BLUE); d.text((x - 16, y - 14), "E1", font=font(11, True), fill=BLUE)

def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if d.textlength((cur + " " + w).strip(), font=f) > width and cur:
            lines.append(cur); cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur: lines.append(cur)
    return lines

LEGEND = [
    ("TERRAIN", None, None),
    ("floor", "Floor you can walk on. Shade the cell, or write a dot.", "floor"),
    ("void", "Nothing / a wall. Leave it blank. Walking off a floor edge into the void makes you fall and lose a little ink.", "void"),
    ("ledge ^", "Raised floor, one level up. Write ^ (^^ for two levels). A ledge needs a stair or you cannot get up.", "ledge"),
    ("stair", "One cell with an arrow pointing UPHILL. Stairs join a level to the one above it.", "stair"),
    ("pit ~", "A plot hole. You fall in if you walk on it. Bridges can cover it.", "pit"),
    ("START and EXIT", None, None),
    ("S", "Where the player appears. Mark with S.", "start"),
    ("X", "The way back out. Mark with X.", "exit"),
    ("ECHO PLATES AND GATES", None, None),
    ("P", "Hold plate. Active only while something stands on it (you or an echo). Number them P1, P2...", "plate"),
    ("PH  (new)", "Heavy plate. Needs TWO things standing on it (for example two echoes).", "heavy"),
    ("PL  (new)", "Latch plate. Stepping on it once opens its gate for good.", "latch"),
    ("PR  (new)", "Reset plate. Pressing it undoes a lock (use with an ordered combination).", "reset"),
    ("G", "Gate, a bar across a doorway. It is always 3 cells wide. Write G1, G2... and next to it which plate(s) hold it open, like G1 <- P1+P2.", "gate"),
    ("COLLECT AND REWARD", None, None),
    ("K", "A key item the dungeon asks you to collect (weight, page, tool...). Number K1, K2, K3. The three keys open the last door.", "key"),
    ("L", "The Locket of Second Thoughts: lets you keep three echoes instead of two. Only the Weighing Room has it.", "locket"),
    ("R", "The reward chest at the end of the dungeon.", "reward"),
    ("CREATURES AND OBJECTS", None, None),
    ("B  /  Bz", "Bare (guard). It chases when it sees you. Bz = asleep. Add a short arrow for a patrol route.", "guard"),
    ("M", "Mite (small fast enemy).", "mite"),
    ("Lb", "Lantern bar: a black bar across a path that only the Lantern can read away. Draw it across the path.", "bar"),
    ("stone", "Sentence stone (rewrite). Write the sentence and its two words: The bridge [BREAKS/HOLDS].", "stone"),
    ("C", "Crate. Blocks the path. Does not move.", "crate"),
    ("post", "Lantern post: a respawn point. Add one per room or two.", "post"),
    ("YOUR SOLUTION", None, None),
    ("E1 E2 E3", "Draw each echo's recorded walk as an arrow and number them in the order you record them. Each walk must be under 9 seconds, about 35 cells.", "echo"),
]

PROMPT_LINES = [
    "A prologue dungeon is a hub with wings. Each wing has two rooms. Collect three keys (K1-K3), one from each wing, to open the last door.",
    "The player moves 1 cell at a time on this grid (top-down, tiles are squares). Walking off the floor into the void or a pit makes you fall.",
    "ECHO: press R to start remembering, walk, press R again (or after 9 seconds it stops). A ghost appears at your starting cell, replays the walk, then STANDS where it ended. You can keep 2 echoes (3 once you have the Locket).",
    "PLATES are pressed by anything standing on them: you or an echo. A GATE opens while its plate(s) are held, and does not close while you stand in it. A gate is 3 cells wide, so doorways that carry gates should be 3 cells wide.",
    "Dying clears your echoes. Everything solves with the skills the player has at that point. The prologue skills are: echo, Lantern (reads Lantern bars), rewrite (sentence stones) and combat. No mini-games.",
    "Tell me for each room: its name, its difficulty 1 to 5, how many echoes it needs, and what it teaches. Draw the SOLUTION as numbered echo arrows and write the steps in order.",
]

def room_sheet():
    W, H = 2100, 1640
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.text((30, 18), "Room sheet: draw one room here", font=ImageFont.truetype(FS, 34), fill=INK)
    d.text((32, 66), "1 square = 1 tile (about the width of the player). Rows 1-26, columns A-AN. Blank = void. Draw the room, then the solution.", font=font(16), fill="#6a5a3c")
    cols, rows, cell = 40, 26, 36
    gx, gy = 60, 130
    for c in range(cols + 1):
        x = gx + c * cell
        d.line((x, gy, x, gy + rows * cell), fill=INK if c % 5 == 0 else GREY, width=2 if c % 5 == 0 else 1)
    for r in range(rows + 1):
        y = gy + r * cell
        d.line((gx, y, gx + cols * cell, y), fill=INK if r % 5 == 0 else GREY, width=2 if r % 5 == 0 else 1)
    names = [chr(65 + i) if i < 26 else "A" + chr(65 + i - 26) for i in range(cols)]
    for c in range(cols):
        d.text((gx + c * cell + cell // 2, gy - 16), names[c], font=font(12, True), fill=INK, anchor="mm")
    for r in range(rows):
        d.text((gx - 18, gy + r * cell + cell // 2), str(r + 1), font=font(12, True), fill=INK, anchor="mm")
    # boxes under the grid
    by = gy + rows * cell + 20
    boxes = [("ROOM NAME", 0, 330), ("DIFFICULTY  1 2 3 4 5", 330, 330), ("ECHOES NEEDED  1 2 3", 660, 330), ("WHAT IT TEACHES", 990, 450)]
    for label, x0, w in boxes:
        d.rectangle((gx + x0, by, gx + x0 + w - 10, by + 70), outline=INK, width=2)
        d.text((gx + x0 + 8, by + 6), label, font=font(13, True), fill=INK)
    d.rectangle((gx, by + 86, gx + 720, by + 270), outline=INK, width=2)
    d.text((gx + 8, by + 92), "SOLUTION STEPS (in order)", font=font(13, True), fill=INK)
    d.rectangle((gx + 735, by + 86, gx + cols * cell, by + 270), outline=INK, width=2)
    d.text((gx + 743, by + 92), "TRAPS (ways to waste an echo) and the IDEA to notice", font=font(13, True), fill=INK)
    # legend panel
    lx = gx + cols * cell + 40
    d.rounded_rectangle((lx, 100, W - 20, H - 20), 12, fill="#f6efd9", outline=INK, width=2)
    d.text((lx + 16, 112), "LEGEND: how to fill it out", font=font(20, True), fill=INK)
    y = 150
    for name, desc, ic in LEGEND:
        if desc is None:
            y += 6
            d.text((lx + 16, y), name, font=font(13, True), fill=RED)
            d.line((lx + 16, y + 18, W - 36, y + 18), fill=GREY, width=1)
            y += 26
            continue
        icon(d, ic, lx + 34, y + 12)
        d.text((lx + 62, y), name, font=font(13, True), fill=INK)
        ls = wrap(d, desc, font(12), W - lx - 160)
        for k, line in enumerate(ls):
            d.text((lx + 140, y + k * 16), line, font=font(12), fill=INK)
        y += max(30, 16 * len(ls) + 8)
    im.save("docs/templates/room_template.png")
    print("room legend ends at y", y, "of", H)

def overview_sheet():
    W, H = 2100, 1300
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.text((30, 18), "Dungeon overview: draw the rooms and how they connect", font=ImageFont.truetype(FS, 34), fill=INK)
    d.text((32, 66), "Each square here is a ROOM-sized block (about 6x6 tiles). Draw rooms as boxes, connect them with doors, and mark what opens what.", font=font(16), fill="#6a5a3c")
    cols, rows, cell = 18, 12, 80
    gx, gy = 60, 130
    for c in range(cols + 1):
        d.line((gx + c * cell, gy, gx + c * cell, gy + rows * cell), fill=GREY, width=1)
    for r in range(rows + 1):
        d.line((gx, gy + r * cell, gx + cols * cell, gy + r * cell), fill=GREY, width=1)
    for c in range(cols):
        d.text((gx + c * cell + cell // 2, gy - 14), chr(65 + c), font=font(12, True), fill=INK, anchor="mm")
    for r in range(rows):
        d.text((gx - 16, gy + r * cell + cell // 2), str(r + 1), font=font(12, True), fill=INK, anchor="mm")
    by = gy + rows * cell + 20
    d.rectangle((gx, by, gx + 700, by + 90), outline=INK, width=2); d.text((gx + 8, by + 6), "DUNGEON NAME", font=font(13, True), fill=INK)
    d.rectangle((gx + 720, by, gx + 1100, by + 90), outline=INK, width=2); d.text((gx + 728, by + 6), "SKILLS THE PLAYER HAS  (echo / Lantern / rewrite / format)", font=font(13, True), fill=INK)
    d.rectangle((gx + 1120, by, gx + cols * cell, by + 90), outline=INK, width=2); d.text((gx + 1128, by + 6), "THE LAST DOOR  (what opens it)", font=font(13, True), fill=INK)
    d.rectangle((gx, by + 106, gx + cols * cell, by + 220), outline=INK, width=2); d.text((gx + 8, by + 112), "ROOM LIST: number, name, difficulty 1-5, echoes needed, what it teaches, key it gives (K1..K3)", font=font(13, True), fill=INK)
    lx = gx + cols * cell + 40
    d.rounded_rectangle((lx, 100, W - 20, H - 20), 12, fill="#f6efd9", outline=INK, width=2)
    d.text((lx + 16, 112), "LEGEND: how to fill it out", font=font(20, True), fill=INK)
    items = [
        ("Box = a room", "Draw each room as a rectangle. Number it 1, 2, 3... and write its name inside. Room 1 is the hub where the player starts."),
        ("Line = a doorway", "Connect two rooms with a line. A doorway can have a gate: draw a red bar on the line and write what holds it open."),
        ("K1 K2 K3", "The three keys. Write which room each one is in. All three open the last door."),
        ("Last door", "The door at the end. Draw it at the edge and write what opens it (usually K1+K2+K3)."),
        ("Reward R", "Mark the room with the reward chest."),
        ("Difficulty", "Write 1 to 5 in each room: 1 tutorial, 3 needs thought, 5 needs a plan."),
        ("Order", "Write 'any order' or an arrow when one room must come before another (for example the room with the Locket first)."),
        ("Echoes", "Write how many echoes the room needs, and whether you must have the Locket (3 echoes)."),
        ("Then", "Use the Room sheet for each room: draw the tiles, plates, gates and the solution."),
    ]
    y = 150
    for name, desc in items:
        d.text((lx + 16, y), name, font=font(14, True), fill=RED)
        ls = wrap(d, desc, font(13), W - lx - 60)
        for k, line in enumerate(ls):
            d.text((lx + 16, y + 22 + k * 18), line, font=font(13), fill=INK)
        y += 22 + 18 * len(ls) + 18
    im.save("docs/templates/dungeon_overview_template.png")

if __name__ == "__main__":
    room_sheet(); overview_sheet()
    open("docs/templates/PROMPT.md", "w").write("# Context for reading the template\n\n" + "\n\n".join("- " + l for l in PROMPT_LINES) + "\n")
    print("done")
