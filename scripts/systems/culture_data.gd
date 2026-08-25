class_name CultureData
extends RefCounted
## Cultural content: the Chapter 4 statue quizzes and the unlockable lore codex.
##
## Kept apart from gameplay code so the writing can be reviewed, corrected or
## expanded by someone who is not touching the engine. Each quiz question is
## `{ "prompt", "options", "answer" (index), "lore" (entry id granted) }`.

const LORE_SCORE := 100

## Four statues, one quiz each. Correct answers unlock the matching lore entry.
const STATUE_QUIZZES: Array[Dictionary] = [
	{
		"statue": "The Statue of the Dreamer",
		"riddle": "I do not invent. I only remember what was shown to me while I slept. What am I?",
		"questions": [
			{
				"prompt": "Where do T'boli weavers traditionally receive their T'nalak patterns?",
				"options": [
					"From dreams sent by Fun Dalu, the spirit of the abaca",
					"From patterns copied out of trade catalogues",
					"From designs assigned by the village council",
					"From patterns invented freely by each weaver",
				],
				"answer": 0,
				"lore": "damgo",
			},
			{
				"prompt": "What is the T'boli word for the dream that carries a pattern?",
				"options": ["Damgo", "Kleng", "Ablun", "Hulo"],
				"answer": 0,
				"lore": "damgo",
			},
		],
	},
	{
		"statue": "The Statue of the Fibre",
		"riddle": "I am torn from a trunk, combed thin, and knotted end to end before I am worthy. What am I?",
		"questions": [
			{
				"prompt": "T'nalak cloth is woven from the fibre of which plant?",
				"options": [
					"Abaca, a relative of the banana",
					"Cotton",
					"Silk from cultivated moths",
					"Pineapple leaf",
				],
				"answer": 0,
				"lore": "abaca",
			},
			{
				"prompt": "After stripping, what must a weaver do to the fine abaca fibres?",
				"options": [
					"Knot them end to end into one continuous thread",
					"Weave them while still wet from the trunk",
					"Bleach them white in the sun",
					"Cut them all to the same short length",
				],
				"answer": 0,
				"lore": "abaca",
			},
		],
	},
	{
		"statue": "The Statue of the Dye",
		"riddle": "I am beaten in a mortar so that I may give my colour away. What am I?",
		"questions": [
			{
				"prompt": "Which root gives T'nalak its traditional red?",
				"options": ["Loko (hulo) root", "Indigo leaf", "Turmeric", "Annatto seed"],
				"answer": 0,
				"lore": "sacred_colors",
			},
			{
				"prompt": "How is the black of T'nalak traditionally achieved?",
				"options": [
					"Steeping tied fibres in a bath of k'nalum leaves and soot-rich mud",
					"Scorching the finished cloth over a fire",
					"Rubbing charcoal directly into the woven surface",
					"Leaving the cloth buried until it rots dark",
				],
				"answer": 0,
				"lore": "sacred_colors",
			},
		],
	},
	{
		"statue": "The Statue of the Master",
		"riddle": "I wove until my hands were maps. My name outlived my loom. Who am I?",
		"questions": [
			{
				"prompt": "Lang Dulay, National Living Treasure, is remembered above all for what?",
				"options": [
					"Preserving and teaching over a hundred T'nalak dream patterns",
					"Inventing a mechanical loom for T'nalak",
					"Introducing synthetic dyes to the T'boli",
					"Exporting T'nalak as fashion fabric",
				],
				"answer": 0,
				"lore": "lang_dulay",
			},
			{
				"prompt": "Which is a genuine T'nalak weaving taboo?",
				"options": [
					"The cloth must never be cut carelessly, and the loom is not stepped over",
					"Only men may sit at the loom",
					"Patterns must be drawn on paper before weaving",
					"Finished cloth must be washed in the river before use",
				],
				"answer": 0,
				"lore": "taboo",
			},
		],
	},
]

