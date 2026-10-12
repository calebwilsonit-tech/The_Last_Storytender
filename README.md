# The Last Storytender

2.5D narrative survival / action-adventure in Godot 4.3 (GL Compatibility renderer).
Design doc: [docs/GDD.md](docs/GDD.md)

## Run
Open this folder in Godot 4.3+ (Project Manager → Import → `project.godot`) and press F5. The game starts at the title screen; New Game asks for a difficulty, which is fixed for that save.

## Current build: Phase 2 + the first Story Realm
Walk the **Prologue Plains**, climb the stairs into **Thistledown** (a Redacted ghost town on a raised page),
and meet the placeholder blacksmith. Touch the **frozen flame** in his forge to enter his memory, **The
Blacksmith's Regret**. Hold up three memories to the Lantern to quiet **The Critic** (his own inner voice,
made of red ink), take the **First Sword**, and bring it back to restore the town.

Controls: **WASD** move · **E / Space / Enter** speak, take, advance dialogue · **Click / J** Quill (after Garrick's lesson) · **Shift** dash · **Hold Q / right mouse** Lantern · **Tab / I** binder · **F** quick-use item · **Ctrl / C** creep · **R** remember an Echo (Garrick's memory) · **V** paste (Scissor-Man fight) · **1 / 2 / 3** Quill styles (Maud's memory) · **Esc** pause / settings · **F10** save the playtest report · **F1** test damage, **F2** heal, **F12** wipe save.

What's in:
- Isometric 2:1 world with **elevation**: height levels, stairs, solid cliff edges, stacked-paper page edges, depth-sorted so tall terraces hide what's behind them. Maps are text (`data/*.gd`).
- **The Storytender**: hooded wanderer with a glowing lantern, walk cycle, front/back/mirrored facing.
- NPCs show **missing** (static + purple glitch) vs **restored** (color + cyan glow) states; the ghost town recolors in a wave from the restored person.
- **The Blacksmith's Regret** (`scripts/memory_forge.gd`): frozen-time forge, three memory shards on raised terraces, The Critic boss that throws discouraging-word projectiles (slow / dim debuffs), memory vignettes with Young Garrick and Wren, a quiet finale.
- **Combat:** Quill combo, dash, and a Lantern beam that proofreads Typo-Ghoul Bares back into Bears and burns Redactor bars off the path. Garrick teaches it at a training dummy. See GDD section 11.
- **Inventory:** a binder UI (Tab) with a paper-doll that shows equipped Bindings and amulet, a card catalog of items, quick-use, Eraser Crumbs bombs, Ink Vials, and **autosave**. See GDD section 13.
- **Pip's memory ("The Last Page")**: a pop-up storybook with a rewriting mechanic (Quill changes the word in a sentence), four rooms, and The Spoiler boss that announces the future and lets you rewrite it. Restoration is per-NPC. See GDD section 14.
- **Stealth:** enemies have vision cones, hearing and line of sight; creep (Ctrl/C), sneak attacks, search behavior. **Maud's memory ("The Empty Table")** introduces the Format mark: keys 1/2/3 pick Underline / Bold / Italic and typography acts as physics (bridges, pressure plates, sliding blocks, dough that must be waited for), with a boss about seating guests between waves of cold. See GDD section 18.
- **The Scissor-Man (Thistledown's Editor, "Cut Content")**: once Garrick, Pip and Maud are restored a tear opens in the square. The fight's verb is the Clipboard: he cuts holes in the page, you pick up what he cut and paste it as a patch, and his shears jam on a patch so you can hit him. Rewards the Thimble. See GDD section 19.
- **Garrick's memory** is four rooms. Its verb is Echoes: record your own movement (R) and a ghost of you replays it and stays, holding plates and luring guards. See GDD section 20.
- **Difficulty:** Normal / Story, a real death cost in Normal, a tuned Critic (leads shots, ink pools) and Spoiler, and a **playtest log** (F10). See GDD section 15.
- Plot holes (fall = lose ink, respawn safely), crumple/smooth-out recovery, typewriter dialogue with clacks, Narrator and Silence text.
- All story text in `scripts/story.gd`. Design: `docs/GDD.md`. Art direction and your reference sheets: `docs/ART_DIRECTION.md`, `docs/art_reference/`.

Art is procedural stand-in art that follows the reference sheets' outline/color/glow language; swap in real sprites later (see the art direction doc).
Fonts: IM Fell English (SIL OFL, `assets/fonts/OFL.txt`).

## Phase 1 systems still present
- Parchment shader (`shaders/parchment.gdshader`, exposes a `glitch` uniform for Phase 3) and the ink-bottle health bar.


## Controller, rebinding and tutorial cards
- **Controller:** left stick moves, right stick aims, A interact, X (or RT) Quill, LT Lantern (hold), B dash, L3 creep, View binder, Y quick item, D-pad left/up/right Underline/Bold/Italic, RB paste, LB Echo, Menu pauses. Glyphs follow the pad in use (Xbox, PlayStation shapes, Nintendo).
- **Settings > Controls** rebinds keyboard/mouse and controller separately (an input already in use is swapped). Saved with your settings.
- **No always-on button bar.** Things you can interact with show a prompt chip with the right button, and the first time a mechanic unlocks (walking, Lantern, Quill, binder, stealth, and the starts of Pip's, Maud's and Garrick's memories and the Scissor-Man) a tutorial card explains it. Turn the cards off in Settings > Tutorial tips.

## The world and the map
The Prologue overworld is about four times larger than before: eleven regions to explore (Page's Edge, Margins Meadow, Old Meadow, Thistledown, Whispering Orchard, Ink-Wells, Footnote Hollow, Hushed Glade, Mill Ridge, the Graveyard of Deleted Scenes and the Margin Gate). Light lantern posts to rest and set your respawn point. Press **M** (D-pad down on a controller, or Map in the pause menu) to open the map: it shows what you have discovered, and you can travel between lit posts that are far apart. The first world is called the Prologue; the chapters come after. See GDD section 21.
