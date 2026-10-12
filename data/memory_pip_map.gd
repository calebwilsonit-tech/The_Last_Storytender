class_name MemoryPipMap
extends RefCounted
## Pip's memory: "The Unfinished Library", a pop-up storybook as a hub of rooms.
##   'p' page floor  '#' chasm / river / missing floor (rewrites bridge them)  P start  E exit  T paper tree  C crystal
##   a b c d e h i j  sentence stones (bridge, wolves, gate, river, stairs, floor, guards, door)
##   G u v w y  gates   k l m n  echo plates   R S  Lantern bars   f F N  torn pages   g Bare  x Mite
##   H door to the Last Page   Z the Spoiler   Y Pip   (columns 30-41, rows 0-10 are the Last Page, unchanged)
## HEIGHTS use the same format as PrologueMap.

const BRIDGE_CELLS: Array[Vector2i] = [Vector2i(11, 16), Vector2i(12, 16), Vector2i(13, 16)]
const RIVER_CELLS: Array[Vector2i] = [Vector2i(21, 28), Vector2i(22, 28), Vector2i(23, 28), Vector2i(21, 29), Vector2i(22, 29), Vector2i(23, 29), Vector2i(21, 30), Vector2i(22, 30), Vector2i(23, 30), Vector2i(21, 31), Vector2i(22, 31), Vector2i(23, 31)]
const FLOOR_CELLS: Array[Vector2i] = [Vector2i(22, 0), Vector2i(23, 0), Vector2i(22, 1), Vector2i(23, 1), Vector2i(22, 2), Vector2i(23, 2), Vector2i(22, 3), Vector2i(23, 3)]

const ROWS: Array[String] = [
	"              pppppppp##ppppp  pppppppppp                   ",
	"              pphppppp##pppFp pppppppppppp                  ",
	"              pppppppp##pgppp ppppppppppYp                  ",
	"              pppppppC##ppppp ppppppZppppp        pppppppp  ",
	"                  pvp         pppppppppppp     ppppppmppnp  ",
	"                  pep          ppppHppppp      jpSpppppppp  ",
	"                  ppp              p           ppppppppppp  ",
	"                  pRp            pppppp            ppp pyp  ",
	"                  pxp           pCppppCp           ppp ppp  ",
	"                  pRp           pppppppp           pwp pNp  ",
	"                  ppp              p               ppp      ",
	"              ppppppppppppppppppppppppppppppp      ppp      ",
	"              ppppppppppppppppppppppppppppppp   pppppppppp  ",
	"  ppppppppp###ppTpppppppppppppppppppppppppppp   pppppppplp  ",
	"  pppppppap###ppppppppppCppppppppppppppppppppppppppgpppppp  ",
	"  ppppTpppp###ppppppppppppppppTppppppppppppppppppppppppppp  ",
	"  pEPpppppp###ppppppppppppppppppppppCppppppppppppppppppppp  ",
	"  ppppppppp###ppppppppppppppppppppppppppTpppp   pippppgppp  ",
	"  ppppTpCpp###ppppppppppppppppppppppppppppppp   pppppppppp  ",
	"  ppppppppp###ppppppppppppppppppppppppppppppp               ",
	"                    ppp                                     ",
	"                    ppp                                     ",
	"              ppppppppppppppp                               ",
	"              pbpppppppgpppcp                               ",
	"              pppppgppppppppp                               ",
	"              pppppppgppppppp                               ",
	"              ppppppppppppppp                               ",
	"                pGp                                         ",
	"              ppppppp###pppkp                               ",
	"              ppppppp###ppppp                               ",
	"              ppppppp###ppppp                               ",
	"              ppxpppp###ppppp                               ",
	"              ppppppp     pup                               ",
	"              pppdppp   ppppp                               ",
	"              ppppppp   ppfpp                               ",
	"                                                            ",
]

const HEIGHTS: Array[String] = [
	"              000000000000000  2222222222                   ",
	"              000000000000000 222222222222                  ",
	"              000000000000000 222222222222                  ",
	"              000000000000000 222222222222        00000000  ",
	"                  000         222222222222     00000000000  ",
	"                  000          2222222222      00000000000  ",
	"                  000              n           00000000000  ",
	"                  000            111111            000 000  ",
	"                  000           11111111           000 000  ",
	"                  000           11111111           000 000  ",
	"                  000              n               000      ",
	"              0000000000000000000000000000000      000      ",
	"              0000000000000000000000000000000   0000000000  ",
	"  0000000000000000000000000000000000000000000   0000000000  ",
	"  00000000000000000000000000000000000000000000000000000000  ",
	"  00000000000000000000000000000000000000000000000000000000  ",
	"  00000000000000000000000000000000000000000000000000000000  ",
	"  0000000000000000000000000000000000000000000   0000000000  ",
	"  0000000000000000000000000000000000000000000   0000000000  ",
	"  0000000000000000000000000000000000000000000               ",
	"                    000                                     ",
	"                    000                                     ",
	"              000000000000000                               ",
	"              000000000000000                               ",
	"              000000000000000                               ",
	"              000000000000000                               ",
	"              000000000000000                               ",
	"                000                                         ",
	"              000000000000111                               ",
	"              000000000000111                               ",
	"              0000000000000n0                               ",
	"              000000000000000                               ",
	"              0000000     000                               ",
	"              0000000   00000                               ",
	"              0000000   00000                               ",
	"                                                            ",
]
