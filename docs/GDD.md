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
