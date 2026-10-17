# Follow-up prompt: make Tilewright work for any kind of isometric game

> Send everything below the line to the Claude session building the engine,
> **after** it has finished the original build prompt (all acceptance
> criteria ticked in `PROGRESS.md`).

---

You have finished the original Tilewright build prompt. This is the next
phase. Same working rules as before: read `PROGRESS.md`, `DECISIONS.md` and
`KNOWN_ISSUES.md` first, keep them updated, small commits, always green,
build every sample through the editor UI only, play it with the playbot,
never tick a box you did not verify.

## Why this phase exists

The original prompt was written around one reference game, The Last
Storytender (an action-adventure puzzle game). That shaped the engine
towards one kind of game. The goal was always a **general-purpose** 2D
isometric engine, closer to Unreal than to RPG Maker: someone should be
able to make just about any isometric game with it, not the same game with a
different story. This phase makes that true and proves it.

The Last Storytender vertical slice must keep working the whole time. It
becomes one sample among several, not the shape of the engine.

## Step 1: Audit (do this before changing anything)

Write `docs/genre_audit.md` answering:

1. What in the **core runtime and editor** assumes a particular kind of game?
   Look for: a built-in player, health/damage, inventory, the
   lantern/checkpoint system, echoes, sentence stones, text formatting, a
   real-time-only game loop, direct-control-only input, a single controlled
   character, the camera always following one entity, menus that assume save
   slots and a story.
2. For each item: should it stay in the core (genuinely general), become an
   optional module, or move to a **"Storytender" behaviour pack** that only
   that sample uses?
3. What is missing to make each genre in Step 3 possible?

Commit the audit, then do the work in Step 2.

## Step 2: Make the core genre-neutral

1. **Nothing about the game is built in.** No fixed player, party, stats, HP,
   inventory, turn system or battle screen in the core. These become
   optional modules/behaviours a project adds, and each can be removed,
   replaced or edited. A brand-new empty project should contain no gameplay
   at all, just an empty iso scene and a camera.
2. **Move reference-game features into a "Storytender" behaviour pack**
   (echoes, sentence stones, formattable text, rising dough, lantern posts,
   etc.). The engine must load packs like any other plugin. The Storytender
   slice uses the pack and must still pass all its tests afterwards.
3. **Composition over presets.** Split big behaviours into small ones that
   combine (e.g. "Grid Mover" + "Turn Taker" + "Selectable" = tactics unit;
   "Grid Mover" + "Player Controller" = action hero).
4. **Users build their own blocks without code:**
   - custom components (named, typed data fields shown in the inspector);
   - custom behaviours made from event sheets and state machines, with
     exposed parameters, saved as reusable assets;
   - custom events/signals;
   - **data tables** in a spreadsheet-style editor (items, units, buildings,
     recipes, waves, cards, dialogue barks: anything), referenceable from
     event sheets and behaviours;
   - shareable **behaviour packs** (export/import between projects).
5. **Time:** a game clock per scene that can be real-time, paused,
   sped up (1x/2x/4x for sims), or **turn-based** with an initiative/turn
   queue, action points, and "end turn". Real-time and turn-based are equal
   citizens.
6. **Control schemes**, each a drop-in module: direct control,
   point-and-click / click-to-move with pathfinding, RTS box-select with
   command queues, a grid cursor (tactics), free camera pan/zoom and
   **rotation between the 4 iso views** (builders), drag-to-place building
   with ghosts, valid/invalid tinting, footprints larger than one cell, and
   rotate-before-place.
7. **Movement:** cell-locked, free pixel movement, or both, per entity.
8. **World scale:** single-screen up to large chunked/streamed maps;
   **procedural generation** (rooms and corridors, caves, islands, towns)
   driven by visually edited rules and lockable seeds.
9. **Simulation helpers** any genre can use: resources and economies,
   schedules (day/night, seasons, calendars), spawn waves, flow fields for
   hundreds of units, utility/needs AI, cellular automata (fire spread,
   water flow, plant growth), simple production chains.
10. **UI for different genres:** selection panels, unit cards, build
    menus, resource bars, turn-order bars, tooltips, minimaps, drag-and-drop
    inventories, card hands.
11. **Plugin API** for programmers: new behaviours, components, editor
    panels, tools and importers in TypeScript, appearing in the no-code UI
    like built-in ones. The Storytender pack must be written against this
    API to prove it works.
12. **Templates:** offer several starting templates (empty, action
    adventure, tactics, builder, roguelike, point-and-click), each just a
    starting point the user can strip down.
