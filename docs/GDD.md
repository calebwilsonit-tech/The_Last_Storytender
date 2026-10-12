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
3. **The Story Realm (Flashback)** — dungeon inside a memory. Example: *The Blacksmith's Regret* (frozen forge fire; find the First Sword; boss **The Critic**, red ink that shouts debuffing words: "Derivative!", "Boring!", "Slow Paced!").
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
