class_name MemoryForgeMap
extends RefCounted
## The Blacksmith's Regret: the inside of Garrick's memory, four rooms long.
##   'm' memory floor   '#' plot hole   P start   E memory portal (way out)
##   a b c d  echo plates (a: room 1, b+c: room 2, d: room 3)   g h i  gates for those rooms
##   f z y  things to look at (Wren, the apprentice's bench, the night watch)   Q the night guard (Bare)
##   O frozen furnace (2x2)   A anvil   Y young Garrick   w Wren   Z the Critic
##   1 2 3 memory shards   B crates   k item pickup (Oxford Comma)
## HEIGHTS use the same format as PrologueMap.

const ROWS: Array[String] = [
	"                                                            ",
	"                                                            ",
	"                                                            ",
	"                                           mmmmmOOmmmmm     ",
	"                                           m1mmmOOmm2mm     ",
	"                                          mmmmmmmmmmmmmm    ",
	"                                          mmmmmmmmmmmmmm    ",
	"                                          mmmmmBmmmBmmmm    ",
	"              mmmmmmmmmmmm  mmmmmmmmmmmm  mmmmmmmZmmmmmm    ",
	"  mmmmmmmmmm  mbmmmmmmmmmy  mmmmmmmBmmzm  mBmmmmmmmmmmmB    ",
	"  EmmmmfmBmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm##mmmmmmmmm    ",
	"  mmmmmmmmmmgmmmmmmmBmmmmmhmmmmmmmmmmmmmimmmmmmmYAmmmmmm    ",
	"  mmmBmmmmmmmmmmmmmmBm##mmmmmmmmmmmmmBmmmmmmmmmmmmwmmmmm    ",
	"  mammmmmmPm  mmmmmmmm##mm  mmmmBmmmmQmm  mBmmmmmmmmm#mm    ",
	"  mmmBmmmmmk  mmmBmmmmmmcm  mmmmmmmmmmdm  mmmmmmmmmmm#mm    ",
	"              mmmmmmmmmmmm  mmmmmmmmmmmm  mm##mmmmmBmmmm    ",
	"                                          mmmmmmmmmmmmmm    ",
	"                                          mmmmmmmmmmmmmm    ",
	"                                           mmmmm3mmmmmm     ",
	"                                            mmmmmmmmmm      ",
	"                                                            ",
	"                                                            ",
]

const HEIGHTS: Array[String] = [
	"                                                            ",
	"                                                            ",
	"                                                            ",
	"                                           111100001111     ",
	"                                           111100001111     ",
	"                                          01111000011110    ",
	"                                          00n0000000n000    ",
	"                                          00000000000000    ",
	"              011110000000  000000000000  00000000000000    ",
	"  0000000000  01111w000000  000000000000  00000000000000    ",
	"  000000000000011110000000000000000000000000000000000000    ",
	"  000000000000000000000000000000000000000000000000000000    ",
	"  000000000000000000000000000000000000000000000000000000    ",
	"  0000000000  000000000000  000000000000  00000000000000    ",
	"  0000000000  000000000000  000000000000  00000000000000    ",
	"              000000000000  000000000000  00000000000000    ",
	"                                          000000s0000000    ",
	"                                          00001111110000    ",
	"                                           000111111000     ",
	"                                            0011111100      ",
	"                                                            ",
	"                                                            ",
]
