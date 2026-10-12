class_name MemoryForgeMap
extends RefCounted
## The Blacksmith's Regret: the inside of Garrick's memory.
##   'm' memory floor   '#' plot hole   P start   E memory portal (way out)
##   O frozen furnace (2x2)   A anvil   Y young Garrick   w Wren   Z the Critic
##   1 2 3 memory shards   B crates   k item pickup (Oxford Comma)
## HEIGHTS use the same format as PrologueMap.

const ROWS: Array[String] = [
	"                              ",
	"                              ",
	"                              ",
	"              mmmmmOOmmmmm    ",
	"              m1mmmOOmm2mm    ",
	"             mmmmmmmmmmmmmm   ",
	"             mmmmmmmmmmmmmm   ",
	"             mmmmmBmmmBmmmm   ",
	"             mmmmmmmZmmmmmm   ",
	"  mmmmmmm    mBmmmmmmmmmmmB   ",
	"  mmmmmBmmmmmmmm##mmmmmmmmm   ",
	"  mEmPmmmmm#mmmmmmmYAmmmmmm   ",
	"  mmmmmmmmm#mmmmmmmmmwmmmmm   ",
	"  mmmBmmmmmmmmBmmmmmmmmm#mm   ",
	"  mmmmmmk    mmmmmmmmmmm#mm   ",
	"             mm##mmmmmBmmmm   ",
	"             mmmmmmmmmmmmmm   ",
	"             mmmmmmmmmmmmmm   ",
	"              mmmmm3mmmmmm    ",
	"               mmmmmmmmmm     ",
	"                              ",
	"                              ",
]

const HEIGHTS: Array[String] = [
	"                              ",
	"                              ",
	"                              ",
	"              111100001111    ",
	"              111100001111    ",
	"             01111000011110   ",
	"             00n0000000n000   ",
	"             00000000000000   ",
	"             00000000000000   ",
	"  0000000    00000000000000   ",
	"  0000000000000000000000000   ",
	"  0000000000000000000000000   ",
	"  0000000000000000000000000   ",
	"  0000000000000000000000000   ",
	"  0000000    00000000000000   ",
	"             00000000000000   ",
	"             000000s0000000   ",
	"             00001111110000   ",
	"              000111111000    ",
	"               0011111100     ",
	"                              ",
	"                              ",
]
