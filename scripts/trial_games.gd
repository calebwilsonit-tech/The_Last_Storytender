class_name TrialGames
extends RefCounted
## The Vault Trials: small word puzzles that guard the chests in the overworld. Each game is
## quick (30 to 90 seconds), has its own rules, and scales with a difficulty tier 1 to 4:
## the harder the trial, the better the prize. All games share one small interface so the
## VaultTrial screen can host any of them.

const WORDS := "bake bale ball band bane bank bare bark barn base bash bass bath bead beak beam bean bear beat beef been beer bell belt bend bent best bike bill bind bird bite blow blue boat body boil bold bolt bond bone book boom boot bore born boss both bowl bulk bull bump burn bush busy cage cake call calm came camp card care cart case cash cast cave cell chat chin chip city clad clam clap claw clay clip club clue coal coat code coil coin cold come cook cool cope copy cord core corn cost cove crew crop crow cube cure curl cute dale dame damp dare dark dart dash data date dawn dead deaf deal dear deck deed deep deer dell dent deny desk dial dice diet dime dine dirt disc dish dive dock dole doll dome done doom door dose dove down drag draw drew drip drop drum duck dull dune dusk dust duty each earn ease east easy edge else even ever evil face fact fade fail fair fake fall fame fare farm fast fate fear feed feel feet fell felt fern file fill film find fine fire firm fish fist five flag flat flaw flea fled flew flip flow foam fold folk fond font food fool foot ford fork form fort foul four free frog from fuel full fund gain game gate gave gear gift girl give glad glow glue goat gold gone good gown grab gray grew grid grin grip grow gulf gust hail hair half hall hand hang hard hare harm hate have hawk head heal heap hear heat heel held hell help herb herd here hero hide high hill hint hire hold hole home hood hook hope horn hose host hour huge hunt hurt idea inch iron isle item jade jail jest join joke jump junk jury just keen keep kept kick kill kind king kiss knee knew knit knob knot know lace lack lady laid lake lamb lamp land lane lark last late lawn lazy lead leaf leak lean leap left lend lens less lick life lift like lily lime line link lion list live load loaf loan lock loft long look loop lord lose loss lost loud love luck lump lung made mail main make male mall mane many mare mark mask mass mast mate math maze meal mean meat meek meet melt memo mend menu mere mesh mild mile milk mill mind mine mint miss mist moan moat mode mole moon more moss most moth move much mule must myth nail name navy near neat neck need nest news next nice nine node none noon nose note noun oath obey once only open oven over pace pack page paid pail pain pair pale palm pane park part pass past path pave peak pear peat peck peel peer pest pick pier pile pine pink pipe plan play plot plow plum pole poll pond pony pool poor pork port pose post pour pray pull pump pure push quit race rack raft rage raid rail rain rake ramp rank rare rate read real reap rear reed reel rely rent rest rice rich ride ring rise risk road roar robe rock rode role roll roof room root rope rose rude ruin rule rush rust sack safe sage said sail sake sale salt same sand sang sank save seal seam seat seed seek seem seen sell send sent shed ship shoe shop shot show shut sick side sigh sign silk sing sink site size skin skip slam slap slid slim slip slot slow snow soak soap soar sock soft soil sold sole some song soon sore sort soul soup sour span spin spit spot star stay stem step stir stop such suit sure swam swan swim tail take tale talk tall tame tank tape task team tear tell tend tent term test text than that them then they thin this thus tide tidy tile till time tiny tire toad told toll tomb tone took tool tore torn toss tour town trap tray tree trim trip true tube tuck tune turn twin type ugly unit upon urge used vain vale vary vast veil vein verb very vest view vine void vote wade wage wait wake walk wall wand want ward warm warn wash wave weak wear weed week well went were west what when whom wide wife wild will wind wine wing wink wipe wire wise wish with wolf wood wool word wore work worm worn wrap yard yarn year yell zero zone"

const GAME_NAMES := {
	"proofread": "Proofread", "sort": "Alphabetize", "anagram": "Unscramble", "sentence": "Rebuild the Sentence",
	"ladder": "Word Ladder", "typewriter": "Typewriter Trial", "rhythm": "Dictation Beat", "cipher": "Cipher Wheel",
}
## Which games can appear at which tier.
const BY_TIER := {
	1: ["proofread", "sort", "anagram"],
	2: ["proofread", "sort", "anagram", "sentence", "ladder"],
	3: ["sentence", "anagram", "ladder", "typewriter", "rhythm", "cipher"],
	4: ["ladder", "typewriter", "rhythm", "cipher", "sentence"],
}

## True when a controller is connected: the Typewriter then shows a letter grid (more time, more
## mistakes allowed). Real key presses still work in either mode.
static var pad_mode := false

