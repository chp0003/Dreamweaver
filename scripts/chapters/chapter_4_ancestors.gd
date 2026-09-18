extends "res://scripts/chapters/house_quest.gd"
## Chapter 4 - Hall of the Master Weaver.
##
## Beats: the Master Weaver's ghost fades in and refuses the pattern -> four
## ancestor statues each open a T'boli culture quiz (shared 3-strike rule) ->
## the Ablun loom awakens -> Warp Alignment on a woven cloth -> Sacred Master
## Pattern, Lang Dulay lore, and the warning that the Sacred Loom is already
## being unwoven.

const CULTURE_QUIZ := "res://scenes/minigames/CultureQuiz.tscn"
const WARP_ALIGNMENT := "res://scenes/minigames/WarpAlignment.tscn"
const COLLISION_SCENE := "res://scenes/world/House4Collision.tscn"

var _plate: Chapter4Plate
var _ghost: PlaceholderProp
var _ghost_trigger: Interactable
var _ghost_aura: AncestralAura
var _loom_anchor: Node2D
var _loom_trigger: Interactable
var _loom_aura: AncestralAura
var _statue_anchors: Array[Node2D] = []
var _statue_triggers: Array[Interactable] = []
var _statue_auras: Array[AncestralAura] = []
var _answered := 0
var _statue_done: Array[bool] = [false, false, false, false]
var _statue_near: Array[bool] = [false, false, false, false]
var _busy := false
var _beacon: QuestBeacon


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


func _process(_delta: float) -> void:
	if _plate != null and player != null and is_instance_valid(player):
		_plate.set_player_world(player.global_position)
	_refresh_statue_proximity()


func _build_world() -> void:
	_mount_plate()
	_build_hall()
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
	_plate = Chapter4Plate.new()
	_plate.name = "Chapter4Plate"
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
	root.name = "House4Collision"
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
		hall.name = "House4Collision"
		root.queue_free()


func _build_hall() -> void:
	_ghost = place_prop("MASTER WEAVER", _plate.ghost_world(), {
		"texture_path": "res://assets/images/characters/fun_kdungon.png",
		"prop_size": Vector2(110.0, 188.0),
		"body_color": Palette.BLACK_CHARCOAL,
		"accent_color": Palette.GOLD_SACRED,
		"float_amplitude": 4.0,
		"float_speed": 0.85,
		"blocks_movement": false,
		"show_label": false,
		"cast_shadow": false,
	})
	_ghost.modulate = Color(0.92, 0.96, 1.05, 0.0)
	_ghost_aura = AncestralAura.new()
	_ghost_aura.aura_color = Color(0.86, 0.92, 1.0, 0.9)
	_ghost_aura.mote_count = 26
	_ghost.add_child(_ghost_aura)
	_ghost_trigger = place_interactable("Listen to the Master Weaver", _plate.ghost_reach_world(), {
		"enabled": false,
		"radius": 120.0,
	})

	_loom_anchor = _anchor("AblunLoom", _plate.loom_reach_world())
	_loom_aura = AncestralAura.new()
	_loom_aura.aura_color = Color(0.96, 0.88, 0.62, 0.9)
	_loom_aura.mote_count = 20
	_loom_anchor.add_child(_loom_aura)
	_loom_trigger = place_interactable("Sit at the Ablun loom", _plate.loom_reach_world(), {
		"enabled": false,
		"radius": 130.0,
	})
	if _color_anchor != null:
		_color_anchor.global_position = _plate.loom_reach_world()

	for i in range(Chapter4Plate.STATUE_UVS.size()):
		var statue_data := CultureData.statue(i)
		var anchor := _anchor("Statue_%d" % i, _plate.statue_reach_world(i))
		var aura := AncestralAura.new()
		aura.aura_color = Color(0.94, 0.86, 0.58, 0.85)
		aura.mote_count = 14
		anchor.add_child(aura)
		_statue_anchors.append(anchor)
		_statue_auras.append(aura)
		var trigger := place_interactable("Question %s" % str(statue_data.get("statue", "the statue")),
			_plate.statue_reach_world(i), {
				"enabled": false,
				"radius": 110.0,
			})
		trigger.interacted.connect(_on_statue_interacted.bind(i))
		_statue_triggers.append(trigger)

	var scroll := place_collectible("Lore Scroll: Taboos of the Loom", _plate.scroll_world(), {
		"texture_path": "res://assets/images/lore/lore_taboo.png",
		"tint": Color(0.78, 0.72, 0.56),
		"score_value": 80,
		"lore_id": "taboo",
		"highlight": true,
		"pickup_radius": 36.0,
	})
	scroll.collected.connect(_on_scroll_collected)


