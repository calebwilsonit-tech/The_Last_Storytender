# PHASE 2 of tools/gen_overworld.py (exec'd inside it, sharing its globals).
#
# Everything above this point is the original world and must not change: saves remember chests, riddles
# and crystals by cell. This phase only (a) converts some of the old "square of trees" vaults into
# varied puzzle sites in place, and (b) branches four new regions off the old map, filling them with
# sites, camps, crystals, lore and two side dungeons. It uses its own random stream.

rng2 = random.Random(2024)
SITES = {}            # id -> site description (see scripts/puzzle_sites.gd)
PORTALS = {}          # id -> side dungeon portal
LORE_TEXT = {}        # extra lore / sign text keyed by id
POSTS_NEW = [         # extra lantern posts, far from town
    ("folio", "Folio Heights Lantern Post", (84, 12), 'f'),
    ("smudge", "Smudge Lantern Post", (112, 72), 'u'),
]

REGIONS.update({"a": "The Dog-Ear Cliffs", "f": "The Folio Heights", "l": "The Lost Margin", "u": "The Smudge"})

# ---- puzzle text ---------------------------------------------------------------------------------------
WORD_PUZZLES = [
    {"sign": "The ferry-keeper left a note: 'The bridge is MENDED, the lantern is LIT, the toll is PAID. In that order, or the river wins.'",
     "stones": [("The bridge is", ["BROKEN", "MENDED", "MISSING"], 1), ("The lantern is", ["DARK", "LIT", "STOLEN"], 1), ("The toll is", ["OWED", "WAIVED", "PAID"], 2)]},
    {"sign": "A cartographer's scrap: 'Mark the road CROOKED, the river DRY, the hill FLAT, and the way becomes easy.'",
     "stones": [("The road is", ["STRAIGHT", "CROOKED", "LOST"], 1), ("The river is", ["WIDE", "DRY", "DEEP"], 1), ("The hill is", ["STEEP", "HAUNTED", "FLAT"], 2)]},
    {"sign": "A weather report, optimistic to a fault: 'Today is SUNNY. The wind is CALM. The air is WARM. Nothing could possibly go wrong.'",
     "stones": [("Today is", ["STORMY", "SUNNY", "GRAY"], 1), ("The wind is", ["FIERCE", "SULKING", "CALM"], 2), ("The air is", ["WARM", "FREEZING", "DAMP"], 0)]},
    {"sign": "Pinned to a post: 'Whoever stole the spoons: the pantry is EMPTY, the cat is INNOCENT, and the butler is SLEEPING.'",
     "stones": [("The pantry is", ["EMPTY", "FULL", "HAUNTED"], 0), ("The cat is", ["GUILTY", "INNOCENT", "MISSING"], 1), ("The butler is", ["AWAKE", "FLEEING", "SLEEPING"], 2)]},
]
_wp_i = [0]

ECHO_HINTS = [
    "Two weighing plates and one visitor. The plates are patient. They are waiting for you to be in two places at once. (Remember an Echo with {echo}, walk to one plate, stop, then stand on the other.)",
    "A pair of stone plates, worn smooth by people who never learned the trick. Something that remembers you can stand in for you.",
]

def clear_area(cx, cy, rad):
    for y in range(cy - rad, cy + rad + 1):
        for x in range(cx - rad, cx + rad + 1):
            if 0 <= x < W and 0 <= y < H and rows[y][x] in 'T.RUSq':
                rows[y][x] = '.'
            RING.discard((x, y))

def lv_at(x, y):
    c = hts[y][x]
    return int(c) if c.isdigit() else None

def raise_cells(cells, h):
    for (x, y) in cells:
        hts[y][x] = str(h)

def stair(x, y, d):
    hts[y][x] = d
    rows[y][x] = '.'

def sq(cx, cy, r):
    return [(x, y) for y in range(cy - r, cy + r + 1) for x in range(cx - r, cx + r + 1)]

def site_flat(cx, cy, rad, lv):
    if cx - rad < 2 or cy - rad < 2 or cx + rad >= W - 2 or cy + rad >= H - 2:
        return False
    for x, y in sq(cx, cy, rad):
        if rows[y][x] not in '.TRSqU' or hts[y][x] != str(lv):
            return False
    return True

