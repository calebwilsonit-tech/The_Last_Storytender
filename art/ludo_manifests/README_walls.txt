Wall pictures for the cliff faces (tools/art/ludo_sides.py): sides_matched.json (earth, flagstone, slate, planks, paper) and side_cobble2.json (cobble), each
made with `style` and the matching floor picture (art/incoming2/tiles/floor_*.png) as the style image, so the wall has the floor's own stones, colours and line.
Picked: wall_cobble (s1), wall_earth (s2), wall_flagstone (s0), wall_slate (s0), wall_planks (s0), wall_paper (s1), copied to art/incoming2/tiles/wall_<name>.png.
What made the cobble wall match: the prompt names the same thick dark outline round every stone and the same green moss in the gaps as the reference, and says
"stones the same size as the reference". The first prompt (no outline or moss, "low wall of rounded cobblestones") gave brown gaps and thin lines.

Tops made to match the walls (tops_from_walls.json for cobble, tops_from_walls_all.json for the rest): the wall picture is the style reference, and the prompt asks for
the same colours, the same thick dark outline weight, and stones/slabs/planks the same size as the reference. Kept (clean names art/incoming2/tiles/top_<name>.png,
which tools/art/ludo_tops.py prefers over floor_<name>.png): cobble (top3 s0), dirt (s0), flagstone (s0), slate (s0), planks (s1), parchment (s2).
Not kept: the new meadow_1/2/3 and moss (too flat; "calm, even, not noisy" took the grass blades out), so those floors still use floor_*.png.
