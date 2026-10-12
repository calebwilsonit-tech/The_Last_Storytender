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
const INTRO_WAKE := "Page forty-one. The pencil lines are still wet."
const INTRO: Array[String] = [
	"Once, there was a world that someone forgot to finish.",
	"And in its margins, a small drawing woke up.",
]
const INDEX_FIRST := "Every lantern post keeps a page of the Index: a bench to mend things on, a stall run by a voice, and a map of everywhere you have been."
const FALL_FIRST := "And so the Storytender learned that plot holes are, in fact, holes."
const CRUMPLED := "A crumpled page can be smoothed. That is the whole trick of it."
const SILENCE_WHISPER := "you are so tired.   rest.   it is only white, and white is gentle."
const RESTORED_NARRATION := "And the ink flowed back."
const RETURNED := "The sword is heavy the way a promise is heavy. Somebody should hear that it's been kept."
const PROOFREAD := "A mistake is not a monster. Sometimes it only wants someone to read it again."
const REDACTOR_HINT := "A black bar hangs across the way. Something is written underneath it. Light makes things matter: hold Q, or the right mouse button."
const REDACTOR_OPEN := "It was written there all along."
const BINDER_HINT := "You have a binder now. Press {inventory} to open it, and wear what Garrick gave you."
const REDACTION_NOTICED := "The Redaction has noticed you."
const SWORD_NARRATION := "It was never a weapon. It was a promise somebody made to the dark."