def too_close_to_site(x, y, gap=10):
    """Sites need room: plates, stones and stairs of one must never land in another's footprint."""
    for sd in SITES.values():
        sx, sy = sd["chest"]
        if max(abs(sx - x), abs(sy - y)) < gap:
            return True
    return False

def find_flat(cx, cy, rad, lv, search=26):
    for d in range(search):
        for dy in range(-d, d + 1):
            for dx in range(-d, d + 1):
                if max(abs(dx), abs(dy)) != d:
                    continue
                if site_flat(cx + dx, cy + dy, rad, lv) and not too_close_to_site(cx + dx, cy + dy):
                    return (cx + dx, cy + dy)
    return None

def free_of_pois(cx, cy, rad):
    for x, y in sq(cx, cy, rad):
        if rows[y][x] in 'PWYLGkoevNKBVQSUXHFD' and (x, y) != (cx, cy):
            return False
    return True

# ---- site templates -------------------------------------------------------------------------------------
def tpl_echo(cx, cy, tier, region_lv):
    """A stone dais with a gated stair. Two weighing plates: one at the foot of the dais, one up on a
    terrace reached the long way round. Stand on one while your Echo holds the other."""
    L = region_lv
    clear_area(cx, cy, 4)
    raise_cells(sq(cx, cy, 1), L + 1)
    for x in (cx - 1, cx, cx + 1):
        stair(x, cy + 2, 'n')
    ax, ay = cx - 3, cy + 3
    terrace = [(cx + 3, cy - 3), (cx + 4, cy - 3), (cx + 3, cy - 4), (cx + 4, cy - 4)]
    raise_cells(terrace, L + 1)
    stair(cx + 3, cy - 2, 'n')
    stair(cx + 4, cy - 2, 'n')
    rows[cy][cx] = 'q'
    CHESTS["%d,%d" % (cx, cy)] = "tier:%d" % tier
    hint = (cx - 3, cy + 1)
    hid = "echo_hint_%d" % len(SITES)
    LORE_TEXT[hid] = ECHO_HINTS[len(SITES) % len(ECHO_HINTS)]
    return {"type": "echo", "chest": [cx, cy], "gate": [cx, cy + 1], "axis": [1, 0], "plates": [[ax, ay], [cx + 3, cy - 4]],
            "hint": list(hint), "hint_id": hid, "tier": tier}

def tpl_words(cx, cy, tier, region_lv):
    """A chest on a little island in a moat of plot holes. Three sentence stones: set all three the way the
    sign says and a bridge of pages unrolls across the moat."""
    clear_area(cx, cy, 4)
    for x, y in sq(cx, cy, 2):
        if max(abs(x - cx), abs(y - cy)) == 2:
            rows[y][x] = '#'
    rows[cy][cx] = 'q'
    CHESTS["%d,%d" % (cx, cy)] = "tier:%d" % tier
    wp = WORD_PUZZLES[_wp_i[0] % len(WORD_PUZZLES)]
    _wp_i[0] += 1
    sid = "words_sign_%d" % len(SITES)
    LORE_TEXT[sid] = wp["sign"]
    stones = []
    for i, (prefix, opts, good) in enumerate(wp["stones"]):
        stones.append({"cell": [cx - 2 + 2 * i, cy + 4], "prefix": prefix, "options": opts, "suffix": ".", "good": good})
    return {"type": "words", "chest": [cx, cy], "bridge": [[cx - 1, cy + 2], [cx, cy + 2], [cx + 1, cy + 2]],
            "stones": stones, "sign": [cx + 3, cy + 3], "sign_id": sid, "tier": tier}

