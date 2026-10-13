class_name CultureData
extends RefCounted
## Cultural content: the Chapter 4 statue quizzes and the unlockable lore codex.
##
## Kept apart from gameplay code so the writing can be reviewed, corrected or
## expanded by someone who is not touching the engine. Each quiz question is
## `{ "prompt", "options", "answer" (index), "lore" (entry id granted) }`.

const LORE_SCORE := 100

## Four statues, one quiz each. Every answer is already in S'lang's bag
## before she enters this house: the notes from Houses 1–3, and what she
## did there. Correct answers unlock the matching lore entry.
const STATUE_QUIZZES: Array[Dictionary] = [
	{
		"statue": "The Statue of the Dreamer",
		"riddle": "I do not make the pattern up. I only remember what I saw while I slept. What am I?",
		"questions": [
			{
				"prompt": "What is a damgo?",
				"options": [
					"A dream that shows a weaver her pattern",
					"A red root",
					"A brass staff",
					"A longhouse",
				],
				"answer": 0,
				"lore": "damgo",
			},
			{
				"prompt": "Who sends that dream?",
				"options": [
					"Fun Kdungon, the one who guides her",
					"The Chief",
					"The Queen",
					"The Spindle",
				],
				"answer": 0,
				"lore": "damgo",
			},
		],
	},
	{
		"statue": "The Statue of the Fibre",
		"riddle": "I come from a trunk. I am combed thin, then knotted end to end. What am I?",
		"questions": [
			{
				"prompt": "What did S'lang gather in the first house?",
				"options": [
					"Abaca, a relative of the banana",
					"Cotton",
					"Silk",
					"Hulo root",
				],
				"answer": 0,
				"lore": "abaca",
			},
			{
				"prompt": "Which strands did she keep?",
				"options": [
					"Strands that bend and hold a knot",
					"Strands that snap",
					"Strands that crack",
					"Strands that fray",
				],
				"answer": 0,
				"lore": "abaca",
			},
		],
	},
	{
		"statue": "The Statue of the Dye",
		"riddle": "I am beaten in a mortar until I give my colour away. What am I?",
		"questions": [
			{
				"prompt": "What root makes the red dye?",
				"options": [
					"Loko, also called hulo",
					"Abaca",
					"Gold",
					"Mud",
				],
				"answer": 0,
				"lore": "sacred_colors",
			},
			{
				"prompt": "How did she get the red out of those roots?",
				"options": [
					"She beat them in a mortar until the red came out",
					"She left them in the sun",
					"She washed them",
					"She burned them",
				],
				"answer": 0,
				"lore": "sacred_colors",
			},
		],
	},
	{
		"statue": "The Statue of the Master",
		"riddle": "I was dark until light from the window reached me. Then I asked you to remember a snake. What woke the torches before that?",
		"questions": [
			{
				"prompt": "What woke the dead torches?",
				"options": [
					"Striking the air with the brass lewet",
					"Crushing hulo in a mortar",
					"Sorting abaca on the rack",
					"Cutting the vines",
				],
				"answer": 0,
				"lore": "lewet_staff",
			},
			{
				"prompt": "What did the Golden Spindle ask her to remember?",
				"options": [
					"The snake on the floor, in the same order",
					"A pattern she invented herself",
					"A pattern copied from a book",
					"The Chief's map of the hall",
				],
				"answer": 0,
				"lore": "kleng",
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
		"text": "A T'boli weaver does not design her cloth. She is given it. Fun Kdungon sends the pattern in a damgo, a dream, and the weaver's task is to carry it back into the waking world without losing a single thread of it. To forget a dream is to lose a pattern forever - which is exactly what the Shadow of Forgetfulness feeds on.",
		"illustration": "res://assets/images/lore/lore_damgo.png",
		"portrait": "res://assets/images/lore/lore_damgo.png",
	},
	{
		"id": "abaca",
		"title": "Abaca - The Patient Fibre",
		"text": "T'nalak is woven from abaca, a relative of the banana. The trunk is stripped, the fibre combed to hair-thinness, then knotted end to end into one unbroken thread. A single cloth can take months. The work rewards patience and punishes hurry, which is why the House of the Black Foundation teaches sorting before anything else.",
		"illustration": "res://assets/images/lore/lore_abaca.png",
		"portrait": "res://assets/images/lore/lore_abaca.png",
	},
	{
		"id": "sacred_colors",
		"title": "The Three Sacred Colours",
		"text": "T'nalak speaks in three colours only. The cream of undyed abaca, the red of pounded loko root, and the deep black of k'nalum steeping. Nothing else is permitted into the sacred cloth. Gold belongs to the sun and the brass, not the dye pot - it is light, not pigment.",
		"illustration": "res://assets/images/lore/lore_sacred_colors.png",
		"portrait": "res://assets/images/lore/lore_sacred_colors.png",
	},
	{
		"id": "lang_dulay",
		"title": "Lang Dulay - National Living Treasure",
		"text": "Lang Dulay (1928-2015) of Lake Sebu held more than a hundred T'nalak patterns in memory and taught them to generations of young weavers at her School of Living Traditions. She is the reason many designs still exist at all. Her legacy is the living argument of this game: memory is a craft, and it can be lost.",
		"illustration": "res://assets/images/lore/lore_lang_dulay.png",
		"portrait": "res://assets/images/lore/lore_lang_dulay.png",
	},
	{
		"id": "taboo",
		"title": "Taboos of the Loom",
		"text": "The loom is treated as a living relation. It is not stepped over. Cloth is not cut thoughtlessly. A weaver in a bad temper leaves the loom rather than pass her mood into the thread. These rules are not superstition to the T'boli - they are how respect is made physical.",
		"illustration": "res://assets/images/lore/lore_taboo.png",
		"portrait": "res://assets/images/lore/lore_taboo.png",
	},
	{
		"id": "the_chief",
		"title": "The Chief — Ancestral Strength",
		"text": "The Chief is the guardian of the valley's history and the first leader S'lang must save in the House of the Black Foundation. He represents Ancestral Strength and defence, teaching how to protect the village from the first shadow invasion. His restoration matters because he holds the knowledge of where the Shadow Weaver first struck, and he gives S'lang her first map — the hall, the garden, and the paths the dark already walked.",
		"portrait": "res://assets/images/characters/the_chief.png",
	},
	{
		"id": "harvest_queen",
		"title": "The Harvest Queen — Abundance of the Land",
		"text": "The Harvest Queen is the spiritual protector of the forests and the source of the region's prosperity. Representing the Abundance of the Land, she is the key to unlocking the Red Dye in the House of Red Courage. She teaches S'lang that weaving is a cycle of life and growth, and grants the explosive Life-Thread — a living stitch that bursts corrupted thorns so the path can be sown again.",
		"portrait": "res://assets/images/characters/harvest_queen.png",
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
		"text": "The weaving goddess of this story's telling. She sends the damgo that carries each sacred pattern, and she is the one who chose S'lang and guides her through the five houses. She does not fight the Shadow of Forgetfulness herself, because forgetting cannot be struck down - it can only be out-remembered.",
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


## Written into S'lang's bag when a House is restored. The statue quizzes in
## the House of the Dream Ancestors are answerable from these notes.
const JOURNALS: Array[Dictionary] = [
	{
		"house": 1,
		"title": "Note — Black Foundation",
		"text": "T'nalak is woven from abaca, a relative of the banana. The trunk is stripped, the fibre combed to a hair, then knotted end to end into one continuous thread. Fibre that bends and holds a knot is kept. Fibre that snaps, cracks, or frays is set aside.",
	},
	{
		"house": 2,
		"title": "Note — Red Courage",
		"text": "The red of T'nalak comes from loko root, also called hulo. It is pounded in a mortar until it gives its colour away. The black comes from steeping the tied fibres in a bath of k'nalum leaves and soot-rich mud. The Harvest Queen taught that weaving is a cycle of growth, and that Life-Thread — press Q — bursts corrupted thorns.",
	},
	{
		"house": 3,
		"title": "Note — Golden Sun",
		"text": "A T'boli weaver does not invent her pattern. Fun Kdungon sends it in a damgo, a dream, and the weaver's work is to remember what was shown while she slept. The T'boli word for that dream is damgo. Gold is not a dye. It is the sun and the brass. The lewet is brass: strike the air with it and the old torches answer. The Golden Spindle asked her to remember the snake on the floor, in the same order.",
	},
	{
		"house": 4,
		"title": "Note — Dream Ancestors",
		"text": "Four stones hold the pattern. The Dreamer remembers the damgo. The Fibre is abaca, knotted end to end. The Dye is loko red and k'nalum black. The Master is Lang Dulay, who preserved the patterns by teaching them. The loom is not stepped over. A weaver in a bad temper leaves it, rather than weaving her mood into the thread.",
	},
	{
		"house": 5,
		"title": "Note — The Sacred Loom",
		"text": "The Shadow Weaver is what a pattern becomes when nobody remembers it. It cannot be ended by striking alone. It is out-remembered: the colours, the dream, and the hands that were taught to carry them.",
	},
]


static func journal_for(house_id: int) -> Dictionary:
	for entry in JOURNALS:
		if int(entry.get("house", 0)) == house_id:
			return entry
	return {}
