class_name Story
extends RefCounted
## All spoken text for Phase 2 lives here so it can be rewritten without
## touching game code. Line format:
##   { "who": "Name" ("" hides the name tab), "text": "...", "style": "speech"|"action"|"sign",
##     "cue": "name" (optional; handled by main.gd before the line is shown) }

const LOREM := ["Lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit"]

static func line(who: String, text: String, style: String = "speech", cue: String = "", tint = null) -> Dictionary:
	var d := {"who": who, "text": text, "style": style}
	if cue != "":
		d["cue"] = cue
	if tint is Color:
		d["tint"] = tint
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
const RETURNED := "The sword is heavy the way a promise is heavy. Somebody should hear that it's been kept."
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

# ---- Garrick (the Retired Hero / Blacksmith) ----------------------------------
static func garrick_ghost() -> Array:
	return [
		line("Lorem Ipsum", "Lorem ipsum dolor sit amet...", "speech"),
		line("Lorem Ipsum", "...consectetur. Horseshoe? Horseshoe.", "speech"),
		line("", "He is not a person right now. He is a placeholder holding a hammer.", "action"),
		line("", "But the forge behind him is holding something, too. Its fire is frozen in a single moment. He cannot let go of it, and he cannot remember it.", "action"),
	]

static func garrick_ghost_repeat() -> Array:
	return [
		line("Lorem Ipsum", "Lorem... ipsum...", "speech"),
		line("", "The frozen flame in his forge is still waiting. Touch it.", "action"),
	]

static func forge_flame() -> Array:
	return [
		line("", "The flame is frozen mid-lick. One moment, held so long it has gone cold.", "action"),
		line("", "Far inside it, small as a coin, a boy is swinging a hammer.", "action"),
		line("", "You hold up the lantern. The flame leans toward the light, as if it has been waiting for someone to ask.", "action"),
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

# ---- The Blacksmith's Regret (Garrick's memory) -------------------------------
const MEMORY_INTRO := "Inside the flame, it is always the same afternoon."
const MEMORY_SHARD_NARRATION: Array[String] = [
	"One memory held up to the light. The voice is quieter.",
	"Two. The forge is beginning to thaw at the edges.",
	"Three.",
]
const MEMORY_SWORD_NARRATION := "The memory lets go of you gently, the way a hand lets go of a hand."
const MEMORY_OBJECTIVE := "Hold up the memories: %d / 3"

static func _y(text: String) -> Dictionary:
	return line("Young Garrick", text, "speech", "", Palette.CYAN_DEEP)

static func _wren(text: String) -> Dictionary:
	return line("Wren", text, "speech", "", Palette.CYAN_DEEP)

static func _critic(text: String, cue: String = "") -> Dictionary:
	return line("The Critic", text, "speech", cue, Palette.CRITIC_RED)

static func boss_intro() -> Array:
	return [
		line("", "The air is cold and perfectly still. Sparks hang where they flew, each one wrapped in frost. Nothing here has moved in a very long time.", "action"),
		_critic("Derivative."),
		_critic("Overwrought. Overlong. A sword? How original."),
		line("", "The voice comes from a pool of red ink beside the anvil. It is rising.", "action"),
		line("", "Three memories glow on the high ground around the forge: small, and warm, and the voice is very loud. Hold them up to the light.", "action"),
	]

static func shard_memory(idx: int) -> Array:
	match idx:
		1:
			return [
				line("", "The shard sinks into the lantern's light, and the forge remembers.", "action"),
				_y("Crooked. Again."),
				_y("Twice I've bent it. The Author keeps writing me clumsy."),
				_wren("It looks like a river!"),
				_y("A river's not a sword, Wren."),
				_wren("Could be both."),
				line("", "Behind the memory the red voice shrieks DERIVATIVE, and for the first time it sounds a little afraid.", "action"),
			]
		2:
			return [
				line("", "Night. A small figure is awake in the dark, holding her blanket like a shield.", "action"),
				_wren("Garrick? Will you stay till I fall asleep?"),
				_y("Is it the thing under the bed again?"),
				_wren("It has teeth."),
				_y("Then I'll make you something. A sword."),
				_wren("Swords are for monsters."),
				_y("A hero's sword makes the dark afraid of her."),
				_wren("Then I'll hold it very tight."),
			]
		_:
			return [
				line("", "Dawn, nearly. The forge is loud and warm. A boy who has not slept brings the hammer down one last time.", "action"),
				_y("Come on. Third time."),
				line("", "The blade rings. It is not perfect. There is a slight, stubborn bend near the tip.", "action"),
				_y("...There."),
				_wren("...is it straight?"),
				_y("No. It's yours."),
				line("", "In the dark above the forge, the red voice says very quietly, It was never good enough. And it does not sound like a critic. It sounds like a boy who was tired.", "action"),
			]

static func critic_finale() -> Array:
	return [
		_critic("...It's crooked."),
		_critic("It was always crooked. I told him so every night. Nobody should carry a crooked sword."),
		line("", "You raise the lantern. In its light the blade on the anvil is bent near the tip, and it is the most beautiful thing in the room.", "action"),
		_critic("...Oh."),
		_critic("She never once asked for it straight.", "dissolve"),
		line("", "The red ink lets go. It runs down the anvil and sinks into the floor like rain into a field.", "action"),
	]

static func memory_sword() -> Array:
	return [
		line("", "The sword is small, and plain, and a little crooked. It is warm, as if someone has only just let go of it.", "action"),
		line("", "Far above the frozen flame, an old man is holding a hammer and does not know why. You know why now.", "action"),
	]
