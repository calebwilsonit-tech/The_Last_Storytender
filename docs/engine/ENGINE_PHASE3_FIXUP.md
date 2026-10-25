# Phase 3 fix-up prompt (from a review of the phase 3 commits)

> Send everything below the line to the Claude session working on
> Tilewright. It comes from a read-only review of `origin/main` at
> `1f2e277` against `ENGINE_PHASE3_V1_FEEDBACK.md`. On that commit,
> typecheck, lint, `npm test` (1410 tests) and `npm run compat` all pass,
> but the owner's project tests skip because the project is not in the
> repo.

---

Phase 3 is mostly in place, and a lot of it is good work: input is
consumed once handled, there are screen roles, the screens are designer
assets, swept 3D collision under 6 gravity directions, the sight-based
fade, Minecraft-style placement, plugin manifests with semver, editor
plugins run in a worker, project format 2 has a tested migration, and the
assistant got image attachments, a sandbox, snapshots and cost limits.

A review against the phase 3 prompt found the gaps below. Fix them in
this order. Same rules as before (Rule A and Rule B still apply, small
commits, always green, failing test first). Every file:line reference was
checked at `1f2e277`; confirm it before relying on it.

**Process rule for this round:** never change harness code and re-take
baselines in the same commit, and never re-take a baseline without
writing in `DECISIONS.md` which differences changed and why each one is
intended. A re-baseline that changes behaviour (for example a trace going
from `"screen": ""` to `"Inventory (modal)"`) needs its own explanation.

## 1. Security (do these first)

1. **Game parts of third-party plugins run unsandboxed in the editor
   window.** `evaluatePlugin` (`packages/behaviors/src/plugins/loader.ts`,
   about 118-131) loads them as a blob module in the main window, where
   they can call everything on `window.tilewright` (`editor/src/main/
   preload.ts`): `fs.write`/`fs.remove`, `assistant.providerKey.get`,
   `hubRequest`, `plugins.fetch`, and `plugins.runProgram(pluginName, ...)`.
   The plugin passes its own name there, so the warning dialog can name
   another plugin. `host.need()` permission checks only cover calls made
   through the plugin api.
   Fix: run third-party game parts somewhere they cannot reach the bridge
   (a worker or isolated realm with only the plugin api, as editor parts
   already do), or at minimum hide the bridge from plugin code and make the
   main process work out the calling plugin itself instead of trusting a
   passed name. Add a watchdog for hangs. Test it with a hostile plugin
   that tries each of the calls above.
2. **Image-provider keys reach the renderer.**
   `assistant:provider-key-get` (`editor/src/main/assistant.ts`, about
   186-188) returns any provider's key in plain text, and the key is then
   used in the renderer (`image-tools.ts`). Keep provider keys in the main
   process, just like the Anthropic key, and make the provider call there
   (or proxy it) so no renderer code ever holds a key.
3. **Secret files are readable.** Nothing in `path-rules.ts`, `sandbox.ts`
   or `file-tools.ts` refuses `.env`, `*.pem`, `*.key`, `id_rsa*`,
   `*.p12` or credential stores. Add a deny-list (extendable in project
   settings), and test it.
4. **"Auto" asks for nothing.** `automatic()` in
   `editor/src/renderer/assistant/store.ts` (about 315-319) lets every
   tool except `submit_plan` run without asking, under both "auto" and an
   approved plan. That includes deletes, `set_plugins` and
   `generate_image`, a paid third-party call that `docs/assistant.md`
   says always asks. As the spec says, auto applies edits inside the
   project but always asks before deletes, plugin installs/enables and
   network calls. Plugin-provided assistant tools must not be able to mark
   themselves "read" to skip approval: classify them by the permissions
   the plugin was granted.

## 2. The owner's bug is still half there (Step 1)

New designer screens are created with `modal: false, back: 'auto'`
(`editor/src/renderer/uidesigner/ui-edit.ts:56`), and `backAction`
(`behaviors/src/ui/router.ts`, about 28-36) turns `auto` on a screen that
does not block input into `pass`. So Esc on a newly made non-modal screen
(an inventory, say) still falls through and opens Pause. That is exactly
what the owner reported.
D041 chose this on purpose ("a heads-up display lets it pass"). But it
treats every screen that does not take the buttons as a HUD, and a
non-modal menu is the owner's case.
Fix: `auto` should mean "go back / close this screen" for any screen the
user opened as a menu. `pass` should only apply to screens with the HUD
role, or ones explicitly set to "let Back through". Keep old behaviour
for old projects only if the compat corpus shows something depends on it.
Also consume `interact` when a widget is activated (`screens-dom.ts`,
about 792), and add a test for every combination of blocks-input, back
setting and role.

