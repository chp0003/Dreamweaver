extends "res://scripts/chapters/house_quest.gd"
## Chapter 1 - House of the Black Foundation.
##
## One readable hall. You spawn facing the work line:
##   1 Spirit (remember) → 2 garden strands → 3 rack (sort) → 4 vat (dye).
## The garden sits behind you, through a single framed door, on the way back
## to the ridge porch.

const STRAND_TOTAL := 10
const FIBER_SORTING := "res://scenes/minigames/FiberSorting.tscn"
const STEPS: Array[String] = [
	"Speak with the Spirit",
	"Find abaca  ·  10",
	"Sort at the rack",
	"Pour the black vat",
]

## Hall pickups sit behind dressing. Garden pickups sit in the plant beds.
const HALL_STRANDS: Array[Vector2] = [
	Vector2(-11.2, -7.5),
	Vector2(-8.5, -4.9),
	Vector2(-9.0, 2.1),
	Vector2(9.3, -7.3),
	Vector2(8.6, -0.6),
]
const GARDEN_STRANDS: Array[Vector2] = [
	Vector2(-9.1, 6.7),
	Vector2(-7.5, 10.5),
	Vector2(3.5, 9.6),
	Vector2(8.8, 7.3),
	Vector2(7.8, 9.7),
]

var _spirit: PlaceholderProp
var _spirit_trigger: Interactable
var _rack: PlaceholderProp
var _rack_trigger: Interactable
var _vat: PlaceholderProp
var _vat_trigger: Interactable
var _garden_door: PlaceholderProp
var _collected := 0
var _beacon: QuestBeacon
var _marks: Dictionary = {}
var _strands: Array[Collectible] = []


func _build_world() -> void:
	add_room_bounds(Vector2i(-12, -11), 25, 25)
	_build_work_line()
	_build_partition()
	_build_garden()
	_beacon = QuestBeacon.new()
	_beacon.name = "QuestBeacon"
	world.add_child(_beacon)


func _build_work_line() -> void:
	# Left to right along the far wall: remember, judge, dye.
	_spirit = spawn_prop("SPIRIT OF THE FIBER", Vector2(-8.2, -7.0), {
		"texture_path": "res://assets/images/characters/spirit_of_the_fiber.png",
		"prop_size": Vector2(64.0, 104.0),
		"body_color": Color(0.34, 0.33, 0.31),
		"accent_color": Color(0.5, 0.48, 0.44),
		"float_amplitude": 2.2,
		"float_speed": 0.7,
		"show_label": false,
	})
	_spirit.set_tint(Color(0.78, 0.78, 0.8))
	_spirit_trigger = add_interactable("Speak with the Spirit", Vector2(-8.2, -5.9),
		{"enabled": false, "radius": 88.0})
	_mark_station("spirit", _spirit, "SPIRIT")

	_rack = spawn_prop("DRYING RACK", Vector2(0.0, -7.2), {
		"texture_path": "res://assets/images/props/drying_rack.png",
		"prop_size": Vector2(122.0, 94.0),
		"body_color": Color(0.31, 0.27, 0.22),
		"accent_color": Color(0.52, 0.44, 0.3),
		"show_label": false,
	})
	_rack_trigger = add_interactable("Sort the strands", Vector2(0.0, -6.0),
		{"enabled": false, "radius": 90.0})
	_mark_station("rack", _rack, "SORT")

	_vat = spawn_prop("SACRED DYE VAT", Vector2(8.2, -7.0), {
		"texture_path": "res://assets/images/props/sacred_vat.png",
		"prop_size": Vector2(94.0, 92.0),
		"body_color": Color(0.18, 0.16, 0.16),
		"accent_color": Color(0.46, 0.4, 0.3),
		"show_label": false,
	})
	_vat_trigger = add_interactable("Pour into the vat", Vector2(8.2, -5.9),
		{"enabled": false, "radius": 88.0})
	_mark_station("vat", _vat, "VAT")

	spawn_prop("ABLUN LOOM (idle)", Vector2(-9.6, -4.4), {
		"texture_path": "res://assets/images/props/loom_small.png",
		"prop_size": Vector2(78.0, 62.0),
		"body_color": Color(0.29, 0.25, 0.21),
		"accent_color": Color(0.5, 0.42, 0.28),
		"show_label": false,
	})
	for i in range(3):
		spawn_prop("FIBRE BASKET", Vector2(9.8, -4.8 + float(i) * 1.45), {
			"texture_path": "res://assets/images/props/fibre_basket.png",
			"prop_size": Vector2(36.0, 36.0),
			"body_color": Color(0.26, 0.23, 0.2),
			"accent_color": Color(0.44, 0.38, 0.27),
			"show_label": false,
		})
	spawn_prop("FIBRE BASKET", Vector2(-10.4, -8.2), {
		"texture_path": "res://assets/images/props/fibre_basket.png",
		"prop_size": Vector2(34.0, 34.0),
		"body_color": Color(0.26, 0.23, 0.2),
		"accent_color": Color(0.44, 0.38, 0.27),
		"show_label": false,
	})
	spawn_prop("STORAGE CRATE", Vector2(10.2, -8.2), {
		"texture_path": "res://assets/images/props/storage_crate.png",
		"prop_size": Vector2(48.0, 52.0),
		"body_color": Color(0.23, 0.2, 0.18),
		"accent_color": Color(0.4, 0.34, 0.26),
		"show_label": false,
	})
	spawn_prop("STORAGE CRATE", Vector2(-10.0, 1.4), {
		"texture_path": "res://assets/images/props/storage_crate.png",
		"prop_size": Vector2(48.0, 52.0),
		"body_color": Color(0.23, 0.2, 0.18),
		"accent_color": Color(0.4, 0.34, 0.26),
		"show_label": false,
	})


