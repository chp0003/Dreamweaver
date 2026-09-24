extends "res://scripts/chapters/house_quest.gd"
## Chapter 2 - House of Red Courage.
##
## Same language as Chapter 1: one painted 16:9 plate. Garden porch in
## front, storage hall beyond. Work line:
##   1 vines across the step (cut) → 2 hall aisles (hulo) → 3 mortar (mash).

const ROOT_TOTAL := 5
const VINE_COUNT := 5
const ROOT_AMBUSH_RANGE := 128.0
const GUARDS_PER_ROOT := 2
const ROOT_SHADOW_CAP := 8
const PIGMENT_MASHING := "res://scenes/minigames/PigmentMashing.tscn"
const COLLISION_SCENE := "res://scenes/world/House2Collision.tscn"
const STEPS: Array[String] = [
	"Speak with the Harvest Queen",
	"Cut the Shadow Vines",
	"Find hulo  ·  5",
	"Crush at the mortar",
]

var _plate: Chapter2Plate
var _vines: Array[ShadowVine] = []
var _vines_cleared := 0
var _vine_barrier: StaticBody2D
var _roots := 0
var _mortar: Node2D
var _mortar_trigger: Interactable
var _queen: PlaceholderProp
var _queen_trigger: Interactable
var _flowers: Node2D
var _vine_anchor: Node2D
var _beacon: QuestBeacon
var _marks: Dictionary = {}
var _pickups: Array[Collectible] = []
var _minions: Array[ShadowMinion] = []
var _root_ambushed: Dictionary = {}
var _ambush_watch := false


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
	_plate = Chapter2Plate.new()
	_plate.name = "Chapter2Plate"
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
	root.name = "House2Collision"
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
		hall.name = "House2Collision"
		root.queue_free()


func _build_work_line() -> void:
	_grow_vines()
	_raise_vine_barrier()

	_mortar = _anchor("MortarAnchor", _plate.mortar_world())
	_mortar_trigger = place_interactable("Crush the roots", _plate.mortar_reach_world(), {
		"enabled": false,
		"radius": 88.0,
	})
	_mark_station("mortar", _mortar, "MASH", Vector2(0.0, -72.0))
	if _color_anchor != null:
		_color_anchor.global_position = _plate.mortar_world()

	_flowers = _anchor("FlowersAnchor", _plate.flowers_world())
	_vine_anchor = _anchor("VineAnchor", _plate.barrier_world())
	_mark_station("vines", _vine_anchor, "VINES", Vector2(0.0, -80.0))

	_queen = place_prop("HARVEST QUEEN", _plate.queen_world(), {
		"texture_path": "res://assets/images/characters/harvest_queen.png",
		"prop_size": Vector2(118.0, 200.0),
		"body_color": Color(0.18, 0.32, 0.16),
		"accent_color": Color(0.78, 0.22, 0.16),
		"float_amplitude": 0.0,
		"show_label": false,
		"blocks_movement": false,
		"cast_shadow": false,
	})
	_queen.set_tint(Color(0.52, 0.52, 0.54))
	_queen_trigger = place_interactable("Speak with the Harvest Queen", _plate.queen_reach_world(), {
		"enabled": false,
		"radius": 96.0,
	})
	_mark_station("queen", _queen, "HARVEST QUEEN", Vector2(0.0, -108.0))


func _grow_vines() -> void:
	var count := mini(VINE_COUNT, Chapter2Plate.VINE_UVS.size())
	for i in range(count):
		var vine := ShadowVine.new()
		vine.name = "ShadowVine_%d" % i
		vine.max_health = 70.0
		vine.art_size = Vector2(110.0, 200.0)
		if world != null:
			world.add_child(vine)
		else:
			add_child(vine)
		vine.global_position = _plate.vine_world(i)
		vine.cleared.connect(_on_vine_cleared)
		_vines.append(vine)


func _raise_vine_barrier() -> void:
	_vine_barrier = StaticBody2D.new()
	_vine_barrier.name = "VineBarrier"
	_vine_barrier.collision_layer = PhysicsLayers.LAYER_WORLD
	_vine_barrier.collision_mask = PhysicsLayers.MASK_WORLD_STATIC
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(460.0, 48.0)
	shape.shape = box
	_vine_barrier.add_child(shape)
	if world != null:
		world.add_child(_vine_barrier)
	else:
		add_child(_vine_barrier)
	_vine_barrier.global_position = _plate.barrier_world() + Vector2(0.0, 6.0)