## 3. Rule A gaps

1. **Back up before the first save in a new format.** `saveProject`
   (`editor/src/renderer/project/io.ts`, about 83-85) just writes. Older
   editors refuse format 2, so a project upgraded by accident cannot go
   back. Before the first save of a project that was migrated, copy the
   old files to `.tilewright/backup-format-<n>/` and tell the user. Test
   it.
2. **Prove the rebuilt screens match the old ones.** D045 explains the
   trace changes in a9a301a: the headless harness now has the pause and
   inventory screens that real Play always had. That is a fair reason, but
   it means the corpus never recorded the old built-in `GameUi` menus
   (`compat/harness/trace.ts` records only `ui.stack`). So nothing compared
   the old menus with the rebuilt ones: rows, focus order, what each row
   does, Back chains, and settings changing values.
   - Check out `4cd481c` in a worktree and record the old menus' behaviour
     with a harness that also records `runtime.menuOpen`, the built-in
     screen, its rows and the focused row.
   - Run the same presses at HEAD, compare, and explain or fix every
     difference.
   - Write the result in `DECISIONS.md`.
3. **Keep the old code paths covered.** D042 says the older samples were
   re-saved with `blockPhysics` and `fadeBySight` and their traces did not
   change. That is good evidence the two physics agree on those samples.
   But it also means CI now runs the old physics and fade only through the
   Storytender sample. Add corpus copies of a few samples *without* the
   flags (as they were at `4cd481c`), so the code path every old project
   uses stays tested in CI.
4. **The legacy plugin fallback is never exercised.** Add a corpus
   project with no `packs`/`plugins` field at all.
5. **Golden screenshots on Linux.** `e2e/compat-screens.spec.ts-snapshots/`
   only has `*-win32.png`, and `updateSnapshots: 'missing'` means the
   Ubuntu CI run checks nothing. Either commit Linux goldens, or run that
   spec only on Windows and set `updateSnapshots: 'none'` in CI so missing
   goldens fail.
6. **New warnings on old samples** (4cfac4d, e.g. `Controls: "Escape" is
   used by both...`). The spec says old projects load with no warnings.
   Fix the cause, or make the check smarter so it does not fire on
   projects that were fine.
7. **The gravity diagnosis must not skip silently.** In
   `compat/gravity-diagnosis.test.ts`, `if (glued === 0) return
   ctx.skip();` (1f2e277) turns an engine regression into a skip. Only
   skip when the specific script file is absent (checked up front, the
   same way for all three tests). If the script is there and the walk
   never glues, the test fails.
8. **"Export build" in the corpus** is only a file list and manifest.
   Make it a real export of at least the samples, and a headless start of
   the exported game.
9. **Working files:** the owner keeps `PROGRESS.md`, `DECISIONS.md` and
   `KNOWN_ISSUES.md` outside the repo and will give them to you. Update
   them with this round, and correct two over-claims in the phase 3
   "done when" table:
   - "A true 3D block world" is marked *holds*, but the world is still a
     height map read as blocks (item 6.8).
   - The Parchment UI kit is marked *holds*, but it only recolours the
     prebuilt screens (section 9).
   A row reads *holds* only when the spec's wording holds. Otherwise
   write *partly* and say what is missing.

## 4. Rule B leaks still in core

- `editor/src/renderer/viewport/play-session.ts`, about 231-233:
  `'travel-post-request'` and `'rested'` (both Storytender events) are
  hard-coded. Route travel through a generic plugin "travel request"
  extension, and autosave only through the generic `autosave` event flag
  (the Storytender plugin marks `rested` as autosave).
- `runtime/src/ui/layout.ts`, about 50-57: `lightbar`, `hearts`, `bosses`
  and `slots` are built-in widgets (and are mocked in
  `InterfaceEditor.tsx`). Move each into the plugin that owns its data
  (lighting, combat, inventory) as a plugin widget.
