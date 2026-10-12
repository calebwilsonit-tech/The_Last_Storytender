class_name Palette
extends RefCounted
## The emotional arc is told in color: graphite pencil = forgotten,
## ink + warm washes = remembered. See docs/ART_DIRECTION.md.

const INK := Color("1b1722")
const INK_BROWN := Color("3b2a1c")
const PENCIL := Color("8d8f9c")        # ghost-town graphite
const PAPER := Color("e8d6ad")
const PAPER_LIGHT := Color("f6ecd2")
const GRASS := Color("7aa35a")
const GRASS_DARK := Color("4f7a3f")
const LEAF := Color("86b062")
const WOOD := Color("8a5a35")
const WALL := Color("ead9b4")
const ROOF := Color("b5533c")
const ROOF_ALT := Color("5d7aa8")
const COBBLE := Color("d9a86a")
const GOLD := Color("f2b84b")          # Mnemosynth: warm, nostalgic
const FLAME := Color("ff9a3c")
const FROZEN := Color("bfe8f0")
const RUST := Color("a8553a")
const TEAR := Color("7fb3e0")
const SILENCE := Color("9a98b8")
const CYAN := Color("6fe3ff")           # restored / remembered glow, the Lantern
const CYAN_DEEP := Color("2b8fb3")
const GLITCH := Color("8a4fd0")         # Redaction corruption
const STATIC_GRAY := Color("9c9ca8")
const OUTLINE := Color("14111a")        # character outlines: thick, near-black
const CLOAK := Color("84694a")
const CLOAK_DARK := Color("5c4833")
const TUNIC := Color("b39b76")
const TROUSERS := Color("62708a")
const LEATHER := Color("5a3c28")
const CRITIC_RED := Color("a3211f")
const CRITIC_DARK := Color("3d0a10")

## Blend a color toward grayscale. r = 0 -> fully faded, 1 -> full color.
static func ghostify(c: Color, r: float) -> Color:
	var g := c.get_luminance()
	return Color(g, g, g, c.a).lerp(c, r)