## Codex entries. `id` is what GameState stores; unlocked entries show up in the
## Lore Codex screen after the credits and from the pause menu.
const LORE_ENTRIES: Array[Dictionary] = [
	{
		"id": "damgo",
		"title": "Damgo - The Dream Given",
		"text": "A T'boli weaver does not design her cloth. She is given it. The pattern arrives in a damgo, a dream, and the weaver's task is to carry it back into the waking world without losing a single thread of it. To forget a dream is to lose a pattern forever - which is exactly what the Shadow of Forgetfulness feeds on.",
	},
	{
		"id": "abaca",
		"title": "Abaca - The Patient Fibre",
		"text": "T'nalak is woven from abaca, a relative of the banana. The trunk is stripped, the fibre combed to hair-thinness, then knotted end to end into one unbroken thread. A single cloth can take months. The work rewards patience and punishes hurry, which is why the House of the Black Foundation teaches sorting before anything else.",
	},
	{
		"id": "sacred_colors",
		"title": "The Three Sacred Colours",
		"text": "T'nalak speaks in three colours only. The cream of undyed abaca, the red of pounded loko root, and the deep black of k'nalum steeping. Nothing else is permitted into the sacred cloth. Gold belongs to the sun and the brass, not the dye pot - it is light, not pigment.",
	},
	{
		"id": "lang_dulay",
		"title": "Lang Dulay - National Living Treasure",
		"text": "Lang Dulay (1928-2015) of Lake Sebu held more than a hundred T'nalak patterns in memory and taught them to generations of young weavers at her School of Living Traditions. She is the reason many designs still exist at all. Her legacy is the living argument of this game: memory is a craft, and it can be lost.",
	},
	{
		"id": "taboo",
		"title": "Taboos of the Loom",
		"text": "The loom is treated as a living relation. It is not stepped over. Cloth is not cut thoughtlessly. A weaver in a bad temper leaves the loom rather than pass her mood into the thread. These rules are not superstition to the T'boli - they are how respect is made physical.",
	},
	{
		"id": "kleng",
		"title": "Kleng - The Lightning Motif",
		"text": "The zigzag that runs through T'nalak is kleng, lightning. It marks the boundary between fields of pattern the way lightning marks the boundary between sky and earth. Nearly every design in the Houses of Weaving is framed by it.",
	},
	{
		"id": "guno_bong",
		"title": "Guno Bong - The Great House",
		"text": "The Guno Bong is the great T'boli longhouse: a single raised hall under a steep roof, where families sleep, cook, argue and weave in one shared space. The five Houses of Weaving in this story borrow its shape - each one a hall with a loom at its heart.",
	},
	{
		"id": "fun_kdungon",
		"title": "Fun Kdungon",
		"text": "The weaving goddess of this story's telling. She does not fight the Shadow of Forgetfulness herself, because forgetting cannot be struck down - it can only be out-remembered. So she chooses a weaver instead of a warrior.",
		"portrait": "res://assets/images/characters/fun_kdungon.png",
	},
	{
		"id": "lewet_staff",
		"title": "The Lewet Staff",
		"text": "A weaver's beater, the lewet, is used to pack each new row of weft tight against the last. In S'lang's hands it becomes both weapon and instrument: it strikes shadow, and its brass rings sound the chime that wakes sleeping light.",
	},
	{
		"id": "shadow_weaver",
		"title": "The Shadow Weaver",
		"text": "Not a demon and not a god. The Shadow Weaver is what a pattern becomes when nobody remembers it: smoke where a figure used to stand, thread unravelling with nothing to hold it. It fights by bleaching, because that is the only thing it knows how to do.",
	},
]


static func statue_count() -> int:
	return STATUE_QUIZZES.size()


static func statue(index: int) -> Dictionary:
	if index < 0 or index >= STATUE_QUIZZES.size():
		return {}
	return STATUE_QUIZZES[index]


static func lore_entry(entry_id: String) -> Dictionary:
	for entry in LORE_ENTRIES:
		if str(entry["id"]) == entry_id:
			return entry
	return {}


static func total_lore() -> int:
	return LORE_ENTRIES.size()
