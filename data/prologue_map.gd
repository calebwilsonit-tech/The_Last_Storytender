class_name PrologueMap
extends RefCounted
## ASCII layout for the Prologue Plains + Thistledown (ghost town).
## Edit freely; every row must be the same width.
##   ' ' void (edge of the page)   '.' plains floor   ',' town floor   '#' plot hole (pit)
##   P player start   T tree   C Mnemosynth crystal   S the First Sword
##   W tutorial sign   X town sign   H house (2x2 block)   F forge (2x2 block)
##   N Garrick the blacksmith   K Pip the child   B Maud the baker

const ROWS: Array[String] = [
	"                                        ",
	"                                        ",
	"                                        ",
	"    ..T....T...T.#..                    ",
	"   .T...T....T...#...                   ",
	"  .T.............#.T..  ,,,,,,,,,,,,    ",
	"  .........T.....#.... ,,,,,,,,,,,,,,   ",
	"  ....C..........#....,,HH,,,,HH,,,,,,  ",
	"  .T....##....T..#..T.,,HH,,,,HH,,,,,,  ",
	"  .......#.......#.T..,,,,,,,,,,,,,,,,  ",
	"  .............C.#....,,,,,,,,,,,,,,,,  ",
	"  ..P.W...............,,,,,,,,,,,,HH,,  ",
	"  ........C..T........,,,,,K,,,,,,HH,,  ",
	"  .T...............C..,X,,,,,,,,,,,,,,  ",
	"  .......T....C.......,,,,,,,,,,,,,,,,  ",
	"  ...C................,,,,,,,N,,,,,,,,  ",
	"  .....T.........#....,,,,,,,,,FF,,,,,  ",
	"  .T.......##....#..T.,,HH,,,,,FF,,,,,  ",
	"  .........##....#....,,HH,B,,,,,,,,,,  ",
	"  .....#C......T.#.T..,,,,,,,,,,,,,,,,  ",
	"  ...S......C....#..T. ,,,,,,,,,,,,,,   ",
	"   .T.#.T.T...T..#...   ,,,,,,,,,,,,    ",
	"    .............#..                    ",
	"                                        ",
	"                                        ",
	"                                        ",
]