def tpl_arena(cx, cy, tier, region_lv, kinds):
    """A raised stone ring. Step on the plate and the stair gate slams shut behind you; beat the waves and it
    opens again. The chest sits at the far end."""
    L = region_lv
    clear_area(cx, cy, 4)
    raise_cells(sq(cx, cy, 3), L + 1)
    for x in (cx - 1, cx, cx + 1):
        stair(x, cy + 4, 'n')
        hts[cy + 4][x] = 'n'
    # the stair cells sit just outside the ring: ring bottom row is cy+3, stairs at cy+4
    rows[cy - 2][cx] = 'q'
    CHESTS["%d,%d" % (cx, cy - 2)] = "tier:%d" % tier
    waves = [
        [[cx - 2, cy - 2, kinds[0]], [cx + 2, cy - 2, kinds[0]]],
        [[cx - 2, cy, kinds[1]], [cx + 2, cy, kinds[1]], [cx, cy - 1, kinds[0]]],
    ]
    return {"type": "arena", "chest": [cx, cy - 2], "gate": [cx, cy + 3], "axis": [1, 0], "trigger": [cx, cy + 1],
            "waves": waves, "tier": tier}

def tpl_crumble(cx, cy, tier, region_lv):
    """A ravine between you and a chest island. The only way across is a zig-zag causeway of loose pages that
    crumble a moment after you step on them. Keep moving (or dash)."""
    clear_area(cx, cy, 6)
    for x, y in sq(cx, cy, 1):
        rows[y][x] = '.'
    rows[cy][cx] = 'q'
    CHESTS["%d,%d" % (cx, cy)] = "tier:%d" % tier
    sgn = rng2.choice([-1, 1])
    rel = [(0, 9), (0, 8), (0, 7), (1, 7), (2, 7), (2, 6), (2, 5), (2, 4), (1, 4), (0, 4), (-1, 4), (-2, 4), (-2, 3), (-2, 2), (-1, 2), (0, 2)]
    full = [(cx + sgn * dx, cy + dy) for dx, dy in rel]
    fullset = set(full)
    for y in range(cy + 2, cy + 10):
        for x in range(cx - 3, cx + 4):
            if (x, y) not in fullset:
                rows[y][x] = '#'
    for x, y in sq(cx, cy, 2):
        if max(abs(x - cx), abs(y - cy)) == 2 and (x, y) not in fullset and y <= cy + 2:
            rows[y][x] = '#'
    return {"type": "crumble", "chest": [cx, cy], "cells": [list(c) for c in full], "start": [cx, cy + 10], "tier": tier}

def tpl_cache(cx, cy, facing, region_lv):
    """A dais cache: the Lantern reads a Redaction bar off the stair. (Replaces the old tree-ring caches.)"""
    L = region_lv
    clear_area(cx, cy, 4)
    raise_cells(sq(cx, cy, 1), L + 1)
    if facing == 's':
        for x in (cx - 1, cx, cx + 1):
            stair(x, cy + 2, 'n')
        rows[cy + 2][cx] = 'R'
    else:
        for x in (cx - 1, cx, cx + 1):
            stair(x, cy - 2, 's')
        rows[cy - 2][cx] = 'R'
    rows[cy][cx] = 'q'
    CHESTS["%d,%d" % (cx, cy)] = next_reward()

# ---- convert some old tree-ring vaults in place ------------------------------------------------------------
def old_riddle_center(rid):
    r = RIDDLES[rid]
    gx, gy = r["gate"]
    cx, cy = r["chest"]
    return cx, cy, gx, gy

def replace_riddle(rid, builder):
    """Remove an old riddle vault (stone, gate, ring) and build a new site on its chest cell."""
    r = RIDDLES.pop(rid)
    cx, cy = r["chest"]
    sx, sy = r["stone"]
    gx, gy = r["gate"]
    CHESTS.pop("%d,%d" % (cx, cy), None)
    rows[sy][sx] = '.'
    rows[gy][gx] = '.'
    # re-centre on the old clearing's centre (the chest sat at its centre)
    return builder(cx, cy)

def new_site(sid, d):
    SITES[sid] = d

