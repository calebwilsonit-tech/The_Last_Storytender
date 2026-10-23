# Phase 3 prompt: owner feedback on v1 (UI, Claude, blocks and gravity, cleanup, plugin SDK)

> Send everything below the line to the Claude session that built
> Tilewright. It assumes the original build prompt and the genre follow-up
> are done.

---

The first version of Tilewright is built and the owner has been using it.
This phase fixes what they hit, extends a few systems, cleans up the engine
after a lot of additions, and turns add-ons into a real plugin platform.

Same working rules as before: read `PROGRESS.md`, `DECISIONS.md` and
`KNOWN_ISSUES.md` first and keep them updated; small commits, always green;
reproduce every bug with a failing test before fixing it; use every feature
through the real editor UI (Playwright) and look at screenshots; never tick
a box you did not verify; report honestly.

## The two rules above everything else

### Rule A: Nothing the owner has made may break

The owner has projects in progress. Every one of them must open, run, play
and export exactly as before, with **no code changes on their side**.

1. **Before changing anything, build a compatibility corpus** in
   `compat/`: every sample, every template, and **every project of the
   owner's**. If you cannot find the owner's projects, ask the owner to
   copy them into `compat/projects/` and wait for that before Step 3. For
   each project record a baseline: it loads with no warnings, golden
   screenshots of each scene, a playbot trace or a recorded input replay,
   a save file round-trip, a script typecheck against the engine API, and an
   export build.
2. A `npm run compat` command re-runs the whole corpus and diffs against the
   baseline. It runs in CI and before every commit in this phase. Any
   difference is a failure unless it is an intended, documented fix (and
   even then, the project must still work).
3. **Project files:** never change the meaning of an existing field. New
   things get new fields with defaults that reproduce the old behaviour.
   Bump `schemaVersion` and write a migration for any format change;
   migrations are tested on the corpus, make a backup of the project before
   the first save in the new version, and can be undone.
4. **Script API:** treat it as public and versioned (semver). Nothing is
   removed or renamed in this phase; old names keep working as aliases with
   a deprecation warning that says what to use instead. The owner's
   scripts must typecheck and behave the same.
5. **Behaviour defaults:** when you fix engine behaviour that a project
   might rely on (e.g. physics or occlusion), put the old behaviour behind
   a per-project compatibility flag that existing projects get
   automatically and new projects do not. Tell the owner which projects got
   which flags and how to switch them off.

### Rule B: The engine revolves around nothing

The owner says it still feels like the engine is built around one game.
Fix that for real. The core must not know about any particular game,
genre, mechanic or look. Concretely:

- The **core** is a small kernel: scenes/entities/components, iso math and
  rendering, the voxel/block world, physics, input, audio, assets, the UI
  framework, the logic system, save/load primitives, the editor shell and
  the plugin host. Everything else (genre modules, behaviour sets, the
  Storytender pack, prebuilt screens, templates, the Claude assistant
  tools beyond the basics, the asset hub client) is a **first-party
  plugin** built only with the public plugin SDK (Step 7).
- Add an automated **"core is neutral" test**: it fails if core packages
  import from any plugin, or contain game-specific names (start the
  blocklist with `storytender, echo, lantern, sentence, ink, quill,
  mnemosynth, critic, spoiler`, and let it be extended).
- New empty projects contain only an empty scene, a camera and the plugins
  the chosen template lists (an empty template lists none).

## Background: the reference game and why it is not built in

The engine was first specified from **The Last Storytender**, a Godot game
by the owner (isometric, 64x32 tiles, paper/parchment look). Its UI is a
good example of what users will want to make, and the engine must make
that kind of UI **easy to replicate, without any of it being built in**:

- **Title screen:** parchment background with a shader, a vertical list of
  parchment buttons (Continue / New Game / Settings / Quit), and New Game
  asks for a difficulty that is locked for that save.
- **Menu column:** a reusable vertical list of parchment buttons with an
  optional description box under it, keyboard/mouse/gamepad navigation,
  disabled items, and a `chosen(id)` event. Used by the title, pause and
  sub-menus.
- **Pause menu:** a main list plus sub-pages that replace it (Settings, a
  "Travel" list of lit checkpoints, a "Restart?" confirmation). Back
  returns to the previous page, not out of the menu.
- **Settings page:** one panel shared by the title and pause menus; rows
  picked with Up/Down, adjusted with Left/Right, toggled with Enter
  (volume, music, fullscreen, graphics, skin, screen shake, dialogue speed,
  tips, log, controls, difficulty, back), with a controls sub-page for
  rebinding.