func _run_chapter() -> void:
	GameState.mark_house_score()
	banner("Chapter IV\nHall of the Master Weaver", 2.6)
	objective("Enter the hall of the Master Weaver.")
	await wait(1.2)

	await say([
		"Cream stone faces stand around a loom the size of a doorway. None of them were carved. They were people, and then they were remembered, and then they were forgotten into stone.",
	])

	await _appear_ghost()

	await say([
		{"speaker": "Master Weaver", "text": "You carry three colours and no pattern. That is a bag of dye and a bare loom, child, and a bare loom weaves nothing."},
		{"speaker": "S'lang", "text": "Then teach me the pattern."},
		{"speaker": "Master Weaver", "text": "It is not mine to hand you. It is held in four stones, and the stones do not answer strangers. They answer those who know what they are looking at."},
	])

	_ghost_trigger.set_enabled(true)
	objective("Hear the Master Weaver's riddle. [E]")
	_point_beacon(_ghost_trigger)
	await _ghost_trigger.interacted
	_ghost_trigger.set_enabled(false)

	await say([
		{"speaker": "Master Weaver", "text": "Hear them, then. One dreams and does not invent. One is torn from a trunk and made worthy. One is beaten so it may give its colour away. One wove until her hands were maps."},
		{"speaker": "Master Weaver", "text": "Four stones. Four questionings. Answer wrongly three times in this House and you will begin it again — the ancestors do not repeat themselves kindly."},
	])
	var known_opening: Array = GameState.lore.duplicate()
	GameState.unlock_lore("fun_kdungon")
	await _reveal_lore_if_new("fun_kdungon", known_opening)

	for trigger in _statue_triggers:
		trigger.set_enabled(true)
	counter("Statues answered  0 / %d" % _statue_triggers.size())
	objective("Question all four ancestor statues. [E]")
	_point_beacon(_statue_triggers[0])

	await until(func() -> bool:
		return _answered >= _statue_triggers.size() or is_finished())
	if is_finished():
		return

	counter("")
	await say([
		{"speaker": "Master Weaver", "text": "Four stones, four true answers. Now the loom. The dream is already on it — you only have to stop arguing with it."},
	])

	await _awaken_loom()
	_loom_trigger.set_enabled(true)
	objective("Align the warp threads at the Ablun loom. [E]")
	_point_beacon(_loom_trigger)
	await _loom_trigger.interacted
	_loom_trigger.set_enabled(false)

	if not await _align_warps():
		return

	set_player_input(false)
	await _reveal_master_pattern()
	GameState.unlock_lore("lang_dulay")
	await _reveal_lore_if_new("lang_dulay", [])

	if _plate != null:
		_plate.bloom_restore(2.8)
		_plate.bloom_sanctity(1.0, 2.2)
	restore_local_color(_loom_anchor)

	await complete_chapter([
		{"speaker": "Master Weaver", "text": "Lang Dulay held a hundred of these in her head and gave them away to anyone who would sit still and learn. That is the whole of it. Memory is a craft."},
		{"speaker": "Master Weaver", "text": "Black, red, gold, and a pattern to put them in. The great house at the centre is open to you now."},
		{"speaker": "Master Weaver", "text": "The Sacred Loom is already being unwoven."},
	])


func _appear_ghost() -> void:
	if _ghost == null:
		return
	var appear := create_tween()
	appear.tween_property(_ghost, "modulate:a", 0.92, 1.9).set_ease(Tween.EASE_OUT)
	if _ghost_aura != null:
		_ghost_aura.set_energy(1.15, 1.8)
		_ghost_aura.burst()
	Audio.set_ambience(0.35, 11.0)
	await wait(2.0)


func _awaken_loom() -> void:
	if _plate != null:
		var tween := create_tween()
		tween.tween_method(_plate.set_loom_energy, 0.0, 1.4, 1.6).set_ease(Tween.EASE_OUT)
		_plate.bloom_sanctity(0.85, 1.6)
	if _loom_aura != null:
		_loom_aura.set_energy(1.4, 1.2)
		_loom_aura.burst()
	Audio.play_sfx(Audio.Sfx.CHIME)
	banner("The Ablun loom wakes", 1.8)
	await wait(1.7)


func _align_warps() -> bool:
	var dreams: Array[Dictionary] = [
		{
			"difficulty": 0,
			"banner": "First warp — the simple cloth",
			"intro": "Begin with the whole cloth. Nine sections, barely out of place. Slide neighbors until the weave sits.",
		},
		{
			"difficulty": 1,
			"banner": "Second warp — Fun Kdungon",
			"intro": "Fun Kdungon next. Her form is the pattern — slide neighbors until she stands whole again.",
		},
		{
			"difficulty": 2,
			"banner": "Third warp — the Golden Era",
			"intro": "Last: the village as it was dreamed, whole and in colour. Slide every section home, or the dream will not hold.",
			"cloth_path": "res://assets/images/minigames/warp_pattern_hard.png",
		},
	]
	for dream in dreams:
		if is_finished():
			return false
		banner(str(dream["banner"]), 1.6)
		await say([
			{"speaker": "Master Weaver", "text": str(dream["intro"])},
		])
		var setup := {
			"difficulty": int(dream["difficulty"]),
		}
		if dream.has("cloth_path"):
			setup["cloth_path"] = str(dream["cloth_path"])
		var aligned: bool = await run_mini_game(WARP_ALIGNMENT, setup)
		if not aligned:
			await say([
				{"speaker": "Master Weaver", "text": "You forced it. A warp forced is a warp broken. Rest, and come back to it."},
			])
			await fail_chapter()
			return false
	return true


