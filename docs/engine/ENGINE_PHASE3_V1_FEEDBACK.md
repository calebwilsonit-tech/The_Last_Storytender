# Phase 3 prompt: owner feedback on v1 (UI, Claude, blocks and gravity, cleanup, plugin SDK)

> Send everything below the line to the Claude session working on
> Tilewright (repo `calebwilsonit-tech/TileWrite`). The file and line
> references were taken from a read-through of that repo on 2026-10-23;
> they may have moved slightly since, so confirm each one before relying
> on it.

---

The first version of Tilewright is built and the owner has been using it.
This phase fixes what they hit, extends a few systems, cleans up the engine
after a lot of additions, and turns packs into a real plugin platform.

Working rules as before: small commits, always green (`npm run typecheck`,
`npm run lint`, `npm test`, and the e2e suite for anything touching the
editor); reproduce every bug with a failing test before fixing it; use
every feature through the real editor UI (Playwright) and look at
screenshots; never tick a box you did not verify; report honestly.

The owner keeps `PROGRESS.md`, `DECISIONS.md` and `KNOWN_ISSUES.md` outside
the repo. If they are not in your working copy, ask the owner for them
before starting, and keep them updated as you go.

## The two rules above everything else

### Rule A: Nothing the owner has made may break

The owner has projects in progress. Every one of them must open, run, play
and export exactly as before, with **no changes on their side**.

1. **Before changing anything, build a compatibility corpus** in
   `compat/`: every folder in `samples/`, `templates/last-storytender`,
   every code template in
   `packages/editor/src/renderer/project/templates.ts`, and **every project
   of the owner's**. The owner's projects are not in the repo: ask the owner
   to copy them into `compat/projects/` (or give you their path) and wait
   for that before Step 3. For each, record a baseline: loads with no
   warnings, golden screenshots of each scene, an input replay
   (`InputRecorder` / `replayPlaythrough`) or playbot trace, a save
   round-trip, a typecheck of its scripts against the script API, and an
   export build.
2. `npm run compat` re-runs the corpus and diffs against the baseline. Add
   it to `.github/workflows/ci.yml` and run it before every commit in this
   phase. Any difference fails unless it is an intended, documented fix,
   and even then the project must still work.
3. **Project files:** `CURRENT_SCHEMA_VERSION` is 1
   (`packages/runtime/src/project/schema.ts`) and `migrate.ts` has no
   migrations yet. Never change the meaning of an existing field; new
   fields get defaults that reproduce old behaviour. Any format change bumps
   the schema version with a tested migration, and the editor backs up the
   project before its first save in the new version.
4. **Script API** (`packages/behaviors/src/scripting/api.ts`) is not
   versioned today. Give it a version (start at 1.0.0) and treat it as
   public semver: nothing removed or renamed in this phase; old names stay
   as aliases with a deprecation warning saying what to use instead.
5. **Behaviour changes** that projects might rely on (physics, fade,
   screens, default packs) go behind a per-project **compatibility flag**:
   existing projects get the old behaviour automatically, new projects get
   the new one. Note that projects with no `packs` field currently fall back
   to `LEGACY_PACKS` (`packages/behaviors/src/packs.ts:238-241`); that
   fallback must keep working for old projects. Give the owner a list of
   which projects got which flags and how to switch each off.

### Rule B: The engine revolves around nothing

The owner says it still feels like the engine is built around one game.
The code agrees. The phase-2 `docs/genre_audit.md` moved a lot into
packs, but the packs only `adopt(...)` behaviours and event blocks that
still live in core, and many core files still know about the reference
game. Fix it for real:

- The **core** is a small kernel: scenes/entities/components, iso math and
  rendering, the block world, physics, input, audio, assets, the UI
  framework, the logic system, save/load primitives, the editor shell and
  the plugin host. Everything else (genre modules, combat, inventory,
  story, AI, lighting, the Storytender set, prebuilt screens, templates,
  the hub client) is a **first-party plugin** whose code lives in the
  plugin, built only with the public plugin SDK (Step 7).
