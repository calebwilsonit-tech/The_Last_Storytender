Stairs for every floor, built by `tools/art/ludo_stairs.py` from the floor tops (`tile_tops`) and the cliff faces made from them (`tile_sides`), so the
treads are the floor's own stones/planks/grass and the risers and sides are the cliff's wall, with the same lighting and (stone, wood, paper) outline.

`<floor>_<n|e|s|w>.png`: 64 x 60, origin (32, 44) = the centre of the cell's floor diamond; four 7 px steps climbing one 28 px level, the way the engine draws
a `stairs` slope. n/e/s/w is the way they rise (the porter's SLOPE.N/E/S/W; the Godot data's stair letters). Rising e or s climbs toward the camera, so the
flight is mostly hidden behind the raised ground it leads to; n and w show every step.
Made from tile variant 00 of each floor. `check` view: `tools/art/ludo_stairs_check.py <repo> <out.png> [zoom] [floor ...]`.

Ludo.ai pictures of a single stair step (art/ludo_manifests/stairs.json, cobble and planks) came out as wall-like textures with the stones too small, so they
are not used; the Ludo wall and floor pictures the faces and tops are made from are what the stairs are made of.
Not wired in yet: the engine's `drawStairs` paints flat colours, so these need a hook (an art name per tile for the stair, per direction) before the porter can use them.