func _on_statue_interacted(index: int) -> void:
	if _busy or is_finished() or _statue_done[index]:
		return
	var statue_data := CultureData.statue(index)
	if statue_data.is_empty():
		return

	_busy = true
	var trigger := _statue_triggers[index]
	trigger.set_enabled(false)
	if _plate != null:
		_plate.set_statue_energy(index, 1.35)
	if index < _statue_auras.size() and _statue_auras[index] != null:
		_statue_auras[index].set_energy(1.2, 0.4)
		_statue_auras[index].burst()

	await say([
		{"speaker": str(statue_data.get("statue", "Statue")),
		 "text": str(statue_data.get("riddle", ""))},
	])

	var known_lore: Array = GameState.lore.duplicate()
	var passed: bool = await run_mini_game(CULTURE_QUIZ, {
		"questions": statue_data.get("questions", []),
		"quiz_speaker": str(statue_data.get("statue", "The Ancestors")),
	})

	if not passed:
		await say([
			{"speaker": "Master Weaver", "text": "Enough. You are guessing, and the stones will not be guessed at. Begin this House again."},
		])
		await fail_chapter()
		return

	_statue_done[index] = true
	_answered += 1
	counter("Statues answered  %d / %d" % [_answered, _statue_triggers.size()])
	GameState.add_score(150)
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	if _plate != null:
		_plate.set_statue_energy(index, 0.85)
		_plate.bloom_sanctity(0.18 * float(_answered), 0.8)
	if index < _statue_auras.size() and _statue_auras[index] != null:
		_statue_auras[index].set_energy(0.7, 0.3)

	var questions: Array = statue_data.get("questions", [])
	for question in questions:
		if question is Dictionary:
			await _reveal_lore_if_new(str((question as Dictionary).get("lore", "")), known_lore)

	_busy = false
	_point_next_statue()


func _on_scroll_collected(_pickup: Collectible) -> void:
	banner("Lore recovered: Taboos of the Loom", 1.6)
	if _busy:
		return
	await _reveal_lore_if_new("taboo", [])


func _reveal_lore_if_new(entry_id: String, previously: Array) -> void:
	if entry_id.is_empty() or not GameState.lore.has(entry_id):
		return
	if previously.has(entry_id):
		return
	if host == null or host.ui_layer == null:
		return
	set_player_input(false)
	var reveal := LoreReveal.new()
	host.ui_layer.add_child(reveal)
	await reveal.present(entry_id)
	if not is_finished():
		set_player_input(true)


func _reveal_master_pattern() -> void:
	banner("The Sacred Master Pattern", 2.2)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if _loom_aura != null:
		_loom_aura.burst()
	if host == null or host.ui_layer == null:
		await wait(1.2)
		return
	var cloth := load("res://assets/images/props/master_pattern_cloth.png") as Texture2D
	var reveal := LoreReveal.new()
	host.ui_layer.add_child(reveal)
	await reveal.present_custom(
		"The Sacred Master Pattern",
		"The pattern comes off the loom as light rather than cloth, and folds itself small enough to carry.",
		cloth
	)


func fail_chapter() -> void:
	GameState.restore_house_score()
	await super.fail_chapter()


func _refresh_statue_proximity() -> void:
	if _busy or _plate == null:
		return
	for i in range(_statue_triggers.size()):
		var trigger := _statue_triggers[i]
		if trigger == null or _statue_done[i]:
			continue
		if not trigger.enabled:
			continue
		var near := trigger.is_player_inside()
		if near == _statue_near[i]:
			continue
		_statue_near[i] = near
		_plate.set_statue_energy(i, 0.9 if near else 0.15)
		if i < _statue_auras.size() and _statue_auras[i] != null:
			_statue_auras[i].set_energy(0.85 if near else 0.12, 0.25)


func _point_next_statue() -> void:
	for i in range(_statue_done.size()):
		if not _statue_done[i] and i < _statue_triggers.size():
			_point_beacon(_statue_triggers[i])
			return
	if _loom_trigger != null:
		_point_beacon(_loom_trigger)


func _point_beacon(target: Node2D) -> void:
	if _beacon == null or target == null:
		return
	_beacon.pin(target)


func _anchor(node_name: String, world_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
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