13. **Claude assistant:** update its tools and project-memory file so it
    knows about packs, data tables, turn mode, control schemes and templates,
    and can build in any genre on request.

14. **UI designer** (a full one; the original prompt only asked for a basic
    layout editor). It must be as easy as a slide editor:
    - **Drag-and-drop canvas** with a widget palette: panel, image, text,
      button, toggle, slider, dropdown, text input, progress/health bar,
      scroll list, grid (inventories), tabs, tooltip, minimap, portrait,
      dialogue box, and any custom widget the user saves.
    - **Layout without maths:** snap guides, alignment/distribute buttons,
      anchor presets (the 9-point "pin to corner/centre" picker), auto-layout
      rows/columns/grids with padding and spacing, safe-area margins, and a
      **preview bar** to switch resolution, aspect ratio, language and
      keyboard vs gamepad.
    - **Styles and states:** themes/style sheets (fonts, colours, nine-slice
      frames), per-widget states (normal, hover, pressed, selected,
      disabled) with a preview toggle, and simple UI animations (fade,
      slide, pop, pulse) on show/hide/hover/click, picked from a list.
    - **Reusable pieces:** UI prefabs (make one inventory slot, reuse it 30
      times; edit once, all update) and **list templates** that repeat a
      prefab for every row in a data table or list variable.
    - **Data binding with a picker, no typing:** click any property (text,
      bar fill, image, visible, enabled, colour) -> "Bind to..." -> pick a
      variable, entity field or data table cell from a tree. Formats like
      "{gold} coins" and simple conditions ("visible when health < 25%").
    - **Screens and flow:** a **screen-flow map** (title -> settings ->
      back, pause -> inventory) drawn as boxes and arrows, with transitions,
      plus a visual **focus-order** tool for gamepad navigation (draw the
      arrows between buttons, or auto-generate them).
    - **In-world UI:** the same widgets attached to entities (health bars
      over heads, speech bubbles, build-cost labels, interaction prompts).
