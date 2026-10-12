# GAME DESIGN DOCUMENT: THE LAST STORYTENDER
**Version 2.0 (Lore & Narrative Expansion)** — Central theme: *"The world is not ending; it is being edited."*

## 1. Executive Summary
- **Genre:** 2.5D Isometric Narrative Survival / Action-Adventure
- **Platform:** PC (Godot 4.x)
- **Visual style:** "Living Parchment." Ground textured like old paper, water like flowing ink, glitches like digital artifacts tearing through a physical book.
- **Pitch:** You are a sentient doodle in the margins of an abandoned manuscript. An entity known as "The Silence" is erasing the world to return it to a blank page. Enter the memories of characters and remind them who they are before they are deleted forever.

## 2. Narrative & World Building
- **The Vellum:** a living story abandoned by its Author. Sky = underside of the next page (future text bleeding through). Ground = faint illegible handwriting (the "Old Script").
- **The Redaction (The Glitch):** an automated process that treats the Vellum as a "Corrupted File" and deletes it. Pixelation, white noise, compression artifacts over hand-drawn paper.
- **The Marginalia (protagonist):** born from a margin doodle, never part of the Main Plot, so the Redaction struggles to see you. You love this flawed world.
- **The Silence (antagonist):** avatar of the Blank Page. Whispers promises of "rest" if characters let go of their stories.

## 3. Gameplay Mechanics
- **View/controls:** **Isometric** (2:1 diamond projection, Y-sorted depth) with parallax; 8-directional WASD mapped to screen directions. Damage bleeds ink; too much damage = crumpled paper.
- **Paper Doll system:** Layer 0 The Sketch (base) · Layer 2 Bindings (Hardcover = high defense, Softcover = high agility) · Layer 4 Tools: **The Lantern** (burns Mnemosynth; light = "Narrative Importance"; things in the dark cease to exist) and **The Quill** (locally rewrites reality).
- **Coherence (stability meter):** low Coherence → BGM distorts/plays backwards; UI text scrambles ("Inventory" → "Ivneoryt"); at 10% the player hears knocking from their actual left/right speakers.

## 4. Core Loop: The Editors' Purge
1. **Exploration** — the Unwritten Wilds; plot holes are literal void pits.
2. **The Ghost Town (Drafts)** — wireframe/sketch-only, no color; NPCs are "Lorem ipsum" placeholders.
3. **The Story Realm (Flashback)** *(built: see below)* — dungeon inside a memory. Example: *The Blacksmith's Regret* (frozen forge fire; find the First Sword; boss **The Critic**, red ink that shouts debuffing words: "Derivative!", "Boring!", "Slow Paced!").
4. **Restoration** — ink flows back, color returns, town becomes a "Published Chapter" (safe zone).

## 5. Entities
- **NPCs:** The Retired Hero (Blacksmith, teaches combat) · The Femme Fatale (Alchemist, potions to resist The Silence) · The Narrator (Merchant, floating mouth or parrot; sells rumors/supplies and narrates every purchase).
- **Enemies (Errors):** Typo-Ghouls (e.g. a "Bare" instead of a "Bear") · The Redactor (black bar blocking paths; Lantern "highlights" the text beneath) · Plot Holes (stationary gravity wells).
- **Bosses (Editors):** Scissor-Man (Cut Content; cuts the screen into impassable void lines) · Deus Ex Machina (mechanical god on strings; spawns enemies; cut its strings to win).

## 6. Items & Economy
- **Currencies:** Mnemosynth ("Crystalized nostalgia. It feels warm to the touch.") · Void Ink (crafting; "It stains your fingers with bad memories.")
- **Key items:** The Bookmark (fast travel; "A promise to return to this moment.") · Eraser Crumbs (bomb consumable) · The Oxford Comma (amulet; brief invulnerability pause before taking damage).

## 7. Biomes
Prologue Plains (tutorial; green, well-written) · Plot-Twist Peaks (geometry shifts) · Purple Prose Swamp (slow movement via "sticky adjectives"; overwhelmingly vibrant) · The Final Chapter (white void with floating geometry; home of The Silence).

## 8. Technical (lore-specific)
- **Sound:** footsteps = paper scratch/typewriter keys; combat = tearing paper/wet ink; voices = Simlish/Animal-Crossing style using typewriter clacks for pitch.
- **UI:** health = ink bottle that cracks and leaks; map = crumpled paper unfolded on screen; inventory = binder or card catalog.

## 9. Roadmap
1. **The Ink & The Page** — Parchment shader + Ink Bleed health.
2. **The Draft** — Prologue Plains + first Ghost Town.
3. **The Revision** — Coherence system (audio/visual glitches).
4. **The Publishing** — Boss fights, finalize narrative arc.

---
## Implemented: The Blacksmith's Regret (first Story Realm)
Touch the frozen flame in Garrick's forge to enter his memory. The inside is a cold slate forge where every spark hangs in the air, frozen mid-flight.

**Design decision (added to the doc's outline):** The Critic cannot be killed with a blade. It is Garrick's *own* inner voice, a boss made of red ink that shouts discouraging words ("Derivative!", "Boring!", "Overwritten.") as projectiles. Each word hits for damage plus a debuff (slow, or the screen dims). To win you reach three memory shards on raised terraces around the forge and hold each up to the Lantern. Each memory plays as a short scene (Young Garrick and Wren) and strips one ink layer from The Critic, making it quieter and slower. After the third, The Critic dissolves and the First Sword is waiting on the anvil. The beat: you don't defeat self-doubt, you out-remember it.

Back in the overworld the sword restores Thistledown as before.

---
## 10. Boss Structure & Difficulty Curve (added v2.1)
**Rule: one memory per NPC, one boss per memory, one Editor per town.**
Every NPC in need has exactly one memory (a Story Realm dungeon), and each memory ends in a **Memory Boss**: the embodiment of that person's specific wound (The Critic is Garrick's self-doubt). A town has 3 NPCs, so 3 memory bosses. When all three are restored, the Redaction sends the town's **Editor** (a big boss fought in the town itself, in the open). Defeating the Editor turns the town into a "Published Chapter" (safe zone). One memory per NPC, rather than several, keeps each story short and emotionally complete; deeper NPCs can earn a second memory later.

**Boss principle (revised, see section 27):** remembering is what makes a boss *beatable*, not what beats it. Memory bosses are a two-part fight: first the puzzle (hold up memories, rewrite sentences, seat guests) which strips their protection, then the Reckoning, a real fight where the Quill can hurt them. Editors are beaten by exposing and cutting their "edits" (Quill / Lantern / Eraser Crumbs).

