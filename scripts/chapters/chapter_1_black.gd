extends "res://scripts/chapters/house_quest.gd"
## Chapter 1 - House of the Black Foundation.
##
## Same language as the tutorial and the hub: one painted 16:9 plate.
## Warm Guno Bong hall, Fun Kdungon by the loom, garden in the
## foreground. Work line on the far wall:
##   1 Fun Kdungon (remember) → 2 garden/hall strands → 3 rack (sort) → 4 vat (join the abaca).

const STRAND_TOTAL := 10
const FIBER_SORTING := "res://scenes/minigames/FiberSorting.tscn"
const TNALAK_WEAVING := "res://scenes/minigames/TnalakWeaving.tscn"
const COLLISION_SCENE := "res://scenes/world/House1Collision.tscn"
const STEPS: Array[String] = [
	"Speak with Fun Kdungon",
	"Find abaca  ·  10",
	"Sort at the rack",
	"Weave the T'nalak",
]

var _plate: Chapter1Plate
var _spirit: PlaceholderProp
var _spirit_trigger: Interactable
var _rack: Node2D
var _rack_trigger: Interactable
var _vat: Node2D
var _vat_trigger: Interactable
var _collected := 0
var _beacon: QuestBeacon
var _marks: Dictionary = {}
var _strands: Array[Collectible] = []
## Latest finished cloth payload from TnalakCloth.to_dictionary().
var _finished_cloth: Dictionary = {}


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


func _mount_plate() -> void:
	var standalone := host != null and host.register_as_current_chapter
	if standalone:
		if host.floor_node != null:
			host.floor_node.visible = false
		if host.stage != null:
			host.stage.visible = false
	_plate = Chapter1Plate.new()
	_plate.name = "Chapter1Plate"
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
		return
	var root := packed.instantiate() as Node2D
	root.name = "House1Collision"
	var hall := root.get_node_or_null("HallCollision") as StaticBody2D
	if hall != null:
		hall.set("show_collision_debug", false)
	# StaticBody2D must sit on World (same branch as the player) or
	# CharacterBody2D.move_and_slide() never hits it — same as HubCollision.
	var host_node: Node2D = world if world != null else self
	host_node.add_child(root)
	if _plate != null:
		root.global_transform = _plate.global_transform
	if hall != null and hall.get_parent() != host_node:
		var xf := hall.global_transform
		hall.reparent(host_node)
		hall.global_transform = xf
		hall.name = "House1Collision"
		root.queue_free()


func _build_work_line() -> void:
	_spirit = place_prop("FUN KDUNGON", _plate.spirit_world(), {
		"texture_path": "res://assets/images/characters/fun_kdungon.png",
		"prop_size": Vector2(110.0, 188.0),
		"body_color": Palette.BLACK_CHARCOAL,
		"accent_color": Palette.GOLD_SACRED,
		"float_amplitude": 0.0,
		"show_label": false,
		"blocks_movement": false,
		"cast_shadow": true,
	})
	_spirit_trigger = place_interactable("Speak with Fun Kdungon", _plate.spirit_reach_world(), {
		"enabled": false,
		"radius": 96.0,
	})
	_mark_station("spirit", _spirit, "FUN KDUNGON", Vector2(0.0, -96.0))
	_light_spirit()

	_rack = _anchor("RackAnchor", _plate.rack_world())
	_rack_trigger = place_interactable("Sort the strands", _plate.rack_reach_world(), {
		"enabled": false,
		"radius": 90.0,
	})
	_mark_station("rack", _rack, "SORT")

	_vat = _anchor("VatAnchor", _plate.vat_world())
	_vat_trigger = place_interactable("Weave the T'nalak", _plate.vat_reach_world(), {
		"enabled": false,
		"radius": 88.0,
	})
	_mark_station("vat", _vat, "WEAVE")
	if _color_anchor != null:
		_color_anchor.global_position = _plate.vat_world()