static func make(kind: String, tier: int, seed_v: int) -> Base:
	var g: Base
	match kind:
		"proofread": g = Proofread.new()
		"sort": g = Sort.new()
		"anagram": g = Anagram.new()
		"sentence": g = SentenceGame.new()
		"ladder": g = Ladder.new()
		"typewriter": g = Typewriter.new()
		"rhythm": g = Rhythm.new()
		_: g = Cipher.new()
	g.kind = kind
	g.tier = tier
	g.rng.seed = seed_v
	g.setup()
	var bonus: int = GameState.attr("wit") / 8     # smarter Storytenders get extra tries
	g.tries += bonus
	g.max_tries += bonus
	return g

## Picks the game for a vault: the same vault always plays the same game. On a controller the
## typing game is skipped (real key presses still work with a pad connected).
static func pick(tier: int, seed_v: int, keyboard: bool) -> String:
	var opts: Array = (BY_TIER[tier] as Array).duplicate()
	return opts[absi(seed_v) % opts.size()]

# =============================================================================================
class Base extends RefCounted:
	var kind := ""
	var tier := 1
	var rng := RandomNumberGenerator.new()
	var tries := 3
	var max_tries := 3
	var message := ""
	var solved := false
	var failed := false
	var time_limit := 0.0        # > 0 for timed games
	var time_left := 0.0
	var rects: Array = []        # [{r: Rect2, i: int}] filled by draw, used for the mouse
	var shake := 0.0

	func setup() -> void:
		pass
	func help() -> String:
		return ""
	func title() -> String:
		return TrialGames.GAME_NAMES.get(kind, kind)
	func input(_ev: InputEvent) -> void:
		pass
	func click(pos: Vector2) -> void:
		for h: Dictionary in rects:
			if (h["r"] as Rect2).has_point(pos):
				click_index(int(h["i"]))
				return
	func click_index(_i: int) -> void:
		pass
	func tick(delta: float) -> void:
		shake = maxf(shake - delta, 0.0)
		if time_limit > 0.0 and not solved and not failed:
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				_fail("Out of time.")
	func draw(_ci: Control, _area: Rect2, _font: Font, _head: Font) -> void:
		pass
	func auto_solve() -> void:
		pass
	func lose_try(msg: String) -> void:
		tries -= 1
		shake = 0.35
		message = msg
		if tries <= 0:
			_fail("That was the last try.")
	func _fail(msg: String) -> void:
		failed = true
		message = msg
	func _win(msg: String = "Solved.") -> void:
		solved = true
		message = msg
	# drawing helper: a rounded tile
	func tile(ci: Control, font: Font, r: Rect2, text: String, fill: Color, edge: Color, size: int = 28, col: Color = Palette.INK) -> void:
		var off := Vector2(sin(shake * 60.0) * 6.0 * minf(shake * 3.0, 1.0), 0.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = edge
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		ci.draw_style_box(sb, Rect2(r.position + off, r.size))
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
		ci.draw_string(font, r.position + off + Vector2((r.size.x - ts.x) * 0.5, (r.size.y + ts.y * 0.62) * 0.5 - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, col)

# =============================================================================================
# Proofread: find the wrong word(s) in a sentence.
const PROOF := [
	["She went to the store to buy some milk and bread.", [[7, "bye"]]],
	["The knight drew his sword and charged at the dragon.", [[3, "drue"]]],
	["It was a bright, cold day in the middle of April.", [[7, "mid-dle"]]],
	["They said the old bridge would never hold their weight.", [[2, "sed"]]],
	["Every night she lit the lantern beside the window.", [[3, "lit"], [6, "beyond"]]],
	["The baker left warm bread on the table for the guests.", [[8, "gests"]]],
	["He didn't know weather the story would ever be finished.", [[3, "weather"]]],
	["Their was a small door hidden behind the bookshelf.", [[0, "Their"]]],
	["The ghost of the forge remembered its first sword.", [[2, "ghoast"]]],
	["A page turned slowly in the wind, then the next one followed.", [[5, "wynd"]]],
	["The tailor stitched the pages back together with gold thread.", [[4, "sticthed"], [8, "goal"]]],
	["She could here the quiet hum of the old machine.", [[2, "here"], [8, "mashine"]]],
	["Nobody remembered who had writen the last chapter.", [[4, "writen"]]],
	["The lantern flickerd twice and then went out completly.", [[2, "flickerd"], [7, "completly"]]],
	["He ate the whole loaf, there was nothing left to share.", [[8, "there"]]],
	["It's hard to finish a story when it's author is gone.", [[9, "it's"]]],
]
class Proofread extends Base:
	var words: PackedStringArray = []
	var bad: Array = []         # indices of wrong words
	var found: Dictionary = {}
	var cursor := 0
	var wrong_idx := {}
	func setup() -> void:
		max_tries = 3
		tries = 3
		var want := 1 if tier <= 1 else 2
		var pool: Array = []
		for e in TrialGames.PROOF:
			if (e[1] as Array).size() == want:
				pool.append(e)
		var e: Array = pool[rng.randi() % pool.size()]
		words = (e[0] as String).split(" ")
		for fix: Array in e[1]:
			words[int(fix[0])] = fix[1]
			bad.append(int(fix[0]))
		message = ""
	func help() -> String:
		return "Find the %d wrong word%s. Pick a word with the arrows and confirm." % [bad.size(), "" if bad.size() == 1 else "s"]
	func input(ev: InputEvent) -> void:
		var d := MenuInput.nav(ev)
		if d.x != 0:
			cursor = (cursor + d.x + words.size()) % words.size()
		elif d.y != 0:
			cursor = clampi(cursor + d.y * 4, 0, words.size() - 1)
		elif MenuInput.accept(ev):
			click_index(cursor)
	func click_index(i: int) -> void:
		cursor = i
		if found.has(i) or wrong_idx.has(i):
			return
		if bad.has(i):
			found[i] = true
			message = "Found one." if found.size() < bad.size() else ""
			if found.size() >= bad.size():
				_win("All fixed.")
		else:
			wrong_idx[i] = true
			lose_try("That one is fine.")
	func auto_solve() -> void:
		for i in bad:
			click_index(i)
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		rects.clear()
		var x := a.position.x
		var y := a.position.y + 40.0
		for i in words.size():
			var w := words[i]
			var ts := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30)
			if x + ts.x + 24.0 > a.end.x:
				x = a.position.x
				y += 60.0
			var r := Rect2(x, y, ts.x + 20.0, 46.0)
			var fill := Color("f6efd8")
			var edge := Palette.INK_BROWN
			if found.has(i):
				fill = Color("bfe3b4")
			elif wrong_idx.has(i):
				fill = Color("e6c2bd")
			if i == cursor:
				edge = Palette.GOLD.darkened(0.15)
			tile(ci, font, r, w, fill, edge, 30)
			rects.append({"r": r, "i": i})
			x += r.size.x + 10.0

# =============================================================================================
# Sort: put the words in alphabetical order by moving one at a time.
const SORTWORDS := ["ankle", "bridge", "candle", "dragon", "ember", "forest", "garden", "harbor", "island", "jewel", "kettle", "lantern", "marble", "needle", "orchard", "paper", "quill", "river", "shadow", "tower", "umbrella", "violin", "window", "yonder", "zephyr"]
class Sort extends Base:
	var items: Array = []
	var cursor := 0
	var lifted := false
	var moves := 0
	func setup() -> void:
		var n := 4 if tier <= 1 else 6
		var pool: Array = TrialGames.SORTWORDS.duplicate()
		for i in pool.size():
			var j := rng.randi() % pool.size()
			var t = pool[i]
			pool[i] = pool[j]
			pool[j] = t
		items = pool.slice(0, n)
		while _sorted():
			items.reverse()
	func help() -> String:
		return "Alphabetical order, A first. Confirm to pick a word up, move it with the arrows, confirm to put it down."
	func _sorted() -> bool:
		for i in items.size() - 1:
			if (items[i] as String) > (items[i + 1] as String):
				return false
		return true
	func input(ev: InputEvent) -> void:
		var d := MenuInput.nav(ev)
		if d.x != 0:
			var n := clampi(cursor + d.x, 0, items.size() - 1)
			if lifted and n != cursor:
				var t = items[cursor]
				items[cursor] = items[n]
				items[n] = t
				moves += 1
			cursor = n
			if not lifted and _sorted():
				_win("Sorted in %d moves." % moves)
		elif MenuInput.accept(ev):
			lifted = not lifted
			if not lifted and _sorted():
				_win("Sorted in %d moves." % moves)
	func click_index(i: int) -> void:
		if lifted:
			var t = items[cursor]
			items.remove_at(cursor)
			items.insert(i, t)
			moves += 1
			cursor = i
			lifted = false
			if _sorted():
				_win("Sorted in %d moves." % moves)
		else:
			cursor = i
			lifted = true
	func auto_solve() -> void:
		items.sort()
		_win()
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		rects.clear()
		var w := minf(150.0, (a.size.x - 10.0 * items.size()) / items.size())
		var total := items.size() * (w + 10.0) - 10.0
		var x := a.position.x + (a.size.x - total) * 0.5
		for i in items.size():
			var up := 24.0 if (i == cursor and lifted) else 0.0
			var r := Rect2(x, a.position.y + 80.0 - up, w, 60.0)
			tile(ci, font, r, items[i], Color("f6efd8") if not (i == cursor and lifted) else Color("f4e6a0"), Palette.GOLD.darkened(0.15) if i == cursor else Palette.INK_BROWN, 26)
			rects.append({"r": r, "i": i})
			x += w + 10.0
		ci.draw_string(font, a.position + Vector2(0, 200), "Moves: %d" % moves, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(Palette.INK, 0.6))

# =============================================================================================
# Unscramble: build the word from its letters.
const ANAGRAMS := {
	4: [["PAGE", "a leaf of a book"], ["TALE", "a story"], ["BOOK", "you are inside one"], ["LINE", "poems are made of these"], ["WORD", "smaller than a sentence"], ["PLOT", "what happens next"], ["EDIT", "to fix what was written"], ["TYPE", "to press keys"]],
	5: [["PROSE", "writing that is not poetry"], ["VERSE", "a line of poetry"], ["SCENE", "part of a play"], ["THEME", "the big idea"], ["NOVEL", "a long story"], ["TITLE", "a book's name"], ["DRAFT", "a first attempt"], ["QUILL", "an old pen"]],
	6: [["AUTHOR", "writes the book"], ["MARGIN", "the empty edge of a page"], ["SCRIPT", "words for actors"], ["EDITOR", "fixes the author's mistakes"], ["PENCIL", "writes in graphite"], ["BINDER", "holds pages together"], ["ERASER", "undoes a pencil"], ["STANZA", "a group of lines"]],
	7: [["CHAPTER", "a part of a book"], ["LIBRARY", "a room of books"], ["VOLUMES", "many books"], ["HEADING", "a title above a section"], ["WRITING", "putting words down"], ["READERS", "they open the book"]],
	8: [["PROLOGUE", "before the story begins"], ["EPILOGUE", "after the story ends"], ["FOOTNOTE", "a note at the bottom of a page"], ["SENTENCE", "words that make a complete thought"], ["BOOKMARK", "keeps your place"]],
}
class Anagram extends Base:
	var answer := ""
	var hint := ""
	var letters: Array = []        # shuffled letters
	var picked: Array = []         # indices into letters, in order
	var cursor := 0
	func setup() -> void:
		var n := 4 if tier <= 1 else (6 if tier == 2 else 8)
		if tier <= 1:
			n = 4 + rng.randi() % 2
		elif tier == 3:
			n = 7 + rng.randi() % 2
		var e: Array = TrialGames.ANAGRAMS[n][rng.randi() % (TrialGames.ANAGRAMS[n] as Array).size()]
		answer = e[0]
		hint = e[1]
		for c in answer:
			letters.append(c)
		var tries_shuffle := 0
		while tries_shuffle < 20:
			for i in letters.size():
				var j := rng.randi() % letters.size()
				var t = letters[i]
				letters[i] = letters[j]
				letters[j] = t
			if "".join(letters) != answer:
				break
			tries_shuffle += 1
	func help() -> String:
		return "Unscramble the word. Clue: %s. Pick letters in order (or just type them). Undo takes the last one back." % hint
	func _word() -> String:
		var w := ""
		for i in picked:
			w += letters[i]
		return w
	func input(ev: InputEvent) -> void:
		var d := MenuInput.nav(ev)
		if d.x != 0:
			cursor = (cursor + d.x + letters.size()) % letters.size()
		elif MenuInput.accept(ev):
			click_index(cursor)
		elif ev.is_action_pressed("use_item") or (ev is InputEventKey and ev.pressed and ev.keycode == KEY_BACKSPACE):
			if not picked.is_empty():
				picked.pop_back()
		elif ev is InputEventKey and ev.pressed and ev.unicode > 0:
			var ch := String.chr(ev.unicode).to_upper()
			for i in letters.size():
				if letters[i] == ch and not picked.has(i):
					click_index(i)
					break
	func click_index(i: int) -> void:
		if picked.has(i):
			return
		picked.append(i)
		cursor = i
		if picked.size() >= letters.size():
			if _word() == answer:
				_win("Yes: %s." % answer)
			else:
				picked.clear()
				lose_try("Not quite.")
	func auto_solve() -> void:
		picked.clear()
		for c in answer:
			for i in letters.size():
				if letters[i] == c and not picked.has(i):
					picked.append(i)
					break
		_win()
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		rects.clear()
		var n := letters.size()
		var sz := minf(68.0, (a.size.x - 8.0 * n) / n)
		var total := n * (sz + 8.0) - 8.0
		var x0 := a.position.x + (a.size.x - total) * 0.5
		# answer slots
		for k in n:
			var r := Rect2(x0 + k * (sz + 8.0), a.position.y + 20.0, sz, sz)
			var txt: String = letters[picked[k]] if k < picked.size() else ""
			tile(ci, font, r, txt, Color("e9dfc0") if k >= picked.size() else Color("f4e6a0"), Color(Palette.INK_BROWN, 0.6), 34)
		# letter tiles
		for i in n:
			var r2 := Rect2(x0 + i * (sz + 8.0), a.position.y + 20.0 + sz + 50.0, sz, sz)
			var used := picked.has(i)
			tile(ci, font, r2, letters[i], Color("d8d0b8") if used else Color("f6efd8"), Palette.GOLD.darkened(0.15) if i == cursor else Palette.INK_BROWN, 34, Color(Palette.INK, 0.25 if used else 1.0))
			rects.append({"r": r2, "i": i})

# =============================================================================================
# Rebuild the sentence from shuffled words.
const SENTENCES := {
	1: ["The lantern is warm.", "A story begins here.", "Nobody is coming yet.", "Ink never forgets."],
	2: ["Every page remembers who wrote it.", "The baker left bread on the table.", "Someone lit the forge again tonight.", "A small door hides behind the shelf."],
	3: ["The Storytender carried the lantern through the empty library.", "Even a broken sword remembers the hand that forged it.", "She never finished the story, but she kept the last page.", "Whatever was cut from the book is still somewhere, waiting."],
	4: ["The editor cut the chapter, but the tailor stitched every word back together.", "Nobody sat at the long table, and yet the whole kitchen felt like company.", "A boy tore out the final page so that no one could spoil the ending for him."],
}
class SentenceGame extends Base:
	var sentence := ""
	var words: Array = []
	var shuffled: Array = []
	var picked: Array = []
	var cursor := 0
	func setup() -> void:
		var key := clampi(tier, 2, 4)
		var pool: Array = TrialGames.SENTENCES[key]
		sentence = pool[rng.randi() % pool.size()]
		words = sentence.split(" ")
		shuffled = words.duplicate()
		var guard := 0
		while guard < 20:
			for i in shuffled.size():
				var j := rng.randi() % shuffled.size()
				var t = shuffled[i]
				shuffled[i] = shuffled[j]
				shuffled[j] = t
			if shuffled != words:
				break
			guard += 1
	func help() -> String:
		return "Put the words back in order. Pick them one at a time; Undo takes the last one back."
	func input(ev: InputEvent) -> void:
		var d := MenuInput.nav(ev)
		if d.x != 0:
			cursor = (cursor + d.x + shuffled.size()) % shuffled.size()
		elif d.y != 0:
			cursor = clampi(cursor + d.y * 4, 0, shuffled.size() - 1)
		elif MenuInput.accept(ev):
			click_index(cursor)
		elif ev.is_action_pressed("use_item") or (ev is InputEventKey and ev.pressed and ev.keycode == KEY_BACKSPACE):
			if not picked.is_empty():
				picked.pop_back()
	func click_index(i: int) -> void:
		if picked.has(i):
			return
		picked.append(i)
		cursor = i
		if picked.size() >= shuffled.size():
			var s: PackedStringArray = []
			for k in picked:
				s.append(shuffled[k])
			if " ".join(s) == sentence:
				_win("That reads right.")
			else:
				picked.clear()
				lose_try("That does not read right.")
	func auto_solve() -> void:
		picked.clear()
		for w in words:
			for i in shuffled.size():
				if shuffled[i] == w and not picked.has(i):
					picked.append(i)
					break
		_win()
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		rects.clear()
		# the line being built
		var x := a.position.x
		var y := a.position.y + 10.0
		for k in picked:
			var w: String = shuffled[k]
			var ts := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24)
			if x + ts.x + 24.0 > a.end.x:
				x = a.position.x
				y += 48.0
			ci.draw_string(font, Vector2(x, y + 30.0), w, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Palette.INK)
			x += ts.x + 12.0
		ci.draw_line(Vector2(a.position.x, y + 40.0), Vector2(a.end.x, y + 40.0), Color(Palette.INK, 0.35), 2.0)
		# the tiles
		x = a.position.x
		y = a.position.y + 150.0
		for i in shuffled.size():
			var w2: String = shuffled[i]
			var ts2 := font.get_string_size(w2, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26)
			if x + ts2.x + 28.0 > a.end.x:
				x = a.position.x
				y += 58.0
			var r := Rect2(x, y, ts2.x + 22.0, 46.0)
			var used := picked.has(i)
			tile(ci, font, r, w2, Color("d8d0b8") if used else Color("f6efd8"), Palette.GOLD.darkened(0.15) if i == cursor else Palette.INK_BROWN, 26, Color(Palette.INK, 0.25 if used else 1.0))
			rects.append({"r": r, "i": i})
			x += r.size.x + 10.0

