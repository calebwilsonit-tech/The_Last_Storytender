# The Last Storytender: flow and rules (spec for the Tilewright port)

Extracted from the Godot sources (main.gd, level_base.gd, game_state.gd, story.gd, player.gd, enemy*.gd, item_*.gd,
drop_tables.gd, puzzle_sites.gd, memory_*.gd, side_*.gd, editor_scissor.gd). Overworld cells are prologue_map.gd ROWS
coordinates (row = y, char = x). "Ground distance" = screen delta with y doubled; ranges below are ground px
(64 px across a cell's width ~ 1 engine cell = 35.8 px of ground along an axis; convert as px / 32 for x and y).

## 1. New game and story beats

- Title: Continue (needs a save) / New Game (confirm if a save exists, then difficulty) / Settings / Quit.
- Difficulty story | normal, fixed per save: enemy damage x0.6 | x1.0; ink after crumpling 100 | 50; boss bolt speed
  x0.85 | x1; Spoiler rewrite window +1.5 s | 0; fall damage 8 | 15; drop chance mobs 1.0 | 1.2, bosses 1.0 | 1.75.
- New game -> intro book (6 spreads: idea, tender, editors, doodle, you, blot; typewriter 46 chars/s; Esc skips) ->
  flag book_seen -> overworld.
- Overworld first time (flag intro_done): wake-up (narrate INTRO_WAKE, the Storytender pops in), tutorial cards
  "move" then "quill", narrate the two INTRO lines 5.6 s apart. Start cell P (16,54).
- At the start: walk, sneak, dash, lantern, strike with the pencil stub (power 0.55), interact, binder, map, pause.
  No echo, no format styles. Bare and Mite roam.
- Regions: HUD label from REGIONS; first visit to a region other than m/s/o: +10 Mnemosynth, +6 renown, "Discovered".
  Entering town first time per load narrates SILENCE_WHISPER.

| # | Trigger | Result | Dialogue | Flags / rewards |
|---|---|---|---|---|
| 0 | signs W (19,53), X (87,55), lore L | read | tutorial_sign, town_sign, lore | |
| 1 | Garrick N (93,55) first talk | | garrick_ghost (then garrick_ghost_repeat) | met_garrick |
| 2 | Forge F (95,56) "Touch the frozen flame" (met_garrick, not memory_done), range 120 | -> forge memory, return (94,55) | forge_flame | |
| 3 | Forge memory won | take the First Sword | memory_sword | has_sword, memory_done |
| 4 | back on the overworld | narrate RETURNED; echo on (R) | | |
| 5 | talk to Garrick with memory_done | cinematic, cues name_reveal, tear, restore (wave) | garrick_restoration | restored_garrick, +25 M, +35 R |
| 6 | talk again, no quill | Quill given; lesson: strike dummy D (93,58) 3x, dash once, hold lantern 1.2 s | garrick_lesson_start, garrick_lesson_hint(1..3) | has_quill |
| 6d | lesson done | +20 M, hardcover_binding x1, eraser_crumbs x2, narrate BINDER_HINT, REDACTION_NOTICED | garrick_lesson_end | lesson_done |
| 6e | later talks | | garrick_restored | |
| 7 | Pip's book Q (90,52) range 90 | without quill: PIP_BOOK_HINT; with: -> pip memory, return (90,53) | pip_book_enter | |
| 8 | Pip memory won | | pip_resolution | pip_memory_done, +40 M, bookmark |
| 9 | Pip K (91,52) | before: pip_ghost; after: cinematic, cue restore_pip | pip_restoration | restored_pip, +30 M, +35 R; Run-on + Dangler spawn |
| 10 | Maud's oven V (90,58) range 110 | without pip_memory_done: MAUD_OVEN_HINT; else -> maud memory, return (90,59) | maud_oven_enter | |
| 11 | Maud memory | format styles granted on entry | maud_format_grant | format_mark, maud_memory_done, +40 M |
| 12 | Maud B (91,58) | before: maud_ghost; after: cinematic, cue restore_maud | maud_restoration | restored_maud, +30 M, warm_loaf x3, +35 R; Censor + Ellipsis spawn |
| 13 | all three restored, not scissor_done | rift prop at (88,53); narrate RIFT_NARRATION | | |
| 14 | "Step into the tear" range 110 | cinematic -> Cutting Room, return (88,54) | scissor_rift_enter | |
| 15 | Scissor-Man won | Thimble | scissor_finale | scissor_done, +60 M, +40 R |
| 16 | back, scissor_done, not published | narrate PUBLISHED, town wave (radius 2600 from the rift), then published | | restored_town, town_published |
| 17 | Margin Gate G (125,53) range 120 | not published: gate_locked; renown < 220: gate_renown; else opened look + gate_open (cell stays blocked) | | |

Other narration: ENEMY_INTRO[kind] for kinds 2-5 once each (met_enemy_k); PROOFREAD first per scene; FALL_FIRST first
per scene; CRUMPLED every crumple; REDACTOR_HINT within 150 once per scene; REDACTOR_OPEN on reveal.

## 2. Player numbers

- Speed 190 px/s (accel 1400, friction 1800). Multipliers: equipped speed, x0.72 lantern on, x0.55 sneaking.
- Dash (Shift): 0.2 s at 520 px/s, cooldown 0.75 x (1 + dash_cd), invulnerable 0.32 s, no attack during it.
- Knockback: stun 0.18 s, cancels the dash.
- Noise radius (enemy hearing): 45 + 105 x speed fraction; dash 290; swing >= 300; lantern +50; sneak x0.4.
- Ink (health): 100 + 10 x (rank - 1) + 2 x attr ink. No base regen (regen stat only). Carried between scenes.
- Damage: armor reduces (clamped 0.75), then invulnerable 0.9 + invuln stat. Falls are non-lethal (leave 1 ink).
- Quill (J / LMB): combo of 3 within 0.75 s; damage 2.0 (finisher 3.5) x (1 + dmg) x tool (1.0 quill/sword, 0.55
  stub); reach 74 (+16 finisher) x (1 + reach) (x0.85 stub); cooldown 0.3 (0.5); arc +-1.2 rad; same floor only.
- Aim: right stick, else mouse (moved within 3 s), else last move direction.
- Lantern (hold Q / RMB): 100 max, drain 24/s x max(0.1, 1 + lantern_eff), regen 14/s after 0.9 s off; beam range
  175, half-angle 0.63 rad; lights "lightable" things. Refuel: crystal +12, post +100, items.
- Sneak attack: unaware or asleep enemies take x2.
- Pits: fall (0.55 s), fall damage (8/15), respawn at the last safe position, FALL_FIRST once.
- Crumple: after 2.2 s. Story: +100 ink at the safe position. Normal: lose floor(M x 0.15 / 5) x 5 Mnemosynth (dropped
  as crystals of 5 where you fell), +50 ink, respawn at the last post rested at (or nearest lit, or (87,53) in town, or
  start), post cell + (0,1); enemies, echoes, arenas and crumble tiles reset.
- Rank up: +10 ink, toast "Rank N! The ink bottle grows."
- Format styles (1/2/3, with format_mark): underline / bold / italic.
- Echo (R, once memory_done): record up to 9 s (under 20 frames is discarded), replays then holds; 2 echoes, 3 with
  echo_third; echoes press echo plates and lure enemies.

## 3. Overworld objects

| Char | Object |
|---|---|
| T (507) | tree, blocks its cell |
| C (86) | Mnemosynth crystal: auto-collect within 30 px: +5 M (x mnemo stat), +12 lantern; flag got_C_x_y |
| W / X / L (27) | signs and lore stones: Read |
| H (4, 2x2) | ghost houses |
| F (2x2) | ghost forge, the flame |
| N K B | Garrick, Pip, Maud (Speak, range 64) |
| V | Maud's oven; Q Pip's storybook (removed after pip_memory_done) |
| g x l d n z | enemy spawn points Bare 12, Mite 14, Run-on 5, Dangler 7, Censor 3, Ellipsis 5 |
| R (6) | Redactor bar, 3 cells, "the way up": blocks; lantern progress +dt/1.4 (decay 0.4/s), at 1 revealed, fades 1.6 s; not saved |
| D | training dummy (never dies) |
| Y (7) | lantern posts (§3.3) |
| G | Margin Gate |
| q (30) | chests (§3.4) |
| S / U (2 each) | riddle stones and gates |
| k o e v | one-time pickups softcover_binding, oxford_comma, eraser_crumbs, void_ink ("Take", flag got_k_x_y) |

Heights: levels 0-9; e/w/s/n stairs rise that way; cliffs are walls; interaction and hits only within 0.6 levels.

3.3 Lantern posts meadow (28,52), orchard (46,27), oldmeadow (76,50), square (95,52), gate (118,52), folio (85,11),
smudge (115,68). Interact range 100: "Light the post" / "Rest at the post". Lighting: flag wp_id, +10 M, +3 R, toast
"Waypoint lit: name"; resting: toast "You rest by the lantern. The page resets: the Errors return." Both: enemies,
echoes and sites reset, ink and lantern full, save, INDEX_FIRST once, then the Index (Revise Your Draft: attributes,
15 free points the first time; Workbench: recipes; Narrator's Stall: SHOP_STOCK, sell at 40%; Travel: world map).
Fast travel only to lit posts at least 40 cells away; lands at post + (0,1).

3.4 Chests range 90 "Open the chest" until got_chest_x_y. Locked while a (non-crumble) site guarding it is unsolved:
toast "The chest is sealed. Something nearby is holding it shut." Opening: +5 R, reward from CHESTS ("tier:N" ->
TrialPrizes.roll seeded by the cell; "mnemo:N"; "item:id[:n]"; default mnemo:20), random CHEST_LINES narration.

3.5 Riddles r0 (stone (39,67), gate (37,65), chest (34,65), tier 1), r3 (stone (58,56), gate (60,54), chest
(63,54), tier 3): "Attempt the trial" -> a vault word minigame; win: stone shows its last option, +(4+4 tier) R,
riddle_id, gate opens, RIDDLE_OPEN; lose: toast "The words slip away. Try again whenever you like."

3.6 Puzzle sites (SITES; solving sets site_id, +4 R):
- echo (3): gate "WEIGHED" (3 cells) seals the chest; two echo plates; both pressed at once -> open.
- words (5): three sentence stones; a sign gives the answers; all on `good` -> stones lock, bridge cells '#'->'.'.
- arena (3): gate "PROOF" open; stepping on the trigger closes it, waves of enemies; after the last wave it opens.
- crumble (2): causeway cells crack 0.8 s after you step on them, hole for 5 s, then solid; reaching the chest
  makes them solid for good.
- portals: Weighing Room (107,74) needs memory_done; Proof Room (13,25) needs has_quill.

3.8 Enemy streaming: spawn when 560-900 px away, free beyond 1500; a killed one wakes 120 s later.

## 4. Enemies

Common: idle wander 28 px/s near home (110), hearing + sight (cone, x1.25 with your lantern, x0.75 sneaking), alert
to 1 -> chase (alarm to others within 170), lose for 2.5 s -> search 3 s -> return. Echoes lure idle enemies. Lit:
speed x0.5. Hurt: knockback 230 (Mite) / 170, 0.22 s. Death: renown, 1 (Mite) or 2 crystals, drop roll.

| Kind | hp | chase | attack | light | renown |
|---|---|---|---|---|---|
| Bare (g) | 9 | 86 | within 80: windup 0.45 s, lunge 0.38 s at 340, 12 dmg | proofread over 2.2 s -> friendly Bear | 2 |
| Mite (x) | 2 | 150 | contact 6 dmg | burns 4.5 hp/s | 1 |
| Run-on (l) | 10 | 40 | puddle trail slows you to 0.55; contact 7 | proofread 3.0 s | 3 |
| Dangler (d) | 5 | keeps 170-290 away | word bolt every 2.5 s (3.2 story), 6 dmg | proofread 1.8 s | 3 |
| Censor (n) | 12 | 62 | lunge 10 dmg; front blocked by its bar | lantern drops the bar for 5 s | 4 |
| Ellipsis (z) | 4 | 70 | blinks, reappears 90-140 px away, 7 dmg | pinned, burns 3 hp/s | 4 |

Proofread: friendly, follows you; 6 crystals; ink_vial (100% story, 60% normal); toast "Proofread: Bare -> Bear".
Drops: drop_tables.gd (each entry rolled on its own).

Economy: Mnemosynth (M) and renown (R). Rank steps 0, 40, 100, 180, 280, 400, 560, 760, 1000, 1300, 1650. Margin Gate
220 R. Attributes ink/grit/pen/wit/foot/luck (cost int(20 + 4p + 0.08p^2)).

## 5. Items

Consumables: eraser_crumbs (thrown 150 px, 5 dmg within 85), ink_vial +45, warm_loaf +60, ink_flask full,
lantern_oil +100 lantern, sticky_note (sleep 6 s within 240), herbal_tea +25/+25, honey_biscuit +30, clarity_tonic
+40/+100, ghost_pepper_ink (sleep 4 s, 280), reader_digest +12 R, memory_jar +60 M, phoenix_draught full/+100,
time_in_a_bottle (sleep 9 s, 360), pocket_workbench (craft anywhere). Bindings and amulets: fx stats (armor, speed,
dash_cd, invuln, dmg, reach, lantern_eff, regen, mnemo, luck, renown). Two quick slots (F use, G switch).

## 6. Restoration

Town tiles, houses, forge and town sign are ghosts (graphite, faded). Each restoration is a circle growing from an
origin (radius 470, +190 soft edge, 5.5 s); restored_at(pos) = max over waves; everything 1 once published. NPCs are
"Lorem Ipsum" placeholders with lorem dialogue until their own wave.

## 7. Dungeons

Shared: pause menu adds "Travel to a lantern" and "Restart this dungeon"; posts and vault chests; death -> last lit
post in the dungeon, else start; no travel during boss fights.

- Forge "The Blacksmith's Regret": echo plates open gates; three tokens (hammer, tongs, bellows) open the forge door;
  the Critic: word bolts (9 dmg, slow or dim), red ink pools, 3 memory shards strip its layers, then hittable (110 HP,
  77 story); win -> the First Sword.
- Pip "The Unfinished Library": rooms with sentence stones (bridge, sleeping wolves 18 s, ice river 12 s, solid floor
  10 s, lock), 3 torn pages open THE END door; the Spoiler: strike it while it reads to rewrite (5 rewrites), then
  190 HP (133 story); win -> bookmark, +40 M.
- Maud "The Empty Table": underline BREAD (bridge), bold+italic SALT onto a plate, rising dough (lantern speeds it,
  rushing burns it), lead 6 guests to chairs with the lantern; the Cold Shoulder: hit from behind or while resting,
  170 HP; win -> +40 M.
- The Cutting Room: clipboard (strike clippings, V pastes, patches last 18 s / 26 story), the Scissor-Man cuts along
  telegraphed lines, jammed for 5.5 s when a cut crosses a patch, only hurt while jammed, 90 HP, phases at 66% and 33%.
- Weighing Room (echo puzzles, Locket -> echo_third, reward hourglass_of_drafts) and Proof Room (lantern-revealed
  plaques give the answers to 3 stones: ALIVE, UNWRITTEN, WELCOME; reward censors_monocle).

## 8. Save

renown, mnemosynth, ink, flags, inventory, equipment (binding, amulet), quick slots and active slot, restoration
sources, town_published, difficulty, spawn cell, last_post, dungeon_last_post, attributes, free points.

## Original-game quirks (kept as they are unless the owner says otherwise)

1. The lesson step is not saved (quitting mid-lesson loses lesson_done and its rewards).
2. Proofread enemies still count as alive, so they stall arena waves; they give no renown or drops.
3. Pickups in memories and side dungeons are not saved; side-dungeon rewards repeat.
4. In dungeons the per-room checkpoints are not used for death.
5. The opened Margin Gate still blocks its cell.
6. The proofread toast always reads "Bare -> Bear".
7. All overworld redactors say "the way up"; only the last one gets the near hint.
8. Garrick's revealed name is not kept after the cinematic.