func _anchor(anchor_name: String, world_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = anchor_name
	node.position = world_pos
	if world != null:
		world.add_child(node)
	else:
		add_child(node)
	return node


func _light_spirit() -> void:
	if _spirit == null:
		return
	var lamp := PointLight2D.new()
	lamp.name = "GoddessGlow"
	lamp.color = Color(0.82, 0.86, 0.92)
	lamp.energy = 0.42
	lamp.texture_scale = 1.25
	lamp.position = Vector2(0.0, -96.0)
	lamp.texture = _radial_light()
	_spirit.add_child(lamp)


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


func _scatter_strands() -> void:
	var uvs: Array[Vector2] = []
	uvs.append_array(Chapter1Plate.HALL_STRAND_UVS)
	uvs.append_array(Chapter1Plate.GARDEN_STRAND_UVS)
	for uv in uvs:
		var strand := place_collectible("Faded Abaca Strand", _plate.uv_to_global(uv), {
			"texture_path": "res://assets/images/props/abaca_strand.png",
			"tint": Color(0.58, 0.54, 0.48),
			"score_value": 40,
			"highlight": true,
			"pickup_radius": 32.0,
		})
		strand.collected.connect(_on_strand_collected)
		_strands.append(strand)


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


func apply_restored_color() -> void:
	super.apply_restored_color()
	if _plate != null:
		_plate.set_restore(1.0)
	if _spirit != null:
		_spirit.set_tint(Color.WHITE)


func _run_chapter() -> void:
	Audio.set_ambience(0.32, 0.0)
	_set_steps(0)
	_light_station("spirit")
	objective("Fun Kdungon on the hall floor, right of the loom. Walk to her and press [E].")
	await wait(0.35)
	await say([
		"Far wall, left to right: Fun Kdungon, a drying rack, a dye vat. That is the work of this house.",
		{"speaker": "S'lang", "text": "You. The one who put the staff in my hands."},
	])

	_spirit_trigger.set_enabled(true)
	await _spirit_trigger.interacted
	_spirit_trigger.set_enabled(false)

	await say([
		{"speaker": "Fun Kdungon", "text": "Weaver's hands. Then tell me — what comes first?"},
		{"speaker": "S'lang", "text": "The abaca. Strip it, comb it, knot it."},
		{"speaker": "Fun Kdungon", "text": "Good. The grayness took that out of this house. Ten pale strands remain — tucked, faded, easy to walk past. Search the hall and the garden. Bring them here."},
	])
	GameState.unlock_lore("abaca")

	_scatter_strands()
	_set_steps(1, 0)
	_light_station("")
	if _beacon != null:
		_beacon.clear()
	objective("Search the hall and the garden below. Strands hide by the loom, the vat, and the plant beds.")
	await until(func() -> bool: return _collected >= STRAND_TOTAL)
	if _beacon != null:
		_beacon.clear()

	await say([
		{"speaker": "S'lang", "text": "Ten. Half of these will snap under tension."},
		{"speaker": "Fun Kdungon", "text": "Then sort them. Brittle from viable. The rack in the centre is waiting."},
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
			{"speaker": "Fun Kdungon", "text": "You hurried, and the fibre knows it. Abaca punishes hurry."},
		])
		_clear_steps()
		if _beacon != null:
			_beacon.clear()
		await fail_chapter()
		return

	await say([
		{"speaker": "Fun Kdungon", "text": "There. The fibre remembers you."},
		{"speaker": "Fun Kdungon", "text": "The vat on the right. The sorted fibre is waiting. Click a strand, then its match. Four pairs make a cloth."},
	])

	_set_steps(3)
	_light_station("vat")
	_vat_trigger.set_enabled(true)
	objective("The vat on the right. Press [E] to match the sorted abaca into a cloth.")
	await _vat_trigger.interacted
	_vat_trigger.set_enabled(false)

	_finished_cloth = {}
	var woven: bool = await run_mini_game(TNALAK_WEAVING, {}, func(game: Node) -> void:
		if game.has_signal("cloth_completed"):
			game.cloth_completed.connect(func(cloth: Variant) -> void:
				if cloth != null and cloth.has_method("to_dictionary"):
					_finished_cloth = cloth.to_dictionary()
				GameState.add_item("tnalak_cloth")
			)
	)
	if not woven:
		await say([
			{"speaker": "Fun Kdungon", "text": "The cloth is not yet on the loom. Come back when the last strand is in."},
		])
		_clear_steps()
		if _beacon != null:
			_beacon.clear()
		await fail_chapter()
		return

	set_player_input(false)
	banner("The first T'nalak holds", 1.8)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if _plate != null:
		_plate.bloom_restore(3.2)
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
	banner("House of Red Courage unlocked", 2.2)
	await wait(1.6)

	await complete_chapter([
		"The cloth is on the loom. Each sorted strand found its twin.",
		{"speaker": "Fun Kdungon", "text": "The foundation is laid. A T'nalak remembers. I will not let this house forget again."},
		{"speaker": "Fun Kdungon", "text": "Leave by the porch at the garden's edge. The House of Red Courage is next — something has grown across its door."},
	])