### Progression table
| Town / Biome | Memory bosses (3) | Town Editor (finale) | New mechanic introduced |
|---|---|---|---|
| 1. Thistledown (Prologue Plains) | **The Critic** (Garrick, self-doubt) done. **The Spoiler** (Pip, fear of how the story ends; attacks are "spoilers"). **The Empty Table** (Maud, lost purpose; hunger/burnt-out ovens) | **The Scissor-Man** (Cut Content): cuts lines of void across the arena | Tutorial: dodge, Lantern "remember", terrain denial |
| 2. Plot-Twist Peaks | Three memories whose arenas **shift geometry mid-fight** | **The Deus Ex Machina**: mechanical god on strings that spawns enemies; cut the strings | Moving platforms, add-spawns, cutting objects |
| 3. Purple Prose Swamp | Memories with **sticky-adjective slow zones** and overwhelming visual noise | **The Overwriter** (new): buries the arena in adjectives; you must "edit" the prose down | Reading the screen under visual clutter; Quill rewrites |
| 4. The Final Chapter | Memories of *the Author* | **The Silence** (final boss) | Everything combined; non-existence as a hazard |

### Difficulty levers (data-driven, scale per boss)
- **Memory layers** to strip: 3 (Thistledown) up to 5 by the Final Chapter.
- **Projectile count and speed**, and spread patterns.
- **Phases:** Thistledown bosses have 1 phase; later bosses gain a second phase (the Critic's voice answering back, etc.).
- **Arena hazards:** plot holes, shifting terrain, slow zones, void lines.
- **Debuffs:** one (slow or dim) at first; later stacking, with Coherence drain from Phase 3.
- **Quieter-with-progress rule:** within a memory boss the enemy gets *easier* as you remember (emotional payoff), while each new town raises the *starting* difficulty. Editors ramp *up* instead, as an escalating finale.
- **Rewards:** each memory boss grants a key item or Binding piece; each Editor grants a Lantern/Quill upgrade and unlocks the next town.

### Restoration flow (implementation note)
Phase 2 restores a whole town from one NPC. With this structure, each restored NPC recolors only the area around them (the wave radius is already per-origin), and the full "Published Chapter" restoration plays after the Editor falls.

---
## 11. Combat & the Lantern (implemented v2.2)
**Controls:** WASD move · **Click / J** Quill · **Shift** dash · **Hold Q / right mouse** Lantern · E interact. Aim is the cursor (keyboard falls back to facing).

**The Quill** (given by Garrick after the first restoration): a 3-hit ink-slash combo; the third hit is a wider, stronger finisher. It rewrites rather than kills ("Don't think about whether it's pretty.").
**Dash:** a short invulnerable scribble-step (cooldown 0.75s).
**The Lantern:** a beam of "narrative importance". It burns fuel while held (slows you slightly) and refills when rested or when you collect Mnemosynth. Light is a tool, not just a weapon:
- **Redactor bars** block paths; the Quill passes through them, only light "highlights" the Old Script beneath until the bar dissolves.
- **Bares** (Typo-Ghouls: a bear missing its fur and an "a") can be cut down, or **proofread** with the light until they correct back into peaceful **Bears** (bigger Mnemosynth reward; they follow you). The same remember-don't-delete theme as the memory bosses.
- **Mites** (scribble swarmers from the enemy sheet) are burned away by light.
**Errors:** Bare (slow, telegraphed lunge, 12 dmg) and Mite (fast, fragile, 5 dmg). They won't walk into plot holes and lose interest if you leave their level.
**Training:** Garrick's lesson uses a training dummy and checks strike → dash → lantern before the Redaction sends Errors into the Plains.

---
## 12. Pacing Requirement: 1-2 hours per town (added v2.3)
**Every town (including its memories and Editor) should take a first-time player roughly 1 to 2 hours.** Length comes from content and mechanical variety, not padding.

### Time budget per town (first playthrough)
| Segment | Target | Notes |
|---|---|---|
| Overworld exploration and discovery | 20-25 min | Plains plus town, secrets behind Redactors, Bares to proofread, plateaus and terraces, Mnemosynth caches |
| Memories (3 NPCs) | ~15-20 min each, 45-60 total | Each memory is a multi-room dungeon (3-4 rooms: approach, puzzle/combat room, memory shard hunt, memory boss) |
| Town Editor boss | 10-15 min | Includes a short run-up (gathering the tools the fight needs) |
| NPC side quests (3-4) | 15-20 min | Small errands that restore flavor (find lost words, proofread a herd, rebuild a sign) |
| Inventory, crafting, Narrator shop | 5-10 min | Binding choices, Eraser Crumbs, Void Ink crafting |
| **Total** | **~95-120 min** | Fast players can finish in ~60-70 |

### Status of Thistledown (honest)
Built: overworld and ghost town (about 10 min to explore), Garrick's memory (about 8-10 min), combat lesson (about 3 min). That is **roughly 20-25 minutes**. To hit 1-2 hours it still needs:
1. **Garrick's memory** extended from one arena to 3-4 rooms (Apprenticeship hall, the Wren-nursery puzzle room with Mites, then the forge arena).
2. **Pip's memory** (The Spoiler) and **Maud's memory** (The Empty Table), each a full dungeon.
3. **The Scissor-Man** (Editor) with its run-up.
4. **3-4 side quests** and a larger Plains with more secrets.
5. A Narrator shop and a crafting loop using Void Ink.
Until these exist, Thistledown is a vertical slice, not a complete town.

### Rules to keep the length honest
- Each memory has at least one combat room, one environmental/puzzle room, and one boss; no copy-pasted arenas.
- Every town introduces 1-2 new mechanics (see section 10) so the 1-2 hours stay varied.
- Autosave at every restoration, memory entrance, and boss door (implemented).

---
## 13. Inventory, Bindings & Saving (implemented v2.4)
**The binder (Tab / I):** left page = the Storytender paper doll (Layer 0 the Sketch, Layer 2 Bindings, Layer 4 Tools) wearing whatever is equipped, with live stats; right page = a card catalog (index cards) of everything carried, with flavor text, Equip/Use buttons and a quick-use slot (F).

| Item | Type | Effect | Where you get it |
|---|---|---|---|
| Hardcover Binding | armor | -35% damage taken, -10% speed | Garrick, after the combat lesson |
| Softcover Binding | armor | -10% damage, +12% speed, -25% dash cooldown | The Glade, behind the Redactor bar |
| The Oxford Comma | amulet | +0.8s grace after being hit | Hidden in Garrick's memory |
| Eraser Crumbs | consumable | Thrown; rubs out Errors in a radius | Garrick (3), Bare drops |
| Ink Vial | consumable | Restores ink | Proofreading a Bare |
| Void Ink | material | Crafting (planned) | Mite drops |
| The Bookmark | key | Fast travel (planned) | Later |
Mnemosynth is the currency and also refuels the Lantern.

**Autosave:** progress, inventory, equipment, flags and currency save automatically at every item pickup, story beat, restoration and on quit, and load on launch. **F12** wipes the save (development).

---
## 14. Memory 2: Pip's "The Last Page" (implemented v2.5)
**Wound:** Pip peeked at the last page of his favorite storybook and has believed ever since that every story ends badly. **Boss:** The Spoiler. **Reward:** The Bookmark, plus Pip's restoration. Estimated first-time length: ~12-15 min.

**New verb: rewriting.** This memory is where the Quill gets its real purpose. *Sentence stones* hold a sentence with one changeable word ("The bridge **BREAKS**"). Strike the word with the Quill (or press E) to rewrite it and change what is true.

| Room | Idea | Mechanics used |
|---|---|---|
| 1. Front Matter | Rewrite "BREAKS" to "HOLDS" and a bridge forms over the chasm | Rewriting, plot holes |
| 2. The Dark Wood | Rewrite the wolves "ASLEEP" (18s, then it wears off) to sneak to the second stone and rewrite the gate "OPEN"; or fight / proofread them | Rewriting under time pressure, combat, Lantern |
| 3. The Tall Tower | Redactor bars across the stairs (Lantern), a Mite ambush, and the **Torn Page** that opens the door to the boss | Elevation, Redactors, enemies |
| 4. The Last Page | **The Spoiler** announces the future in huge words. Sentences come true after 5s unless rewritten | Reading the screen, rewriting, dodging |

**The Spoiler fight (a fighting boss, rewrite as a skill shot):** the book attacks directly in a rhythm of three moves. It opens its pages and fans paper cuts at you (the aim lines show where; the Quill can swat a cut out of the air), or it rises and dives onto where you were standing (a red ring marks the landing; it lands, rests, and the Reckoning adds a ring of cuts), and every third move it stops, drops to eye level and READS a sentence aloud ("The floor beneath the WEST COLLAPSES", "Wolves from the NORTH ATTACK", "Lightning in the MIDDLE STRIKES"). A gold ring counts down how long you have. Strike the book itself with the Quill before the ring empties and the sentence is rewritten (the cells bloom into healing flowers); the book reels. Let the ring run out and the sentence comes true (the floor collapses for 7s, three Mites appear, or lightning hits the marked cells for 16). While it reads it spits slow spirals of paper cuts, so the skill is getting close enough to strike. After 3 rewrites it reads two sentences at once; each strike cancels one. Five rewrites end the puzzle half and begin the Reckoning. The window shrinks from 5.6s to 3.8s as you rewrite.
**Emotional resolution:** it dissolves into a boy who was afraid to find out. You can't tell Pip how it ends, only stay while he turns the page.

### Restoration is now per-NPC
Each restored NPC blooms color outward from them (Garrick, then Pip, then Maud). The full "Published Chapter" restoration is reserved for the Editor fight.

---
## 15. Difficulty & Tuning Pass (implemented v2.6)
Why: an honest review found nothing could really threaten the player (free respawn, a dodge-only Critic, stacking armor, one-throw crowd clears, infinite lantern, no resource pressure).

**Difficulty setting (chosen at New Game, fixed for that save):** *Normal* and *Story* (gentler: 60% enemy damage, full ink after crumpling, no Mnemosynth loss, slower bolts, longer Spoiler windows, 8 fall damage).
**Death cost (Normal):** crumpling loses 15% of your Mnemosynth (dropped as crystals where you fell, recoverable), restores 50 ink, and wakes you at the start of the current room with 2s of grace. The room's Errors reset (but not right on top of you); boss progress is mostly kept (the Spoiler recovers one sentence; the Critic keeps your remembered shards). Falling costs 15 (Story 8) and never kills.
**Combat:** Bare 9 hp / faster (86) / shorter windup (0.45s); Mite faster (150) and hits for 6; Errors drift back into the Plains over time.
**Gear & items:** Hardcover -30% (was -35%), Oxford Comma +0.5s grace (was +0.8), total armor capped at 50%. Eraser Crumbs: 5 damage, smaller radius, Garrick gives 2. Lantern drains faster (24/s); crystals refuel less (12). A proofread Bare gives an Ink Vial 60% of the time (always in Story).
**The Critic:** leads its shots (aims where you're going), fires 2 / 3 / 1 words by phase, and from the second phase also cuts the floor with red ink pools (damage over time). Slightly faster words; still quieter with every memory, but no longer dodge-by-walking.
**The Spoiler:** read window shrinks from 5.6s to 3.8s as you rewrite (Story mode adds time); a move every ~1.9s shrinking to ~0.9s; reckoning HP 190 (Story 70%); a strike during a read does 12 damage in the Reckoning, and the book takes double damage while staggered; wolf events spawn 3 Mites.
**Playtest log:** every session records deaths per room, damage by source, time per scene and boss events to a JSON file. **F10** saves it and shows the path. It lives in the game's user-data folder under `playtest/` (Windows: `%APPDATA%\Godot\app_userdata\The Last Storytender\playtest\`).

### Known gaps (not yet tuned)
- Mnemosynth has nothing to spend on until the Narrator shop exists.
- Only two enemy types; the tall shadow "Censor" (ranged) from the enemy sheet is the next addition.
- All numbers are from reading code and automated runs. Real tuning needs the playtest log.

---
## 16. Menus & Settings (implemented v2.7)
- **Title screen:** Continue (if a save exists), New Game, Settings, Quit. New Game confirms before erasing an existing save, then asks for **difficulty (Story / Normal), which is fixed for that save**. The game now starts here.
- **Pause menu (Esc):** Resume, Settings, Save and return to title, Quit.
- **Settings (title or pause):** master volume, fullscreen, screen shake, dialogue speed, playtest log on/off. Difficulty is shown read-only. Settings are stored separately from the save.
- **Menu controls:** **WASD, arrow keys and gamepad all work** in every menu and in the binder (W/S move, A/D adjust or move sideways, Enter/E/Space accept, Esc back). Mouse works too.

### Enemy awareness (how mobs notice you)
A Bare notices you within **250 px** and a Mite within **300 px** (ground distance, vertical counts double), which is the inner half of the screen at the default zoom. Nothing off-screen chases you; they give up beyond double that range and return home. They cannot see you across different floor levels. There is currently no line of sight, vision cone or noise; this is a candidate for a stealth-flavored upgrade.

---
## 17. Puzzle Design Language: the Editor's Toolkit (proposed v2.8)
The game is about *editing a story*, so puzzles should use the tools of an editor on the world itself. **Each town unlocks one new "proofreader's mark" for the Quill**, so every town has a fresh puzzle verb and the 1-2 hour length stays varied.

| Where | Puzzle verb | What it does | Status |
|---|---|---|---|
| Thistledown: Garrick's memory | **Remember** (Lantern) | Hold memories up to the light | Built |
| Thistledown: Pip's memory | **Rewrite** | Swap a word in a sentence | Built |
| Thistledown: Maud's memory | **Format** (Underline / Bold / Italic) | Text styling acts as physics | Built |
| Every later town | **Chosen by the designer** | Each town gets its own verbs | Open (the Fold / Reorder, Strike and "all marks" ideas below are suggestions only) |

**Rule: every town gets its own puzzle mechanics.** Marks the Quill has already learned stay available, so a later town *may* call back to an earlier one, but it is never required. Global systems (stealth/perception, difficulty, death cost, the binder) apply in every town.

### Out-of-the-box puzzle ideas (pick and mix)
1. **Letter-level proofreading.** Objects are labeled with typos. Change one letter and the object changes: HOLE -> WHOLE (a pit fills in), STARE -> STAIR (stairs appear), BARE -> BEAR (already in the game). A starter-area secret.
2. **Typography is physics (Maud's memory).** Underline a word-block and it extends into a walkable line (a bridge). Bold makes it heavy enough to press a pressure plate or crack thin floor. Italic makes it lean and slide. Solve rooms by styling the text the room is made of.
3. **Strike-through negation.** "The door is NOT open": strike NOT. Deleting can be the answer, not just swapping.
4. **The page is a physical object.** Dog-ear a corner of the world to fold a far ledge onto a near one; the page edge's stacked-paper cliffs are literally the fold. (Peaks.)
5. **Footnotes as portals.** Superscript numbers (^1) on the ground teleport you to the page's footer, a strip of world where the explanation (and the key) is written. (Garrick's extended memory or Peaks.)
6. **The unreliable Narrator.** The Narrator's text tells you which path is safe, and one of his lines is a lie. Cross-check with a sentence stone or the Lantern to find which. (Uses the existing narration UI as a puzzle.)
7. **A puzzle you solve by waiting (Maud).** Dough cannot be rushed. Rewriting "rises SLOWLY" to "QUICKLY" burns it. The emotionally right answer is patience: a puzzle whose solution is to do nothing and stay.
8. **Lorem-ipsum cipher.** A Redacted sentence with only some letters revealed by the Lantern; deduce the missing words (Wordle-like) to rewrite the right one.
9. **Undo / Revision history.** Hold a button to rewind objects 3 seconds (burnt bread un-burns, a falling block rises again): the Eraser Crumbs' cousin, an "Undo". Pair with a saved "draft" of a room.
10. **Index / card-catalog sorting.** Recipe cards arrive out of order; file them in the right order to open a drawer (alphabetical, or "order of operations").

### Proposed assignment for Thistledown
- **Maud's memory ("The Empty Table"):** the *Format* mark (idea 2), one *waiting* puzzle (7), one *unreliable Narrator* puzzle (6), and the boss is her fear that nobody is left to feed.
- **Garrick's memory (extension to 3-4 rooms):** *strike-through negation* (3) and a *footnote portal* room (5).
- **Starter-area secrets:** letter-level proofreading (1) hidden in the Plains.

---
## 18. Memory 3: Maud's "The Empty Table" and Stealth (implemented v2.8)
### Stealth (global, every town)
Enemies now **perceive** you instead of noticing you at a fixed distance. Each has a vision **cone** (Bare: ~54 deg either side, 270 px range; Mite: very wide cone, shorter range, sharp hearing), **hearing** (your noise radius), and **line of sight** (trees, houses and crates block it; so do cliffs/terraces higher than both of you). An alert meter fills (shown as a growing "?"), then they chase; if they lose you they **search** the last place they saw you, look around, and give up.
- **Creep** (hold **Ctrl or C**): 55% speed, 40% noise, 75% sight range; a faint ring shows how far your presence carries.
- Walking = 150 noise, dashing = 290, fighting = 300, the Lantern adds +50 and makes you easier to see.
- **Sneak attack:** hitting an unaware (or sleeping) enemy does **double damage**. When one notices you, the ones beside it do too.
- Cones are drawn on the ground near you (yellow, then orange, then red as they notice you).

### The Format mark (Maud's memory verb)
Choose a style with **1 (Underline), 2 (Bold), 3 (Italic)** and strike a word with the Quill:
- **Underline:** the word becomes walkable; plot holes beneath it become a bridge.
- **Bold:** the word is heavy (weight 2): it can press a pressure plate (needs weight 2).
- **Italic:** the word slides along its lean until something stops it (a wall, another block, you); a block that slides into a plot hole plugs it for good.
- **Rising dough** cannot be rushed: strike it early and it collapses. Hold the Lantern's warmth on it to help it rise.

### The rooms (about 12-15 min)
1. **The Pantry:** underline BREAD into a bridge (tutorial).
2. **The Kitchen:** make SALT bold, then italic, and it slides onto the plate and opens the gate. Patrols to sneak past.
3. **The Cellar:** the DOUGH must be waited for (the "do nothing" puzzle), then underlined into a bridge. Bares and Mites patrol (stealth practice).
4. **The Hall (boss, The Empty Table):** six chairs set for six. Shapes in the dark are drawn to the Lantern's light; lead each to a chair. Every ~11 s **The Clearing** (a telegraphed cold) sweeps the hall from a random side: it erases standing guests, stands seated ones back up, and hurts you, unless you or they are **behind a bold word** (it shelters up to 3 tiles behind it). SERVE blocks can be bolded and slid into place. Seat all six at once to win.
**Emotional resolution:** the table was only ever "a place where people are invited". Maud never lost the recipe; she lost the reason.

Reward: **Warm Loaf** x3 (restores 60 ink), Maud's restoration, +40 Mnemosynth. The oven doorway needs Pip's memory first (the Quill must learn Rewrite before Format).


## 19. The Scissor-Man: "Cut Content" (implemented v2.9)
Thistledown's Editor. Unlocked when Garrick, Pip and Maud are all restored: a tear (Prop RIFT) opens at the town square and leads to **The Cutting Room**, a green cutting mat.

**Signature verb: the Clipboard (cut / copy / paste).** No other NPC, memory or boss uses it.
- He telegraphs a cut line (red dashes on the mat, about 3 s, 3.8 s on Story), then snips. Unpatched cells along the line become pits for about 11 s (8 s on Story) and the paper then heals. Each snip leaves clippings (max 4 on the mat).
- Strike a clipping with the Quill (or press E) to put its shape on the clipboard (HUD). Aim and press **V** to paste it 96 px ahead as a taped patch (valid placement shows green, invalid red). A patch cannot be cut and lasts about 18 s (26 s on Story).
- A cut line that crosses a patch **jams his shears** for 5.5 s (7 s on Story). Only while jammed can the Quill hurt him (90 hp). Nothing else damages him.
- Phase 1: one thin line. Phase 2 (below 66%): width-2 lines plus two Mites. Phase 3 (below 33%): two lines at once plus Mites and a Bare.
- Finale: Wick the tailor remembers; reward is the **Thimble** amulet (armor +0.08, dash cooldown -0.15), flag `scissor_done`, +60 Mnemosynth. The player returns to the square and the whole town is published (restoration wave radius 2600, region reads "Published Chapter").

### The variety rule (design law)
Every NPC memory, and every boss, gets its **own signature mechanic**. Do not reuse the same 3-4 mechanics across NPCs. A previous mechanic may return only as a callback inside a town finale, never as the main verb of a new memory. Stealth is the one global system.

### Mechanic Registry
| Owner | Signature mechanic | Notes |
|---|---|---|
| Garrick (town tutorial) | Lantern / proofreading | Combat basics |
| Garrick's memory | **Echoes** (record a few seconds of yourself; the ghost replays and stays) | Holds plates, lures guards; Critic boss unchanged |
| Pip | Rewrite (Quill changes a word in a sentence) | Spoiler boss |
| Maud | Format marks (underline / bold / italic as physics), waiting, guest herding, cover | Guest boss |
| Scissor-Man | Clipboard: cut, copy, paste, jam | Boss only |
| Stealth | Global, all towns | Cones, hearing, creep, sneak attack |

### Pool of unused mechanics (for future NPCs and towns)
Fold / reorder pages; strike-through (cross out an obstacle, but it costs a word); footnote portals; unreliable narrator (dialogue hints lie in a pattern); undo / rewind; index sorting (alphabetical order puzzles); Lorem-ipsum cipher; tracing paper overlays; anagram doors; font-size / scale physics; highlighter colors; layered transparency; flipbook / timeline scrub.


## 20. Garrick's Memory, Expanded: "The Blacksmith's Regret" (implemented v2.10)
The memory is now four rooms (about 20-25 minutes) instead of one hall. The first three teach and use a new signature verb, **Echoes**, then the Critic boss is unchanged.

**Echoes (key R).** Press R to start remembering, walk, press R again (or 9 s runs out). A cyan ghost appears at your start point, replays the walk, and then stands where the memory ended. You can keep **two**; a third recording replaces the oldest. An echo has weight (it presses Echo Plates) and the curious are drawn to it (idle or returning enemies within about 340 px with line of sight go and search around it). Dying clears all echoes.

| Room | Idea |
|---|---|
| The Cold Hearth | One plate, one gate. Leave an echo on the plate, walk through. Wren asleep under a blanket of oven mitts (look). |
| The Apprentice's Bench | Two plates, both far from the gate: one on a raised platform up a staircase, one past crates and plot holes. Needs both echoes at once. Bench of tools all named Gerald (look). |
| The Night Watch | A Bare guard stands right beside the plate (walking up unaided gets you chased in about 9 runs in 10 in simulation). Lured guards stare at the echo instead of scanning, and echoes draw them from up to about 420 px. Record an echo near the entrance to draw it away, then record a second echo to the plate. (Killing the guard also works.) The boy asleep on the watch (look). |
| The Forge | The Critic fight, unchanged. |

Gates are momentary: they stay open only while every plate is held (they will not close while you are standing in them). Remembered figures can be looked at (E) for short emotional beats, so the puzzle rooms carry story too.

Enemies now stay near their post: idle wandering drifts back toward home beyond about 110 px.


## 21. The Overworld, Chapters and the Map (implemented v2.11)
- **The first world is the Prologue**, not a chapter. It is called "the Prologue" until it is liberated, and the map lists it as complete afterwards. Chapters One onward are later worlds (Plot-Twist Peaks, Purple Prose Swamp, The Final Chapter). Each is its own scene and map.
- **Scale rule:** chapters are large and built to be explored; dungeons and memories stay short. The Prologue overworld is 132 x 104 cells (about 4x the old 40 x 26) with eleven regions: the Page's Edge, Margins Meadow, Old Meadow, Thistledown, Whispering Orchard, Ink-Wells, Footnote Hollow, Hushed Glade (hidden behind a redaction), Mill Ridge, Graveyard of Deleted Scenes and the Margin Gate. Future chapters should be larger again, with more characters and a bigger town to restore.
- **Map generation:** data/prologue_map.gd is generated by tools/gen_overworld.py, which also checks that every landmark can be reached on foot. Edit the script, not the data file.
- **Exploration:** lore stones, one-time pickups and crystals (remembered in the save), secret regions behind redaction bars, and a Mnemosynth reward the first time you discover a region.
- **Lantern posts:** light one by interacting; resting at one restores ink and Lantern and saves, and you wake at the nearest lit post after being crumpled.
- **Map (key M, or Map in the pause menu):** shows only the regions you have discovered. You can fast travel between lit posts, but only to posts at least 40 cells away, so travel is for long backtracks, not shortcuts.
- **Enemies stream by distance** (wake within about 900 px, never on top of you, fade out far behind you) so a big world stays fast.
- **Planned, not yet built:** hidden items that need finding or a puzzle to reach, and side quests and missions. They do not have to live in the Prologue; the first chapter after it is the better home.

### Scale rule for future chapters (design law)
- The Prologue (132 x 104 cells, about 13,700 cells) is the **starter** size and is fine as it is.
- **Every later chapter is at least 4x the Prologue's area**: about 55,000 cells or more (roughly 264 x 208). Chapters keep growing from there, with more characters, a larger town to restore, more regions, and more hidden finds, side quests and missions.
- Memories and dungeons stay small; the chapter itself is the thing that is large and rewards exploration.
- Fast travel only exists where it earns its place (long distances), and gets more useful as chapters grow.
- **Technical prerequisite before building Chapter One:** the ground is currently redrawn from per-cell commands, which will not hold at 4x. Chapter maps need chunked ground (cache each chunk as a texture or mesh and only repaint chunks that change, such as restoration waves), props and enemies streamed by distance, region data per chunk, and the map generator extended to produce multi-region chapters. Treat that engine work as the first task of Chapter One.

### Length and pacing: "this goes on absurdly long" (design intent)
The game should be a decent sized game, and at points it should feel *absurdly* long, in the way a few stretches of Undertale feel like they keep going. That is deliberate, not a pacing bug:
- Each chapter gets a few **marathon set pieces**: very long routes, sprawling regions or chained puzzle sequences where the player starts to wonder how much is left. Make the length itself part of the joke or the mood (a corridor that keeps going, a stairwell nobody finished writing, a chapter that clearly could have ended three scenes ago).
- Make the length **earn its keep**: escalating gags, new small ideas every few minutes, sincere beats tucked in, and no repeating the same trick. Never pad.
- Give relief inside the long parts: lantern posts to rest at, safe pockets, and the occasional shortcut that rewards exploration.
- Keep the **memories and dungeons short**; the long stretches belong to the chapters themselves, which scale at 4x the Prologue or more.
- Track it in playtest reports: record time per region and flag any stretch where players quit or stall, so "long on purpose" never turns into "long and dull".

### Graphics options (implemented v2.12)
Every visual cost has an option, so players on weak machines choose where to sacrifice: pixel density (renders at 1280x720 instead of native on Retina), paper background (flat color or 3 resolutions), paper shader detail, grass, tile outlines, cliff lines, ground refresh, draw distance, tree sway, shadows, glow, edge shading, smooth lines, FPS cap, VSync, FPS counter. New visual effects added later should get an option in Settings.GFX rather than being always on.


## 22. Enemy Roster, Renown and the Grind (implemented v2.13, design law)
### Enemy roster (it keeps growing)
Six kinds of Error exist in the Prologue, each with its own way of fighting, and each is **unlocked by the story** so the world keeps changing:
| Kind | Verb | Counter | Appears |
|---|---|---|---|
| Bare (Typo-Ghoul) | heavy lunge | proofread with the Lantern, or cut down | from the start |
| Mite | fast swarm | light burns it off | from the start |
| Run-on | sticky ink trail that slows you | Lantern teaches it to stop | after Pip is restored |
| Dangling Modifier | ranged, keeps distance, flings slow words | keep moving; Lantern ties it off | after Pip is restored |
| Censor | frontal black bar blocks the Quill | strip the bar with the Lantern, or hit from behind | after Maud is restored |
| Ellipsis ("...") | blinks around you, then strikes | the Lantern pins it so it can be cut | after Maud is restored |
**Later chapters add many more than six.** Each chapter introduces several new kinds (plus variants of old ones), fitted to its theme, and chapter maps are much larger, so the roster should keep widening. Rules: every new kind gets a distinct verb (not a re-skin), a Lantern interaction, a one-line intro the first time it appears, and an unlock point in the story. Keep counts moderate; variety beats numbers, and enemies are streamed by distance so big maps stay uncluttered.

### Renown: the deliberate grind
There is a small grind by design, and **the player chooses how to do it**. Renown (shown as Rank and a bar under the Mnemosynth counter) is earned by any deed: beating Errors (1 to 4 each by kind), opening chests (5), solving vault trials (8 / 12 / 16 / 20 by tier), discovering regions (6), lighting posts (3), restoring people (35 each), bosses (40) and, later, side quests and mini-dungeons. Story gates require a minimum Renown (the Margin Gate asks for 220), so a player who ignores optional content will be a bit short and has to explore, fight, solve or run a mini-dungeon. Beating enemies is always a valid way to fill the gap.
- Each rank widens the ink bottle (+10 max ink per rank). More perks per rank are planned.
- Tune so the story alone gives roughly two-thirds of a gate's requirement; the rest comes from optional deeds (in the Prologue about 145 from the story, 220 needed, around 280 or more on offer optionally).
- Later chapters scale both the requirements and the amount on offer; side quests and mini-dungeons (still to build) should be the most efficient sources, so they feel worthwhile and not skippable.

### Things to do in the world (overworld density)
The Prologue map now has 6 vaults (a Vault Trial on the plinth outside opens the gate, a chest behind), 5 hidden caches behind redaction bars (hold the Lantern), chests guarded by enemy camps, lore stones and one-time pickups. Dense but not overwhelming: roughly one point of interest every 10 to 15 cells.

### Performance architecture (implemented v2.14)
Integrated graphics (for example a 2020 Intel MacBook Pro running Windows) struggle with thousands of tiny draw calls per frame, so the overworld is built to issue very few:
- **Cached ground (GroundChunks):** flat ground is painted once per 16 x 16 block into a texture and shown as one image. Only blocks near the camera exist. Cliff faces, stairs and holes stay live because they are depth-sorted against people. While a restoration wave spreads, the town blocks on screen repaint each frame. Option: Settings > Graphics > Cached ground.
- **Baked trees (TreeBake):** each tree look (3 sizes x 4 variations) is painted once at 2x and every tree draws that single picture (sway is a slight lean). The dense orchard went from about 20,000 draw commands to about 1,200.
- **Streaming:** enemies, ground chunks and far props are created and dropped by distance.
Rule for new content: anything that appears many times (trees, rocks, grass, fences, houses) should be baked or batched, not drawn command by command each frame. Chapter maps at 4x the Prologue depend on this.


## 23. Vault Trials and prizes
The sentence-stone locks on the overworld are now **Vault Trials**: interact with the plinth to open a small word game (30 to 90 seconds, 3 tries, Esc to walk away, retry any time). Each vault has a tier of 1 to 4 stars; the same vault always plays the same game, but the puzzle inside is freshly rolled. Mouse, keyboard and controller all work. Games: **Proofread** (find the wrong word), **Alphabetize** (sort by moving words), **Unscramble** (letters with a clue), **Rebuild the Sentence**, **Word Ladder** (change one letter per step, par shrinks with tier), **Typewriter Trial** (timed typing, keyboard only), **Cipher Wheel** (Caesar shift). Tier 1 uses the first three; higher tiers mix in the harder ones.
**Prizes scale with the tier** (rolled deterministically per vault; unique gear you already own is rerolled). T1: ink vials, eraser crumbs, small Mnemosynth, bread. T2: Highlighter, Margin Note, Index Tab, Paperback Binding, lantern oil, sticky notes. T3: Red Pen, Footnote, Leatherbound Binding, big Mnemosynth, Ink Flasks. T4: Gilded Binding, Bookmark Charm, First Edition, huge Mnemosynth.
**New items (14):** Ink Flask (refills ink), Lantern Oil (refills lantern), Sticky Note (puts nearby Errors to sleep), Paperback / Leatherbound / Gilded Bindings (armor), Highlighter, Margin Note, Index Tab, Red Pen, Footnote, Bookmark Charm, First Edition (amulets and gear with new stats: quill damage, reach, lantern efficiency, ink regen).
**Controller play:** *Dictation Beat* (tier 3 to 4, notes fall in four lanes, press the matching direction) is a rhythm game that suits a pad. With a controller connected the *Typewriter Trial* shows a letter grid instead (d-pad to move, A to type, 14 s extra and 2 extra mistakes allowed); real key presses still work.

## 24. Items, rarity and loot
**Rarity** (card border colour in the Binder): Common (grey), Uncommon (green), Rare (blue), Epic (purple), Legendary (gold). There are now ~90 items: 14 crafting materials, 8 more consumables (tea, biscuits, tonics, Memory Jars, Phoenix Draught, Time in a Bottle...), 5 more bindings (Cloth, Dust Jacket, Library, Vellum, Illuminated) and 18 artifacts with stats such as Quill damage/reach, ink regen, lantern efficiency, **Mnemosynth found**, **Renown earned** and **drop luck**. Everything lives in `item_catalog.gd` (with `price` for the later-game shop, `RECIPES` for the workbench, `SHOP_STOCK`).
**Drop tables** (`drop_tables.gd`): every Error kind has its own list of [item, chance %, count]. Each entry rolls on its own, so a kill can drop several things or none. Common crumbs are 25 to 50%, crafting materials 10 to 30%, tonics and tea about 5%, artifacts 1 to 2%. Normal difficulty pays 20% more than Story; **bosses** have their own tables rolled every time they are beaten (guaranteed basics, then 1% to 60% chances), and Normal pays 75% more on them. A Lucky Clover adds 30% to every chance.
**Vault prizes** now draw from the same item list: tier 1 gets small things and the first artifacts, tier 4 can pay out Legendary artifacts (never a duplicate of one you own).
**Not built yet:** the workbench UI that uses `RECIPES`, and the shop that sells `SHOP_STOCK`; the data and balance targets are in place for both.

## 25. The opening, and the Index hub
**New Game opening:** after choosing a difficulty a storybook opens on a desk and reads six short spreads (what a Storytender is, the Editors and the Redaction, the one doodle left on page 41, "that is where you come in"), then a drop of ink swallows the page and the Prologue fades in with the doodle being inked and standing up off the page. Confirm turns the page (finishes the line first), Back or Esc skips.
**The Index (hub):** every *lit lantern post* now opens the Index after you rest: the **Workbench** (craft from `RECIPES`), the **Narrator's Stall** (buy and sell for Mnemosynth; stock opens up with Rank) and the **Map** (fast travel). The only portable piece is the **Pocket Workbench** (buy it or craft it): from the Binder it opens the Workbench alone, never the stall or the map.

## 26. Levels, attributes and resting
**Revise Your Draft** (Index > first entry): six attributes, **each up to 100**; Level is 1 plus every point you have put in (so 601 is the ceiling). **The first time the Index shows you the system you get 15 free points** to spend as you like; after that each point costs Mnemosynth, and **the cost rises with every point you have ever bought** (about 110 at Level 16, 1,600 at 100 points in, 8,400 at 300 points in, 31,000 for the very last point; a maxed build is an endgame / new-game-plus goal). Per point: Inkwell +2 max ink, Thick Paper -0.5% damage taken, Penmanship +1% Quill damage and +0.25% reach, Wit +0.025 ink regen/s and -0.5% Lantern burn and +1 Vault Trial try per 20 points, Footwork +0.3% speed and -0.5% dash cooldown, Fortune +0.5% drop chances and +0.25% Mnemosynth found. Dying still drops Mnemosynth where you fell. There is no respec.
**Resting resets the page:** every Error you beat comes back when you rest at a lantern post (they reappear as you walk away from the post).

## 27. Boss fights: remember first, then fight
Memory bosses are a two-part fight. **Part one is the puzzle**: hold up the memories (Critic), rewrite the sentences (Spoiler), and so on, while surviving its attacks; each success strips a layer and quiets it. **Part two, the Reckoning**: once it has been remembered, the boss is no longer a voice or an idea; it has a body and a health bar, and the Quill can hurt it. It is still a hard fight, with a new set of attacks. Remembering is what makes it fightable, and building your Level makes the fight easier. The Critic's Reckoning: fans of words, sprays of ink pools on the floor and a telegraphed lunge; after a lunge it sags and the Quill lands 60% harder; below half health it hurries.
**The three Reckonings:** *The Critic* (Garrick): fans of words, floor ink pools and a telegraphed lunge; strike its words out of the air to rewrite them and send them back (the Quill's whole idea), it sags after a lunge, and it slips away across the forge if you hit it too much in a row. *The Spoiler* (Pip): the book comes down to eye level and keeps fanning paper cuts, diving and reading sentences; striking it while it reads strikes the sentence out and wounds it badly, and it takes double damage while staggered after a cancelled sentence. *The Cold Shoulder* (Maud): a frost figure that always turns its shoulder toward you; the Quill only lands from behind, so you circle it, and holding the Lantern on it warms it and slows its turning; it slams a warned ring on the floor and rests, open, afterwards. Dying resets a boss's health in the Reckoning.

## 28. Dungeons match the overworld
Every memory now has two lantern posts (rest, and the Index without fast travel: workbench, stall, levelling) and **three locked vault chests (word trials, one per stretch of the dungeon, tiers 1 to 3)** with the same tier-scaled prizes. Redaction bars (the black censor bars) are read away by **holding the Lantern and aiming it at the bar**; a hint chip with the bound button now floats over any bar you are near.

## 29. Cutscenes
A small cinematic system (`LevelBase.cinematic`) plays at the moments that deserve one: letterbox bars slide in, the camera glides to the subject and pushes in, the dialogue plays over it, and the camera returns to the Storytender. In use now: every memory boss intro, the Critic's, the Spoiler's and the Cold Shoulder's Reckoning reveal, every memory boss ending, the Scissor-Man's entrance and defeat, and the Editor's tear opening in the overworld. The New Game storybook is its own cutscene. Rule of thumb: a cutscene is for a reveal, an entrance or a turning point; never for something the player is about to do again. The sword pickup, the memory endings (Pip, Maud) and all three restoration scenes (Garrick, Pip, Maud) also use it now. Planned: the Margin Gate opening and chapter transitions.

## 30. The opening hours, in order (current flow)
1. New Game: choose Story or Normal, then the storybook (what a Storytender is, the Editors, the Redaction, page 41) and the doodle waking up on the page.
2. Walk the Prologue. Lantern posts light up and open the Index (workbench, stall, levelling, map). The first Index visit hands you 15 free attribute points.
3. Garrick's ghost sends you into his memory. You fight the Critic's Reckoning with the pencil stub (struck words fly back for 18 damage, so parrying matters most). The First Sword waits on the anvil when the Critic falls: a real melee upgrade (full damage and reach) that you carry out to Garrick.
4. **The Errors roam the overworld from the very start.** You begin with a **pencil stub** (about half the damage and reach of the real thing), so the first fights are small and careful; Garrick's First Sword (the reward at the end of his memory) and then the Quill are the real weapons. Beating Errors drops materials and gear (section 24), gives Renown, and they return when you rest at a post.
5. Vault trials, hidden caches behind Redaction bars (hold and aim the Lantern at the bar), dungeon vault chests and boss Reckonings feed the Level and crafting loop; the Margin Gate asks for 220 Renown.

## 31. Design decisions log (things we agreed on, in one place)
- **Tone:** semi-emotional: a silly surface with something sincere underneath.
- **Souls-like in a 2D isometric, bookish key:** Mnemosynth is souls, lantern posts are bonfires (rest, resets the page, opens the Index), levelling is spending a currency that costs more each time, bosses have a puzzle and a fight, dying drops Mnemosynth. The setting, the verbs (rewrite, remember, format), the Index hub and the word-game vaults keep it its own thing.
- **Difficulty is chosen at New Game** (Story or Normal) and fixed for the save. Normal pays better drops (more on bosses).
- **Height must read clearly at every graphics setting** (non-negotiable), with cut-paper art that is appealing to look at; see sections 21 and 22 for the graphics options and performance architecture aimed at integrated GPUs.
- **The Prologue is not a chapter**; later chapters (Plot-Twist Peaks, Purple Prose Swamp, The Final Chapter) are at least 4x its size with bigger towns and more characters; dungeons and memories stay short.
- **The grind is deliberate:** Renown from side quests, mini-dungeons or beating enemies; the roster of Errors keeps growing past six as the story goes on; level costs rise every point.
- **Every NPC, memory and boss has its own mechanic** without feeling repetitive (callbacks are welcome).
- **Controller is a first-class device:** rebinding for keyboard/mouse and pad, glyphs that follow the last device used, a button legend at the bottom of every menu, B backs out of menus, a slowed menu stick, letter-grid typing and a rhythm trial for pads.
- **Menus use WASD**; a pocket workbench is the only portable crafting; shop and map live at lantern posts.
- **Hidden items, side quests and missions** are wanted from the Prologue on (hidden caches are the first step).
- **Known gaps:** the Cold Shoulder and Critic are untuned against real players, level-matched Mnemosynth income for later chapters, a respec option, and rank perks.

## 32. Rendering note: walls and nearer tiles
Ground is painted behind everything, which used to let a wall (or stair) draw over the top of a nearer tile, most visibly along diagonal page edges where it made a stack of floating wall slabs. A wall or stair now repaints the tops of the nearer tiles it overlaps, nearest last (`IsoSlice._recover`). Cost: about 70 extra draw calls in an edge-heavy view on Balanced. A second fix: two tutorial cards opening at once could leave the game frozen; later cards now queue, and a watchdog frees the player if the game ever thinks a conversation is open when nothing is.

## 33. Music (system built, tracks to come)
The `Music` autoload is in place and ships empty: any file named after a slot in `assets/music/` (for example `overworld.ogg`, `boss_critic.ogg`) starts playing in that place; slots with no file stay silent, so tracks can be added one at a time. Tracks loop and crossfade, dip about 7 dB under dialogue, tutorial cards and cutscenes, and obey **Settings > Music volume** (separate from Master volume). Slots wired: title, storybook, overworld (plus optional per-region `region_<id>`), the Index hub, each memory, the Scissor-Man arena, each boss in two halves where there are two (puzzle, then Reckoning), and a one-shot `victory` sting. The full list and a credits table (every track's license and source must be recorded; CC-BY needs on-screen credit) live in `assets/music/README.md`. Royalty-free sources to browse: incompetech (Kevin MacLeod), OpenGameArt, Pixabay Music, itch.io asset packs; the mood to aim for is a gentle music-box and parchment feel, tenser for the Critic and the Cold Shoulder. Choosing the tracks themselves is deferred until the game is closer to complete.

## 34. Art-style Skins (compare looks on the real game)
**Settings > Art style** (or **F9** anywhere) cycles whole-world looks: *Cut Paper* (the default, hand-built), *Pencil Sketch*, *Watercolor*, *Pixel*, *Ink Noir* and *Picture Book Print*. They are screen filters (`shaders/skin.gdshader`, `Skins` autoload) that restyle the world but never the HUD, dialogue or menus, and cost nothing when off (filters do cost some GPU on integrated graphics, so judge speed separately). Purpose: pick a direction by seeing it in play. **Character and art direction:** the current art is procedural code (shapes drawn in script); hand-painted or illustrated characters need an artist or an image tool, then get imported as sprite sheets. The planned hook is a per-skin sprite folder (`res://skins/<id>/`) that overrides the procedural Storytender, NPCs and Errors when its PNGs exist. If any AI-generated art is used, store pages (Steam in particular) ask for it to be disclosed, and the license of any tool or asset must be recorded.

## 35. The wider prologue: regions, puzzle sites and side dungeons (implemented v2.15)
Design law from playtesting: the village is the hub, not the whole prologue. Garrick, Pip and Maud stay in town; everything else is spread across the map.
- **Four new regions** branch off the old map: Folio Heights, the Dog-Ear Cliffs, the Lost Margin and the Smudge. Each has its own lantern post, lore signs, camps, small clusters and dais caches.
- **Thirteen puzzle sites** replace the old "chest in a square of trees" (generated by `tools/gen_phase2.py`, driven by `SITES` in `data/prologue_map.gd`, run by `scripts/puzzle_sites.gd`). Only two vault-trial minigames remain (about 2 in 10). The rest reuse learned mechanics:
  - **Echo:** remember an Echo (Garrick's memory), hold one plate with it and stand on the other.
  - **Words:** set three sentence stones the way a nearby sign says and a page bridge unrolls over the moat.
  - **Arena:** step on the plate, the gate slams, beat two waves, it opens.
  - **Crumble:** a zig-zag causeway of loose pages that falls away behind you.
  - Sites keep a minimum distance from each other; gates stand on the flat top of a stair, never across the steps.
- **Two side dungeons**, entered by portals: the **Weighing Room** (needs the Echo; reward Hourglass of Drafts) and the **Proof Room** (needs the quill; reward Censor's Monocle).
- **Respawn:** dying outside a dungeon returns you to the last lantern post you rested at; loading a save places you beside the nearest post. Quick items: two slots with a swap button.
- **Look:** chests, gates, spine walls and sentence stones use the weathered storybook look (see `docs/ART_BIBLE.md`).

## 36. Chapter 1 dungeon design brief (planned, from playtesting)
Dungeons from Chapter 1 onward are built from **multiple literal rooms**, not one flow of mini-games:
- **Collect-to-open structure.** A dungeon asks you to gather several things (for example X, Y and Z, in any sensible order) from different rooms, and only then does the way to room A open. Rooms are connected, revisitable and readable as a place.
- **Real puzzles, not mini-games.** Each room is a "get from point A to point B" problem solved with the skills the player has *at that point in the story* (Echo, Lantern/rewrite, Format, clipboard, stealth, and anything learned since). Difficulty rises across the dungeon and across chapters.
- **Skills define the puzzle.** Design each room around a combination of known skills. Do not add a one-off minigame to a room that a skill combination could solve.
- **Mini-games stay rare** (the 2-in-10 rule from the prologue overworld) and are never required to progress a dungeon.
- **Scope check before building:** list the skills available at that chapter, the items to collect, and the gate each one opens. Add a reachability test for every room, as the prologue generators do.

### Garrick's memory, rebuilt as a hub (implemented v2.16, per section 36)
The four straight rooms are replaced by connected rooms. The Forge (the Critic fight) is unchanged. Generated by `tools/gen_forge.py` (reachability-checked: nothing behind a gate is reachable while it is shut).
- **The Cold Hearth** (start): one plate, one gate. The Echo tutorial, as before.
- **The Long Hall** (hub): two posts, wandering Bares, and the **Forge Door** (shows 0/3, 1/3, 2/3). Three wings branch off.
- **The Bellows Loft** (north, two chambers): a chain puzzle. Echo 1 holds the first gate open from its plate; walk in, record Echo 2 up the stair onto the ledge plate, and the second gate opens onto the **bellows**.
- **The Apprentice's Bench** (south-west): two plates, one up a stair on a raised platform, one across the room. Both echoes must hold at once to open the gate to the **hammer**; a Bare waits inside.
- **The Night Watch** (south-east): a guard stands by the plate; lure it with an echo, then hold the plate to open the gate. The **tongs** sit behind a black Redactor bar that only the Lantern can read away.
- Collect all three tools (any order) and the Forge Door opens. Skills used: Echo, Lantern, combat/avoiding, elevation. No mini-games required (optional vault trials remain).