- **Inventory ("the binder"):** an open book. The left page is a paper doll
  of the character with equipment slots and stats; the right page is a
  4-column grid of item cards with scrolling, hover and selection; opens
  and closes with Tab / I / Esc.
- **World map:** an unfolded parchment showing only discovered regions, a
  chapter list on the left, lit checkpoints as waypoints, a "you are here"
  marker; arrows move between waypoints, Interact fast-travels, and
  travel is hidden for posts too close to be worth it.
- **HUD:** a resource bottle gauge, a currency counter, the current region
  name, an interaction prompt, toasts, a boss name and health bar, and
  floating narrator text.

Make sure every one of these can be built **with general widgets, the UI
designer, data binding and Quick Actions/wires only**. Where something is
awkward, improve the general tools (e.g. a "book" two-page layout is just
a panel with two child panels; a paper doll is an image with slot widgets
bound to equipment data). Then provide them as an optional **"Parchment
UI kit" sample plugin** and write recipes in `docs/recipes/` ("A grid
inventory with a paper doll", "A discovered-areas world map with fast
travel", "A shared settings page", "A pause menu with sub-pages"). They are
examples, never defaults.

## Step 1: Fix the custom-screen bug (owner's note 1a)

**What the owner sees:** when they make their **own** screens in the UI
designer, then whatever screen they are on, they get sent to the **pause
menu**. The prebuilt screens do not do this.

Reproduce it first (build a custom screen in the UI designer the way a
user would, open it in play mode, try navigating, pressing Back/Esc,
clicking buttons, opening it from the title screen and from gameplay).
Write the failing test, then find the **root cause**. Likely suspects to
check, but do not assume:

- the pause/cancel input (Esc / Start / "ui_cancel") is handled globally
  by the built-in pause screen, while custom screens are not registered
  with the screen stack, so they never consume the input and the pause
  handler fires underneath them;
- custom screens default to "Back -> pause menu" or have a default
  return/fallback screen in the screen-flow map;
- opening a custom screen pauses the game, and "game paused" is wired to
  "show pause menu";
- prebuilt screens use a private code path the UI designer's screens do
  not get.

Fix it **generally** with one screen system everyone uses:

- A **screen stack/router** with explicit, visible per-screen settings in
  the inspector: *pauses the game* (yes/no), *blocks gameplay input*
  (yes/no), *what Back does* (go to previous screen, go to a chosen
  screen, close, nothing), *input priority*, *open/close transition*.
- The top screen gets input first and can consume it; nothing underneath
  reacts unless the screen lets it through.
- The pause key is just a project input binding with a Quick Action
  ("Open screen: Pause") that the user can see, change or delete, and it
  does nothing while a screen that blocks input is open.
- A **debug overlay** showing the current screen stack and which screen
  handled the last input, so this class of bug is obvious next time.

Existing projects keep working (Rule A): the prebuilt screens get the
same settings they effectively had before.

## Step 2: Make every prebuilt UI editable (owner's note 1b)

The owner wants to edit the preloaded UI (pause menu, title, settings,
save slots, HUD, dialogue box, etc.).

- Every prebuilt screen and widget must be an ordinary **UI asset made
  with the UI designer and the logic system**, with no private code path.
  If a prebuilt screen currently uses hidden code, rebuild it as a normal
  asset and prove it behaves the same (compat corpus).
- Prebuilt screens come from plugins (Rule B). In a project, each shows a
  **"Customize"** button that makes an editable copy owned by the project,
  wired in the same places. **"Revert to default"** restores the original.
  If the plugin's version is updated later, offer a side-by-side
  comparison so the user can take changes or keep theirs.
- Any part can be changed: layout, art, fonts, which buttons exist and what
  they do, sub-pages, transitions.
- Users can **save their customized screens** to the personal library and
  reuse them in other projects.

## Step 3: A more capable Claude assistant (owner's note 2)

The owner wants Claude to do more inside the engine, **within the
current project only**, never system files.

Before writing this, load the **claude-api** skill (or the official
Anthropic docs) and follow it; do not write SDK calls from memory. Check
which input types the API accepts at build time; the notes below are what
is expected, but the docs win.

### 3.1 Uploading and reading images
- Drag and drop, paste, or pick images (and screenshots of the viewport)
  into the chat. Claude can see them directly (the API takes common image
  formats such as PNG, JPEG, GIF and WebP; convert anything else, such as
  PSD, Aseprite, SVG or BMP, to PNG before sending, and downscale very
  large images).
