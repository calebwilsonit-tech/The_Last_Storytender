class_name MemoryMaudMap
extends RefCounted
## Maud's memory: "The Empty Table", a warm kitchen gone cold.
##   'w' kitchen floor   '#' chasm   P start   E exit
##   a BREAD (3 cells, floats over the chasm)   q SALT   L pressure plate   G gate
##   d DOUGH (rises; bridges the cellar chasm)   e SERVE blocks (cover from the Clearing)
##   M the long table   h chairs   Y Maud, remembered   g Bare   x Mite   C crystal   B crate
## HEIGHTS use the same format as PrologueMap.

const ROWS: Array[String] = [
	"                             wwwwwwwwwwwww      ",
	"                            wwwwwwwwCwwwwww     ",
	"                            wwwwwwwwwwwwwww     ",
	"                            wwwwwhwhwhwwwww     ",
	"                            wwwwwwwMwwYwwww     ",
	"                            wwwCwhwhwhwwwCw     ",
	"                            wwwwwwwwwwwwwww     ",
	"                            wwewwwwwwwwweww     ",
	"                            wwwwCwwewwwwwww     ",
	"                             wwwwwwwwwwwww      ",
	"                wwwwwwwwwww           w         ",
	"              wwwwwwwwwwwww www ww###www        ",
	"              wwwwBwwwCwwwwwGwCwxw###wwww       ",
	"              wCwwwwwgwwwBwwwwwwwC###wwww       ",
	"   wwwwwww ###wwBwwwwwwwwwww   www###wCww       ",
	"  wwwCwwwww###wwwwwCBwwwwwww   wgwd##Bwww       ",
	"  wwwwwwwww###wwwwwwwwwwwwww   www###wwww       ",
	"  wEPwwwwwwa##wwqwwwwwwwL ww   wBw###wwww       ",
	"  wwwwwwwww###wwwwwwwwwwwwww   wwx###wwCw       ",
	"  wwwwwwCww###wwwwwxwBwwwwCw   wwC###wwww       ",
	"   wwwwwwww###wwwwwwwwwwwwww    ww###www        ",
	"                wwwwwwwwww                      ",
	"                                                ",
	"                                                ",
	"                                                ",
	"                                                ",
]

const HEIGHTS: Array[String] = [
	"                             1111111111111      ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                            111111111111111     ",
	"                             1111111111111      ",
	"                00000000000           n         ",
	"              0000000000000 000 00000000        ",
	"              000000000000000000000000000       ",
	"              000000000000000000000000000       ",
	"   0000000 00000000000000000   0000000000       ",
	"  00000000000000000000000000   0000000000       ",
	"  00000000000000000000000000   0000000000       ",
	"  00000000000000000000000 00   0000000000       ",
	"  00000000000000000000000000   0000000000       ",
	"  00000000000000000000000000   0000000000       ",
	"   0000000000000000000000000    00000000        ",
	"                0000000000                      ",
	"                                                ",
	"                                                ",
	"                                                ",
	"                                                ",
]
