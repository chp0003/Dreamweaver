extends "res://scripts/chapters/house_quest.gd"
## Chapter 3 - House of the Golden Sun.
##
## Same language as Chapters 1 and 2: one painted 16:9 plate. Garden porch
## in front, brass hall beyond. Work line:
##   1 wall torches (chime) → 2 brass mirrors (beam) → 3 spindle (Pattern Memory).

const PATTERN_MEMORY := "res://scenes/minigames/PatternMemory.tscn"
const COLLISION_SCENE := "res://scenes/world/House3Collision.tscn"
const MirrorPuzzle := preload("res://scripts/world/brass_mirror_puzzle.gd")
const STEPS: Array[String] = [
	"Wake the wall torches",
	"Turn the brass mirrors",
	"Recall the pattern",
]

const TORCH_REACH := 210.0

var _plate: Chapter3Plate
var _torches: Array[Dictionary] = []
var _torches_lit := 0
var _light_raised := false
var _puzzle: MirrorPuzzle
var _spindle: Node2D
var _spindle_trigger: Interactable
var _mirror_anchor: Node2D
var _mirror_props: Array[Node2D] = []
var _beacon: QuestBeacon
var _marks: Dictionary = {}
var _sky_streaks: Node2D


func uses_painted_plate() -> bool:
	return true


func player_spawn_world() -> Vector2:
	if _plate != null:
		return _plate.spawn_world()
	return super.player_spawn_world()


func threshold_world() -> Vector2:
	if _plate != null:
		return _plate.exit_world()
	return Vector2.ZERO


func plate_world_rect() -> Rect2:
	if _plate != null:
		return _plate.global_world_rect()
	return Rect2()


func plate_camera_zoom() -> float:
	return 0.86


func painted_player_scale() -> float:
	return 2.6


func _build_world() -> void:
	_mount_plate()
	_build_work_line()
	_beacon = QuestBeacon.new()
	_beacon.name = "QuestBeacon"
	if world != null:
		world.add_child(_beacon)
	else:
		add_child(_beacon)
	if host != null and host.register_as_current_chapter:
		_bind_host_camera()


func _process(_delta: float) -> void:
	if _plate != null and player != null and is_instance_valid(player):
		_plate.set_player_world(player.global_position)


func _mount_plate() -> void:
	var standalone := host != null and host.register_as_current_chapter
	if standalone:
		if host.floor_node != null:
			host.floor_node.visible = false
		if host.stage != null:
			host.stage.visible = false
	_plate = Chapter3Plate.new()
	_plate.name = "Chapter3Plate"
	_plate.position = Iso.cell_to_world(region_origin)
	add_child(_plate)
	if world != null:
		_plate.attach_solids(world)
	_mount_collision()
	if standalone and player != null:
		var spawn := _plate.spawn_world()
		player.global_position = spawn
		host._spawn_position = spawn


func _mount_collision() -> void:
	var packed := load(COLLISION_SCENE) as PackedScene
	if packed == null:
		if _plate != null:
			_plate.add_fallback_solids()
			if world != null:
				_plate.attach_solids(world)
		return
	var root := packed.instantiate() as Node2D
	root.name = "House3Collision"
	var hall := root.get_node_or_null("HallCollision") as StaticBody2D
	if hall != null:
		hall.set("show_collision_debug", false)
	var host_node: Node2D = world if world != null else self
	host_node.add_child(root)
	if _plate != null:
		root.global_transform = _plate.global_transform
	if hall != null and hall.get_parent() != host_node:
		var xf := hall.global_transform
		hall.reparent(host_node)
		hall.global_transform = xf
		hall.name = "House3Collision"
		root.queue_free()


func _build_work_line() -> void:
	_build_torches()
	_build_mirror_puzzle()

	_spindle = _anchor("SpindleAnchor", _plate.spindle_world())
	_spindle_trigger = place_interactable("Touch the Golden Spindle", _plate.spindle_reach_world(), {
		"enabled": false,
		"radius": 88.0,
	})
	_mark_station("spindle", _spindle, "SPINDLE", Vector2(0.0, -92.0))
	if _color_anchor != null:
		_color_anchor.global_position = _plate.spindle_world()

	var torch_anchor := _anchor("TorchAnchor", _plate.torch_world(2))
	_mark_station("torches", torch_anchor, "TORCHES", Vector2(0.0, -80.0))