- `runtime/src/story/*` (dialogue, cutscene, items, minigames, worldmap),
  `runtime/src/ai/`, `runtime/src/lighting/`, `behaviors/src/ui/
  screens-dom.ts` and `defeat.ts` (reads `state:health`) are still in
  core. Decide for each whether it is truly general (keep it, say why in
  `DECISIONS.md`) or belongs in a plugin (move it). At least items,
  minigames, lighting, AI and `defeat.ts` should be plugins.
- Collision layers: plugins can register them, but users cannot define
  their own. Add a project-level list of named layers editable in Project
  settings.
- **Strengthen the neutral test** (`packages/bundled-plugins/src/
  neutral.test.ts`):
  - scan all text files in core, not just `.ts`/`.tsx`;
  - check core tests too, or keep game words out of core tests;
  - catch relative imports into `packages/plugins`;
  - remove `COMPOSITION_ROOTS` entries for files that do not exist;
  - add `rested`, `post`, `fuel`, `parchment` and any other Storytender
    event or variable names to the blocklist.
- Docs: `docs/README.md` still mentions "an echo puzzle" and has a
  top-level "Echoes, lights and words" row; the tutorial line leads with a
  puzzle room. Move game-specific pages under the plugin that owns them.
  `emptyIso`'s description still says "with every module switched on".

## 5. Plugin platform gaps (Step 7)

1. **The SDK is the whole core.** `packages/plugin-sdk/src/index.ts`
   re-exports all of `@tilewright/runtime` and `@tilewright/behaviors`
   (802 names). Define a deliberate public surface: the plugin api, types,
   and a curated set of helpers. Mark everything else internal, and make
   first-party plugins compile against the curated surface only. Keep the
   current names reachable through a deprecated `@tilewright/plugin-sdk/
   legacy` entry so nothing breaks. Make the package publishable (built
   output, real version ranges, not `"private": true`).
2. **Exports:** `export.ts` (about 84) skips `example-*` plugins as "in the
   player", but the player only imports the bundled plugins, so the
   Parchment UI kit's game widget is probably missing from exported games.
   Test it with an export and fix it. Follow dependencies of listed
   plugins, and include bundled plugins only if the project uses them.
3. **Plugin manager (7.1), missing pieces:** install from the hub, an
   explicit Update, "used by these projects", "what will stop working"
   before disable/remove, offering to install a missing plugin, and an
   Inspector placeholder for data owned by a missing plugin.
4. **Scaffolding:** `npm create tilewright-plugin` makes one starter.
   Offer a starter per extension point (the examples in `plugin-examples`
   can be the source).
5. First-party `plugin.json` files leave out `entry.editor` even when
   they have an `editor.ts`. Fix them, and make
   `editor/scripts/copy-samples.mjs` use the manifest's `samples` field.
   Move the last-storytender sample's `project.json` to format 2.
6. Plugin assistant tools: only the first 20 are passed to the model
   (`assistant/store.ts`, about 463). Pass all of them, or let the user
   choose which, and say so when some are left out.

## 6. Gravity and blocks (Step 4)

1. **Saves forget gravity.** `SaveSchema` (`runtime/src/story/save.ts`)
   stores no scene gravity or per-body `gdir`, so a game saved on a wall
   loads with normal gravity. Save and restore both, with a test.
2. **Transitions snap.** `turnFeet` in `physics3d.ts` (about 158-169)
   moves the feet instantly and only the picture eases. Make the
   reorientation an actual timed transition (configurable, can be 0), with
   collision every frame and depenetration, as specified.
3. **The fade-ray overlay is a dot.** It draws along `cameraDirection()`,
   which projects to a point. Draw the swept box and highlight the blocks
   it hits.
4. **The gravity-room test** (`e2e/p3-gravity-room.spec.ts`) teleports the
   player by writing the transform, checks for overlap only every 5th
   tick, builds `SolidField` without the tileset (so it disagrees with the
   physics on `solid:false` tiles), and does not assert position for "the
   pillar stops a walk". Make it walk with inputs (the playbot), check
   every tick, use the same solid field the physics uses, and assert
   positions.
5. **The script `gravity` setter** (`scripting/script.ts`, about 306) does
   nothing under the old physics without saying so. Make it warn, like
   the event rows do.
