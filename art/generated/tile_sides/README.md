Cliff and ledge faces for every floor, built from the floor tiles themselves (`tools/art/ludo_tops.py` -> `art/generated/tile_tops/`) by
`tools/art/ludo_sides.py`. `<floor>_<x><y>_left.png` / `_right.png` are 32 x 44, the same shape and size as the game's own faces (origin at the
foot, 16, 43); x and y (0 to 3) are the tile of the floor (the floor repeats every 4 x 4 cells), because each tile's face is made from the edge
of that tile: the colours along the top's edge are carried down the wall, so a plank line, a stone joint or the grass on top continues as the same
line down the side. `pit` and `page_edge` have one pair each.

Earth and grass faces have no outline (the grass lip shows where the ground ends). Stone, wood and paper faces are outlined along the ledge, the corner
and the foot; their back ledges get a line from `tools/art/ludo_ledges.py` (`outline_edges`).

`check.png` (and `check_zoom.png`, 2x): every floor as a raised platform on another floor. Not wired into the porter yet: each of a floor's 16 tile ids takes
its own `leftArt` / `rightArt` (the porter's TileEntry `what: 'left' | 'right'`). The faces can be made from any folder of tops with the same names:
`ludo_sides.py <repo> <out> --tops <folder>`.