func _build_torches() -> void:
	for i in range(Chapter3Plate.TORCH_UVS.size()):
		var prop := _anchor("WallTorch_%d" % i, _plate.torch_world(i))
		var light := PointLight2D.new()
		light.name = "TorchLight"
		light.texture = _light_texture()
		light.color = Color(1.0, 0.82, 0.5)
		light.energy = 0.0
		light.texture_scale = 2.4
		light.position = Vector2(0.0, -48.0)
		prop.add_child(light)
		_torches.append({"prop": prop, "light": light, "lit": false, "index": i})

	if player != null:
		player.chimed.connect(_on_chime)


func _build_mirror_puzzle() -> void:
	_puzzle = MirrorPuzzle.new()
	_puzzle.name = "MirrorPuzzle"
	_puzzle.emitter_cell = Chapter3Plate.EMITTER_CELL
	_puzzle.emitter_direction = Vector2i(1, 0)
	_puzzle.spindle_cell = Chapter3Plate.SPINDLE_CELL
	_puzzle.max_extent = 8
	_puzzle.cell_to_world = Callable(_plate, "puzzle_world")
	if world != null:
		world.add_child(_puzzle)
	else:
		add_child(_puzzle)
	_puzzle.z_as_relative = false
	_puzzle.z_index = -8

	var facings: Array[int] = [
		MirrorPuzzle.Facing.SLASH,
		MirrorPuzzle.Facing.SLASH,
		MirrorPuzzle.Facing.BACKSLASH,
	]
	for i in range(Chapter3Plate.MIRROR_CELLS.size()):
		var cell: Vector2i = Chapter3Plate.MIRROR_CELLS[i]
		var prop := _spawn_mirror(cell)
		var trigger := place_interactable("Turn the brass mirror",
			_plate.puzzle_world(cell) + Vector2(0.0, 18.0), {
				"enabled": false,
				"radius": 72.0,
			})
		_puzzle.add_mirror(cell, facings[i], prop, trigger)

	var decoy := _spawn_mirror(Chapter3Plate.DECOY_CELL)
	var decoy_trigger := place_interactable("Turn the brass mirror",
		_plate.puzzle_world(Chapter3Plate.DECOY_CELL) + Vector2(0.0, 18.0), {
			"enabled": false,
			"radius": 72.0,
		})
	_puzzle.add_mirror(Chapter3Plate.DECOY_CELL, MirrorPuzzle.Facing.SLASH, decoy, decoy_trigger)
	_puzzle.visible = false
	_puzzle.modulate.a = 0.0
	_puzzle.trace_beam()

	_mirror_anchor = _anchor("MirrorAnchor", _plate.puzzle_world(Chapter3Plate.MIRROR_CELLS[1]))
	_mark_station("mirrors", _mirror_anchor, "MIRRORS", Vector2(0.0, -80.0))


func _spawn_mirror(cell: Vector2i) -> BrassMirrorStand:
	var stand := BrassMirrorStand.new()
	stand.name = "BrassMirror_%d_%d" % [cell.x, cell.y]
	if world != null:
		world.add_child(stand)
	else:
		add_child(stand)
	stand.global_position = _plate.puzzle_world(cell)
	stand.visible = false
	stand.modulate.a = 0.0
	_mirror_props.append(stand)
	return stand


