class_name PatternData
extends RefCounted

const COLS := 16
const ROWS := 16
const BEIGE := 0
const RED := 1
const BLACK := 2

const IDS: Array[String] = ["house_1", "house_2", "house_3", "house_4", "house_5"]
const SLOT_ORDER: Array[int] = [1, 2, 5, 3, 4]
const CHAPTER_TITLES: Dictionary = {
	1: "Heart Diamond",
	2: "River Zigzag",
	3: "Star Bloom",
	4: "Dreamer's Eye",
	5: "Fu Dalu, the Dreamweaver",
}
const CHAPTER_FILES: Dictionary = {
	1: "chapter1_heart_diamond.png",
	2: "chapter2_river_zigzag.png",
	3: "chapter3_star_bloom.png",
	4: "chapter4_dreamers_eye.png",
	5: "chapter5_fu_dalu.png",
}
const _PANEL_STRINGS: Dictionary = {
	1: [
		"2111111331111112", "1111113223111111", "1111132112311111", "1111321111231111",
		"1113211331123111", "1132113333112311", "1321133223311231", "3211332222331123",
		"3211332222331123", "1321133223311231", "1132113333112311", "1113211331123111",
		"1111321111231111", "1112232112322111", "1121123223211211", "1211112332111121",
	],
	2: [
		"2111111331111112", "1111113223111111", "1111132332311111", "1111321111231111",
		"1113231111323111", "1132213113122311", "1322221331222231", "3223322112233223",
		"3231132222311323", "1321113223111231", "1132111331112311", "1113211111123111",
		"1111321111231111", "1112232112322111", "1121123223211211", "1211112332111121",
	],
	3: [
		"2111111331111112", "1111113223111111", "1111132332311111", "1111321331231111",
		"1113211331123111", "1132121331212311", "1321112222111231", "3233332222333323",
		"3233332222333323", "1321112222111231", "1132121331212311", "1113211331123111",
		"1111321331231111", "1112232332322111", "1121123223211211", "1211112332111121",
	],
	4: [
		"2111111331111112", "1111113223111111", "1111132112311111", "1111321111231111",
		"1113213333123111", "1132131111312311", "1321112222111231", "3211312332131123",
		"3211312332131123", "1321112222111231", "1132131111312311", "1113213333123111",
		"1111321111231111", "1112232112322111", "1121123223211211", "1211112332111121",
	],
	5: [
		"2111111331111112", "1111113223111111", "1111132332311111", "1111322332231111",
		"1113221221223111", "1132233223322311", "1322132332312231", "3233223113223323",
		"3233223113223323", "1322132332312231", "1132233223322311", "1113221221223111",
		"1111322332231111", "1112232332322111", "1121123223211211", "1211112332111121",
	],
}

# These are respectful, T'nalak-inspired pixel studies rather than copies of
# any particular community-owned textile or named motif.
static var facts: Array[String] = [
	"T'nalak is woven from abaca fiber by T'boli weavers of Lake Sebu.",
	"The design is prepared by tie-dyeing warp threads before weaving.",
	"T'boli weavers describe patterns as dreams received by the weaver.",
	"T'nalak is traditionally woven in three colors: beige, red-brown and black.",
	"After weaving, the cloth is polished by rubbing it with a cowrie shell.",
	"T'boli weavers traditionally work on a backstrap loom.",
]

static func display_name(pattern_id: String) -> String:
	match pattern_id:
		"house_1":
			return "FOUNDATION DIAMOND"
		"house_2":
			return "STEPPED PATH"
		"house_3":
			return "SUN-CROSSED LATTICE"
		"house_4":
			return "ANCESTOR LATTICE"
		"house_5":
			return "SACRED LOOM"
		_:
			return "FOUNDATION DIAMOND"

static func yarn_name(color_id: int) -> String:
	match color_id:
		RED:
			return "RED-BROWN"
		BLACK:
			return "BLACK"
		_:
			return "BEIGE"

static func yarn_label(color_id: int) -> String:
	return "%s (%d)" % [yarn_name(color_id), color_id + 1]

static func yarn_color(color_id: int) -> Color:
	match color_id:
		RED:
			return Color("#8B2E1A")
		BLACK:
			return Color("#1C1412")
		_:
			return Color("#E8D5A8")

static func yarn_highlight(color_id: int) -> Color:
	match color_id:
		RED:
			return Color("#B04328")
		BLACK:
			return Color("#3A2C27")
		_:
			return Color("#F5E8C7")