# old riddles: r0 and r3 stay as vault trials (the minigames); r1, r2, r4, r5 become real puzzles
lv_of = lambda x, y: lv_at(x, y) if lv_at(x, y) is not None else 0
new_site("p_echo_neck", replace_riddle("r1", lambda cx, cy: tpl_echo(cx, cy, 2, lv_of(cx, cy))))
new_site("p_words_wells", replace_riddle("r2", lambda cx, cy: tpl_words(cx, cy, 2, lv_of(cx, cy))))
new_site("p_arena_ridge", replace_riddle("r4", lambda cx, cy: tpl_arena(cx, cy, 3, lv_of(cx, cy), ['g', 'x'])))
new_site("p_words_ridge", replace_riddle("r5", lambda cx, cy: tpl_words(cx, cy, 4, lv_of(cx, cy))))

# three of the five Redaction caches become dais caches (no square of trees); two keep the old look
for (cx, cy, facing) in [(22, 44, 's'), (84, 31, 's'), (46, 92, 'n')]:
    if rows[cy][cx] == 'q':
        # ring centre is the chest
        tpl_cache(cx, cy, facing, lv_of(cx, cy))

# ---- four new regions ---------------------------------------------------------------------------------------------
def region_clear(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rows[y][x] != ' ':
                return False
    return True

# Folio Heights: a library-ruin plateau north of Mill Ridge (level 3)
blob(85, 9, 20, 8, 3, 'f')
rect(70, 3, 100, 15, 3, 'f')
top_y = None
for y in range(12, 30):
    if rows[y][93] == '.' and hts[y][93] == '2':
        top_y = y
        break
assert top_y is not None
rect(88, 14, 98, top_y - 2, 3, 'f')
for x in range(91, 96):
    ramp(x, top_y - 1, 'n')

# The Dog-Ear Cliffs: terraced cliffs east of Mill Ridge (levels 3 and 4)
xr = max(x for x in range(100, 125) if rows[28][x] == '.' and hts[28][x] == '2')
blob(123, 23, 8, 17, 3, 'a')
rect(xr + 2, 6, 128, 40, 3, 'a')
rect(xr + 2, 25, xr + 6, 31, 3, 'a')
for y in (27, 28, 29):
    ramp(xr + 1, y, 'e')

# The Lost Margin: a ruined library wing in the north-west (level 1)
blob(15, 22, 11, 13, 1, 'l')
m_top = None
for y in range(36, 56):
    if rows[y][15] == '.' and hts[y][15] == '0':
        m_top = y
        break
assert m_top is not None
rect(12, m_top - 5, 18, m_top - 2, 1, 'l')
for x in (14, 15, 16):
    ramp(x, m_top - 1, 'n')

# The Smudge: a marshy lowland south of the Margin Gate (level 0), reached by a neck and stairs
blob(112, 82, 14, 15, 0, 'u')
rect(108, 68, 126, 74, 0, 'u')
rect(119, 59, 125, 66, 1, 'e')
for x in (120, 121, 122, 123, 124):
    ramp(x, 67, 'n')

# ---- sites in the new regions ---------------------------------------------------------------------------------------
def place(cx, cy, rad, lv, builder):
    s = find_flat(cx, cy, rad, lv)
    if not s:
        print("no flat spot for site near", cx, cy)
        return None
    return builder(*s)

new_site("p_echo_folio", place(78, 9, 5, 3, lambda x, y: tpl_echo(x, y, 3, 3)))
new_site("p_words_folio", place(92, 8, 5, 3, lambda x, y: tpl_words(x, y, 3, 3)))
new_site("p_arena_cliffs", place(120, 32, 5, 3, lambda x, y: tpl_arena(x, y, 4, 3, ['g', 'n'])))
new_site("p_crumble_cliffs", place(120, 14, 6, 3, lambda x, y: tpl_crumble(x, y, 4, 3)))
new_site("p_words_margin", place(14, 14, 5, 1, lambda x, y: tpl_words(x, y, 2, 1)))
new_site("p_echo_margin", place(8, 26, 5, 1, lambda x, y: tpl_echo(x, y, 2, 1)))
new_site("p_crumble_smudge", place(104, 84, 6, 0, lambda x, y: tpl_crumble(x, y, 3, 0)))
new_site("p_arena_smudge", place(120, 88, 5, 0, lambda x, y: tpl_arena(x, y, 3, 0, ['x', 'l'])))
new_site("p_words_smudge", place(110, 94, 5, 0, lambda x, y: tpl_words(x, y, 3, 0)))
for k in [k for k, v in SITES.items() if v is None]:
    del SITES[k]

# ---- side dungeon portals -------------------------------------------------------------------------------------------
def portal_at(pid, cx, cy, lv, name, scene, ret, blurb):
    s = find_flat(cx, cy, 2, lv)
    if not s:
        print("no spot for portal", pid)
        return
    x, y = s
    clear_area(x, y, 2)
    PORTALS[pid] = {"cell": [x, y], "scene": scene, "name": name, "return": [x, y + 2], "blurb": blurb}

portal_at("weighing", 112, 78, 0, "The Weighing Room", "res://scenes/memory_weighing.tscn", None,
          "A doorway of stacked scales, left open. It hums when you stand near it, as if comparing you to something.")
portal_at("proof", 14, 24, 1, "The Proof Room", "res://scenes/memory_proof.tscn", None,
          "A door painted on the air, covered in editor's marks. Every one of them is a question mark.")

# ---- posts, lore, crystals, camps ------------------------------------------------------------------------------------
for wid, name, (x, y), r in POSTS_NEW:
    s = find_flat(x, y, 1, lv_of(x, y) if lv_at(x, y) is not None else 0)
    if s:
        x, y = s
    clear_area(x, y, 1)
    rows[y][x] = 'Y'
    WAYPOINTS.append((wid, name, (x, y), r))

NEW_LORE = {
    "folio_1": ((80, 12), "A shelf, a ladder, and no books: only the dust-shapes where they used to lean on each other."),
    "folio_2": ((90, 6), "Someone has underlined 'once upon a time' in a book that is now missing. The underline is all that is left."),
    "cliffs_1": ((118, 22), "The cliffs are layered like pages: dog-eared at the corners where someone could not wait to find out what happened."),
    "cliffs_2": ((124, 30), "A footnote, carved small: 'See also: the view from the top. Worth the stairs.'"),
    "margin_1": ((10, 14), "Notes in the margin of the world, all in the same handwriting: 'unclear', 'expand', 'but why?'"),
    "margin_2": ((20, 30), "This used to be the wing where unfinished books were kept. They are still here. They are still unfinished. They seem fine with it."),
    "smudge_1": ((108, 80), "Ink pooled here once and never quite dried. Things that stand still too long start to blur."),
    "smudge_2": ((116, 90), "A signpost points three ways: 'ahead', 'back', and 'somewhere'. Someone has circled 'somewhere'."),
}
for lid, ((x, y), text) in NEW_LORE.items():
    s = find_flat(x, y, 1, lv_of(x, y) if lv_at(x, y) is not None else 0)
    if not s:
        continue
    x, y = s
    clear_area(x, y, 1)
    rows[y][x] = 'L'
    LORE[lid] = (x, y)
    LORE_TEXT[lid] = text

# forests in the new regions (own density, own stream; never on sites)
SITE_CELLS = set()
for sid, sd in SITES.items():
    cx, cy = sd["chest"]
    for x, y in sq(cx, cy, 6):
        SITE_CELLS.add((x, y))
    if sd["type"] == "crumble":
        for yy in range(cy, cy + 13):
            for xx in range(cx - 6, cx + 7):
                SITE_CELLS.add((xx, yy))
    if sd["type"] in ("arena", "echo", "words"):
        for yy in range(cy - 6, cy + 8):
            for xx in range(cx - 6, cx + 7):
                SITE_CELLS.add((xx, yy))
for pid, pd in PORTALS.items():
    for x, y in sq(pd["cell"][0], pd["cell"][1], 3):
        SITE_CELLS.add((x, y))
NEW_FOREST = {'f': 0.07, 'a': 0.06, 'l': 0.10, 'u': 0.05}
for y in range(H):
    for x in range(W):
        r = reg[y][x]
        if r in NEW_FOREST and rows[y][x] == '.' and hts[y][x].isdigit() and (x, y) not in SITE_CELLS and rng2.random() < NEW_FOREST[r]:
            rows[y][x] = 'T'
# keep clearings around everything placed
for y in range(H):
    for x in range(W):
        if rows[y][x] in 'YLq':
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if rows[y + dy][x + dx] == 'T' and (x + dx, y + dy) not in RING:
                        rows[y + dy][x + dx] = '.'

def cluster2(cx, cy, n, spread=3):
    placed, tries = 0, 0
    while placed < n and tries < 60:
        tries += 1
        x, y = cx + rng2.randint(-spread, spread), cy + rng2.randint(-spread, spread)
        if 0 <= x < W and 0 <= y < H and rows[y][x] == '.' and (x, y) not in SITE_CELLS:
            rows[y][x] = 'C'
            placed += 1

for cx, cy, n in [(86, 10, 4), (100, 8, 3), (118, 20, 3), (124, 26, 3), (112, 30, 2), (10, 20, 3), (20, 12, 3), (12, 30, 3),
                  (108, 76, 3), (118, 82, 3), (106, 92, 3), (122, 70, 2)]:
    cluster2(cx, cy, n)

def camp2(cx, cy, kinds, spread=3):
    for ch, n in kinds.items():
        for _ in range(n):
            for _t in range(40):
                x, y = cx + rng2.randint(-spread, spread), cy + rng2.randint(-spread, spread)
                if 0 <= x < W and 0 <= y < H and rows[y][x] == '.' and hts[y][x].isdigit() and (x, y) not in SITE_CELLS:
                    rows[y][x] = ch
                    break

NEW_CAMPS = [(84, 8, {'n': 1, 'd': 1}), (96, 10, {'z': 1, 'x': 1}), (118, 24, {'g': 2, 'n': 1}), (126, 30, {'d': 1, 'x': 1}),
             (14, 18, {'n': 1, 'z': 1}), (20, 28, {'g': 1, 'l': 1}), (106, 80, {'l': 2, 'x': 1}), (116, 88, {'z': 1, 'd': 1, 'g': 1})]
for cx, cy, kinds in NEW_CAMPS:
    camp2(cx, cy, kinds)
    for _t in range(40):
        x, y = cx + rng2.randint(-2, 2), cy + rng2.randint(-2, 2)
        if 0 <= x < W and 0 <= y < H and rows[y][x] == '.' and (x, y) not in SITE_CELLS:
            rows[y][x] = 'q'
            CHESTS["%d,%d" % (x, y)] = next_reward()
            break

# ---- reachability of everything new (gates / bridges / plates count as passable for the check) -------------------------------
def solved_view():
    saved = []
    for sid, sd in SITES.items():
        for c in sd.get("bridge", []):
            saved.append((c[0], c[1], rows[c[1]][c[0]]))
            rows[c[1]][c[0]] = '.'
    return saved

_sv = solved_view()
reach2 = bfs(START, True)
bad2 = []
for sid, sd in SITES.items():
    for key in ("chest", "gate", "start", "trigger", "sign"):
        if key in sd:
            c = tuple(sd[key])
            near = [c] + [(c[0] + d[0], c[1] + d[1]) for d in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if not any(n in reach2 for n in near):
                bad2.append((sid, key, c))
    for p in sd.get("plates", []):
        if tuple(p) not in reach2:
            bad2.append((sid, "plate", tuple(p)))
for pid, pd in PORTALS.items():
    c = tuple(pd["cell"])
    if not any(n in reach2 for n in [c, (c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]):
        bad2.append((pid, "portal", c))
for wid, name, (x, y), r in POSTS_NEW:
    pass
for (x, y, ch) in _sv:
    rows[y][x] = ch
print("phase 2 sites:", sorted(SITES.keys()))
print("phase 2 portals:", sorted(PORTALS.keys()))
print("phase 2 unreachable parts:", bad2)

if bad2 and "--debug" in sys.argv:
    print("xr =", xr)
    for y in range(24, 34):
        print("%3d %s | %s" % (y, "".join(rows[y][xr - 6:xr + 12]), "".join(hts[y][xr - 6:xr + 12])))