func _build_partition() -> void:
	spawn_prop("WALL", Vector2(-7.4, 2.8), {
		"texture_path": "res://assets/images/props/wall_panel.png",
		"prop_size": Vector2(200.0, 92.0),
		"body_color": Color(0.2, 0.19, 0.18),
		"accent_color": Color(0.33, 0.3, 0.26),
		"show_label": false,
		"cast_shadow": false,
		"collision_feet": Vector2(52.0, 20.0),
	})
	spawn_prop("WALL", Vector2(7.4, 2.8), {
		"texture_path": "res://assets/images/props/wall_panel.png",
		"prop_size": Vector2(200.0, 92.0),
		"body_color": Color(0.2, 0.19, 0.18),
		"accent_color": Color(0.33, 0.3, 0.26),
		"show_label": false,
		"cast_shadow": false,
		"collision_feet": Vector2(52.0, 20.0),
	})
	_garden_door = spawn_prop("DOORWAY TO THE GARDEN", Vector2(0.0, 2.75), {
		"texture_path": "res://assets/images/props/doorway_garden.png",
		"prop_size": Vector2(128.0, 108.0),
		"body_color": Color(0.14, 0.13, 0.12),
		"accent_color": Color(0.62, 0.52, 0.3),
		"show_label": false,
		"cast_shadow": false,
	})


func _build_garden() -> void:
	var plants: Array[Vector2] = [
		Vector2(-10.2, 6.2), Vector2(-8.6, 10.0), Vector2(-6.4, 7.4),
		Vector2(6.2, 7.6), Vector2(10.0, 6.6), Vector2(8.8, 10.2),
		Vector2(-4.8, 9.4), Vector2(4.4, 10.4),
	]
	for cell in plants:
		spawn_prop("ABACA PLANT", cell, {
			"texture_path": "res://assets/images/props/abaca_plant.png",
			"prop_size": Vector2(52.0, 104.0),
			"body_color": Color(0.24, 0.26, 0.23),
			"accent_color": Color(0.4, 0.44, 0.36),
			"show_label": false,
			"sway_degrees": 2.8,
		})
	spawn_prop("STRIPPING BENCH", Vector2(9.2, 10.6), {
		"texture_path": "res://assets/images/props/stripping_bench.png",
		"prop_size": Vector2(82.0, 56.0),
		"body_color": Color(0.28, 0.25, 0.21),
		"accent_color": Color(0.48, 0.4, 0.28),
		"show_label": false,
	})


func _scatter_strands() -> void:
	var cells: Array[Vector2] = []
	cells.append_array(HALL_STRANDS)
	cells.append_array(GARDEN_STRANDS)
	for cell in cells:
		var strand := spawn_collectible("Faded Abaca Strand", cell, {
			"texture_path": "res://assets/images/props/abaca_strand.png",
			"tint": Color(0.52, 0.48, 0.42),
			"score_value": 40,
			"highlight": false,
			"pickup_radius": 22.0,
		})
		strand.collected.connect(_on_strand_collected)
		_strands.append(strand)


