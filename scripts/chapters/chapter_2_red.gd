extends "res://scripts/chapters/house_quest.gd"
## Chapter 2 - House of Red Courage.
##
## Beats: hack through the Shadow Vines across the door -> hunt five Hulo roots
## through the storage corridors while shadow minions harry you -> pass Pigment
## Mashing at the mortar -> take the Red Dye Essence and wake the red flowers.

const ROOT_TOTAL := 5
const VINE_COUNT := 5
const PIGMENT_MASHING := "res://scenes/minigames/PigmentMashing.tscn"

const ROOT_CELLS: Array[Vector2] = [
	Vector2(-6.0, -6.0),
	Vector2(6.0, -6.0),
	Vector2(-6.0, 0.0),
	Vector2(6.0, 1.0),
	Vector2(0.0, -7.0),
]

const MINION_CELLS: Array[Vector2] = [
	Vector2(0.0, -2.0),
]

var _vines: Array[ShadowVine] = []
var _vines_cleared := 0
var _roots := 0
var _mortar_trigger: Interactable
var _flowers: PlaceholderProp


func _build_world() -> void:
	add_room_bounds(Vector2i(-8, -8), 17, 17)

	# The barred doorway sits between the entry porch and the storage hall.
	for i in range(VINE_COUNT):
		var vine := ShadowVine.new()
		vine.position = Iso.cell_to_world(map_cell(Vector2(-2.0 + float(i), 4.0)))
		vine.max_health = 100.0
		world.add_child(vine)
		vine.cleared.connect(_on_vine_cleared)
		_vines.append(vine)

	spawn_prop("DOOR FRAME", Vector2(0.0, 5.0), {
		"texture_path": "res://assets/images/props/door_frame.png",
		"prop_size": Vector2(200.0, 48.0),
		"body_color": Color(0.2, 0.16, 0.15),
		"accent_color": Color(0.5, 0.24, 0.2),
		"show_label": false,
		"cast_shadow": false,
	})

	_build_storage_corridors()

	spawn_prop("MORTAR AND PESTLE", Vector2(0.0, -5.0), {
		"texture_path": "res://assets/images/props/mortar_pestle.png",
		"prop_size": Vector2(72.0, 62.0),
		"body_color": Color(0.27, 0.2, 0.18),
		"accent_color": Color(0.62, 0.28, 0.22),
		"show_label": false,
	})
	_mortar_trigger = add_interactable("Crush the roots", Vector2(0.0, -4.0),
		{"enabled": false, "radius": 78.0})

	_flowers = spawn_prop("RED FLOWERS (bleached)", Vector2(4.0, 4.0), {
		"texture_path": "res://assets/images/props/red_flowers.png",
		"prop_size": Vector2(56.0, 46.0),
		"body_color": Color(0.34, 0.3, 0.29),
		"accent_color": Color(0.5, 0.42, 0.4),
		"show_label": false,
	})
	for i in range(4):
		spawn_prop("PIGMENT STAIN", Vector2(-3.0 + float(i) * 2.0, 2.0), {
			"prop_size": Vector2(42.0, 12.0),
			"body_color": Color(0.28, 0.12, 0.11),
			"accent_color": Color(0.55, 0.18, 0.14),
			"show_label": false,
			"cast_shadow": false,
		})

	for cell in ROOT_CELLS:
		var root := spawn_collectible("Hulo Root", cell, {
			"texture_path": "res://assets/images/props/hulo_root.png",
			"tint": Color(0.55, 0.38, 0.32),
			"score_value": 60,
		})
		root.collected.connect(_on_root_collected)