# ---- Signs -------------------------------------------------------------------
static func tutorial_sign() -> Array:
	return [
		line("", "{move} to walk.   {interact} to speak, or to pick up what was forgotten.", "sign"),
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
	return [
		line("Lorem Ipsum", "Dolor sit... amet? Amet.", "speech"),
		line("", "A storybook lies open at his feet. Whatever he was reading, he has been standing here since.", "action"),
	]

static func pip_restored() -> Array:
	return [
		line("Pip", "I found a word in the sky. It said 'Once'. Do you think it's a good one?", "speech"),
		line("Pip", "I'm not going to read ahead. Not this time. I'm going to find out the slow way.", "speech"),
	]

static func maud_ghost() -> Array:
	return [
		line("Lorem Ipsum", "Consectetur... adipiscing...", "speech"),
		line("", "She is standing next to a cold oven, hands curled around nothing, as if holding a loaf that was never there.", "action"),
	]

static func maud_restored() -> Array:
	return [
		line("Maud", "Don't tell the Narrator I gave you the heel. It's the best part.", "speech"),
		line("Maud", "Come by at dinner. There's always a chair now.", "speech"),
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
const FORGE_OBJECTIVES: Array[String] = [
	"The gate is cold and shut. Leave a memory of yourself standing on the plate ({echo}).",
	"Two plates, one of you. Remember twice.",
	"The watch is awake. Give it something to look at.",
]
const FORGE_GATE_OPEN := "Someone is still standing there, in the past, holding the door."

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

const CRITIC_FIGHT_OBJECTIVE := "Strike the Critic with the Quill. Hit its words in the air to rewrite them and send them back."

static func critic_reckoning() -> Array:
	return [
		line("", "The red ink stops being a voice. It pulls itself together into something with edges, and the edges are pointed at you.", "action"),
		_critic("Fine. FINE. You remembered. Do you think that makes it GOOD?"),
		line("", "It is still the Critic, and it is still very loud. But you held up what it was built to drown out, and now it has a shape, and shapes can be struck. Raise the Quill.", "action"),
	]

const FORGE_SWORD_OBJECTIVE := "Something small and crooked is lying on the floor ahead. Take it."

static func forge_sword_start() -> Array:
	return [
		line("", "A sword lies in the first room, small and plain and a little crooked, as if somebody put it down for a moment and never came back.", "action"),
		line("", "It is warm. It does not feel like a weapon. It feels like something that was meant to be carried out of here. Take it, and keep it safe.", "action"),
	]

static func memory_sword() -> Array:
	return [
		line("", "The sword is small, and plain, and a little crooked. It is warm, as if someone has only just let go of it.", "action"),
		line("", "Far above the frozen flame, an old man is holding a hammer and does not know why. You know why now.", "action"),
	]

# ---- Garrick's lesson ----------------------------------------------------------
static func garrick_lesson_start() -> Array:
	return [
		line("Garrick", "You've got a lantern. Good. A lantern is how you tell the dark what matters.", "speech"),
		line("Garrick", "But light doesn't swing back. For that...", "speech"),
		line("", "He sets a feather on the anvil and takes the hammer to its nib. Four clean strikes. No bending.", "action"),
		line("Garrick", "A Quill. Not a sword. A sword ends things. This one rewrites them.", "speech"),
		line("Garrick", "Go on. Hit the dummy. Three times. Don't think about whether it's pretty.", "speech"),
	]

static func garrick_lesson_hint(step: int) -> Array:
	match step:
		1:
			return [line("Garrick", "The dummy, little scribble. Click, or J. It won't hit back. That's the whole appeal.", "speech")]
		2:
			return [line("Garrick", "Now run at nothing and run away from it. Shift. A step before the blow lands is worth ten after.", "speech")]
		_:
			return [line("Garrick", "Hold your light up. Q, or the right mouse button. Let it say what matters.", "speech")]

static func garrick_lesson_end() -> Array:
	return [
		line("Garrick", "Not bad. Crooked, but not bad.", "speech"),
		line("Garrick", "Out there, the Redaction is sending Errors. Bares, mostly. Poor beasts. Spelling mistakes with teeth.", "speech"),
		line("Garrick", "You can cut them down. Or you can hold your light on them until they remember what they were.", "speech"),
		line("Garrick", "The second way takes longer. It's usually worth it.", "speech"),
		line("Garrick", "Here. Hardcover. Heavy. It'll keep the Errors from reading you too closely.", "speech"),
		line("Garrick", "And these: eraser crumbs. Throw them at anything you'd rather not read.", "speech"),
	]

# ---- Pip's memory: The Last Page --------------------------------------------------
const PIP_BOOK_HINT := "A storybook lies open on the ground, its last page torn out. The words on the pages keep rearranging themselves. You will need something that can rewrite them."
const PIP_INTRO := "Every page is bright and printed. Every sentence is waiting to be true."
const PIP_STONE_HINT := "A sentence stands here with one word that can change. Strike it with the Quill, or press {interact}."
const PIP_BRIDGE_HOLDS := "The bridge held. All it needed was one different word."
const PIP_WOLVES_ASLEEP := "The wolves are asleep. The sentence will not stay true forever."
const PIP_WOLVES_WAKE := "The word wears off. The wolves stir."
const PIP_GATE_OPEN := "Open. Sometimes the whole story is waiting on a single word."
const PIP_TOWER_HINT := "A tower of pages, with black bars across the stairs. Light shows what is written underneath."
const PIP_DOOR_LOCKED := "A door made of bound pages, with a slot the shape of a missing page."
const PIP_OBJECTIVES: Array[String] = [
	"Strike the word with your Quill (or press {interact}) to rewrite the sentence",
	"Get past the wolves, and rewrite the gate",
	"Climb the tower and find the Torn Page",
	"Strike the book while it reads aloud: %d / 5",
	"Turn the page with Pip",
]
const PIP_REWRITE_NARRATION: Array[String] = [
	"The first sentence changed. The Spoiler stammers, a book that did not expect to be edited.",
	"Two. It was so sure.",
	"Three. Its words are getting smaller.",
	"Four. \"Don't,\" it says, in a voice that sounds like a boy.",
	"Five.",
]

static func _sp(text: String, cue: String = "") -> Dictionary:
	return line("The Spoiler", text, "speech", cue, Palette.GLITCH)

static func _pip(text: String) -> Dictionary:
	return line("Pip", text, "speech", "", Palette.CYAN_DEEP)

static func pip_book_enter() -> Array:
	return [
		line("", "The book is open to a page with nothing on it. The pages around it shiver, as if someone has been holding their breath.", "action"),
		line("", "You lean in. The lantern's light falls into the white space, and the white space falls into you.", "action"),
	]

static func pip_page_found() -> Array:
	return [line("", "The last page of the story, torn out and folded very small, as if someone were hiding it from himself.", "action")]

static func pip_door_fit() -> Array:
	return [
		line("", "You slide the Torn Page into the slot. It fits exactly. Of course it does. He knows how this story ends.", "action"),
		line("", "The door of bound pages swings open onto a vast white room.", "action"),
	]

static func pip_boss_intro() -> Array:
	return [
		line("", "The room is one enormous open book, its pages stacked like stairs. At the far end a small boy sits with his hands pressed over his eyes.", "action"),
		_sp("The knight dies."),
		_sp("The dragon wins. The kingdom burns. Everyone you love is gone by chapter nine."),
		_pip("I didn't want to know! I just wanted to see if it was okay!"),
		_sp("It is not okay. I have read the end. I read it for you."),
		line("", "Its words are enormous and they are not lying: when it says the floor will fall, the floor falls. But they are written in ink, and ink can be rewritten.", "action"),
	]

const SPOILER_FIGHT_OBJECTIVE := "The Spoiler is on the page now. Strike it with the Quill. Striking it while it reads a sentence rewrites that sentence and wounds it badly."

static func spoiler_reckoning() -> Array:
	return [
		line("", "The book sinks out of the air until it hangs at the height of your eyes. Its pages are shaking. It has run out of things to say that you haven't already changed.", "action"),
		_sp("...Fine. If you're so sure of the ending, come and take it."),
		line("", "It is still the Spoiler, and the next spoiler is already loading. But it is made of paper now, and paper can be written on. Strike it, and when it stops to read, strike harder.", "action"),
	]

static func pip_finale() -> Array:
	return [
		_sp("...You can't just change it."),
		line("", "It sounds younger now. Its pages are shaking.", "action"),
		_sp("If I don't tell him how it ends, he'll find out alone. That's worse. That's always worse."),
		line("", "You hold up the lantern. The torn page drifts down out of the book and lands in your hand, blank.", "action"),
		line("", "It was never torn out. It was never written. That was the whole secret: there was never a last page, only a boy who was afraid to find out.", "action"),
		_sp("...Oh.", "dissolve_spoiler"),
	]

static func pip_resolution() -> Array:
	return [
		_pip("Is it... is it over?"),
		line("", "He is small, and he is gripping the book so tightly his knuckles have gone pale. The page in his lap is blank.", "action"),
		_pip("I read the last page. I read it before anyone could tell me it was safe to."),
		_pip("And after that nothing felt like it mattered, because I already knew how it ended."),
		line("", "You hold out the lantern. You can't tell him how it ends. You don't know. Nobody does.", "action"),
		_pip("...That's scary."),
		line("", "It is. It is also the only way a story gets to keep going.", "action"),
		_pip("Will you stay while I turn it?"),
		line("", "You stay.", "action"),
		line("", "He turns the page. Nothing terrible happens. A new sentence begins to write itself, slowly, in handwriting that looks a great deal like his.", "action"),
	]

static func pip_restoration() -> Array:
	return [
		line("Lorem Ipsum", "Dolor... sit... ", "speech"),
		_pip("...Who are you?"),
		_pip("Oh. You're the doodle from the page."),
		_pip("I was reading a book and then I wasn't. It was scary. But I think I finished a chapter."),
		_pip("Mister Garrick says you can swing a quill. Will you show me how to hold one? I want to write the next page myself."),
		line("", "He is smiling at the sky, where the underside of the next page is very faintly beginning to show text. It is not an ending. It is a sentence that starts with \"Once.\"", "action", "restore_pip"),
	]

# ---- Maud's memory: The Empty Table ------------------------------------------------------
const MAUD_OVEN_HINT := "The oven is cold. Not just unlit: cold the way a room is cold when everyone has left it. Something else has to teach your Quill a new edge before you can reach what is in the ashes."
const MAUD_INTRO := "Flour on every surface. The smell of bread that is not baking."
const MAUD_OBJECTIVES: Array[String] = [
	"Press {style_underline} (Underline), then strike the word BREAD with your Quill",
	"Make SALT heavy (2: Bold) and send it sliding (3: Italic) onto the plate",
	"Dough cannot be rushed. Wait for it to rise, then underline it. Your Lantern's warmth helps",
	"Seat the guests: %d / 6.  Hold your Lantern on them to lead them to a chair",
	"Sit with Maud",
]
const MAUD_BREAD_DONE := "Underlined, the word stops being a word. It becomes somewhere to stand."
const MAUD_SLID := "Italic: it leans, and everything that leans eventually lands somewhere."
const MAUD_PLATE := "Bold. Heavy enough to matter."
const MAUD_DOUGH_BURNED := "It collapsed. It was not ready. Try again, and this time wait."
const MAUD_DOUGH_READY := "It rose."
const MAUD_DOUGH_HINT := "Some things cannot be rewritten. They can only be waited for."
const MAUD_SEATED: Array[String] = [
	"One chair filled.", "Two.", "Three. The room has begun to warm.",
	"Four. You can hear someone laughing, a long way off.", "Five.", "Six.",
]

static func _maud(text: String) -> Dictionary:
	return line("Maud", text, "speech", "", Palette.CYAN_DEEP)

static func _table(text: String, cue: String = "") -> Dictionary:
	return line("The Empty Table", text, "speech", cue, Palette.CYAN_DEEP.darkened(0.2))

static func maud_oven_enter() -> Array:
	return [
		line("", "You look into the oven. Cold ashes. In the middle of them, one very small light is still burning.", "action"),
		line("", "You hold up the lantern, and the light in the ashes leans toward it.", "action"),
	]

static func maud_format_grant() -> Array:
	return [
		line("", "The Quill hums. It has learned a new edge: it can format.", "action"),
		line("", "Press {style_underline}, {style_bold} or {style_italic} to choose Underline, Bold or Italic, then strike a word. Words in this kitchen have weight.", "action"),
	]

static func maud_boss_intro() -> Array:
	return [
		line("", "A long table, set for six, with six empty chairs. The room is cold in the way a kitchen is cold when it has stopped being used.", "action"),
		_table("Set for six."),
		_table("Nobody is coming."),
		line("", "Shapes stand in the dark at the edges of the room, the outlines of people who sat here once. Warmth is an invitation. Hold your lantern up to them and they will come.", "action"),
		line("", "Every so often the cold will sweep across the floor and clear it. Anything heavy will shelter whatever stands behind it.", "action"),
	]

const MAUD_FIGHT_OBJECTIVE := "The Cold Shoulder always turns away from you. Circle behind it and strike with the Quill. Your Lantern's warmth slows its turning."

static func maud_reckoning() -> Array:
	return [
		line("", "Six guests, six chairs. And from the dark behind the last chair, something rises to its feet: tall, hunched, glittering, with one great shoulder turned toward the table.", "action"),
		_table("...You came. All of you came. Then why does it feel like I'm being turned away?"),
		line("", "It is the thing she was afraid of all along: the cold shoulder. It will always show you its side. But anything that turns away has a back, and the guests are warm, and so are you.", "action"),
	]

static func maud_finale() -> Array:
	return [
		_table("...It was set for six. It was always set for six."),
		line("", "The shapes at the table are not guests anyone could name. They are the outlines of people who were loud, and hungry, and late. They are warm now.", "action"),
		_table("I thought if no one came, it meant no one had ever needed me."),
		line("", "You hold the lantern up to the long table. It is only a table. A table is just a place where people are invited.", "action"),
		_table("...Is the bread still good?", "dissolve_table"),
	]

static func maud_resolution() -> Array:
	return [
		_maud("I stopped baking the day the last chair stayed empty."),
		_maud("Funny thing. I never lost the recipe. I lost the reason."),
		line("", "She puts her hands into the flour. It is warm. It has been warm the whole time.", "action"),
		_maud("Flour, water, salt, patience... and someone to feed."),
		line("", "She looks across the table at you.", "action"),
		_maud("Sit. You look like you could use a loaf."),
	]

static func maud_restoration() -> Array:
	return [
		line("Lorem Ipsum", "Consectetur...", "speech"),
		_maud("...Oh. The oven's warm."),
		_maud("I had a whole table of people in my head just now. All of them talking at once. I'd forgotten how loud it was. How good."),
		_maud("Here. Take these. A loaf is for carrying to someone who needs it. That's the only rule I've ever had."),
		line("", "She is already kneading something. The smell of bread spreads out across the square like a held breath let go.", "action", "restore_maud"),
	]

# ---- The Scissor-Man ("Cut Content"): Thistledown's Editor --------------------------------
const RIFT_NARRATION := "With the last of them remembered, something in the sky begins to cut. A seam opens in the middle of the square."
const SCISSOR_OBJECTIVES: Array[String] = [
	"Pick up a clipping (strike it with the Quill), then press {paste} to paste it onto his cut line",
	"Strike him while his shears are jammed!",
	"Hold up the lantern",
]
const SCISSOR_FIRST_PASTE := "Patched paper will not be cut. Paste a clipping onto the line before he cuts it, and his shears will jam."
const SCISSOR_JAM := "The shears are caught in the patch. Now!"
const SCISSOR_PHASE: Array[String] = [
	"",
	"He is cutting wider, and he has begun to cut out little copies of the things that hurt.",
	"Two cuts at once. He does not enjoy this, but he cannot stop.",
]
const PUBLISHED := "The Prologue is written. Whatever comes next, it has somewhere to begin."

static func _scissor(text: String, cue: String = "") -> Dictionary:
	return line("The Scissor-Man", text, "speech", cue, Color("7a8499"))

const LORE := {
	"edge_1": "A margin note, very small: 'Start here. It gets better. (the writer, 3 a.m.)'",
	"edge_2": "The page ends in a clean, white edge. Someone has drawn a very small door in the margin, crossed it out, and drawn it again.",
	"meadow_1": "A stone with a sentence carved into it: 'It was a bright, cold day in April, and the clocks were striking thirteen.' Underneath, in pencil: 'Too familiar?'",
	"meadow_2": "'Show, don't tell,' says the stone. Then it just sits there, showing.",
	"meadow_3": "A scrap of map is tucked under this stone. It says HERE BE PLOT. The rest has been rubbed out.",
	"orchard_1": "Every apple on this tree is a half-written idea. They taste of almost.",
	"orchard_2": "A name is scratched into the bark: WREN. Then a heart. Then a careful correction: 'sister, not that kind of heart.'",
	"orchard_3": "A plaque: 'First drafts are allowed to be bad.' Someone has added: 'This one was.'",
	"wells_1": "The ink in these wells never dries. Don't stare into them too long. They tend to take notes.",
	"wells_2": "A wishing coin sits on the rim. It is the letter Q. It did not get what it wished for.",
	"hollow_1": "Down here the footnotes live. They are small, and numbered, and a little bitter about it.",
	"glade_1": "A glade nobody wrote on purpose. It happened in the margins, between two sentences, and it stayed.",
	"ridge_1": "A ruined mill. Its sails are the pages of an unfinished manuscript, still turning in a wind that is not there.",
	"ridge_2": "From up here you can see the whole town, drafted in pencil. Somebody is going to ink it one day. Maybe you.",
	"graves_1": "HERE LIES CHAPTER 3. (Cut for length.)",
	"graves_2": "HERE LIES THE SIDEKICK WHO WAS ONLY EVER CALLED 'HE'. HE WAS MORE THAN THAT.",
	"graves_3": "HERE LIES A FLASHBACK. IT WILL BE BACK.",
	"graves_4": "HERE LIES THE ORIGINAL ENDING. NO ONE ASKED FOR IT. IT WAITED ANYWAY.",
	"gate_1": "A sign on the gate: 'The next chapter is not yet written. Check back when the last one is finished.' Underneath, smaller: 'Please.'",
}

static func lore(id: String) -> Array:
	return [line("", LORE.get(id, "The stone is blank, and a little embarrassed about it."), "action")]

static func gate_locked() -> Array:
	return [
		line("", "The Margin Gate is shut, a wall of pages bound with ribbon. Its lock is shaped like a full stop.", "action"),
		line("", "Whatever lies beyond cannot be opened until the Prologue is finished: Thistledown still has an Editor.", "action"),
	]

static func gate_renown(have: int, need: int) -> Array:
	return [
		line("", "The ribbon on the Margin Gate stays tied. A small tag hangs from it: 'Not enough people know your name yet.'", "action"),
		line("", "Renown %d / %d. Beat Errors, open chests, solve riddles, light posts, explore: any of it counts. The page remembers what you do." % [have, need], "action"),
	]

static func gate_open() -> Array:
	return [
		line("", "The ribbon unties itself. The pages part like a curtain, and beyond them is white, and a faint sound like someone, far away, turning a page.", "action"),
		line("", "There is nothing there yet. But there will be.", "action"),
	]

const CHEST_LINES := [
	"Inside: something that was cut from a very early draft and has been waiting to be useful.",
	"The lid creaks like a page turning. Whoever hid this had good taste and poor handwriting.",
	"A tidy little hoard, labeled in a hand you almost recognise.",
	"It was never locked, only ignored.",
	"There is a note inside: 'if you found this, the story is going better than I feared.'",
]
const RIDDLE_OPEN := "The sentence settles into place, and the gate remembers it was always unlatched."

## Shown the first time each new kind of Error wanders into range (keys are Enemy.Kind values).
const ENEMY_INTRO := {
	2: "A Run-on drags itself across the page, leaving a sticky trail behind it. Shine the Lantern on it until it learns when to stop.",
	3: "A Dangling Modifier hangs from nothing, flinging words from a distance. Keep moving, and light it until it clings to something else.",
	4: "A Censor stands with a black bar across its front. The Quill will not pierce it. Light the bar until it fades, or go around behind.",
	5: "Three dots blink in and out around you. Light pins them in place, and then they can be cut.",
}

static func echo_grant() -> Array:
	return [
		line("", "The lantern remembers more than you do. Press {echo}, walk somewhere, and press {echo} again: a ghost of you will play it back and then stand where it ended.", "action"),
		line("", "A remembered you has weight. It can hold a plate down, and the curious are drawn to it. You can keep two.", "action"),
	]

static func forge_look(idx: int) -> Array:
	match idx:
		0:
			return [
				line("", "A small girl asleep by the cold hearth, under a blanket made of oven mitts. She would not go to bed unless the forge was lit.", "action"),
				line("", "'It's the only thing in the house that's awake,' she told him. He lit it every night after that, even when there was nothing to forge.", "action"),
			]
		1:
			return [
				line("", "Every tool on the bench has a name scratched into the handle. Hammer: Gerald. Tongs: Also Gerald. Chisel: He ran out of names around week three.", "action"),
				line("", "Under the vise, a note in a child's writing: 'You are allowed to stop for today.' It is signed with a drawing of a very small sword.", "action"),
			]
		_:
			return [
				line("", "The night watch was meant to be a grown man with a lantern. It was a boy with a hammer and a stool, and he fell asleep every night at the third hour.", "action"),
				line("", "Every night, someone put a blanket over him and told nobody. He never worked out who. He knew, though. He just never said.", "action"),
			]

static func scissor_rift_enter() -> Array:
	return [
		line("", "The seam is not dark. It is white, the white of a page with nothing on it. At its edges the paper has been cut so cleanly it hums.", "action"),
		line("", "You hold up the lantern and step through.", "action"),
	]

static func scissor_boss_intro() -> Array:
	return [
		line("", "A long green mat runs out under a wall of black. The air smells of cut paper. Something enormous stands in the middle of it, unfinished: half colored, half sketch, with a pair of shears where its hands should be.", "action"),
		_scissor("Cut for pacing."),
		_scissor("Cut for length. Cut for 'it doesn't serve the story.'"),
		_scissor("Everything has a page count. Yours is up."),
		line("", "Every cut leaves a clipping behind. Strike a clipping to pick it up, and press {paste} to paste it back. Paper that has been patched, scissors will not cut.", "action"),
	]

static func scissor_finale() -> Array:
	return [
		_scissor("...That isn't how it works. You can't just put it back."),
		line("", "The clippings are all around him now, hundreds of them, small cut-out scenes with their edges still sharp. In one, a young man hammers a blade straight and then does not. In another, a boy tears out a page. In another, a woman sets a table for six, and then for one.", "action"),
		_scissor("I cut them to keep the story short. Every one of them was somebody's favorite part."),
		line("", "You hold up the lantern. In its light the clippings turn over, one at a time. Every one has a back side, and on every back side something has been written: kept.", "action"),
		_scissor("...Kept.", "restore_town"),
		line("", "The shears fall open and are only shears. Without them his hands are just hands: a tailor's, thimble-dented and tired.", "action"),
		line("Wick", "My name's Wick. I used to mend things. Somewhere along the way I got confused and started cutting them out instead.", "speech", "", Palette.CYAN_DEEP),
		line("Wick", "Take this. It's the only thing I ever made that I didn't have to cut anything off to finish.", "speech", "", Palette.CYAN_DEEP),
	]