func _drop_vine_barrier() -> void:
	if _vine_barrier != null and is_instance_valid(_vine_barrier):
		_vine_barrier.queue_free()
	_vine_barrier = null


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


func _scatter_roots() -> void:
	for uv in Chapter2Plate.ROOT_UVS:
		var root := place_collectible("Hulo Root", _plate.uv_to_global(uv), {
			"texture_path": "res://assets/images/props/hulo_root.png",
			"tint": Color(0.72, 0.38, 0.28),
			"score_value": 60,
			"highlight": true,
			"pickup_radius": 34.0,
		})
		root.collected.connect(_on_root_collected)
		_pickups.append(root)


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
		"queen":
			target = _queen
		"vines":
			target = _vine_anchor
		"mortar":
			target = _mortar
	if _beacon != null:
		_beacon.pin(target)


func _set_steps(index: int, gather_count := -1) -> void:
	var steps := STEPS.duplicate()
	steps[1] = "Cut the Shadow Vines  ·  %d / %d" % [_vines_cleared, VINE_COUNT]
	if gather_count >= 0:
		steps[2] = "Find hulo  ·  %d / %d" % [gather_count, ROOT_TOTAL]
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", steps, index)


func _clear_steps() -> void:
	if hud != null and hud.has_method("set_quest_steps"):
		hud.call("set_quest_steps", [], 0)


func _on_vine_cleared(vine: ShadowVine) -> void:
	_vines.erase(vine)
	_vines_cleared += 1
	_set_steps(1)


func _on_root_collected(pickup: Collectible) -> void:
	_pickups.erase(pickup)
	_roots += 1
	_set_steps(2, _roots)


func apply_restored_color() -> void:
	super.apply_restored_color()
	if _plate != null:
		_plate.set_restore(1.0)
	if _queen != null:
		_queen.set_tint(Color.WHITE)


func _run_chapter() -> void:
	if player != null and not player.has_staff:
		player.has_staff = true
	Audio.set_ambience(0.38, 0.0)
	_set_steps(0)
	_light_station("queen")
	objective("The Harvest Queen waits on the porch. Walk to her and press [E].")
	await wait(0.35)
	await say([
		"The porch is a garden, same as the last house. A woman in green stands in the gray — the forest still knows her, even if the hall does not.",
		{"speaker": "S'lang", "text": "If she is the land, then the thorns are a wound in her."},
	])
	_queen_trigger.set_enabled(true)
	await _queen_trigger.interacted
	_queen_trigger.set_enabled(false)
	_grant_life_thread()
	await say([
		{"speaker": "The Harvest Queen", "text": "I am the abundance of this land. The red in the root, the grain in the basket, the cycle that weaving copies."},
		{"speaker": "S'lang", "text": "The step is blocked. Wrong plants."},
		{"speaker": "The Harvest Queen", "text": "Life-Thread. A stitch that grows until it bursts. Press [Q]. The corrupted thorns will come apart like a harvest, not a fight. Then the red dye can be remembered."},
	])
	GameState.unlock_lore("harvest_queen")

	_set_steps(1)
	_light_station("vines", "[Q]")
	objective("Vines block the step. Press [Q] for Life-Thread, or [Space] to cut.")
	await until(func() -> bool: return _vines_cleared >= VINE_COUNT)
	_drop_vine_barrier()
	if _beacon != null:
		_beacon.clear()
	Audio.play_sfx(Audio.Sfx.CHIME)
	await say([
		"The vines come apart like a knot pulled from the wrong end, and the hall is only a hall again — crates, jars, the smell of old root.",
		{"speaker": "S'lang", "text": "Five. The old ones called it loko — hulo. It hides in the aisles until you look twice."},
	])

	_scatter_roots()
	_set_steps(2, 0)
	_light_station("")
	if _beacon != null:
		_beacon.clear()
	objective("Find 5 red roots in the hall. Shadows rise when you get close — press [Space] to swing.")
	_arm_root_ambushes()
	await until(func() -> bool: return _roots >= ROOT_TOTAL)
	_disarm_root_ambushes()
	if _beacon != null:
		_beacon.clear()
	_clear_minions()

	await say([
		{"speaker": "S'lang", "text": "Five roots. Beaten in a mortar until they give the colour away."},
		{"speaker": "The Harvest Queen", "text": "Courage is not found. It is grown, crushed, and sown again. That is the cycle."},
	])

	_set_steps(3)
	_light_station("mortar")
	_mortar_trigger.set_enabled(true)
	objective("The mortar at the back of the hall. Press [E] to crush the hulo.")
	await _mortar_trigger.interacted
	_mortar_trigger.set_enabled(false)

	var mashed: bool = await run_mini_game(PIGMENT_MASHING)
	if not mashed:
		await say([
		{"speaker": "The Harvest Queen", "text": "The pestle struck dry stone. Come back when the root has given its red."},
		])
		_clear_steps()
		if _beacon != null:
			_beacon.clear()
		await fail_chapter()
		return

	set_player_input(false)
	banner("Red rises in the mortar", 1.8)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if _plate != null:
		_plate.bloom_restore(3.2)
	restore_local_color(_flowers)
	if _beacon != null:
		_beacon.clear()
	for key in _marks:
		var mark: StationMarker = _marks[key]
		if mark != null:
			mark.set_lit(false)
	await wait(3.2)
	_clear_steps()
	banner("House of the Golden Sun unlocked", 2.2)
	await wait(1.6)

	GameState.unlock_lore("sacred_colors")
	await complete_chapter([
		"Red climbs the stone, then the hall remembers itself — wood, flower, and the colour of courage.",
		{"speaker": "The Harvest Queen", "text": "The land remembers its plenty. Carry the red. The next house has forgotten the sun."},
		{"speaker": "Fun Kdungon", "text": "Leave by the porch at the garden's edge. The House of the Golden Sun is dark, and it will stay dark until you bring it light."},
	])