# =============================================================================================
# Word ladder: change one letter at a time, each step a real word, to reach the goal.
class Ladder extends Base:
	var dict: Dictionary = {}
	var start := ""
	var goal := ""
	var cur := ""
	var typed: Array = []
	var cursor := 0
	var steps := 0
	var max_steps := 0
	var history: Array = []
	var par := 0
	func setup() -> void:
		for w in TrialGames.WORDS.split(" "):
			dict[w] = true
		par = 3 if tier <= 2 else (4 if tier == 3 else 5)
		max_steps = par + (4 if tier <= 2 else (3 if tier == 3 else 2))
		var keys: Array = dict.keys()
		for _try in 200:
			var s: String = keys[rng.randi() % keys.size()]
			var dist := _bfs(s)
			var cands: Array = []
			for w in dist.keys():
				if dist[w] == par:
					cands.append(w)
			if cands.size() > 0:
				start = s
				goal = cands[rng.randi() % cands.size()]
				break
		cur = start
		history = [start]
		for c in cur:
			typed.append(c)
		tries = 99
	func _bfs(from: String) -> Dictionary:
		var dist := {from: 0}
		var q: Array = [from]
		var qi := 0
		while qi < q.size():
			var w: String = q[qi]
			qi += 1
			for i in 4:
				for ch in "abcdefghijklmnopqrstuvwxyz":
					if ch != w[i]:
						var x: String = w.substr(0, i) + ch + w.substr(i + 1)
						if dict.has(x) and not dist.has(x):
							dist[x] = dist[w] + 1
							q.append(x)
		return dist
	func help() -> String:
		return "Change one letter at a time, every step a real word, from %s to %s in %d steps or fewer. Left and right pick a letter, up and down change it, confirm submits." % [start.to_upper(), goal.to_upper(), max_steps]
	func input(ev: InputEvent) -> void:
		var d := MenuInput.nav(ev)
		if d.x != 0:
			cursor = (cursor + d.x + 4) % 4
		elif d.y != 0:
			var c := (typed[cursor] as String).unicode_at(0) - 97
			c = (c - d.y + 26) % 26
			typed[cursor] = String.chr(97 + c)
		elif MenuInput.accept(ev):
			_submit()
		elif ev is InputEventKey and ev.pressed and ev.unicode > 0:
			var ch := String.chr(ev.unicode).to_lower()
			if ch >= "a" and ch <= "z":
				typed[cursor] = ch
				cursor = mini(cursor + 1, 3)
	func _submit() -> void:
		var w := "".join(typed)
		var diff := 0
		for i in 4:
			if w[i] != cur[i]:
				diff += 1
		if diff != 1:
			message = "Change exactly one letter."
			shake = 0.3
			return
		if not dict.has(w):
			message = "%s is not a word I know." % w.to_upper()
			shake = 0.3
			return
		cur = w
		steps += 1
		history.append(w)
		message = ""
		if w == goal:
			_win("Reached %s in %d steps." % [goal.to_upper(), steps])
		elif steps >= max_steps:
			_fail("Out of steps.")
	func auto_solve() -> void:
		var dist := _bfs(goal)
		while cur != goal:
			for i in 4:
				var found := false
				for ch in "abcdefghijklmnopqrstuvwxyz":
					if ch != cur[i]:
						var x: String = cur.substr(0, i) + ch + cur.substr(i + 1)
						if dict.has(x) and dist.has(x) and dist[x] == dist[cur] - 1:
							typed = []
							for c in x:
								typed.append(c)
							_submit()
							found = true
							break
				if found:
					break
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		rects.clear()
		var sz := 74.0
		var x0 := a.position.x + (a.size.x - (4 * (sz + 8.0) - 8.0)) * 0.5
		for i in 4:
			var r := Rect2(x0 + i * (sz + 8.0), a.position.y + 20.0, sz, sz)
			tile(ci, font, r, (typed[i] as String).to_upper(), Color("f6efd8"), Palette.GOLD.darkened(0.15) if i == cursor else Palette.INK_BROWN, 40)
			rects.append({"r": r, "i": i})
		ci.draw_string(font, Vector2(a.position.x, a.position.y + 150.0), "Goal: %s     Steps: %d / %d" % [goal.to_upper(), steps, max_steps], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Palette.INK)
		var line := "  >  ".join(history.map(func(w): return (w as String).to_upper()))
		ci.draw_string(font, Vector2(a.position.x, a.position.y + 196.0), line, HORIZONTAL_ALIGNMENT_LEFT, a.size.x, 22, Color(Palette.INK, 0.65))
	func click_index(i: int) -> void:
		cursor = i

