class_name PrologueMap
extends RefCounted
## ASCII layout for the Prologue Plains + Thistledown (ghost town).
## Edit freely; every row must be the same width in both layers.
##
## ROWS (what is on each cell)
##   ' ' void (edge of the page)   '.' plains floor   ',' town floor   '#' plot hole (pit)
##   P player start   T tree   C Mnemosynth crystal   S the First Sword
##   W tutorial sign   X town sign   H house (2x2 block)   F forge (2x2 block)
##   N Garrick the blacksmith   K Pip the child   B Maud the baker
##   g Bare (Typo-Ghoul)   k item pickup (Softcover Binding)   x Mite   R Redactor bar (3 cells wide)   D training dummy
##
## HEIGHTS (elevation of each cell, one level = Iso.LEVEL_H pixels)
##   '0'..'9' flat ground at that level.  Cliffs between different levels are solid walls.
##   Stairs climb exactly one level, rising toward the letter's direction:
##   'e' toward +x   'w' toward -x   's' toward +y   'n' toward -y
##   (the low-side neighbor must be the level just below the high-side neighbor)

const ROWS: Array[String] = [
	"                                        ",
	"                                        ",
	"                                        ",
	"    ..T....T...T.#..                    ",
	"   .T...T....T...#...                   ",
	"  .T.............#.T..  ,,,,,,,,,,,,    ",
	"  .........T.....#.... ,,,,,,,,,,,,,,   ",
	"  ....C......g...#....,,HH,,,,HH,,,,,,  ",
	"  .T....##....T..#..T.,,HH,,,,HH,,,,,,  ",
	"  .......#.....x.#.T..,,,,,,,,,,,,,,,,  ",
	"  .............C.#....,,,,,,,,,,,,,,,,  ",
	"  ..P.W..x............,,,,,,,,,,,,HH,,  ",
	"  ........C..T........,,,,,K,,,,,,HH,,  ",
	"  .T...............C..,,,,,,,,,,,,,,,,  ",
	"  .......T.g..C.......,,,,,,,,,,,,,,,,  ",
	"  ...C................,X,,,,,N,,,,,,,,  ",
	"  .....T.....x...#....,,,,,,,,,FF,,,,,  ",
	"  .T..R....##....#..T.,,HH,,,,,FF,,,,,  ",
	"  .........##....#....,,HH,B,D,,,,,,,,  ",
	"  .....#C.x...gT.#.T..,,,,,,,,,,,,,,,,  ",
	"  ...k......C....#..T. ,,,,,,,,,,,,,,   ",
	"   .T.#.T.T...T..#...   ,,,,,,,,,,,,    ",
	"    .............#..                    ",
	"                                        ",
	"                                        ",
	"                                        ",
]

const HEIGHTS: Array[String] = [
	"                                        ",
	"                                        ",
	"                                        ",
	"    0000000000000000                    ",
	"   000000000000000000                   ",
	"  00000000000000000000  111111111111    ",
	"  00000000000000000000 11111111111111   ",
	"  000000000000000000001111111111111111  ",
	"  000000000000000000001111111111111111  ",
	"  000000000000000000001111111111111111  ",
	"  000000000000000000001111111111111111  ",
	"  000000000000000000001111111111111111  ",
	"  00000000000000000000e111111111111111  ",
	"  00000000000000000000e111112222222222  ",
	"  00000000000000000000e1111e2222222222  ",
	"  0000000000000000000011111e2222222222  ",
	"  0000000000000000000011111e2222222222  ",
	"  000000000000000000001111112222222222  ",
	"  0111s1100000000000001111112222222222  ",
	"  011111100000000000001111112222222222  ",
	"  01111110000000000000 11111222222222   ",
	"   111111000000000000   111122222222    ",
	"    0000000000000000                    ",
	"                                        ",
	"                                        ",
	"                                        ",
]
