extends ChapterBase
## Tutorial - "S'lang's Awakening".
##
## Same language as the hub: one painted plate you walk on. The room starts
## dusk-bleached; the Lewet Staff is the lantern. Take it, and colour returns
## to the house — a small Color Restoration before the ridge.

var _staff: PlaceholderProp
var _staff_trigger: Interactable
var _goddess: PlaceholderProp
var _tutorial: TutorialManager
var _plate: TutorialPlate


func at_uv(uv: Vector2) -> Vector2:
	if _plate != null:
		return _plate.uv_to_global(uv)
	return Iso.cell_to_world(uv)


func creep_world(index: int) -> Vector2:
	if _plate != null:
		return _plate.creep_world(index)
	return Iso.cell_to_world(Vector2(-4.5, 1.2) if index == 0 else Vector2(4.5, 1.6))


func strand_world() -> Vector2:
	if _plate != null:
		return _plate.strand_world()
	return Iso.cell_to_world(Vector2(-1.4, 2.4))


func spawn_tutorial_strand() -> Collectible:
	return spawn_collectible("Faded Abaca Strand", Vector2.ZERO, {
		"position": strand_world(),
		"texture_path": "res://assets/images/props/abaca_strand.png",
		"tint": Color(1.0, 0.92, 0.55),
		"score_value": 0,
		"highlight": true,
		"art_size": Vector2(96.0, 36.0),
		"pickup_radius": 56.0,
	})


func _build_world() -> void:
	if floor_node != null:
		floor_node.visible = false
	if stage != null:
		stage.visible = false
	Audio.set_ambience(0.45, 0.0)

	_mount_plate()
	_place_staff()
	_light_staff()

	if player != null:
		player.has_staff = false
		player.set_light_enabled(false)
		var spawn := _plate.spawn_world() if _plate != null else Iso.cell_to_world(player_spawn_cell)
		player.global_position = spawn
		_spawn_position = spawn
	_bind_plate_camera()

	_tutorial = TutorialManager.new()
	_tutorial.name = "TutorialManager"
	add_child(_tutorial)
	_tutorial.setup(self, _staff, _staff_trigger)

	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_view_resized):
		get_viewport().size_changed.connect(_on_view_resized)
	apply_camera_world_limits()
	_clamp_camera()


func painted_player_scale() -> float:
	return 2.6


func plate_camera_zoom() -> float:
	if _plate == null:
		return 0.86
	return cover_zoom_for(_plate.global_world_rect())


func _mount_plate() -> void:
	_plate = TutorialPlate.new()
	_plate.name = "TutorialPlate"
	add_child(_plate)
	move_child(_plate, 0)
	if world != null:
		_plate.attach_solids(world)


func _bind_plate_camera() -> void:
	if _plate == null or camera == null:
		return
	camera_limit_rect = _plate.global_world_rect()
	var z := plate_camera_zoom()
	var rect := camera_limit_rect
	camera.zoom = Vector2(z, z)
	var view := get_viewport_rect().size / Vector2(z, z)
	camera_follows_player = view.x < rect.size.x or view.y < rect.size.y
	if camera_follows_player and player != null:
		camera.global_position = player.global_position
	else:
		camera.global_position = rect.get_center()
	if player != null and player.has_method("apply_depth_scale"):
		player.apply_depth_scale(painted_player_scale())
	apply_camera_world_limits()
	_clamp_camera()


func _place_staff() -> void:
	var staff_pos := _plate.staff_world() if _plate != null else Iso.cell_to_world(Vector2(0.0, -4.0))
	var reach_pos := _plate.staff_reach_world() if _plate != null else Iso.cell_to_world(Vector2(0.0, -3.3))
	_staff = spawn_prop("LEWET STAFF", Vector2.ZERO, {
		"position": staff_pos,
		"texture_path": "res://assets/images/props/lewet_staff.png",
		"prop_size": Vector2(32.0, 112.0),
		"body_color": Color(0.68, 0.52, 0.24),
		"accent_color": Color(0.98, 0.86, 0.46),
		"float_amplitude": 4.0,
		"float_speed": 1.4,
		"show_label": false,
		"blocks_movement": false,
		"cast_shadow": true,
	})
	_staff_trigger = add_interactable("Take the Lewet Staff", Vector2.ZERO, {
		"position": reach_pos,
		"one_shot": true,
		"radius": 78.0,
		"enabled": false,
	})
	if _staff != null:
		ColorRestoration.add_zone("lewet_staff", _staff, 200.0, 1.0)