## Crates and racks arranged into a prison-like grid of corridors.
func _build_storage_corridors() -> void:
	var blocks: Array[Vector2] = [
		Vector2(-4.0, -6.0), Vector2(-4.0, -5.0), Vector2(-4.0, -4.0),
		Vector2(-2.0, -2.0), Vector2(-1.0, -2.0), Vector2(0.0, -2.0),
		Vector2(3.0, -6.0), Vector2(3.0, -5.0), Vector2(3.0, -4.0),
		Vector2(-6.0, -2.0), Vector2(-6.0, -1.0),
		Vector2(5.0, -2.0), Vector2(5.0, -1.0),
		Vector2(-2.0, 1.0), Vector2(2.0, 1.0),
	]
	for i in range(blocks.size()):
		spawn_prop("STORAGE CRATE", blocks[i], {
			"texture_path": "res://assets/images/props/storage_crate.png",
			"prop_size": Vector2(56.0, 62.0),
			"body_color": Color(0.23, 0.2, 0.18),
			"accent_color": Color(0.4, 0.28, 0.24),
			"show_label": false,
			"cast_shadow": false,
		})

	spawn_prop("BARRED WINDOW", Vector2(-7.0, -7.0), {
		"texture_path": "res://assets/images/props/barred_window.png",
		"prop_size": Vector2(48.0, 78.0),
		"body_color": Color(0.16, 0.14, 0.14),
		"accent_color": Color(0.45, 0.3, 0.26),
		"show_label": false,
	})


func _on_vine_cleared(_vine: ShadowVine) -> void:
	_vines_cleared += 1
	counter("Shadow Vines  %d / %d cleared" % [_vines_cleared, VINE_COUNT])


func _on_root_collected(_pickup: Collectible) -> void:
	_roots += 1
	counter("Hulo Roots  %d / %d" % [_roots, ROOT_TOTAL])


# --------------------------------------------------------------------------

func _run_chapter() -> void:
	banner("Chapter II\nHouse of Red Courage", 2.6)
	objective("Reach the door of the House of Red Courage.")
	await wait(1.2)

	await say([
		"Something has grown across the doorway. Not a plant - the shape of a plant, remembered wrongly, swaying in air that is not moving.",
		{"speaker": "S'lang", "text": "It is between me and the door. So it is between me and the red."},
	])

	counter("Shadow Vines  0 / %d cleared" % VINE_COUNT)
	objective("Left-click the Shadow Vines to lock on and fire Lewet bolts.")
	await until(func() -> bool: return _vines_cleared >= VINE_COUNT)

	counter("")
	Audio.play_sfx(Audio.Sfx.CHIME)
	await say([
		"The vines come apart like a knot pulled from the wrong end, and the door is only a door again.",
		{"speaker": "S'lang", "text": "Storage. Racks and crates, all of it stacked like a cell. And it smells of old root."},
	])

	counter("Hulo Roots  0 / %d" % ROOT_TOTAL)
	objective("Collect 5 Hulo Roots. One Shadow Minion hunts you — left-click it to lock on.")
	_release_minions()
	await until(func() -> bool: return _roots >= ROOT_TOTAL)

	counter("")
	await say([
		{"speaker": "S'lang", "text": "Five roots. Loko - hulo, the old ones called it. Beaten in a mortar until it gives its colour away."},
		"The mortar stands in the middle of the hall, dry as bone.",
	])

	_mortar_trigger.set_enabled(true)
	objective("Crush the roots in the mortar. [E]")
	await _mortar_trigger.interacted

	var mashed: bool = await run_mini_game(PIGMENT_MASHING)
	if not mashed:
		await say([
			"The roots are bruised and stubborn, and the pestle has nothing left to say to them.",
		])
		await fail_chapter()
		return

	set_player_input(false)
	banner("Red rises in the mortar", 1.8)
	restore_local_color(_flowers)
	_flowers.prop_label = "RED FLOWERS"
	_flowers.set_tint(Color(1.15, 0.95, 0.92))
	Audio.play_sfx(Audio.Sfx.CHIME)
	await wait(1.6)

	GameState.unlock_lore("sacred_colors")
	await complete_chapter([
		"Red climbs the walls of the mortar, and then the hall remembers itself — wood, flower, and the colour of courage.",
		{"speaker": "S'lang", "text": "This house is no longer gray. The ridge still is."},
		"The House of the Golden Sun is dark and waiting.",
	])


func _release_minions(offset := Vector2.ZERO) -> void:
	for cell in MINION_CELLS:
		spawn_minion(cell + offset, {"max_health": 60.0, "speed": 78.0})