func _grant_life_thread() -> void:
	if _queen != null:
		_queen.set_tint(Color.WHITE)
		Fx.hit_flash(_queen, Color(0.82, 0.28, 0.18))
		Fx.fiber_burst(_queen, Color(0.78, 0.22, 0.16))
	Audio.play_sfx(Audio.Sfx.CHIME)
	GameState.add_item("life_thread")
	if player != null and is_instance_valid(player):
		player.has_life_thread = true


func _arm_root_ambushes() -> void:
	_ambush_watch = true
	_root_ambushed.clear()
	if host != null:
		host.max_shadows_alive = ROOT_SHADOW_CAP
	set_process(true)


func _disarm_root_ambushes() -> void:
	_ambush_watch = false
	set_process(false)


func _process(_delta: float) -> void:
	if not _ambush_watch:
		return
	_try_root_ambushes()


func _try_root_ambushes() -> void:
	if player == null or not is_instance_valid(player):
		return
	for pickup in _pickups:
		if pickup == null or not is_instance_valid(pickup):
			continue
		var key := pickup.get_instance_id()
		if bool(_root_ambushed.get(key, false)):
			continue
		if Iso.iso_distance(player.global_position, pickup.global_position) > ROOT_AMBUSH_RANGE:
			continue
		_root_ambushed[key] = true
		_spawn_root_guards(pickup.global_position)


func _spawn_root_guards(at: Vector2) -> void:
	var offsets: Array[Vector2] = [
		Vector2(-42.0, -18.0),
		Vector2(38.0, 16.0),
		Vector2(0.0, -36.0),
	]
	var spawned := 0
	for offset in offsets:
		if spawned >= GUARDS_PER_ROOT:
			break
		var style := "chaser" if spawned == 0 else "stalker"
		var minion := place_minion(at + offset, {
			"max_health": 52.0,
			"speed": 80.0 if style == "chaser" else 74.0,
			"combat_style": style,
			"spawn_delay": 0.2 + float(spawned) * 0.12,
		})
		if minion == null:
			continue
		_minions.append(minion)
		spawned += 1


func _clear_minions() -> void:
	for minion in _minions:
		if minion != null and is_instance_valid(minion):
			minion.queue_free()
	_minions.clear()
	_root_ambushed.clear()
	if host != null:
		host.max_shadows_alive = 4
