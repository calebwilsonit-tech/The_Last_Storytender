# The Last Storytender

2.5D narrative survival / action-adventure in Godot 4.3 (GL Compatibility renderer).
Design doc: [docs/GDD.md](docs/GDD.md)

## Run
Open this folder in Godot 4.3+ (Project Manager → Import → `project.godot`) and press F5.

## Phase 1 sandbox (current)
- WASD / arrows: move the Storytender
- SPACE: take ink damage (splatters; at 0 ink the doodle crumples)
- H: restore ink
- Parchment shader (`shaders/parchment.gdshader`) scrolls under the camera; it already exposes a `glitch` uniform for Phase 3.
- HUD: ink bottle health bar that cracks and leaks at low ink.

Art is drawn procedurally in code for now; replace with real assets later.
