class_name PatternData
extends RefCounted

const COLS := 16
const ROWS := 16
const BEIGE := 0
const RED := 1
const BLACK := 2

const IDS: Array[String] = ["diamond", "stripes", "zigzag"]

# Verify T'boli motif names with cultural sources before naming patterns in the UI.
# These are generic practice patterns, not traditional motifs.
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
		"stripes":
			return "STRIPES"
		"zigzag":
			return "ZIGZAG"
		_:
			return "DIAMOND"

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
	var result: Array = []
	for row in range(ROWS):
		var values: Array[int] = []
		for col in range(COLS):
			values.append(BEIGE)
		result.append(values)
	match pattern_id:
		"stripes":
			_fill_stripes(result)
		"zigzag":
			_fill_zigzag(result)
		_:
			_fill_diamond(result)
	return result

static func next_id(pattern_id: String) -> String:
	var index := IDS.find(pattern_id)
	return IDS[(index + 1) % IDS.size()]

static func random_fact() -> String:
	return facts[randi_range(0, facts.size() - 1)]

static func _fill_stripes(result: Array) -> void:
	# Mirrored bands, plus dashed accents on two beige rows for extra yarn changes.
	var half: Array[int] = [RED, RED, BEIGE, BLACK, BEIGE, RED, BEIGE, BEIGE]
	for row in range(ROWS):
		var index: int = row if row < ROWS / 2 else ROWS - 1 - row
		for col in range(COLS):
			result[row][col] = half[index]
	for accent_row in [2, ROWS - 3]:
		for col in range(COLS):
			if col % 4 < 2:
				result[accent_row][col] = RED

static func _fill_zigzag(result: Array) -> void:
	# Two zigzag lines that cross each other as the cloth grows.
	for row in range(ROWS):
		var phase: int = row % 14
		var tri: int = phase if phase <= 7 else 14 - phase
		var a: int = tri * 2
		var b: int = 14 - a
		for col in range(COLS):
			if col == a or col == a + 1:
				result[row][col] = BLACK
			elif col == b or col == b + 1:
				result[row][col] = RED

static func _fill_diamond(result: Array) -> void:
	# Doubled coordinates keep the diamond perfectly centered on a 16x16 grid.
	for row in range(ROWS):
		for col in range(COLS):
			var d: int = (absi(2 * col - (COLS - 1)) + absi(2 * row - (ROWS - 1))) >> 1
			var value: int = BEIGE
			if d <= 2:
				value = RED
			elif d <= 4:
				value = BEIGE
			elif d <= 6:
				value = BLACK
			elif d <= 8:
				value = BEIGE
			elif d == 9:
				value = RED
			elif d >= 12 and (mini(col, COLS - 1 - col) + mini(row, ROWS - 1 - row)) % 2 == 0:
				value = BLACK
			if col == 0 or col == COLS - 1 or row == 0 or row == ROWS - 1:
				value = RED
			result[row][col] = value