15. **Buttons and logic wiring (one logic system everywhere).** Every
    interactive thing (UI buttons, entities, triggers, plates, timers,
    state machines) exposes **events** (On Click, On Hover, On Enter, On
    Pressed, On Value Changed, On Turn Start...) and **actions**, and the
    user connects them at three levels of difficulty, all editing the same
    underlying logic so they can switch between them:
    1. **Quick Actions (easiest):** in the inspector, under "On Click", a
       dropdown of common actions: go to scene, open/close screen, back,
       start/continue/save/load game, set/add variable, play sound, show
       dialogue, quit game. Chain several with "+". This covers most menus
       with zero graphs.
    2. **Wires / logic strings:** drag a string from a button's "On Click"
       pin (or a plate's "On Pressed") to any target in the scene, the
       outliner or the UI canvas, then pick an action on that target ("Gate
       -> Open", "Panel -> Show"). Wires are visible as coloured lines in the
       viewport and canvas, can pass through logic nodes (AND, OR, NOT,
       latch, delay, counter, random, compare) and light up live while the
       game runs, so you can see the signal travel.
    3. **Logic graph (Blueprint-style node editor)** for anything bigger:
       event nodes, action nodes, branches, loops, variables, math,
       "for each in table", custom functions, with the same nodes available
       in state machines, behaviours, UI and scenes. Double-click a wire to
       open it as a graph; collapse a graph into a reusable node.
    Event sheets and code stay available and convert to/from graphs where
    possible. Everywhere: search-as-you-type node picker that only shows
    actions valid for the chosen target, plain-English tooltips, breakpoints
    and step-through on nodes, and the problems panel flags broken wires
    (target deleted, action missing) with a one-click fix.

16. **Tile studio** (a mode of the sprite maker; the original prompt only
    had an iso grid and an "iso box" helper):
    - **Tile canvas presets:** flat diamond (project tile size, default
      64x32), half-height and full-height blocks, wall faces (left/right),
      cliff faces per height level, stairs/ramps in all 4 facings, and
      custom sizes; the diamond outline and top/left/right faces are shown
      as guides, and drawing can be clipped to them.
    - **Live tiling preview** beside the canvas: the tile repeated across a
      patch of ground (and stacked for walls/cliffs) as you draw, with seam
      highlighting and a wrap-around mode so edges line up.
    - **Autotile sets with guided slots:** pick a set type (ground edges,
      cliffs, walls, water shores, paths, fences) and get a sheet of
      labelled empty slots (every edge, inner/outer corner, end piece). Fill
      them in any order; a preview map shows the result painted, and
      missing slots are listed. Option to generate a starter set from one
      base tile plus an edge brush, then hand-touch it.
    - **Variants and decoration:** several versions of a tile with weights
      for random painting; overlay decals (cracks, moss, flowers) that the
      world painter can scatter.
    - **Animated tiles:** frames and timing for water, lava, torches, grass
      sway, synced across the map.
    - **Palette tools:** recolour a whole tileset at once (e.g. turn a
      forest set into a snow set), palette swaps saved as variants, and a
      light/shadow shading helper for the three iso faces.
    - **Tile properties set in one place:** collision shape, walkable,
      height, is-stair/is-pit/is-water, footstep sound, light blocking,
      sort offset, tags, any custom fields. Saving sends the tile straight
      into the world painter's palette with these properties, and editing
      it later updates every placed copy.
    - **Import/export:** slice imported tilesheets into tiles with a grid
      tool, and export tilesets as sheets.
    - Must also work for **props and multi-cell objects** (a 2x3 house with
      its footprint and collision drawn on the grid).

17. **Trees, tall props and wall attachments** (in the tile studio /
    sprite maker):
    - **Tall props** (trees, lamp posts, statues, towers): draw the full
      image, then mark the **footprint** (the cell(s) the base stands on),
      the **collision** (e.g. trunk only), the **sort point**, and which
      part **fades when the player is behind it** (e.g. canopy only).
      Optional sway/idle animation, seasonal variants, random variants with
      weights, and a scatter brush in the world painter (density, spacing,
      no-overlap, avoid paths).
    - **Wall attachments** (windows, doors, shelves, guitars, posters,
      torches, signs, vines, cracks): drawn on a wall-face template so they
      come out at the correct iso angle, with a version for the left-facing
      and right-facing wall (auto-mirrored, editable). In the world painter
      they **snap onto any wall face at any height**, can be moved along the
      wall, and keep their place if the wall is edited. Attachments can
      carry properties and behaviours (a window that lets light through, a
      torch that is a light source, a guitar the player can interact with,
      a door that is a scene portal).
    - **Floor/surface attachments** (rugs, puddles, tables on floors,
      things on top of blocks) work the same way on top faces.
18. **Block-level world editing** (the original prompt only had height
    raise/lower per cell, which edits a whole column at once):
    - Every cell is a **stack of individual blocks**. Click any single block
      at any height to select it and change its tile, delete it, or set its
      properties, without touching the blocks above or below (e.g. brick
      at the bottom, a window block in the middle, wood on top).
    - **Gaps in a stack** are allowed: arches, tunnels, overhangs, bridges
      and balconies (a block at height 3 with nothing under it). Collision
      and walking work under and on top of them.
    - **Per-face painting:** give one face of one block (top, left or right)
      a different tile or decal.
    - **Layer slicing view:** show only blocks up to height N, or cut away
      everything in front of the cursor, so inner blocks can be reached; an
      x-ray toggle.
    - Box-select a 3D region of blocks to copy, paste, fill, hollow out or
      replace; save a selection as a reusable **structure** (a house, a
      ruin) with its attachments.
19. **Personal asset library (make once, use in any project):**
    - Everything the user makes (tiles, tilesets, tall props, attachments,
      characters, animations, UI widgets, structures, behaviours, sounds)
      can be saved to a **library that lives outside any one project**,
      with folders, tags, thumbnails and search.
    - Drag from the library into any project; choose **link** (updates
      when the library version changes) or **copy** (independent).
    - Export/import **asset packs** (one file containing art, properties,
      behaviours and dependencies) to move assets between computers, keep
      backups, or share with others; importing shows what it contains and
      flags name clashes.
    - Version history per asset, so an old version can be restored.
20. **Community asset hub (people make art and upload it for others).**
    **Do this item last**, after everything else in this phase passes; it
    must never delay or block the rest of the engine.
    - An **Asset Hub** panel inside the editor: browse, search and filter
      (tiles, tall props, attachments, characters, UI, sounds, behaviours,
      structures, full templates) by tag, style, tile size, licence and
      rating; preview animated thumbnails and a **try-in-scene** preview
      before downloading; one click adds it to the personal library.
    - **Upload** straight from the personal library: title, description,
      tags, screenshots, licence, version notes. The engine checks the pack
      first (tile size, missing files, broken references) and shows what
      will be published.
    - **Licences** chosen from a list (CC0, CC-BY, CC-BY-NC, "free for any
      game", custom text), shown on every asset, and an auto-generated
      **credits file** for exported games listing every hub asset used and
      its author.
    - **Safety:** art, audio and data-only packs are safe by design. Packs
      containing **code or plugins** are clearly marked, need the user's
      explicit approval to install, and run with limited permissions; the
      hub scans uploads and has report buttons and a moderation queue.
    - Accounts, profiles, likes/ratings, comments, follow creators,
      collections, update notifications for downloaded assets, and
      versioning (projects keep the version they used until the user
      updates).
    - **Backend:** this needs a server. Build it as a separate package
      (`packages/hub-server`) the owner can self-host, with storage, auth,
      search and moderation tools, plus a documented low-cost hosting setup
      in `docs/HUB_HOSTING.md` (what it costs, how to deploy, how to back
      up). Until a server is deployed, the panel must work against a local
      test server, and the rest of the engine must work with no hub at all.
      Do not deploy anything publicly or create paid accounts yourself;
      write the steps for the owner.
    - Optional later: paid assets (requires a payment provider, tax and
      legal setup; design for it but do not build payments unless the
      owner asks).

Record each choice in `DECISIONS.md`.

## Step 3: Prove it with genre samples

Build each of these **only through the editor UI** (drive it with
Playwright like a user), keep each in `samples/` as a test, and make the
playbot able to play each one:

1. **Tactics:** a turn-based battle on a height map; units with move
   range, attack range, height advantage, an initiative bar, enemy AI turns,
   win/lose.
2. **City/colony builder:** place buildings with footprints on a grid,
   resources produced and consumed over time, a speed-up clock, villagers
   who path to jobs, a goal (reach population 20).
3. **Roguelike:** a procedurally generated dungeon run with a seed, rooms,
   loot from a data table, permadeath and a new run.
4. **Tower defence:** enemy waves from a data table along a path, placeable
   towers with upgrades, lives and money.
5. **Point-and-click adventure:** click-to-move, hotspots, look/use/talk,
   combining items, a simple puzzle.
6. **Your choice:** one more genre that tests something none of the above
   do (e.g. RTS with box-select, a farming/life sim, an isometric racer).

7. **UI showcase:** using only the UI designer and Quick Actions/wires
   (no graphs, no code), build a title screen (New Game, Continue,
   Settings, Quit), a settings screen with working sliders and key
   remapping, a pause menu, a HUD bound to live variables, and a grid
   inventory driven by a data table. Then rebuild the Storytender slice's
   menus with it. Everything must work with mouse, keyboard and gamepad and
   at 16:9, 16:10, 21:9 and 4:3.

8. **Tile showcase:** in the tile studio only, draw a grass ground set
   with a full autotile edge set, a cliff set for two height levels with
   stairs, an animated water shore, and a recoloured snow version; paint a
   small map with them in the world painter and walk it with the playbot
   (collision and heights must come from the tile properties alone).
   Then, in a **new project**, draw a tree (canopy fades, trunk collides),
   a window and a guitar as wall attachments, and save all of them to the
   personal library. In a **second project**, pull them from the library,
   build a small house whose wall stack uses different blocks at each
   height (stone base, window block, wood top), with an archway gap, the
   window and guitar on its walls, and trees scattered around it. Walk
   through the archway and behind the trees with the playbot. Finally,
   upload the tree to a local hub test server and download it into a
   third project, with the licence and credits file correct.

If a sample needs something the engine lacks, add it **to the engine in a
general way**, never as a one-off hack for that sample.

## Done when

1. The audit is committed, and every item is resolved or recorded in
   `KNOWN_ISSUES.md` with a reason.
2. A new empty project contains no gameplay assumptions.
3. The Storytender slice works through the behaviour pack and still passes
   all its tests, playbot run included.
4. All eight samples (six genres plus the UI and tile showcases) are built in the UI, play correctly, are finished
   by the playbot, and needed no genre-specific code in the core.
5. Data tables, custom components, custom behaviours, behaviour packs, turn
   mode, the speed-up clock, all control schemes, procedural maps and the
   plugin API, the tile studio, tall props and attachments, block-level
   editing, the personal asset library, the community asset hub (with
   `docs/HUB_HOSTING.md`), the UI designer, data binding, Quick Actions, wires and the
   logic graph are documented in `docs/` with a recipe each.
6. The Claude assistant can build a small room in at least three different
   genres from a one-sentence request (tests with a mocked API, plus one
   optional live test).
7. All tests pass, exported `.exe` builds of at least two genre samples run
   with no editor installed, and the 60 fps budget holds for the builder
   sample with 200 moving units.

When all are true, add a summary of this phase to `PROGRESS.md`.