- Typical uses: "make a tile like this", "why does this screenshot look
  wrong", "match the style of this reference art".

### 3.2 Reading every file in the project
Claude gets tools to list, search and read **any file inside the project
folder**, choosing the best way to read each type:
- **Text and code** (JSON, scripts, CSV, Markdown, shaders...): read
  directly, in chunks for big files.
- **Images and sprite sheets:** sent as images (see 3.1), plus metadata
  (size, frames, palette).
- **PDFs** (design docs): sent as documents if the API supports it,
  otherwise as extracted text.
- **Engine assets** (scenes, UI, logic graphs, tilesets, animations): read
  as their JSON plus a rendered preview image.
- **Audio:** Claude cannot listen to audio through the API. Give it
  metadata (length, format, loudness, loop points) and a waveform image,
  and say so honestly in the UI.
- **Unknown binary files:** metadata and a short summary, never raw dumps.
A **project index** (file tree, asset list, what references what) is kept
up to date so Claude can find things without reading everything.

### 3.3 Generating images
Claude does not generate pixel images itself, so give it two honest
routes, and make the difference clear in the UI:
1. **Claude draws with the engine's own tools** (works with no extra
   setup): a tool that lets it create and edit sprites and tiles in the
   sprite/tile studio with drawing commands (pixels, shapes, fills,
   layers, palettes, frames), or write SVG that the studio converts. Good
   for pixel art, iso tiles, icons and UI frames. The result opens in the
   studio so the user can touch it up.
2. **An image-generation provider plugin** (optional): an extension point
   in the plugin SDK (Step 7) for third-party image models. The user
   installs one and enters their own key for that service; Claude can then
   call it as a tool ("generate a mossy stone wall texture"), and the
   result goes through the studio's import (slice to tiles, fit to the iso
   template, set the palette). Ship the extension point, a mock provider for
   tests and docs; do not pick or pay for a service on the owner's behalf.

### 3.4 Doing more, safely
- More tools: create and edit scenes, blocks, tiles, sprites, UI screens,
  logic graphs, data tables, plugins (as source in the project); run the
  game, the playbot, the validators, the tests and the compat corpus; read
  logs, the problems panel and the profiler; take screenshots.