static func pattern(pattern_id: String) -> Array:
	var chapter: int = IDS.find(pattern_id) + 1
	if chapter >= 1 and chapter <= 5:
		var panel: Array = get_panel(chapter)
		var legacy: Array = []
		for row in panel:
			var converted: Array[int] = []
			for value in row:
				converted.append(int(value) - 1)
			legacy.append(converted)
		return legacy
	var result: Array = []
	for row in range(ROWS):
		var values: Array[int] = []
		for col in range(COLS):
			values.append(BEIGE)
		result.append(values)
	match pattern_id:
		"house_2":
			_fill_stepped_path(result)
		"house_3":
			_fill_sun_lattice(result)
		"house_4":
			_fill_ancestor_lattice(result)
		"house_5":
			_fill_sacred_loom(result)
		_:
			_fill_foundation_diamond(result)
	return result

static func get_panel(chapter: int) -> Array:
	var rows: Array = []
	var source: Array = _PANEL_STRINGS.get(chapter, [])
	for row_text in source:
		var row: PackedInt32Array = PackedInt32Array()
		for character in str(row_text):
			row.append(int(character))
		rows.append(row)
	return rows

static func color_changes(row: PackedInt32Array) -> int:
	var changes: int = 0
	for index in range(1, row.size()):
		if row[index] != row[index - 1]:
			changes += 1
	return changes

static func next_id(pattern_id: String) -> String:
	var index := IDS.find(pattern_id)
	return IDS[(index + 1) % IDS.size()]

static func random_fact() -> String:
	return facts[randi_range(0, facts.size() - 1)]

static func _fill_foundation_diamond(result: Array) -> void:
	# A stepped diamond and a dark selvedge introduce the three-dye palette.
	for row in range(ROWS):
		for col in range(COLS):
			var d: int = (absi(2 * col - (COLS - 1)) + absi(2 * row - (ROWS - 1))) >> 1
			if d <= 2:
				result[row][col] = RED
			elif d == 5 or d == 6:
				result[row][col] = BLACK
			elif d == 9:
				result[row][col] = RED
			if col == 0 or col == COLS - 1:
				result[row][col] = BLACK

static func _fill_stepped_path(result: Array) -> void:
	_fill_foundation_diamond(result)
	for row in range(ROWS):
		var phase := row % 8
		var step := phase if phase <= 4 else 8 - phase
		var left := 1 + step * 2
		var right := COLS - 2 - step * 2
		for col in range(COLS):
			if col == left or col == left + 1 or col == right or col == right - 1:
				result[row][col] = RED if row % 4 < 2 else BLACK
			elif row == 3 or row == ROWS - 4:
				result[row][col] = BLACK if col % 4 < 2 else BEIGE

static func _fill_sun_lattice(result: Array) -> void:
	_fill_stepped_path(result)
	for row in range(ROWS):
		for col in range(COLS):
			var diagonal := absi(col - row) <= 1 or absi((COLS - 1 - col) - row) <= 1
			if diagonal and row > 1 and row < ROWS - 2:
				result[row][col] = BLACK if (row + col) % 4 < 2 else RED
			if absi(col - 7) <= 1 and absi(row - 7) <= 1:
				result[row][col] = RED

static func _fill_ancestor_lattice(result: Array) -> void:
	_fill_sun_lattice(result)
	for row in range(ROWS):
		for col in range(COLS):
			var d := absi(col - 7) + absi(row - 7)
			if d == 3 or d == 4:
				result[row][col] = RED
			elif d == 7 or d == 8:
				result[row][col] = BLACK
			if (row == 2 or row == 13) and col % 3 != 1:
				result[row][col] = RED

static func _fill_sacred_loom(result: Array) -> void:
	# House 5 retains the foundation border, stepped paths, crossed lattice,
	# sun centre, and nested ancestor diamond as one continuous cloth.
	_fill_ancestor_lattice(result)
	for row in range(ROWS):
		for col in range(COLS):
			var outer: int = mini(mini(col, COLS - 1 - col), mini(row, ROWS - 1 - row))
			if outer == 0:
				result[row][col] = RED
			elif outer == 1 and (row + col) % 2 == 0:
				result[row][col] = BLACK
			var d := absi(col - 7) + absi(row - 7)
			if d <= 2:
				result[row][col] = RED
			elif d == 5 or d == 6:
				result[row][col] = BLACK
			elif d == 9:
				result[row][col] = RED
