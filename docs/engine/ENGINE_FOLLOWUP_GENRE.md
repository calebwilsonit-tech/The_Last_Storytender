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

If a sample needs something the engine lacks, add it **to the engine in a
general way**, never as a one-off hack for that sample.

## Done when

1. The audit is committed, and every item is resolved or recorded in
   `KNOWN_ISSUES.md` with a reason.
2. A new empty project contains no gameplay assumptions.
3. The Storytender slice works through the behaviour pack and still passes
   all its tests, playbot run included.
4. All six genre samples are built in the UI, play correctly, are finished
   by the playbot, and needed no genre-specific code in the core.
5. Data tables, custom components, custom behaviours, behaviour packs, turn
   mode, the speed-up clock, all control schemes, procedural maps and the
   plugin API are documented in `docs/` with a recipe each.
6. The Claude assistant can build a small room in at least three different
   genres from a one-sentence request (tests with a mocked API, plus one
   optional live test).
7. All tests pass, exported `.exe` builds of at least two genre samples run
   with no editor installed, and the 60 fps budget holds for the builder
   sample with 200 moving units.

When all are true, add a summary of this phase to `PROGRESS.md`.
