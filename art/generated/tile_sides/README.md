Cliff and ledge faces for every floor, made from the Ludo.ai wall pictures (`art/incoming2/tiles/side_*.png`) by `tools/art/ludo_sides.py`.
`<name>_left.png` and `_right.png` are 32 x 44, the same shape and size as the game's own faces (origin at the foot, 16, 43).

Sets: meadow_1, meadow_2, meadow_3, dirt, moss, cobble, flagstone, slate, planks, parchment (the floors), pit (the dark inside of a hole) and
page_edge (the edge of the page: a stack of leaves). Each takes its colours from its own floor picture, so face and top belong together; the wall
carries on from one tile to the next without a seam. Each is outlined along the ledge (the top rim), up the corner where the two faces meet and
along the foot; the open floor has no outline (it would draw a grid), so the edge of a raised floor is easy to see.

`preview.png`: every set as a run of three blocks. `check.png`: every real floor as a raised platform on another floor (`tools/art/ludo_sides_check.py`).
Not wired into the porter yet: the porter takes each floor's faces from the Godot game's left/right pictures (TileEntry `what: 'left' | 'right'`).
