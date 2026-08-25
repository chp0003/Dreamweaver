extends "res://scripts/chapters/house_quest.gd"
## Chapter 3 - House of the Golden Sun.
##
## Beats: enter a pitch-dark hall lit only by the staff -> sound the sonic chime
## to wake the ancient wall torches -> rotate the brass mirrors until the light
## beam reaches the Golden Spindle -> pass Pattern Memory -> take the Gold Essence
## and let the golden streaks back into the sky.

const PATTERN_MEMORY := "res://scenes/minigames/PatternMemory.tscn"
const MirrorPuzzle := preload("res://scripts/world/brass_mirror_puzzle.gd")

const DARK := Color(0.1, 0.1, 0.13)
const TORCHLIT := Color(0.52, 0.47, 0.42)
const DAYLIGHT := Color(1.0, 1.0, 1.0)

const TORCH_CELLS: Array[Vector2] = [
	Vector2(-7.0, -7.0),
	Vector2(7.0, -7.0),
	Vector2(-7.0, 5.0),
	Vector2(7.0, 5.0),
]

## Every mirror starts on the wrong facing, so all three must be turned.
const MIRROR_CELLS: Array[Vector2i] = [
	Vector2i(-2, -6),
	Vector2i(-2, -2),
	Vector2i(0, -2),
]

var _modulate: CanvasModulate
var _torches: Array[Dictionary] = []
var _torches_lit := 0
var _light_raised := false
var _puzzle: MirrorPuzzle
var _spindle: PlaceholderProp
var _spindle_trigger: Interactable
var _sky_streaks: Node2D


func _build_world() -> void:
	add_room_bounds(Vector2i(-8, -8), 17, 17)

	# The hall is genuinely dark: a CanvasModulate crushes everything, and the
	# only light in the room is the PointLight2D on S'lang's staff.
	_modulate = CanvasModulate.new()
	_modulate.name = "Darkness"
	_modulate.color = DARK
	add_child(_modulate)

	if player != null:
		player.set_light_enabled(true)

	_build_torches()
	_build_mirror_puzzle()

	spawn_prop("BRASS BELL RACK", Vector2(-6.0, 3.0), {
		"prop_size": Vector2(58.0, 74.0),
		"body_color": Color(0.4, 0.33, 0.18),
		"accent_color": Color(0.7, 0.58, 0.28),
	})
	spawn_prop("SUN-THREAD SPOOLS", Vector2(5.0, 3.0), {
		"prop_size": Vector2(64.0, 44.0),
		"body_color": Color(0.36, 0.31, 0.2),
		"accent_color": Color(0.72, 0.6, 0.3),
	})
	for i in range(3):
		var shaft := spawn_prop("LIGHT SHAFT", Vector2(-4.0 + float(i) * 4.0, -3.0), {
			"prop_size": Vector2(14.0, 140.0),
			"body_color": Color(0.9, 0.78, 0.4, 0.12),
			"accent_color": Color(1.0, 0.88, 0.5),
			"show_label": false,
			"cast_shadow": false,
		})
		shaft.modulate.a = 0.28


func _build_torches() -> void:
	for cell in TORCH_CELLS:
		var prop := spawn_prop("WALL TORCH (cold)", cell, {
			"texture_path": "res://assets/images/props/wall_torch.png",
			"prop_size": Vector2(30.0, 72.0),
			"body_color": Color(0.26, 0.24, 0.22),
			"accent_color": Color(0.44, 0.38, 0.28),
			"show_label": false,
		})

		var light := PointLight2D.new()
		light.name = "TorchLight"
		light.texture = _light_texture()
		light.color = Color(1.0, 0.82, 0.5)
		light.energy = 0.0
		light.texture_scale = 2.6
		light.position = Vector2(0.0, -48.0)
		prop.add_child(light)

		_torches.append({"prop": prop, "light": light, "lit": false})

	if player != null:
		player.chimed.connect(_on_chime)


func _build_mirror_puzzle() -> void:
	_puzzle = MirrorPuzzle.new()
	_puzzle.name = "MirrorPuzzle"
	_puzzle.emitter_cell = Vector2i(-6, -6)
	_puzzle.emitter_direction = Vector2i(1, 0)
	_puzzle.spindle_cell = Vector2i(0, 0)
	_puzzle.position = Iso.cell_to_world(region_origin)
	add_child(_puzzle)

	spawn_prop("LIGHT SHAFT (emitter)", Vector2(-6.0, -6.0), {
		"prop_size": Vector2(34.0, 40.0),
		"body_color": Color(0.5, 0.44, 0.28),
		"accent_color": Color(0.95, 0.85, 0.5),
		"cast_shadow": false,
	})

	for cell in MIRROR_CELLS:
		var prop := spawn_prop("BRASS MIRROR", Vector2(cell), {
			"texture_path": "res://assets/images/props/brass_mirror.png",
			"prop_size": Vector2(46.0, 66.0),
			"body_color": Color(0.44, 0.37, 0.2),
			"accent_color": Color(0.86, 0.74, 0.36),
			"show_label": false,
		})
		var trigger := add_interactable("Rotate mirror", Vector2(cell) + Vector2(0.0, 0.6),
			{"radius": 62.0})
		_puzzle.add_mirror(cell, MirrorPuzzle.Facing.SLASH, prop, trigger)

	# A mirror that is not part of any solution, to make the hall feel real.
	var decoy := spawn_prop("BRASS MIRROR", Vector2(4.0, -6.0), {
		"prop_size": Vector2(46.0, 66.0),
		"body_color": Color(0.44, 0.37, 0.2),
		"accent_color": Color(0.86, 0.74, 0.36),
		"show_label": false,
	})
	var decoy_trigger := add_interactable("Rotate mirror", Vector2(4.0, -5.4), {"radius": 62.0})
	_puzzle.add_mirror(Vector2i(4, -6), MirrorPuzzle.Facing.SLASH, decoy, decoy_trigger)

	_spindle = spawn_prop("GOLDEN SPINDLE", Vector2(0.0, 0.0), {
		"texture_path": "res://assets/images/props/golden_spindle.png",
		"prop_size": Vector2(58.0, 96.0),
		"body_color": Color(0.42, 0.36, 0.2),
		"accent_color": Color(0.95, 0.82, 0.4),
		"float_amplitude": 3.0,
		"float_speed": 1.0,
	})
	_puzzle.set_spindle_prop(_spindle)
	_spindle_trigger = add_interactable("Touch the Golden Spindle", Vector2(0.0, 0.8),
		{"enabled": false, "radius": 70.0})

	_puzzle.trace_beam()


