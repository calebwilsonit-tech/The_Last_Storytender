# The Last Storytender

2.5D narrative survival / action-adventure in Godot 4.3 (GL Compatibility renderer).
Design doc: [docs/GDD.md](docs/GDD.md)

## Run
Open this folder in Godot 4.3+ (Project Manager → Import → `project.godot`) and press F5.

## Current build: Phase 2 + the first Story Realm
Walk the **Prologue Plains**, climb the stairs into **Thistledown** (a Redacted ghost town on a raised page),
and meet the placeholder blacksmith. Touch the **frozen flame** in his forge to enter his memory, **The
Blacksmith's Regret**. Hold up three memories to the Lantern to quiet **The Critic** (his own inner voice,
made of red ink), take the **First Sword**, and bring it back to restore the town.

Controls: **WASD** move · **E / Space / Enter** speak, take, advance dialogue · **Click / J** Quill (after Garrick's lesson) · **Shift** dash · **Hold Q / right mouse** Lantern · **Tab / I** binder · **F** quick-use item · **D** (in the binder) difficulty · **F10** save the playtest report · **F1** test damage, **F2** heal, **F12** wipe save.

What's in:
- Isometric 2:1 world with **elevation**: height levels, stairs, solid cliff edges, stacked-paper page edges, depth-sorted so tall terraces hide what's behind them. Maps are text (`data/*.gd`).
- **The Storytender**: hooded wanderer with a glowing lantern, walk cycle, front/back/mirrored facing.
- NPCs show **missing** (static + purple glitch) vs **restored** (color + cyan glow) states; the ghost town recolors in a wave from the restored person.
- **The Blacksmith's Regret** (`scripts/memory_forge.gd`): frozen-time forge, three memory shards on raised terraces, The Critic boss that throws discouraging-word projectiles (slow / dim debuffs), memory vignettes with Young Garrick and Wren, a quiet finale.
- **Combat:** Quill combo, dash, and a Lantern beam that proofreads Typo-Ghoul Bares back into Bears and burns Redactor bars off the path. Garrick teaches it at a training dummy. See GDD section 11.
- **Inventory:** a binder UI (Tab) with a paper-doll that shows equipped Bindings and amulet, a card catalog of items, quick-use, Eraser Crumbs bombs, Ink Vials, and **autosave**. See GDD section 13.
- **Pip's memory ("The Last Page")**: a pop-up storybook with a rewriting mechanic (Quill changes the word in a sentence), four rooms, and The Spoiler boss that announces the future and lets you rewrite it. Restoration is per-NPC. See GDD section 14.
- **Difficulty:** Normal / Story, a real death cost in Normal, a tuned Critic (leads shots, ink pools) and Spoiler, and a **playtest log** (F10). See GDD section 15.
- Plot holes (fall = lose ink, respawn safely), crumple/smooth-out recovery, typewriter dialogue with clacks, Narrator and Silence text.
- All story text in `scripts/story.gd`. Design: `docs/GDD.md`. Art direction and your reference sheets: `docs/ART_DIRECTION.md`, `docs/art_reference/`.

Art is procedural stand-in art that follows the reference sheets' outline/color/glow language; swap in real sprites later (see the art direction doc).
Fonts: IM Fell English (SIL OFL, `assets/fonts/OFL.txt`).

## Phase 1 systems still present
- Parchment shader (`shaders/parchment.gdshader`, exposes a `glitch` uniform for Phase 3) and the ink-bottle health bar.