- Known leaks to remove from core (move into the relevant plugin, keeping
  saved data working):
  - `packages/runtime/src/physics/physics.ts:19`: an `ECHO` collision
    layer. Make collision layers user-defined; plugins register their own.
  - `packages/runtime/src/input/keyboard.ts` `DEFAULT_INPUT_MAP` /
    `ACTION_LABELS` (around 185-234): echo, "Attack (quill)", inventory,
    map. Plugins contribute their own actions.
  - `runtime/src/story/worldmap.ts` (a `'lantern'` unlock kind),
    `core/simulation.ts` (lantern-post respawn), `story/save.ts` ("the
    last lantern"), `ui/layout.ts` ("Lantern light bar").
  - `packages/behaviors/src/builtins/echo.ts`, `light.ts`, `text.ts` and
    the echo/sentence blocks in `events/sheet.ts` (e.g. `echoCount`,
    `stoneSays`): move the code into the Storytender plugin, not just the
    registration.
  - `packages/editor/src/renderer/tools/prefabs.ts`: hardcodes Lantern
    post, Sentence stone, Rising dough, Lantern and others, and `PREFABS`
    is **not filtered by active packs**. Prefabs come from plugins and only
    show when the plugin is enabled.
  - `editor/src/renderer/model/validate.ts` (around 142-151: sentenceStone
    and echoRecorder checks): validators come from plugins.
  - `PlaybotPanel.tsx` ("Hold the plates with echoes" button),
    `play-session.ts` (`'lantern-lit'` listener), `ViewportPanel.tsx` (hint
    "R records an echo, J attacks"), `AssistantPanel.tsx` (example prompt
    about echoes).
  - `templates.ts` `baseProject()` defaults to `LEGACY_PACKS` when no packs
    are passed: new projects must default to none.
- Add an automated **"core is neutral" test**: fails if core packages
  import from any plugin, or contain game-specific names (start the
  blocklist with `storytender, echo, lantern, sentence, dough, quill,
  mnemosynth, critic, spoiler`, extendable).
- The empty template stays a plain map, a camera and no plugins.

## Background: the reference game, and its UI as an example only

The engine was first specified from **The Last Storytender**, the owner's
Godot game (isometric, 64x32 tiles, paper/parchment look). Its UI is a good
example of what users will want to make. The engine must make this kind of
UI **easy to replicate, without any of it being built in**:

- **Title screen:** parchment background with a shader, a vertical list of
  parchment buttons (Continue / New Game / Settings / Quit); New Game asks
  for a difficulty that is then locked for that save.
- **Menu column:** a reusable vertical list of parchment buttons with an
  optional description box under it, keyboard/mouse/gamepad navigation,
  disabled items, and a `chosen(id)` event. Used by title, pause and
  sub-menus.
- **Pause menu:** a main list plus sub-pages that replace it (Settings, a
  "Travel" list of lit checkpoints, a "Restart?" confirmation). Back goes
  to the previous page, not out of the menu.
- **Settings page:** one panel shared by the title and pause menus; rows
  picked with Up/Down, adjusted with Left/Right, toggled with Enter
  (volume, music, fullscreen, graphics, skin, screen shake, dialogue speed,
  tips, log, controls, difficulty, back), with a controls sub-page for
  rebinding.
- **Inventory ("the binder"):** an open book. Left page: a paper doll of
  the character with equipment slots and stats. Right page: a 4-column grid
  of item cards with scrolling, hover and selection. Opens/closes with
  Tab / I / Esc.
- **World map:** an unfolded parchment showing only discovered regions, a
  chapter list on the left, lit checkpoints as waypoints, a "you are here"
  marker; arrows move between waypoints, Interact fast-travels, and posts
  too close to be worth travelling to are hidden.
- **HUD:** a resource gauge, a currency counter, the region name, an
  interaction prompt, toasts, a boss name and health bar, and floating
  narrator text.

Each must be buildable **with general widgets, the UI designer, data
binding and Quick Actions/wires only**. Where that is awkward, improve the
general tools (a two-page "book" is two child panels; a paper doll is an
image with slot widgets bound to equipment data). Ship them as an optional
**"Parchment UI kit" sample plugin**, with recipes in `docs/recipes/`. They
are examples, never defaults.

## Step 1: Fix the custom-screen bug (owner's note 1a)

**What the owner sees:** with their **own** screens from the UI designer,
whatever screen they are on, they get sent to the **pause menu**. The
prebuilt screens do not do this.

**Cause found in the read-through** (confirm with a failing test first):
`GameUi.handleInput()` in `packages/behaviors/src/ui/game-ui.ts`
(around lines 505-549).

- **Bug A: one Esc press is handled twice in the same tick.** When a
  modal designer screen is on top and `pause` is pressed, the first block
  calls `backScreen` / `closeScreen`. That makes `runtime.ui.modal` false, so
  the `if (stack.length > 0 && sim.runtime.ui.modal) return;` line does not
  return. Execution falls through to `if (!this.builtinOpen) { ...
  if (ui.pressed('pause')) this.openMenu('main'); }`, and
  `ui.pressed('pause')` is still true for the whole tick. Input presses
  are never consumed (`packages/runtime/src/input/input.ts`, `pressed()`).
  So Back from any custom screen lands on Pause, and closing a custom
  Pause reopens it at once.
- **Bug B: non-modal screens.** `UiScreenSchema.modal` defaults to `false`
  (`packages/runtime/src/ui/model.ts`) and the designer's `addScreen` also
  creates screens with `modal: false`
  (`packages/editor/src/renderer/uidesigner/ui-edit.ts`). With a non-modal
  user screen on top, Esc never goes back: it always opens Pause. A
  non-modal user Pause cannot be closed with Esc at all.
- **Why prebuilt screens work:** they are not designer screens. They are a
  hardcoded state machine inside `GameUi` (`type Screen = 'title' |
  'main' | 'inventory' | 'travel' | 'map' | 'save' | 'load' | 'settings' |
  'controls'`, rows built in a `switch (this.screen)`, `back()` walks a
  fixed parent chain, `builtinOpen` returns early). That separate code path
  is also why they cannot be edited (Step 2).
- Also: `RESERVED_SCREENS.settings` is never honoured, so the built-in
  pause menu's Settings row always opens the built-in settings. Inventory,
  map, travel, save/load and controls cannot be replaced at all.

**Fix it generally, with one screen system for everything:**

- Consume input: once a screen handles a press, nothing else sees it that
  tick (an explicit `consume(action)` on the UI input, used everywhere).
- A single **screen stack/router** with visible per-screen settings in the
  inspector: *pauses the game*, *blocks gameplay input*, *what Back does*
  (previous screen, a chosen screen, close, nothing), *input priority*,
  *transition*. Splitting today's single `modal` flag into "pauses" and
  "blocks input" is a schema change: migrate old screens so they behave as
  before (Rule A).
- The top screen gets input first; nothing underneath reacts unless the
  screen lets it through.
- The pause key is a normal input binding with a visible Quick Action
  ("Open screen: Pause") the user can change or delete. It does nothing
  while an input-blocking screen is open.
- A **debug overlay** showing the screen stack and which screen handled
  the last input.
- Regression tests: `samples/ui-showcase` reproduces the bug (Inventory is
  modal; Esc pops it and Pause opens). Cover modal and non-modal screens,
  custom Pause, custom Title, and gamepad Start.

## Step 2: Make every prebuilt UI editable (owner's note 1b)

- Rebuild every hardcoded `GameUi` screen (title, main/pause, inventory,
  travel, map, save, load, settings, controls) and the HUD as **ordinary
  UI-designer assets plus logic**. Delete the private code path once the
  compat corpus proves the rebuilt screens behave the same.
- They ship in plugins (Rule B). In a project, each has **Customize**
  (make an editable copy owned by the project, wired into the same
  places), **Revert to default**, and, when the plugin's version updates,
  a side-by-side comparison so the user can take the changes or keep
  theirs.
- Replace the reserved-name trick (`RESERVED_SCREENS`, designer hint in
  `UiDesigner.tsx`) with explicit "this screen is used as: Title / Pause /
  Settings / ..." roles that any screen can take. Keep reserved names
  working for old projects.
- Customized screens can be saved to the personal library and reused.

## Step 3: A more capable Claude assistant (owner's note 2)

The owner wants Claude to do more inside the engine, **within the current
project only**, never system files.

**Today** (`packages/assistant`, `editor/src/renderer/assistant/store.ts`,
`editor/src/main/assistant.ts`): Zod-checked read/act tools over the
editor's in-memory store; every act tool is previewed and approved; modes
chat/explain/fix/build/review; `MAX_STEPS = 30`; streaming with adaptive
thinking, effort, caching and refusal handling; key in `safeStorage` in
the main process. **Missing:** the user cannot attach images (`send`
takes text only; images only come from the `screenshot` tool), there is no
general file reading (only store data), no image creation, no multi-step
mode with rollback, no permission levels.

Before writing this, load the **claude-api** skill (or the official
Anthropic docs) and follow it, especially for image and document inputs.
Do not write SDK calls from memory. Check what input types the API accepts;
the notes below are expectations, and the docs win.

### 3.1 Uploading images
Drag and drop, paste, or pick images (and viewport screenshots) into the
chat. Claude sees them directly. The API takes common formats such as PNG,
JPEG, GIF and WebP; convert anything else (PSD, Aseprite, SVG, BMP) to PNG
first and downscale very large images. Typical uses: "make a tile like
this", "why does this look wrong", "match this art style".

### 3.2 Reading every file in the project
Tools to list, search and read **any file inside the project folder**,
read the best way for each type:
- **Text and code** (JSON, scripts, CSV, Markdown, shaders): directly, in
  chunks for big files.
- **Images and sprite sheets:** as images, plus metadata (size, frames,
  palette).
- **PDFs:** as documents if the API supports it, otherwise as extracted
  text.
- **Engine assets** (scenes, screens, graphs, tilesets, animations): their
  JSON plus a rendered preview image.
- **Audio:** Claude cannot listen to audio through the API. Give metadata
  (length, format, loudness, loop points) and a waveform image, and say
  so honestly in the UI.
- **Unknown binaries:** metadata and a short summary, never raw dumps.
Keep a **project index** (file tree, assets, what references what) so
Claude finds things without reading everything. Reuse the existing
`resolveInside` check in `editor/src/main` for every path.

### 3.3 Creating images
Claude does not generate pixel images itself. Offer two honest routes and
make the difference clear in the UI:
1. **Claude draws with the engine's tools** (no setup): a tool to create
   and edit sprites and tiles in the sprite/tile studio with drawing
   commands (pixels, shapes, fills, layers, palettes, frames), or SVG the
   studio converts. Good for pixel art, iso tiles, icons and UI frames. The
   result opens in the studio for touch-ups.
2. **Image-generation provider plugins** (optional): an extension point in
   the SDK (Step 7) for third-party image models. The user installs one and
   enters their own key for that service. Claude can call it as a tool, and
   results go through the studio import (slice to tiles, fit to the iso
   template, match the palette). Ship the extension point, a mock provider
   for tests, and docs. Do not choose or pay for a service for the owner.

### 3.4 Doing more, safely
- New tools: edit blocks, tiles, sprites, screens, graphs, tables and
  plugin source in the project; run the game, playbot, validators, tests
  and `npm run compat` equivalents for the project; read logs and the
  profiler.
- **Agent mode** for multi-step jobs: Claude writes a plan, the user
  approves it, Claude works through it with checkpoints, the user can stop
  at any time. A **project snapshot** is taken first so the whole run can be
  rolled back.
- **Permission levels** per project: read-only; ask before every change
  (today's behaviour and the default); auto-apply edits inside the project
  but ask before deletes, plugin installs and network calls.
- **Sandbox:** paths must stay inside the project (test `..`, symlinks,
  absolute paths, case tricks on Windows). Never read `.env`, key files or
  the credential store. No shell access; engine tools only.
- Show tokens and estimated cost per message and per run, with a spending
  limit per run.

## Step 4: Minecraft-style building and gravity (owner's note 3)

### 4.1 What the code does today
From `packages/runtime/src/tilemap/tilemap.ts`, `physics/physics.ts`,
`physics/terrain.ts`, `render/iso-renderer.ts` and `render/depth.ts`:

- The world is a **height map** (`TileMap`: per-cell `tiles`, `heights`,
  `slopes`, `flags`, `decks`, `blockLow`/`blockHigh`) with **optional
  per-cell block stacks** (`stacks: Map<number, CellStack>`,
  `StackBlock {z, tile, faces?}`, `runs()`, `surfaces()`, `syncColumn()`).
  Stairs, ramps and decks cannot become stacks (`toStack` returns null).
- Entities have only `x, y, h`. There is no orientation or "up" direction.
- Collision is **2D movement plus a feet-height test**:
  `surfaceAt(map, x, y, z, ...)` (terrain.ts) asks "what is under the
  feet". `stepBody` moves X then Y and checks the 4 footprint corners **at
  the feet only** (`cornerBlocked`). For stacks, `stackSurface` judges
  head clearance from the standing level `best`, not from `z`. Blocker cells
  (`FLAG.BLOCK`) are the only things solid at every height.
- Gravity is a scalar: `b.vz -= GRAVITY * b.gravity * dt` in `fall()`.
  **Upward motion is never collision-checked** (no ceiling test), and
  landing is tested only when `vz <= 0`, at the centre point.
- `TileDef.wall` only affects the Walls layer's visibility and locking in
  the editor and renderer. **It plays no part in collision.**
- The occlusion fade (`updateFade` in iso-renderer.ts) uses a focus box
  built as an **upright box from the feet `t.h` upward with the sprite's
  w/d/height**. It fades an occluder when `v.box.maxZ > focusBox.minZ +
  0.5`, the screen rects overlap, and `isInFront(focusBox, vb)`. Column
  tiles are one box from `minZ: -1` to the top (`TileMap.boxFor`).
  `relation()` in depth.ts lets ground-plane separation win over height.
- The Blocks tool (`blocksTool` in `editor/src/renderer/tools/tools.ts`)
  already places on a face (`pickBlock` -> `cellBeside`), with add,
  replace, face and delete modes.

### 4.2 The owner's gravity problems
The owner built a gravity switch in their project: press a button and
gravity points at a wall or the ceiling, so they walk on it. Two problems:

1. **On a wall, at certain spots, a block turns see-through as if the
   player were behind it.** Likely cause: the fade's focus box is still an
   upright box rising from `t.h`. On a wall, `t.h` is partway up, so the
   height check passes for any taller column. Then `relation()` decides by
   ground-plane separation, which flips as the player's footprint crosses
   cell edges or overlaps the wall cell. That matches "at certain points".
   The same box feeds depth sorting, so draw order on walls is also
   suspect.
2. **Blocks that are not "wall" blocks are passed through until the shift
   finishes.** The engine never uses `wall` for collision, so whatever
   behaves like a "wall" for the owner is something else. Likely
   candidates: (a) Blocker cells (solid at every height) vs ordinary
   blocks (solid only relative to the feet); (b) the transition moves the
   body upward or sets the transform directly or tweens it, and none of
   that is collision-checked; (c) sideways "gravity" applied as `vx`/`vy`
   is only checked at foot height, and stack blocks above are judged from
   `best`, not `z`.

**The owner's gravity script is not in the engine repo.** Ask the owner
for that project (it should be in the compat corpus anyway), read the
script, reproduce both problems in a test, and report the cause of each:
engine, project, or both. Fix the engine where it is at fault. If the
owner's code is at fault, explain and **propose** a fix as a diff, but do
not edit their project without approval.

### 4.3 Make gravity and blocks general (behind a compat flag for old projects)
- **True 3D block world.** Every block is its own object in an (x, y, z)
  grid, including stairs, ramps and decks (each with an orientation).
  Keep the height-map fast path internally if it helps performance, but
  the model the user and the physics see is blocks. Old projects load
  through a migration and must look and play the same (Rule A).
- **Minecraft-style placement** on top of the existing Blocks tool:
  - the hovered face highlights;
  - click places on that face, right-click (or a modifier) removes;
  - a ghost preview shows where the block will go;
  - a hotbar (1-9) of recent blocks, middle-click eyedropper, and block
    orientation with a rotate key;
  - drag for lines and walls, shift-drag for filled boxes;
  - the existing view rotation, slice view and x-ray reach hidden faces;
  - the same block API, opt-in, **at runtime** for games where players
    build or break blocks, with limits and saving.
- **Gravity as a vector**, per scene with per-entity overrides (the 6 axis
  directions; arbitrary directions optional). Each entity gets an
  orientation/up vector. The character controller works in a
  gravity-relative frame: walking on the plane perpendicular to gravity,
  with ground checks, steps, slopes and jumps along it.
- **Full 3D collision against every solid block**, in every direction of
  movement (including upward/ceiling), using the body's full box, not the
  feet. Block type, layer or the `wall` flag never decides solidity; only
  an explicit "solid" property does (default on).
- **Gravity transitions** (smooth reorientation) keep collision on every
  frame, depenetrate safely if the new orientation starts inside a block,
  and fire `On Gravity Changed` / `On Landed` for logic.
- **Fade and depth sorting use the entity's real 3D box in its current
  orientation.** Fade only occluders that are in front in view depth **and**
  overlap the entity's on-screen silhouette, confirmed by a ray/box test
  from the entity toward the camera through the block grid. Add a little
  hysteresis so blocks do not flicker at edges.
- **Sprites per gravity direction:** animation sets per orientation, with
  an automatic fallback (rotate/skew the down set) until custom art exists.
- Debug overlay: gravity vector, ground contact, body boxes, fade rays.
- A sample where gravity switches between floor, wall and ceiling in a room
  of mixed block types (including stacks with gaps and Blocker cells). The
  playbot walks through every transition, with tests that nothing is
  passed through and nothing fades when the player is not behind it.

## Step 5: Clean up and refine

A lot has been added. Write `docs/cleanup_audit.md`, then fix what it finds
(compat corpus green at every commit):

- **One logic runtime.** Today Quick Actions are stored as wires, sheets,
  graphs and wires share one block registry (`events/sheet.ts`,
  `logic-catalog.ts`) but **execute separately** (sheet rows, the graph
  interpreter in `events/graph.ts`, signals in `signals.ts`), with partial
  conversion (`graph-convert.ts`: graph-to-rows is partial). State machines
  (`builtins/brain.ts`) and behaviour trees (`builtins/tree.ts`) have their
  own logic. Compile all of them to **one shared representation** with one
  interpreter, one debugger and full two-way conversion where possible.
- **Plugin plumbing that is not connected:** `editorExtensions()` and
  `onPacksChanged` in `packages/behaviors/src/packs.ts` have no consumers,
  so pack-provided panels, tools and importers never appear. Either wire
  them up (Step 7) or remove them.
- **Two meanings of "pack":** code packs (`behaviors/src/packs.ts`) and
  asset packs (`editor/src/renderer/library/*`, `hub-server/src/pack.ts`,
  format `tilewright-pack`). Rename so the UI and docs use one clear term
  for each ("plugin" for code, "asset pack" for content).
- **Consistent UX:** the same inspector patterns, naming, shortcuts, undo
  behaviour, empty states, error messages and context menus in every
  panel. Merge panels that do the same job.
- **Naming:** one word per concept across UI, docs and API (API renames
  only with aliases, Rule A).
- Remove dead code, unused assets, stale flags and duplicate utilities; fix
  every warning; refresh docs (`docs/README.md` still leads with echo
  puzzles and links "Echoes, lights and words" as a top-level topic: make
  the docs genre-neutral and move game-specific pages under the plugin
  that owns them).
- **Performance pass:** startup, project load, editor frame time on big
  maps, memory, export size. Record numbers before and after.

## Step 6: Templates and samples, not defaults
Templates are a list of plugins plus starter content. `empty` stays truly
empty, and nothing a template adds is required by the engine.
`templates/last-storytender` becomes a sample that depends on the
Storytender plugin.

## Step 7: Plugins as a real platform (with an SDK)

**Today:** a `Pack` is a code object compiled into `@tilewright/behaviors`
(`{id, name, version, description, requires?, builtin?, install(api)}`,
with `registerPack`). There is no manifest file, no semver checks
(`version` is display only), no permissions, no loading of third-party code
from disk, no SDK package, no scaffolding, no isolation (global
module-level registry), and editor extensions are not consumed. Per-project
enabling works through `project.json` `packs` and a tick-box list in
`ProjectSettingsDialog.tsx`. `PluginApi` offers `behavior`, `condition`,
`action`, `system`, `inputAction`, `panel`, `tool`, `importer` and
`adopt`.

Replace it with a deliberate plugin platform. **Existing packs and project
`packs` lists must keep working**: map each old pack id to its new
first-party plugin automatically.

### 7.1 Plugin manager (editor)
- A **Plugins** window: installed plugins with name, author, version,
  description, permissions and which projects use them; **enable/disable
  per project**, install (from a file, a folder, a URL, or the hub),
  uninstall, update, roll back to an earlier version, view the changelog.
- The project manifest lists required plugins and version ranges. Opening
  a project with a missing or incompatible plugin explains what is missing
  and offers to install it. **Data owned by a missing plugin is never
  deleted**; it is kept as placeholders and comes back with the plugin.
- Disabling or removing a plugin a project uses first shows exactly what
  will stop working.

### 7.2 Plugin format
- `plugin.json` manifest: id, name, version (semver), engine version range,
  dependencies with ranges, requested permissions, entry points (runtime,
  editor, or both).
- **Runtime parts** are bundled into exported games only if the project
  uses them; **editor parts** never ship in exports.
- Plugins can include assets (art, sounds, UI, templates, docs).

### 7.3 SDK
- An npm package (e.g. `@tilewright/plugin-sdk`) with fully typed,
  documented APIs, plus a scaffolding command
  (`npm create tilewright-plugin`) with a starter per extension point.
- **Extension points**, each with a template, docs and an example plugin:
  components, behaviours, logic nodes (conditions/actions/events), UI
  widgets, screens and screen roles, editor panels, editor tools (brushes,
  gizmos), inspectors for custom data, asset importers/exporters, block
  types, collision layers, input actions, physics modifiers, playbot
  strategies, validators, prefabs, project templates, export targets,
  **file readers for the assistant** (teach Claude a new file type),
  **assistant tools** (new abilities, same permission and approval rules),
  and **image-generation providers** (Step 3.3).
- **Developer loop:** load a plugin from a folder in dev mode with hot
  reload, console logs tagged by plugin, breakpoints, and a test harness
  that runs a plugin's tests against a headless engine.
- **Stable API:** versioned; breaking changes only in a new major version,
  with deprecations announced at least one minor version earlier; a
  compatibility check when a plugin loads.

### 7.4 Safety and stability
- **Permissions** shown at install and changeable later: read/write the
  project, network (and which hosts), clipboard, running external programs
  (off by default, strongly warned). A plugin gets only what it asked for
  and the user granted.
- Editor plugins run isolated from the editor core. A plugin that crashes
  or hangs is disabled with a message instead of taking the editor down,
  and its errors go to the problems panel tagged with its name.
- Asset packs containing code keep the existing "look before you approve"
  rule (`approveCode`) and become plugins on install.

### 7.5 Dogfooding
Move combat, inventory, story, AI, lighting, turns, controls, sim, the
Storytender set, the prebuilt screens, the templates and the Parchment UI
kit into **first-party plugins built only with the public SDK, with their
code inside the plugin** (no `adopt` of core code). If a first-party
plugin needs something the SDK does not expose, add it to the SDK
properly; first-party plugins get no private access.

## Done when

1. `npm run compat` passes in CI: every sample, template and owner project
   loads, plays, saves and exports as before, with no changes in the
   owner's projects. The owner has a list of compat flags set and what
   each does.
2. The "core is neutral" test passes; every leak listed under Rule B is
   gone from core; new projects default to no plugins.
3. Custom screens behave like prebuilt ones: Bug A and Bug B have
   regression tests, input is consumed once handled, and the screen-stack
   overlay exists.
4. Every former hardcoded `GameUi` screen is an editable asset with
   Customize / Revert / compare-on-update and screen roles; the private
   code path is gone.
5. The Parchment UI kit (title, menu column, pause with sub-pages, shared
   settings, binder inventory, world map, HUD) is built with general tools
   only, with a recipe each.
6. Claude can: take uploaded images; read every file type as described
   (with the honest audio limit); draw a usable iso tile in the tile
   studio from a text request; call a mock image-provider plugin; run an
   approved agent-mode plan with full rollback. It is blocked from
   anything outside the project (tested with path tricks).
7. The world is a true 3D block world for the user and physics;
   Minecraft-style placement works in the editor and, opt-in, at runtime.
8. Gravity in any axis direction works with mixed block types: nothing is
   passed through in any direction and nothing fades wrongly. The cause of
   each of the owner's two problems is written up (engine, project or both),
   and any change to the owner's project was approved by them.
9. The cleanup audit is done: one logic runtime, plugin plumbing connected,
   one term each for plugins and asset packs, consistent UX and naming, no
   warnings, genre-neutral docs, performance numbers before and after.
10. The plugin manager, manifest, SDK, scaffolding, every listed extension
    point, dev mode, permissions and crash isolation work. Every
    first-party module is a plugin on the public SDK with its own code, and
    old `packs` lists load automatically.
11. All unit, e2e and compat tests pass on Ubuntu and Windows CI.

When all are true, summarise the phase in `PROGRESS.md`, including which
problems turned out to be in the owner's project rather than the engine.