func _on_chime(origin: Vector2, radius: float) -> void:
	for torch in _torches:
		if bool(torch["lit"]):
			continue
		var prop := torch["prop"] as PlaceholderProp
		if Iso.iso_distance(origin, prop.global_position) > radius * 1.6:
			continue
		torch["lit"] = true
		_torches_lit += 1
		prop.prop_label = "WALL TORCH"
		GameState.add_score(50)

		var light := torch["light"] as PointLight2D
		var tween := create_tween()
		tween.tween_property(light, "energy", 1.35, 0.6)

		counter("Torches woken  %d / %d" % [_torches_lit, TORCH_CELLS.size()])

	if _torches_lit >= TORCH_CELLS.size():
		_raise_the_light()


## Once every torch burns, the hall lifts out of total darkness.
func _raise_the_light() -> void:
	if _light_raised:
		return
	_light_raised = true
	var tween := create_tween()
	tween.tween_property(_modulate, "color", TORCHLIT, 1.6)


# --------------------------------------------------------------------------

func _run_chapter() -> void:
	banner("Chapter III\nHouse of the Golden Sun", 2.6)
	objective("Find a way to see in the dark.")
	await wait(1.2)

	await say([
		"The door closes behind her and the dark is total - not night, but the absence of the idea of light.",
		{"speaker": "S'lang", "text": "The staff is glowing. Only the staff. A circle of floor, and nothing outside it."},
		{"speaker": "Fun Kdungon", "text": "The lewet is brass, daughter. Brass sings. Strike the air with it and the old torches will answer - they have only been waiting to be asked."},
	])
	GameState.unlock_lore("lewet_staff")

	counter("Torches woken  0 / %d" % TORCH_CELLS.size())
	objective("Sound the sonic chime near the walls to wake the torches. Press [Q].")
	if hud != null and hud.has_method("show_chime_meter"):
		hud.call("show_chime_meter", true)
	await until(func() -> bool: return _torches_lit >= TORCH_CELLS.size())

	counter("")
	await wait(1.4)
	await say([
		"Four torches burn, and the hall is a hall: brass mirrors on stands, a shaft of daylight cutting in from a high slot, and at the centre a spindle wound with dead gold.",
		{"speaker": "S'lang", "text": "The light comes in there. And it stops at the first mirror because the mirror is facing the wrong way."},
	])

	objective("Rotate the brass mirrors until the beam reaches the Golden Spindle. [E]")
	await _puzzle.solved

	Audio.play_sfx(Audio.Sfx.CHIME)
	await say([
		"The beam turns once, twice, three times, and lands square on the spindle. The dead gold on it catches and holds.",
		{"speaker": "Golden Spindle", "text": "Light I have. Memory I do not. Show me the snake that crosses this floor, weaver, and I will turn again."},
	])

	_spindle_trigger.set_enabled(true)
	objective("Touch the Golden Spindle and recall its pattern. [E]")
	await _spindle_trigger.interacted

	var remembered: bool = await run_mini_game(PATTERN_MEMORY)
	if not remembered:
		await say([
			{"speaker": "Golden Spindle", "text": "That is not the path. The snake does not double back on itself."},
		])
		await fail_chapter()
		return

	set_player_input(false)
	banner("The spindle turns", 1.8)
	var brighten := create_tween()
	brighten.tween_property(_modulate, "color", DAYLIGHT, 2.0)
	restore_local_color(_spindle)
	_build_sky_streaks()
	await wait(2.0)

	GameState.unlock_lore("guno_bong")
	await complete_chapter([
		"Gold runs up the spindle, off the spindle, out through the high slot - and the sky above the House fills with streaks of it, long and warm and unmistakably morning.",
		{"speaker": "S'lang", "text": "Black. Red. Gold. Three, and the cloth still needs a pattern to be woven into."},
		"Three colours held. What remains is knowledge - and that is kept in the House of the Dream Ancestors.",
	])


## Golden light streaks across the zone's sky, drawn as long soft bars.
func _build_sky_streaks() -> void:
	_sky_streaks = Node2D.new()
	_sky_streaks.name = "SkyStreaks"
	_sky_streaks.z_index = -60
	add_child(_sky_streaks)

	for i in range(9):
		var streak := ColorRect.new()
		streak.color = Color(0.98, 0.84, 0.44, 0.0)
		streak.size = Vector2(randf_range(320.0, 760.0), randf_range(6.0, 16.0))
		streak.position = Vector2(randf_range(-900.0, 500.0), randf_range(-620.0, 340.0))
		streak.rotation = deg_to_rad(26.0)
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sky_streaks.add_child(streak)

		var tween := create_tween()
		tween.tween_interval(float(i) * 0.09)
		tween.tween_property(streak, "color:a", randf_range(0.18, 0.42), 0.9)


## Soft round falloff shared by the wall torches.
func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1, 1, 1, 0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