- **Agent mode** for multi-step jobs ("build a 3-room dungeon with a key
  puzzle"): Claude writes a short plan, the user approves it, Claude works
  through it with checkpoints, and the user can stop at any time.
- **Permissions,** set by the user per project: read-only; ask before
  every change (default); auto-apply edits inside the project but ask
  before deletes, plugin installs and network calls.
- **Sandbox:** every path is resolved and must stay inside the project
  folder (no `..`, no symlinks out, no absolute paths elsewhere). Files
  matching a sensitive list (`.env`, key files, the engine's credential
  store) are never readable. Claude cannot run arbitrary shell commands;
  it only uses the engine's tools.
- Every change is a diff/preview and one undo step; a project
  **snapshot** is taken before each agent-mode run so the whole run can be
  rolled back.
- Show tokens and estimated cost per message and per run, and let the user
  set a spending limit per run.

## Step 4: Minecraft-style block building and gravity (owner's note 3)

### 4.1 Block placement closer to Minecraft
This translates well to isometric, and it does not make the engine "too
easy": it is a better default that still allows fine control.
- The world is a true **3D grid of blocks** (x, y, z). Every block is its
  own object with its own type and properties (if the engine still stores
  some of the world as height columns, convert to a block grid internally
  and keep loading old projects through a migration, Rule A).
- **Place against a face:** hover a block, the face under the mouse (top,
  left or right as seen in iso) highlights, click to place a new block on
  that face, right-click (or a modifier) to remove. A **ghost preview**
  shows exactly where it will go.
- A **hotbar** of recent blocks (1-9 keys), a block picker, eyedropper
  (middle-click a block to pick it), and block **orientation** (which way
  it faces, which side is "up") with a rotate key.
- Hidden faces: rotate the view in 90-degree steps, use the slice view
  (show blocks only up to a height) and an x-ray toggle, so any face can be
  reached.
- Drag to place a line or a wall, shift-drag for a filled box, and the
  existing fill/hollow/replace and structure tools keep working.
- The same block API is available **at runtime** for games where the player
  builds or breaks blocks (opt-in per project, with limits and save
  support).

### 4.2 Gravity in any direction
The owner built a mechanic in their project: press a button and gravity
switches so you walk on a **wall** or the **ceiling**. Two problems:

1. **While walking on a wall, at certain spots the engine thinks the player
   is behind something and makes a block transparent** when it should
   not.
2. **Blocks that are not "wall" blocks are passed through until the
   gravity shift finishes.**

These may be engine bugs or bugs in the owner's project code. **Find out
which.** Read the owner's project scripts for the gravity mechanic,
reproduce both problems in a test scene, and report the cause of each.
Fix the engine where the engine is at fault. If the owner's code is at
fault, explain it and **propose** a fix as a diff, but do not edit their
project without their approval.

Either way, make gravity a **general physics feature** so nobody has to
hack it:

- Gravity is a **vector**, per scene with per-entity overrides (any of the
  6 axis directions; arbitrary directions optional). A character
  controller works in a gravity-relative frame: "down" is the gravity
  direction, walking happens on the plane perpendicular to it, ground
  checks, slopes, steps and jumps all follow it.
- **Collision is full 3D against every solid block**, whatever its type,
  layer or tag ("wall", "floor", "decoration" only change looks and
  properties, never whether something is solid, unless the block is
  explicitly set non-solid). Likely cause of problem 2: collision built
  only from certain block types or from a height map that assumes gravity
  points down, or collision switched off or still using the old frame
  during the transition.
- **Gravity transitions** (a smooth reorientation over time) keep collision
  on every frame, depenetrate safely if the new frame starts inside a
  block, and have events (On Gravity Changed, On Landed) for logic.
- **Occlusion fade and depth sorting use the real 3D position and bounding
  box** of the entity, never "feet on the floor at height h". Fade only
  blocks that are both in front of the entity in iso depth and overlap its
  on-screen silhouette (a short ray/box test from the entity towards the
  camera through the block grid), with a little hysteresis so blocks do not
  flicker at edges. Likely cause of problem 1: the fade test assumes the
  player stands on top of a floor, so on a wall the computed depth is wrong
  at certain cells.
- **Sprites for other orientations:** animation sets can be given per
  gravity direction, with an automatic fallback (rotate/skew the down set)
  so it works before custom art exists.
- Debug overlay: gravity vector, ground contact, collision boxes and the
  occlusion test rays.
- Old projects keep their behaviour via a compatibility flag (Rule A),
  but the owner's gravity project should be switched to the new system
  once it is verified, with their approval.

Prove it: a sample where gravity switches between floor, a wall and the
ceiling in a room with mixed block types, walked by the playbot through
every transition, with tests that no block is passed through and no
block fades when the player is not behind it.

## Step 5: Clean up and refine

A lot has been added. Before Step 7, do a full review and write
`docs/cleanup_audit.md`, then fix what it finds (with the compat corpus
green at every commit):

- **One logic system.** Event sheets, wires, Quick Actions, state machines
  and logic graphs must compile to one shared logic representation with
  one runtime, one debugger and one set of nodes. Remove duplicate
  implementations.
- **Consistent UX:** the same inspector patterns, naming, shortcuts,
  undo behaviour, empty states, error messages and right-click menus in
  every panel. Merge panels that do the same job.
- **Naming:** consistent terms across the UI, docs and API (one word for
  each concept); rename in the UI and docs freely, rename in the API only
  with aliases (Rule A).
- Remove dead code, unused assets, stale feature flags, duplicate
  utilities and outdated docs. Fix every warning.
- **Performance pass:** startup time, project load time, editor frame time
  with big maps, memory, export size.
- **Neutrality pass (Rule B):** list everything in the core that still
  assumes a particular game or genre and move it into a plugin.
- **Docs pass:** one getting-started guide that works for any genre, a
  reference page per panel, recipes per task, and an up-to-date API
  reference.

## Step 6: Templates and samples, not defaults
Templates (empty, action adventure, tactics, builder, roguelike,
point-and-click, and a "Parchment UI kit" example) are just lists of
plugins plus starter content. The empty template must stay truly empty.
Nothing a template adds may be required by the engine.

## Step 7: Plugins as a real platform (with an SDK)

Replace the current add-ons/behaviour-pack system with a deliberate
plugin platform. Existing packs and add-ons must keep loading (convert them
automatically to plugins, Rule A).

### 7.1 Plugin manager (in the editor)
- A **Plugins** window: installed plugins with name, author, version,
  description, permissions and which projects use them; **enable/disable
  per project**, install (from a file, a folder, a URL, or the hub if it
  exists), uninstall, update, roll back to a previous version, and view
  the changelog.
- A project's manifest lists the plugins and versions it needs. Opening a
  project with a missing or incompatible plugin explains what is missing
  and offers to install it. **Data owned by a missing plugin is never
  deleted**; it is kept as placeholders and comes back when the plugin
  does.
- Disabling or uninstalling a plugin a project uses shows exactly what
  will stop working first.

### 7.2 Plugin format
- A **manifest** (`plugin.json`): id, name, version (semver), engine
  version range, dependencies with version ranges, the permissions it
  asks for, and entry points (runtime, editor, or both).
- **Runtime parts** are bundled into exported games only if the project
  uses them; **editor parts** never ship in exports.
- Plugins can include assets (art, sounds, UI, templates, docs).

### 7.3 SDK
- An npm package (e.g. `@tilewright/plugin-sdk`) with fully typed,
  documented APIs, and a scaffolding command
  (`npm create tilewright-plugin`) with starter templates for each
  extension point.
- **Extension points** (each with a template, docs and an example
  plugin): components, behaviours, logic nodes, UI widgets, prebuilt
  screens, editor panels, editor tools (brushes, gizmos), inspectors for
  custom data, asset importers and exporters, block types, physics
  modifiers, playbot strategies, validators, project templates, export
  targets, **file readers for the Claude assistant** (teach Claude to read
  a new file type), **Claude tools** (give Claude new abilities, with the
  same permission and diff rules), and **image-generation providers**
  (Step 3.3).
- **Developer loop:** load a plugin from a folder in dev mode with hot
  reload, logs in the console tagged by plugin, breakpoints, and a test
  harness to run a plugin's tests against a headless engine.
- **Stable API:** the SDK is versioned; breaking changes only in a new
  major version, with deprecations announced at least one minor version
  earlier. A compatibility check runs when a plugin loads.

### 7.4 Safety and stability
- **Permissions** shown at install and changeable later: read/write the
  project, network access (and to which hosts), clipboard, running
  external programs (off by default, strongly warned). A plugin only gets
  what it asked for and the user granted.
- Editor plugins run isolated from the editor core, so a plugin that
  crashes or hangs is disabled with a message instead of taking the editor
  down; its error goes to the problems panel with the plugin's name.
- The asset hub (if built) marks plugins as code and requires explicit
  approval to install them.

### 7.5 Dogfooding
Move the Storytender pack, every genre module, the prebuilt screens, the
templates and the Parchment UI kit into **first-party plugins built only
with the public SDK**. If a first-party plugin needs something the SDK
does not expose, add it to the SDK properly; first-party plugins get no
private access.

## Done when

1. `npm run compat` passes: every sample, template and owner project loads,
   plays, saves and exports as before, with no changes needed in the
   owner's code. The owner has a list of any compatibility flags set and
   what they do.
2. The "core is neutral" test passes, and the empty template has no
   plugins and no gameplay.
3. Custom screens behave like prebuilt ones: the pause-menu bug has a
   regression test and the screen-stack debug overlay exists.
4. Every prebuilt screen can be customized, reverted, compared after an
   update, and saved to the library.
5. The Parchment UI kit (title, menu column, pause with sub-pages, shared
   settings, binder inventory, world map, HUD) is rebuilt with general
   tools only and has a recipe each.
6. Claude can: read every file type in the project as described (with
   honest limits for audio), see uploaded images, draw a usable iso tile
   in the tile studio from a text request, call a mock image provider
   plugin, run an approved agent-mode plan with rollback, and is blocked
   from reading or writing anything outside the project (tested with path
   tricks such as `..` and symlinks).
7. Minecraft-style placement works in the editor and, opt-in, at runtime.
8. Gravity switching works for floor/wall/ceiling with mixed block types:
   no passing through blocks, no wrong fades; the cause of each of the
   owner's two gravity problems is written up, and any fix to the owner's
   project was approved by them.
9. The cleanup audit is done: one logic runtime, consistent UX and naming,
   no warnings, docs refreshed, performance numbers recorded before and
   after.
10. The plugin manager, format, SDK, scaffolding, all listed extension
    points, dev mode, permissions and crash isolation work; every
    first-party feature pack is a plugin on the public SDK; old packs load
    automatically.
11. All tests pass.

When all are true, add a summary of this phase to `PROGRESS.md`,
including anything that turned out to be the owner's project code rather
than the engine.
