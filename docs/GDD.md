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

**Boss principle:** you never win by dealing more damage, you win by remembering. Memory bosses are beaten by holding memories up to the Lantern while surviving their attacks. Editors are beaten by exposing and cutting their "edits" (Quill / Lantern / Eraser Crumbs).

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

**The Spoiler fight (reading the screen):** every 8s it announces a spoiler ("The floor beneath the WEST collapses."; "Wolves from the NORTH attack."), the cells flash red, and a sentence stone appears elsewhere on the platform. Do nothing and the floor becomes plot holes (7s) or Mites spawn. Rewrite it in time and the floor blooms into flowers that heal you. After 3 rewrites it speaks two sentences at once. Five rewrites win. The sky darkens while the Spoiler is winning and brightens as you succeed.
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
**The Spoiler:** window shrinks from 5.0s to 3.2s as you rewrite; stones sit at least 4 tiles away; speaks every 6.5s (Story 8); wolf events spawn 3 Mites.
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

| Town | Mark (verb) | What it does | Status |
|---|---|---|---|
| Thistledown (Pip) | **Rewrite** | Swap a word in a sentence | Built |
| Thistledown (Maud) | **Format** (Underline / Bold / Italic) | Text styling acts as physics (below) | Proposed |
| Plot-Twist Peaks | **Fold / Reorder** | Dog-ear a page corner, shuffle chapters | Proposed |
| Purple Prose Swamp | **Strike** | Delete words (adjectives, "not", whole sentences) | Proposed |
| The Final Chapter | **All marks, at once** | Combined | Proposed |

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

### Proposed assignment
- **Maud's memory ("The Empty Table"):** the *Format* mark (idea 2), one *waiting* puzzle (7), one *unreliable Narrator* puzzle (6), and the boss is her fear that nobody is left to feed.
- **Garrick's memory (extension to 3-4 rooms):** *strike-through negation* (3) and a *footnote portal* room (5).
- **Starter-area secrets:** letter-level proofreading (1) hidden in the Plains.