# =============================================================================================
# Typewriter: type the phrase before the time runs out.
const PHRASES := {
	3: ["the quill remembers", "write what you remember", "a page is never empty", "keep the lantern lit"],
	4: ["somewhere a story is waiting for its last page", "the only way out of a draft is through it", "nobody ever finished writing the kind ones"],
}
class Typewriter extends Base:
	var phrase := ""
	var pos := 0
	var mistakes := 0
	var max_mistakes := 5
	var pad := false
	var grid := ["ABCDEFGHI", "JKLMNOPQR", "STUVWXYZ'", "_,.-?!"]
	var gx := 0
	var gy := 0
	func setup() -> void:
		pad = TrialGames.pad_mode
		var key := 3 if tier <= 3 else 4
		var pool: Array = TrialGames.PHRASES[key]
		phrase = pool[rng.randi() % pool.size()]
		time_limit = 24.0 if key == 3 else 30.0
		time_left = time_limit
		max_mistakes = 5 if key == 3 else 4
		if pad:
			time_limit += 14.0
			time_left = time_limit
			max_mistakes += 2
		tries = max_mistakes
		max_tries = max_mistakes
	func help() -> String:
		if pad:
			return "Spell the line with the letter grid (move, then confirm), before the bar runs out. Mistakes: %d allowed." % max_mistakes
		return "Type the line exactly, before the bar runs out. Mistakes: %d allowed." % max_mistakes
	func _type(ch: String) -> void:
		if ch.to_lower() == phrase[pos].to_lower():
			pos += 1
			if pos >= phrase.length():
				_win("Typed in %.1f seconds." % (time_limit - time_left))
		else:
			mistakes += 1
			lose_try("Wrong key.")
	func click_index(i: int) -> void:
		gy = clampi(i / 10, 0, grid.size() - 1)
		gx = clampi(i % 10, 0, (grid[gy] as String).length() - 1)
		_type_cell()
	func _type_cell() -> void:
		var c: String = (grid[gy] as String)[gx]
		_type(" " if c == "_" else c)
	func input(ev: InputEvent) -> void:
		if solved or failed:
			return
		if pad and not (ev is InputEventKey):
			var d := MenuInput.nav(ev)
			if d != Vector2i.ZERO:
				gy = clampi(gy + d.y, 0, grid.size() - 1)
				gx = clampi(gx + d.x, 0, (grid[gy] as String).length() - 1)
				return
			if MenuInput.accept(ev) and not (ev is InputEventKey):
				_type_cell()
				return
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.unicode > 0:
			var ch := String.chr(ev.unicode)
			if ch.to_lower() == phrase[pos].to_lower():
				pos += 1
				if pos >= phrase.length():
					_win("Typed in %.1f seconds." % (time_limit - time_left))
			else:
				mistakes += 1
				lose_try("Wrong key.")
	func auto_solve() -> void:
		pos = phrase.length()
		_win()
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		var x := a.position.x
		var y := a.position.y + 50.0
		for i in phrase.length():
			var ch := phrase[i]
			var col := Color(Palette.INK, 0.35)
			if i < pos:
				col = Color("2f7a4a")
			elif i == pos:
				col = Palette.INK
			var ts := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34)
			if x + ts.x > a.end.x:
				x = a.position.x
				y += 56.0
			if i == pos:
				ci.draw_rect(Rect2(x - 2.0, y - 36.0, maxf(ts.x, 14.0) + 4.0, 46.0), Color(Palette.GOLD, 0.4))
			ci.draw_string(font, Vector2(x, y), ch if ch != " " else " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, col)
			x += maxf(ts.x, 10.0)
		ci.draw_string(font, a.position + Vector2(0, 130), "Mistakes: %d / %d" % [mistakes, max_mistakes], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(Palette.INK, 0.65))
		rects.clear()
		if pad:
			var cs := 44.0
			var gx0 := a.position.x + (a.size.x - cs * 9.0) * 0.5
			for r in grid.size():
				for c in (grid[r] as String).length():
					var ch: String = (grid[r] as String)[c]
					var cell := Rect2(gx0 + c * cs, a.position.y + 150.0 + r * cs, cs - 4.0, cs - 4.0)
					var sel := r == gy and c == gx
					tile(ci, font, cell, "␣" if ch == "_" else ch, Color("f6efd8") if not sel else Color("f2d88a"), Palette.GOLD.darkened(0.15) if sel else Palette.INK_BROWN, 22)
					rects.append({"r": cell, "i": r * 10 + c})

# =============================================================================================
# Dictation Beat: the controller-friendly cousin of the Typewriter. Notes fall down four lanes;
# press that direction as a note crosses the line. Works with d-pad, stick, WASD, arrows or mouse.
class Rhythm extends Base:
	const TRAVEL := 1.7
	const WINDOW := 0.3
	const LANE_NAMES := ["<", "v", "^", ">"]
	var notes: Array = []        # {lane, t, state} state 0 pending, 1 hit, 2 missed
	var clock := 0.0
	var flash := {}              # lane -> seconds of highlight
	func setup() -> void:
		var count := 14 if tier <= 3 else 18
		var gap := 0.85 if tier <= 3 else 0.68
		max_tries = 4 if tier <= 3 else 3
		tries = max_tries
		clock = -1.2
		var t := 1.0
		var last := -1
		for i in count:
			var lane := rng.randi() % 4
			if lane == last and rng.randf() < 0.6:
				lane = (lane + 1 + rng.randi() % 3) % 4
			last = lane
			notes.append({"lane": lane, "t": t, "state": 0})
			t += gap
		message = ""
	func help() -> String:
		return "Hit each falling note with its direction as it crosses the line. %d misses allowed." % max_tries
	func input(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.echo:
			return
		var d := MenuInput.nav(ev)
		if d == Vector2i.ZERO:
			return
		var lane := 0
		if d.x < 0: lane = 0
		elif d.y > 0: lane = 1
		elif d.y < 0: lane = 2
		else: lane = 3
		press(lane)
	func click(pos: Vector2) -> void:
		for h: Dictionary in rects:
			if (h["r"] as Rect2).has_point(pos):
				press(int(h["i"]))
				return
	func press(lane: int) -> void:
		if solved or failed:
			return
		flash[lane] = 0.15
		var best := -1
		var best_d := WINDOW
		for i in notes.size():
			var n: Dictionary = notes[i]
			if int(n["state"]) != 0 or int(n["lane"]) != lane:
				continue
			var dt := absf(float(n["t"]) - clock)
			if dt <= best_d:
				best_d = dt
				best = i
		if best >= 0:
			notes[best]["state"] = 1
			message = ""
			_check_done()
		else:
			lose_try("Off the beat.")
	func tick(delta: float) -> void:
		super.tick(delta)
		if solved or failed:
			return
		clock += delta
		for k in flash.keys():
			flash[k] = float(flash[k]) - delta
		for n: Dictionary in notes:
			if int(n["state"]) == 0 and clock > float(n["t"]) + WINDOW:
				n["state"] = 2
				lose_try("Missed one.")
				if failed:
					return
		_check_done()
	func _check_done() -> void:
		if solved or failed:
			return
		for n: Dictionary in notes:
			if int(n["state"]) == 0:
				return
		_win("Right on the beat.")
	func auto_solve() -> void:
		for n: Dictionary in notes:
			n["state"] = 1
		_check_done()
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		rects.clear()
		var lane_w := minf(110.0, a.size.x / 4.0 - 10.0)
		var x0 := a.position.x + (a.size.x - lane_w * 4.0 - 30.0) * 0.5
		var top := a.position.y
		var line_y := a.end.y - 40.0
		for l in 4:
			var r := Rect2(x0 + l * (lane_w + 10.0), top, lane_w, a.size.y)
			ci.draw_rect(r, Color(0.23, 0.16, 0.11, 0.12 + (0.2 if float(flash.get(l, 0.0)) > 0.0 else 0.0)))
			rects.append({"r": r, "i": l})
			tile(ci, font, Rect2(r.position.x + 4.0, line_y - 8.0, lane_w - 8.0, 46.0), LANE_NAMES[l], Color("f6efd8"), Palette.GOLD.darkened(0.15), 26)
			for n: Dictionary in notes:
				if int(n["lane"]) != l or int(n["state"]) == 1:
					continue
				var f := 1.0 - (float(n["t"]) - clock) / TRAVEL
				if f < 0.0 or f > 1.15:
					continue
				var y := lerpf(top + 10.0, line_y + 15.0, f)
				var col := Color("c9822b") if int(n["state"]) == 0 else Color("b8402f")
				ci.draw_circle(Vector2(r.position.x + lane_w * 0.5, y), 20.0, col)
				ci.draw_circle(Vector2(r.position.x + lane_w * 0.5, y), 20.0, Palette.INK_BROWN, false, 3.0)

# =============================================================================================
# Cipher wheel: turn the wheel until the message reads.
const CIPHERS := {
	3: ["THE LAST PAGE", "REMEMBER ME", "LIGHT THE WAY"],
	4: ["EVERY STORY NEEDS A READER", "THE EDITOR IS AFRAID OF BLANK PAGES", "NOBODY WRITES ALONE"],
}
class Cipher extends Base:
	var plain := ""
	var shift := 0
	var guess := 0
	func setup() -> void:
		var key := 3 if tier <= 3 else 4
		var pool: Array = TrialGames.CIPHERS[key]
		plain = pool[rng.randi() % pool.size()]
		shift = 2 + rng.randi() % 22
		tries = 3 if key == 3 else 2
		max_tries = tries
	func _shifted(text: String, s: int) -> String:
		var out := ""
		for c in text:
			if c >= "A" and c <= "Z":
				out += String.chr(65 + (c.unicode_at(0) - 65 + s + 26) % 26)
			else:
				out += c
		return out
	func _cipher() -> String:
		return _shifted(plain, shift)
	func help() -> String:
		return "The message was shifted along the alphabet. Turn the wheel with left and right until it reads, then confirm."
	func input(ev: InputEvent) -> void:
		var d := MenuInput.nav(ev)
		if d.x != 0:
			guess = (guess + d.x + 26) % 26
		elif MenuInput.accept(ev):
			if guess == (26 - shift) % 26:
				_win("It reads.")
			else:
				lose_try("Gibberish.")
	func auto_solve() -> void:
		guess = (26 - shift) % 26
		_win()
	func draw(ci: Control, a: Rect2, font: Font, _head: Font) -> void:
		ci.draw_string(font, a.position + Vector2(0, 40), "Coded:   " + _cipher(), HORIZONTAL_ALIGNMENT_LEFT, a.size.x, 28, Color(Palette.INK, 0.7))
		ci.draw_string(font, a.position + Vector2(0, 110), "Wheel:   %+d" % guess, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Palette.INK_BROWN)
		ci.draw_string(font, a.position + Vector2(0, 180), "Reads:   " + _shifted(_cipher(), guess), HORIZONTAL_ALIGNMENT_LEFT, a.size.x, 34, Palette.INK)
