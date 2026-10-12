class_name Story
extends RefCounted
## All spoken text for Phase 2 lives here so it can be rewritten without
## touching game code. Line format:
##   { "who": "Name" ("" hides the name tab), "text": "...", "style": "speech"|"action"|"sign",
##     "cue": "name" (optional; handled by main.gd before the line is shown) }

const LOREM := ["Lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit"]

static func line(who: String, text: String, style: String = "speech", cue: String = "") -> Dictionary:
	var d := {"who": who, "text": text, "style": style}
	if cue != "":
		d["cue"] = cue
	return d

# ---- Narration (floating text, not blocking) ---------------------------------
const INTRO: Array[String] = [
	"Once, there was a world that someone forgot to finish.",
	"And in its margins, a small drawing woke up.",
]
const FALL_FIRST := "And so the Storytender learned that plot holes are, in fact, holes."
const CRUMPLED := "A crumpled page can be smoothed. That is the whole trick of it."
const SILENCE_WHISPER := "you are so tired.   rest.   it is only white, and white is gentle."
const RESTORED_NARRATION := "And the ink flowed back."
const SWORD_NARRATION := "It was never a weapon. It was a promise somebody made to the dark."

# ---- Signs -------------------------------------------------------------------
static func tutorial_sign() -> Array:
	return [
		line("", "WASD to walk.   E to speak, or to pick up what was forgotten.", "sign"),
		line("", "Mind the plot holes.", "sign"),
	]

static func town_sign() -> Array:
	return [
		line("", "THISTLEDOWN", "sign"),
		line("", "Population: ████.   Founded: ████.   Please enjoy your ████.", "sign"),
	]

# ---- The Sword ---------------------------------------------------------------
static func pickup_sword() -> Array:
	return [
		line("", "A sword, lying in the grass as if it had fallen out of someone's memory.", "action"),
		line("", "The blade is only half drawn. It is cold, and somehow exactly the right weight.", "action"),
	]

# ---- Garrick (the Retired Hero / Blacksmith) ----------------------------------
static func garrick_ghost() -> Array:
	return [
		line("Lorem Ipsum", "Lorem ipsum dolor sit amet...", "speech"),
		line("Lorem Ipsum", "...consectetur. Horseshoe? Horseshoe.", "speech"),
		line("", "He is not a person right now. He is a placeholder holding a hammer.", "action"),
		line("", "Somewhere out in the Plains, the first thing he ever made is waiting to be remembered.", "action"),
	]

static func garrick_ghost_repeat() -> Array:
	return [
		line("Lorem Ipsum", "Lorem... ipsum...", "speech"),
		line("", "Somewhere out in the Plains, a sword is waiting.", "action"),
	]

static func garrick_restoration() -> Array:
	return [
		line("", "You hold out the sword.", "action"),
		line("Lorem Ipsum", "Lorem. Ip-- ...", "speech"),
		line("Garrick", "That's not a horseshoe.", "speech", "name_reveal"),
		line("Garrick", "I made this when I was sixteen. Bent the blade twice. The Author was kind enough to write that I got it right on the third try.", "speech"),
		line("Garrick", "I didn't forge it for a war. I forged it for Wren. My little sister. She was afraid of the dark.", "speech"),
		line("Garrick", "I told her a hero's sword makes the dark afraid of her.", "speech", "tear"),
		line("Garrick", "Then the chapter ended. I got old. Nobody needed a hero anymore, so I told myself horseshoes were enough.", "speech"),
		line("Garrick", "Funny. I forgot I ever loved it. Not the sword. The making.", "speech"),
		line("Garrick", "Thank you, little scribble. You didn't have to find it. You aren't even in the story.", "speech"),
		line("", "You are in the story now.", "action", "restore"),
		line("Garrick", "Hm. Colors. I'd forgotten about those, too.", "speech"),
		line("Garrick", "Come find me when you're ready to learn. Swinging a sword is mostly knowing what you're swinging it for.", "speech"),
	]

static func garrick_restored() -> Array:
	return [
		line("Garrick", "Go on. The dark has nothing on you.", "speech"),
	]

# ---- Villagers ---------------------------------------------------------------
static func pip_ghost() -> Array:
	return [line("Lorem Ipsum", "Dolor sit... amet? Amet.", "speech")]

static func pip_restored() -> Array:
	return [
		line("Pip", "Mister Garrick is hammering again! It sounds like a heartbeat.", "speech"),
		line("Pip", "I found a word in the sky. It said 'Chapter'. Do you think it's a good one?", "speech"),
	]

static func maud_ghost() -> Array:
	return [line("Lorem Ipsum", "Consectetur... adipiscing...", "speech")]

static func maud_restored() -> Array:
	return [
		line("Maud", "I couldn't remember my own recipe. Turns out it was only ever bread, and someone to feed.", "speech"),
		line("Maud", "Here. Don't tell the Narrator I gave you the heel. It's the best part.", "speech"),
	]
