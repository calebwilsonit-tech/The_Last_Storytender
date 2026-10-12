# The Last Storytender

2.5D narrative survival / action-adventure in Godot 4.3 (GL Compatibility renderer).
Design doc: [docs/GDD.md](docs/GDD.md)

## Run
Open this folder in Godot 4.3+ (Project Manager → Import → `project.godot`) and press F5.

## Phase 2: The Draft (current)
Walk the **Prologue Plains**, find **The First Sword**, and carry it to the placeholder
blacksmith in **Thistledown**, a Redacted ghost town. Giving it back restores his memory
(and the town: ink flows back and color returns).

Controls: **WASD** move, **E / Space / Enter** speak, take, or advance dialogue. **F1** test damage, **F2** heal.

What's in:
- Isometric 2:1 world built from a text map (`data/prologue_map.gd`), Y-sorted, with a paper-stack page edge.
- Plot holes (pits) you fall into (lose ink, respawn safely) and a crumple/smooth-out recovery.
- Ghost town rendered as graphite pencil with `[REDACTED]` bars; restoration wave recolors it.
- NPCs (Garrick, Pip, Maud) as "Lorem ipsum" placeholders until restored; typewriter dialogue with clack sounds.
- Narrator and Silence floating lines; Mnemosynth crystals; ink-bottle HUD.
- All story text in `scripts/story.gd`; art direction in `docs/ART_DIRECTION.md`.

Art is procedural stand-in art for now (see the art direction doc for how to swap in real sprites).
Fonts: IM Fell English (SIL OFL, `assets/fonts/OFL.txt`).

## Phase 1 systems still present
- Parchment shader (`shaders/parchment.gdshader`, exposes a `glitch` uniform for Phase 3) and the ink-bottle health bar.
