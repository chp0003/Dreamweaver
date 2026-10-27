class_name MotifLibrary
extends RefCounted

## Motif names are descriptive placeholders. Verify motif names and meanings
## with T'boli cultural sources before shipping them as traditional names.

const PATTERNS: Array[Dictionary] = [
	{"id": "diamond", "name": "Stepped Diamond", "difficulty": "Easy", "locked": false, "fact": "T'nalak is made from abaca warp threads tied and dyed before plain weaving."},
	{"id": "butterfly", "name": "Butterfly-inspired", "difficulty": "Easy", "locked": false, "fact": "Dreams are traditionally important to the T'nalak design process."},
	{"id": "frog", "name": "Frog-inspired", "difficulty": "Medium", "locked": false, "fact": "The weft crosses the dyed vertical warp to build the cloth row by row."},
	{"id": "lizard", "name": "Lizard-inspired", "difficulty": "Hard", "locked": false, "fact": "Natural abaca beige, deep red-brown, and black are characteristic T'nalak tones."},
	{"id": "zigzag", "name": "Zigzag Border", "difficulty": "Master", "locked": true, "fact": "Plain weave alternates over and under the warp threads."},
	{"id": "master", "name": "Master Combined Cloth", "difficulty": "Master", "locked": true, "fact": "A finished cloth records the patience and precision of the weaver."},
]

static var unlocked_ids: Dictionary = {
	"diamond": true,
	"butterfly": true,
	"frog": true,
	"lizard": true,
	"zigzag": false,
	"master": false,
}

static func all_patterns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_entry in PATTERNS:
		var entry: Dictionary = source_entry.duplicate()
		entry["locked"] = not bool(unlocked_ids.get(str(entry["id"]), false))
		result.append(entry)
	return result

static func get_pattern(pattern_id: String) -> Dictionary:
	for entry in all_patterns():
		if str(entry["id"]) == pattern_id:
			return entry
	return all_patterns()[0]

static func unlock_next(pattern_id: String) -> void:
	var found := false
	for entry in PATTERNS:
		if found:
			unlocked_ids[str(entry["id"])] = true
			return
		if str(entry["id"]) == pattern_id:
			found = true

static func palette() -> Dictionary:
	return {
		"beige": Color("#d7b889"),
		"beige_shadow": Color("#a9825b"),
		"beige_highlight": Color("#f0d7a7"),
		"red": Color("#713326"),
		"red_shadow": Color("#48201b"),
		"red_highlight": Color("#9b5140"),
		"black": Color("#21191a"),
		"black_shadow": Color("#110e10"),
		"black_highlight": Color("#3d3030"),
		"gold": Color("#c69b42"),
		"green": Color("#385845"),
	}
