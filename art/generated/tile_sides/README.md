Cliff and ledge faces made from the Ludo.ai wall pictures (`art/incoming2/tiles/side_*.png`) by `tools/art/ludo_sides.py`.
`<material>_left.png` and `_right.png` are 32 x 44, the same shape and size as the game's own faces (origin at the foot, 16, 43), for earth
(with a grass lip), stone and wood. The wall carries on seamlessly from one tile to the next. `preview.png` shows them large and as blocks.
They are not wired into the porter yet: the porter takes each floor's faces from `capture_tiles.gd`'s left/right pictures, so use these in place of
those (the porter's TileEntry `what: 'left' | 'right'`).
