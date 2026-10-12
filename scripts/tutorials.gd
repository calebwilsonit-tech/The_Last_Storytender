class_name Tutorials
extends RefCounted
## The how-to cards that pop up the first time a mechanic unlocks. Each item is
## {a: action id (or "move" / "aim"), t: what it does}; the card shows the glyph for
## whichever device you are using.

const CARDS := {
	"move": {
		"title": "Walking the page",
		"body": "Speak to anyone who looks forgotten. Anything that glows can be touched.",
		"items": [{"a": "move", "t": "Walk"}, {"a": "interact", "t": "Speak, take, continue"}],
	},
	"lantern": {
		"title": "The Lantern",
		"body": "Hold it up and forgotten things remember. It burns while it is lit, and the light is tiring to carry.",
		"items": [{"a": "lantern", "t": "Hold to light the Lantern"}],
	},
	"quill": {
		"title": "The Quill",
		"body": "A strike, a strike, then a wider third. Dashing is quick and leaves no trail for the Errors to follow.",
		"items": [{"a": "attack", "t": "Strike (chain three)"}, {"a": "aim", "t": "Aim"}, {"a": "dash", "t": "Dash"}],
	},
	"binder": {
		"title": "Your binder",
		"body": "Wear what Garrick gave you. Put one item in the quick slot to use it without stopping.",
		"items": [{"a": "inventory", "t": "Open the binder"}, {"a": "use_item", "t": "Use the quick item"}],
	},
	"stealth": {
		"title": "Quiet feet",
		"body": "Errors can see and hear you. Their cones show where they look, and running is loud. Creeping is slower but nearly silent, and a strike from behind hurts twice as much.",
		"items": [{"a": "sneak", "t": "Hold to creep"}, {"a": "attack", "t": "Strike from behind"}],
	},
	"rewrite": {
		"title": "Rewriting",
		"body": "Some sentences have one word that can change. Strike the word, or stand close and interact, and the story follows.",
		"items": [{"a": "attack", "t": "Strike the word"}, {"a": "interact", "t": "Rewrite it"}],
	},
	"format": {
		"title": "Format",
		"body": "Pick a style, then strike a block of text. Words in this kitchen have weight.",
		"items": [{"a": "style_underline", "t": "Underline"}, {"a": "style_bold", "t": "Bold"}, {"a": "style_italic", "t": "Italic"}, {"a": "attack", "t": "Strike a word"}],
	},
	"echo": {
		"title": "Echoes",
		"body": "Start remembering, walk, and stop. A ghost of you replays it and stays where it ended. You can keep two, and they have weight.",
		"items": [{"a": "echo", "t": "Start / stop remembering"}, {"a": "move", "t": "Walk the memory"}],
	},
	"paste": {
		"title": "The Clipboard",
		"body": "Strike a clipping to pick it up. Aim, and paste it as a patch. Paper that has been patched, scissors will not cut.",
		"items": [{"a": "attack", "t": "Pick up a clipping"}, {"a": "aim", "t": "Aim the patch"}, {"a": "paste", "t": "Paste"}],
	},
}