func _anchor(anchor_name: String, world_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = anchor_name
	if world != null:
		world.add_child(node)
	else:
		add_child(node)
	node.global_position = world_pos
	return node


func _bind_host_camera() -> void:
	if host == null or _plate == null:
		return
	host.camera_limit_rect = _plate.global_world_rect()
	var z := plate_camera_zoom()
	var rect := _plate.global_world_rect()
	if host.camera != null:
		host.camera.zoom = Vector2(z, z)
		var view := host.get_viewport_rect().size / Vector2(z, z)
		host.camera_follows_player = view.x < rect.size.x or view.y < rect.size.y
		if host.camera_follows_player and player != null:
			host.camera.global_position = player.global_position
		else:
			host.camera.global_position = rect.get_center()
		if player != null and player.has_method("apply_depth_scale"):
			player.apply_depth_scale(painted_player_scale())
	host.apply_camera_world_limits()
	host._clamp_camera()


func _mark_station(id: String, anchor: Node2D, title: String, offset := Vector2(0.0, 2.0)) -> void:
	if anchor == null:
		return
	var mark := StationMarker.new()
	mark.title = title
	anchor.add_child(mark)
	mark.position = offset
	_marks[id] = mark


func _light_station(id: String, action := "[E]") -> void:
	for key in _marks:
		var mark: StationMarker = _marks[key]
		if mark != null:
			mark.set_lit(str(key) == id, action)
	var target: Node2D = null
	match id:
		"torches":
			target = _next_unlit_torch()
		"mirrors":
			target = _mirror_anchor
		"spindle":
			target = _spindle
	if _beacon != null:
		_beacon.pin(target)


func _next_unlit_torch() -> Node2D:
	for torch in _torches:
		if not bool(torch["lit"]):
			return torch["prop"] as Node2D
	return null


func _set_mirror_triggers(on: bool) -> void:
	if _puzzle != null:
		_puzzle.set_triggers_enabled(on)


func _set_steps(index: int, gather_count := -1) -> void:
	var steps := STEPS.duplicate()
	steps[0] = "Wake the wall torches  ·  %d / %d" % [_torches_lit, _torches.size()]
	if gather_count >= 0:
		steps[1] = "Turn the brass mirrors"
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", steps, index)


func _clear_steps() -> void:
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", [], 0)


func _on_chime(origin: Vector2, _radius: float) -> void:
	for torch in _torches:
		if bool(torch["lit"]):
			continue
		var prop := torch["prop"] as Node2D
		if origin.distance_to(prop.global_position) > TORCH_REACH:
			continue
		torch["lit"] = true
		_torches_lit += 1
		GameState.add_score(50)

		var light := torch["light"] as PointLight2D
		var tween := create_tween()
		tween.tween_property(light, "energy", 1.35, 0.6)
		if _plate != null:
			_plate.set_torch_energy(int(torch["index"]), 1.0)

		_set_steps(0)
		if _beacon != null and not _light_raised:
			var next := _next_unlit_torch()
			if next != null:
				_beacon.pin(next)

	if _torches_lit >= _torches.size():
		_raise_the_light()


func _raise_the_light() -> void:
	if _light_raised:
		return
	_light_raised = true
	if _plate != null:
		_plate.bloom_veil_out(1.6)
	_reveal_mirrors()


func apply_restored_color() -> void:
	super.apply_restored_color()
	if _plate != null:
		_plate.set_restore(1.0)
		_plate.set_veil(0.0)
	_reveal_mirrors(true)


func _reveal_mirrors(settled := false) -> void:
	if _puzzle != null:
		_puzzle.visible = true
		_puzzle.set_settled(settled)
		if _puzzle.modulate.a < 0.99:
			var beam := create_tween()
			beam.tween_property(_puzzle, "modulate:a", 1.0, 0.8)
	for prop in _mirror_props:
		if prop == null or not is_instance_valid(prop):
			continue
		prop.visible = true
		if prop.modulate.a >= 0.99:
			continue
		var tween := create_tween()
		tween.tween_property(prop, "modulate:a", 1.0, 0.7)


func _run_chapter() -> void:
	if player != null:
		if not player.has_staff:
			player.has_staff = true
		player.set_light_enabled(true)
	Audio.set_ambience(0.34, 0.0)
	_set_steps(0)
	_light_station("torches", "[Q]")
	objective("The hall is dark. Sound the sonic chime near the wall torches. Press [Q].")
	await wait(0.35)
	await say([
		"The porch is a garden, same as the last house. Past the step the hall is not night — it is the absence of the idea of light.",
		{"speaker": "S'lang", "text": "The staff is a circle of floor, and nothing outside it."},
		{"speaker": "Fun Kdungon", "text": "The lewet is brass, daughter. Brass sings. Strike the air with it and the old torches will answer."},
	])
	GameState.unlock_lore("lewet_staff")

	if hud != null and hud.has_method("show_chime_meter"):
		hud.call("show_chime_meter", true)
	await until(func() -> bool: return _torches_lit >= _torches.size())
	if hud != null and hud.has_method("show_chime_meter"):
		hud.call("show_chime_meter", false)

	await wait(1.1)
	await say([
		"Four torches burn. Brass mirrors on the floor, a shaft of daylight from the left window, and at the centre a spindle wound with dead gold.",
		{"speaker": "S'lang", "text": "The light comes in there. And it stops at the first mirror because the mirror is facing the wrong way."},
	])

	_set_steps(1)
	_light_station("mirrors")
	_set_mirror_triggers(true)
	objective("Turn the brass mirrors until the window light reaches the Golden Spindle. [E]")
	if _puzzle != null and not _puzzle.is_solved():
		await _puzzle.solved

	Audio.play_sfx(Audio.Sfx.CHIME)
	await say([
		"The beam turns once, twice, three times, and lands square on the spindle. The dead gold on it catches and holds.",
		{"speaker": "Golden Spindle", "text": "Light I have. Memory I do not. Show me the snake that crosses this floor, weaver, and I will turn again."},
	])

	_set_steps(2)
	_light_station("spindle")
	_spindle_trigger.set_enabled(true)
	objective("The Golden Spindle at the back of the hall. Press [E] to recall its pattern.")
	await _spindle_trigger.interacted
	_spindle_trigger.set_enabled(false)

	var remembered: bool = await run_mini_game(PATTERN_MEMORY)
	if not remembered:
		await say([
			{"speaker": "Golden Spindle", "text": "That is not the path. The snake does not double back on itself."},
		])
		_clear_steps()
		if _beacon != null:
			_beacon.clear()
		await fail_chapter()
		return

	set_player_input(false)
	banner("The spindle turns", 1.8)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if _plate != null:
		_plate.bloom_restore(3.2)
		_plate.set_veil(0.0)
	restore_local_color(_spindle)
	_build_sky_streaks()
	if _puzzle != null:
		_puzzle.set_settled(true)
		_puzzle.set_triggers_enabled(false)
	if _beacon != null:
		_beacon.clear()
	for key in _marks:
		var mark: StationMarker = _marks[key]
		if mark != null:
			mark.set_lit(false)
	await wait(3.2)
	_clear_steps()
	banner("House of the Dream Ancestors unlocked", 2.2)
	await wait(1.6)

	GameState.unlock_lore("guno_bong")
	await complete_chapter([
		"Gold runs up the spindle, off the spindle, out through the high slot — and the hall remembers morning.",
		{"speaker": "S'lang", "text": "Black. Red. Gold. Three, and the cloth still needs a pattern to be woven into."},
		{"speaker": "Fun Kdungon", "text": "Leave by the porch at the garden's edge. What remains is knowledge — and that is kept in the House of the Dream Ancestors."},
	])


func _build_sky_streaks() -> void:
	if _plate == null:
		return
	_sky_streaks = Node2D.new()
	_sky_streaks.name = "SkyStreaks"
	_sky_streaks.z_index = -60
	_plate.add_child(_sky_streaks)

	for i in range(7):
		var streak := ColorRect.new()
		streak.color = Color(0.98, 0.84, 0.44, 0.0)
		streak.size = Vector2(randf_range(220.0, 480.0), randf_range(5.0, 12.0))
		streak.position = Vector2(randf_range(-520.0, 80.0), randf_range(-380.0, -40.0))
		streak.rotation = deg_to_rad(26.0)
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sky_streaks.add_child(streak)

		var tween := create_tween()
		tween.tween_interval(float(i) * 0.09)
		tween.tween_property(streak, "color:a", randf_range(0.16, 0.36), 0.9)


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