func _mark_station(id: String, anchor: Node2D, title: String) -> void:
	var mark := StationMarker.new()
	mark.title = title
	anchor.add_child(mark)
	mark.position = Vector2(0.0, 2.0)
	_marks[id] = mark


func _light_station(id: String, action := "[E]") -> void:
	for key in _marks:
		var mark: StationMarker = _marks[key]
		if mark != null:
			mark.set_lit(str(key) == id, action)
	var target: Node2D = null
	match id:
		"spirit":
			target = _spirit
		"rack":
			target = _rack
		"vat":
			target = _vat
	if _beacon != null:
		_beacon.pin(target)


func _set_steps(index: int, gather_count := -1) -> void:
	var steps := STEPS.duplicate()
	if gather_count >= 0:
		steps[1] = "Find abaca  ·  %d / %d" % [gather_count, STRAND_TOTAL]
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", steps, index)


func _clear_steps() -> void:
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", [], 0)


func _on_strand_collected(pickup: Collectible) -> void:
	_strands.erase(pickup)
	_collected += 1
	_set_steps(1, _collected)


func _run_chapter() -> void:
	_set_steps(0)
	_light_station("spirit")
	objective("The glowing figure on the left. Walk to her and press [E].")
	await wait(0.35)
	await say([
		"Far wall, left to right: a spirit, a drying rack, a dye vat. That is the work of this house.",
		{"speaker": "S'lang", "text": "Someone is sitting so still I took her for a post."},
	])

	_spirit_trigger.set_enabled(true)
	await _spirit_trigger.interacted
	_spirit_trigger.set_enabled(false)

	await say([
		{"speaker": "Spirit of the Fiber", "text": "Weaver's hands. Then tell me — what comes first?"},
		{"speaker": "S'lang", "text": "The abaca. Strip it, comb it, knot it."},
		{"speaker": "Spirit of the Fiber", "text": "The grayness took that out of me. Ten pale strands remain in this house — tucked, faded, easy to walk past. Search the hall and the garden. Bring them here."},
	])
	GameState.unlock_lore("abaca")

	_scatter_strands()
	_set_steps(1, 0)
	_light_station("")
	if _beacon != null:
		_beacon.clear()
	objective("Search the hall and garden. Strands hide behind plants, baskets, and crates.")
	await until(func() -> bool: return _collected >= STRAND_TOTAL)
	if _beacon != null:
		_beacon.clear()

	await say([
		{"speaker": "S'lang", "text": "Ten. Half of these will snap under tension."},
		{"speaker": "Spirit of the Fiber", "text": "Then sort them. Brittle from viable. The rack in the centre is waiting."},
	])

	_set_steps(2)
	_light_station("rack")
	_rack_trigger.set_enabled(true)
	objective("The centre rack. Press [E] to sort brittle from viable.")
	await _rack_trigger.interacted
	_rack_trigger.set_enabled(false)

	var sorted_well: bool = await run_mini_game(FIBER_SORTING)
	if not sorted_well:
		await say([
			{"speaker": "Spirit of the Fiber", "text": "You hurried, and the fibre knows it. Abaca punishes hurry."},
		])
		_clear_steps()
		if _beacon != null:
			_beacon.clear()
		await fail_chapter()
		return

	await say([
		{"speaker": "Spirit of the Fiber", "text": "There. My hands moved before I told them to."},
		{"speaker": "Spirit of the Fiber", "text": "The vat on the right. What you judged well, the black will accept."},
	])

	_set_steps(3)
	_light_station("vat")
	_vat_trigger.set_enabled(true)
	objective("The vat on the right. Press [E] to pour.")
	await _vat_trigger.interacted
	_vat_trigger.set_enabled(false)

	set_player_input(false)
	banner("Black returns to the vat", 1.8)
	Audio.play_sfx(Audio.Sfx.CHIME)
	restore_local_color(_vat)
	_spirit.set_tint(Color.WHITE)
	if _beacon != null:
		_beacon.clear()
	for key in _marks:
		var mark: StationMarker = _marks[key]
		if mark != null:
			mark.set_lit(false)
	await wait(3.2)
	_clear_steps()

	await complete_chapter([
		"The vat is not gray anymore. It is black — the night-soil black every cloth is built on.",
		{"speaker": "Spirit of the Fiber", "text": "The foundation is laid. I will not lose it again."},
		{"speaker": "Spirit of the Fiber", "text": "Leave by the porch behind the garden. The House of Red Courage is next — something has grown across its door."},
	])