func _light_staff() -> void:
	if _staff == null:
		return
	var lamp := PointLight2D.new()
	lamp.name = "StaffGlow"
	lamp.color = Color(1.0, 0.86, 0.48)
	lamp.energy = 0.95
	lamp.texture_scale = 1.8
	lamp.position = Vector2(0.0, -48.0)
	lamp.texture = _radial_light()
	_staff.add_child(lamp)


func _radial_light() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _run_chapter() -> void:
	set_player_input(false)
	objective("Listen.")

	await say([
		"S'lang wakes on the mat where she fell asleep, in a room she has known her whole life.",
		{"speaker": "S'lang", "text": "The loom. The mat. Still here. And there — by the wall — the beater kept its gold."},
	])

	_tutorial.begin()
	await _tutorial.finished

	set_player_input(false)
	GameState.unlock_lore("fun_kdungon")
	await _reveal_fun_kdungon()
	await say([
		{"speaker": "Fun Kdungon", "text": "A weaver's beater. Brass on one end, and my hand on the other. Where you carry it, colour follows — a little of it, for now."},
		{"speaker": "Fun Kdungon", "text": "Five houses stand on one highland. Four hold a thing that was lost. The fifth holds what took it."},
		{"speaker": "S'lang", "text": "Then I start at the first."},
	])

	objective("Walk the boardwalk and enter the House of the Black Foundation.")
	SceneFader.fade_to_scene(AccountManager.HUB_SCENE)


func _reveal_fun_kdungon() -> void:
	var where := _plate.goddess_world() if _plate != null else Iso.cell_to_world(Vector2(-1.2, 0.4))
	_goddess = spawn_prop("FUN KDUNGON", Vector2.ZERO, {
		"position": where,
		"texture_path": "res://assets/images/characters/fun_kdungon.png",
		"prop_size": Vector2(110.0, 188.0),
		"body_color": Palette.BLACK_CHARCOAL,
		"accent_color": Palette.GOLD_SACRED,
		"float_amplitude": 0.0,
		"show_label": false,
		"blocks_movement": false,
		"cast_shadow": true,
	})
	_goddess.modulate.a = 0.0
	ColorRestoration.add_zone("fun_kdungon", _goddess, 210.0, 1.0)
	var lamp := PointLight2D.new()
	lamp.name = "GoddessLight"
	lamp.color = Color(1.0, 0.86, 0.48)
	lamp.energy = 1.1
	lamp.texture_scale = 2.4
	lamp.position = Vector2(0.0, -96.0)
	lamp.texture = _radial_light()
	_goddess.add_child(lamp)
	var arrive := create_tween()
	arrive.tween_property(_goddess, "modulate:a", 1.0, 0.9)\
		.set_ease(Tween.EASE_OUT)
	await arrive.finished


func apply_camera_world_limits(which: Node2D = null) -> void:
	if _plate != null and camera != null:
		camera_limit_rect = _plate.global_world_rect()
		_limit_camera_to_rect(camera_limit_rect)
		return
	super.apply_camera_world_limits(which)


func _clamp_camera() -> void:
	if _plate != null and camera != null:
		_clamp_camera_to_rect(_plate.global_world_rect())
		return
	super._clamp_camera()


func _limit_camera_to_rect(rect: Rect2) -> void:
	if camera == null or rect.size.x < 8.0:
		return
	var pad := 8
	camera.limit_left = int(floor(rect.position.x)) - pad
	camera.limit_top = int(floor(rect.position.y)) - pad
	camera.limit_right = int(ceil(rect.end.x)) + pad
	camera.limit_bottom = int(ceil(rect.end.y)) + pad
	camera.limit_smoothed = false


func _clamp_camera_to_rect(rect: Rect2) -> void:
	if camera == null or rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var half := get_viewport_rect().size / (camera.zoom * 2.0)
	var min_x := rect.position.x + half.x
	var max_x := rect.end.x - half.x
	var min_y := rect.position.y + half.y
	var max_y := rect.end.y - half.y
	var pos := camera.global_position
	if min_x > max_x:
		pos.x = rect.get_center().x
	else:
		pos.x = clampf(pos.x, min_x, max_x)
	if min_y > max_y:
		pos.y = rect.get_center().y
	else:
		pos.y = clampf(pos.y, min_y, max_y)
	camera.global_position = pos


func _on_view_resized() -> void:
	_bind_plate_camera()