6. `Sprite.byGravity` has no editor UI, docs or test. Add all three.
7. Blocks tool polish: the hotbar should remember shape and rotation as
   well as tile, and the ghost should show the real shape.
8. **Decide, and write down, the block-world question.** The world is
   still a height map, read as blocks at query time. Stairs, ramps and
   decks only become blocks when edited, there are only 4 rotations about
   the vertical axis, and a ramp is the same as stairs physically. Either
   finish the true 3D block model the spec asked for (full orientations
   including upside-down and wall-mounted, real ramps, a migration), or
   write in `DECISIONS.md` why the hybrid is kept and what users cannot do
   because of it, and tell the owner.

## 7. Assistant (Step 3)

1. **PDFs:** add document blocks (check the claude-api skill for the
   current shape) or extracted text. Today a PDF is "binary, cannot read".
2. **Images:** convert PSD, Aseprite, SVG and BMP to PNG and downscale
   large images instead of refusing them (both in the renderer,
   `store.ts:135-158`, and the main process, `main/assistant.ts:82-94`).
   File reads of images should include size, frames and palette.
3. **A search tool** over project files (text search, plus finding
   assets by name or kind).
4. **Engine assets with previews:** scenes, screens, graphs and tilesets
   should come back as JSON plus a rendered preview image. Today only
   sprites do.
5. **Audio:** add a waveform image, loudness and loop points, and MP3
   length.
6. **The project index** should record what references what.
7. **Drawing:** `draw_sprite` takes a palette and rows of characters only.
   Add shapes, fills, layers and SVG; open the result in the studio; and
   add a tile-studio path that makes a usable iso tile (Done-when 6).
   Provider images should go through the tile import (slice, fit to the
   iso template, match the palette), not a plain `importPng`.
8. **Agent mode checkpoints:** today it is one `planApproved` flag. Show
   the plan's steps, tick them off as they finish, let the user stop
   between steps, and allow rolling back to a step as well as the whole
   run.
9. Tools for reading logs and the profiler, and for running the project's
   tests and checks.

## 8. Cleanup (Step 5)

1. **One logic runtime.** D046 keeps three schedulers on purpose (merging
   them could change timing in projects the corpus has never seen). The
   owner accepts that reasoning for rows, graphs and wires. Two things are
   still owed:
   - D046 does not cover state machines and behaviour trees, which still
     have their own executors (`packages/plugins/ai/src/brain.ts`,
     `tree.ts`) and cannot run event-sheet actions (KNOWN_ISSUES). Make
     them use the shared condition/action registry and the shared
     debugger (breakpoints, live highlighting), or write the case for not
     doing so in `DECISIONS.md`.
   - Give all schedulers one debugger view: one place to see what fired
     this tick, whatever kind of logic it came from.
2. `editorExtensions()` / `onPacksChanged` still have no consumers: keep
   them only as documented deprecated aliases of the real extension
   tables, and say so in the SDK docs.
3. Leftover "pack" wording: the `'packs'` tab id in
   `ProjectSettingsDialog.tsx`, `ps-packs`, "pack" in `LibraryPanel.tsx`
   for asset packs, and "packs" in `docs/assistant.md`.
4. **Performance numbers:** add startup time, project load time, memory
   and export size, before and after (measure "before" on `4cd481c`).

## 9. Parchment UI kit (Background section)

Today the kit only recolours the prebuilt screens. Build the actual
examples the spec describes, with general tools only, each with its own
recipe in `docs/recipes/`:
- the binder inventory (two-page book, paper doll with equipment slots
  and stats, a 4-column item grid with scrolling, hover and selection);
- the world map (chapter list, discovered regions only, lit waypoints,
  "you are here", hide posts too close to travel to);
- the pause menu with Travel and "Restart?" sub-pages;
- a title whose New Game picks a difficulty that is locked for the save;
- the HUD (gauge, counter, region name, prompt, toasts, boss bar, narrator
  text).
Make it a real plugin with a `plugin.json` (not only an entry in
`plugin-examples`), and check that it works in an exported game (item 5.2).

## Done when

Every numbered item above is fixed (or, for 6.8, decided and
written down with the owner told). There are tests for each fix. CI is
green on Ubuntu and Windows. The owner has been asked to run
`npm run compat` with their projects in `compat/projects/` and it
passes on their machine. `PROGRESS.md` summarises this round, including a
list of anything deliberately left undone.
