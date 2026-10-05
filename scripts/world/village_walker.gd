class_name VillageWalker
extends NpcActor
## A house resident who strolls the green, steps inside, and comes back out.
## Locomotion and the walk cycle live on NpcActor. This script only owns the
## house route, fade, and quest talk trigger.

const FADE_TIME := 0.32

var house_id := 1
var resident_name := ""
var outside_uvs: Array[Vector2] = []
var inside_uvs: Array[Vector2] = []
var door_uv := Vector2(0.5, 0.6)
var exit_uv := Vector2(0.5, 0.86)
var hub_plate: Node = null
var interior_plate: Node = null
var stand_in: PlaceholderProp = null
var talk_trigger: Interactable = null
var space_of: Callable = Callable()
var speak_prompt := "Speak"
var chat_lines: Array = []
var interior_scale := 2.6

signal chatted(walker: VillageWalker)

var _inside := false
var _points: Array[Vector2] = []
var _index := 0
var _fading := 0.0
var _fade_out := false
var _stay_inside := false


func setup(texture_path: String, _prop_size: Vector2) -> void:
	interact_prompt = speak_prompt
	if interact != null:
		interact.set_prompt(speak_prompt)
	if not has_walk_cycle():
		use_still(texture_path, resident_name)
	add_to_group("village_walker")
	if not talked.is_connected(_on_talked):
		talked.connect(_on_talked)
	if not arrived.is_connected(_on_arrived):
		arrived.connect(_on_arrived)
	_claim_stand_in()
	_inside = randf() < 0.4
	set_art_scale_factor(interior_scale if _inside else 1.0)
	_rebuild_route()
	if _points.is_empty():
		return
	_index = randi() % _points.size()
	global_position = _points[_index]
	_home = global_position
	idle_for(randf_range(0.2, 1.1))


func _physics_process(delta: float) -> void:
	_tick_space(delta)
	if _fading > 0.0:
		movement_locked = true
		_tick_fade(delta)
		_apply_presence()
		return
	movement_locked = false
	_offer_next_leg()
	super._physics_process(delta)
	set_art_scale_factor(interior_scale if _inside else 1.0)
	_apply_presence()


func _tick_space(_delta: float) -> void:
	var stay := talk_trigger != null and is_instance_valid(talk_trigger) and talk_trigger.enabled
	if stay != _stay_inside:
		_stay_inside = stay
		if _fading <= 0.0:
			_rebuild_route()
	if _stay_inside and not _inside and _fading <= 0.0:
		_begin_fade(true)


func _offer_next_leg() -> void:
	if state == State.TALKING or _talk_hold or movement_locked:
		return
	if is_traveling():
		return
	if _pause_left > 0.0:
		return
	if _points.is_empty():
		_rebuild_route()
	if _points.is_empty():
		return
	walk_to(_points[_index])


func _on_arrived() -> void:
	var last := _index >= _points.size() - 1
	if last and _switches_space():
		_begin_fade(not _inside)
		return
	_index += 1
	if _index >= _points.size():
		_rebuild_route()
		_index = 0


func _on_talked() -> void:
	chatted.emit(self)


func _can_accept_talk() -> bool:
	return not _talk_hold and _is_nearest_chat()


func _on_interact() -> void:
	if talk_trigger != null and is_instance_valid(talk_trigger) and talk_trigger.enabled:
		if _interact_busy or _talk_hold or not _is_nearest_chat():
			return
		talk_trigger.interacted.emit()
		return
	super._on_interact()


func release() -> void:
	if stand_in != null and is_instance_valid(stand_in):
		var spr := stand_in.get_sprite()
		if spr != null:
			spr.visible = true
		stand_in.visible = true
	queue_free()


func pick_lines() -> Array:
	if chat_lines.is_empty():
		return [{"speaker": resident_name, "text": "The path is quiet today."}]
	return [chat_lines[randi() % chat_lines.size()]]


func _claim_stand_in() -> void:
	if stand_in == null:
		return
	stand_in.float_amplitude = 0.0
	stand_in.set_process(false)
	var spr := stand_in.get_sprite()
	if spr != null:
		spr.visible = false


func _switches_space() -> bool:
	if _points.is_empty():
		return false
	if _inside:
		return not _stay_inside
	return true


func _begin_fade(into_house: bool) -> void:
	_fade_out = true
	_fading = FADE_TIME
	movement_locked = true
	idle_for(0.0)
	set_meta("enter_house", into_house)


func _tick_fade(delta: float) -> void:
	_fading = maxf(0.0, _fading - delta)
	var shown := clampf(_fading / FADE_TIME, 0.0, 1.0)
	if not _fade_out:
		shown = 1.0 - shown
	if _sprite != null:
		_sprite.modulate.a = shown
	if _fading > 0.0:
		return
	if _fade_out:
		_inside = bool(get_meta("enter_house", false))
		_rebuild_route()
		_index = 0
		global_position = _inside_pos(exit_uv) if _inside else _outside_pos(door_uv)
		_fade_out = false
		_fading = FADE_TIME
		if _sprite != null:
			_sprite.modulate.a = 0.0
		return
	if _sprite != null:
		_sprite.modulate.a = 1.0
	idle_for(0.4)


func _rebuild_route() -> void:
	_points.clear()
	if _inside:
		for uv in inside_uvs:
			_points.append(_inside_pos(uv))
		if not _stay_inside:
			_points.append(_inside_pos(exit_uv))
	else:
		for uv in outside_uvs:
			_points.append(_outside_pos(uv))
		_points.append(_outside_pos(door_uv))
	if _index >= _points.size():
		_index = 0


func _outside_pos(uv: Vector2) -> Vector2:
	if hub_plate != null and hub_plate.has_method("uv_to_world"):
		return hub_plate.uv_to_world(uv)
	return Vector2.ZERO


func _inside_pos(uv: Vector2) -> Vector2:
	if interior_plate != null and interior_plate.has_method("uv_to_global"):
		return interior_plate.uv_to_global(uv)
	return Vector2.ZERO


func _player_here() -> bool:
	if not space_of.is_valid():
		return false
	var space := int(space_of.call())
	if _inside:
		return space == house_id
	return space == 0


func _apply_presence() -> void:
	var here := _player_here()
	visible = here
	var feet := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet != null:
		feet.disabled = not here or _fading > 0.0
	var tint := Color.WHITE
	if stand_in != null and is_instance_valid(stand_in):
		var spr := stand_in.get_sprite()
		if spr != null:
			spr.visible = false
			tint = spr.modulate
		if here and _inside:
			stand_in.visible = true
			stand_in.global_position = global_position
		elif _inside == false or not here:
			stand_in.visible = false
	if tint.a < 0.2:
		tint.a = 1.0
	if _sprite != null and _fading <= 0.0:
		if _hovered or _selected:
			_refresh_tint()
		else:
			_sprite.modulate = tint
	var quest_talk := false
	if talk_trigger != null and is_instance_valid(talk_trigger):
		quest_talk = here and talk_trigger.enabled
		talk_trigger.visible = quest_talk
		talk_trigger.monitoring = quest_talk
		talk_trigger.monitorable = quest_talk
		if quest_talk:
			talk_trigger.global_position = global_position + Vector2(0.0, -8.0)
			talk_trigger.set_enabled(true)
		else:
			talk_trigger.set_prompt_visible(false)
	_sync_chat(here and not quest_talk)
	if here:
		queue_redraw()


func _sync_chat(allow: bool) -> void:
	if interact == null:
		return
	if interact.enabled != allow and not _talk_hold and state != State.TALKING:
		interact.set_enabled(allow)
	var show := allow and not _talk_hold and state != State.TALKING \
		and interact.is_player_inside() and _is_nearest_chat()
	interact.set_prompt_visible(show)


func _is_nearest_chat() -> bool:
	var who := get_tree().get_first_node_in_group("player") as Node2D
	if who == null or interact == null:
		return true
	var mine := global_position.distance_squared_to(who.global_position)
	for node in get_tree().get_nodes_in_group("village_walker"):
		var other := node as VillageWalker
		if other == null or other == self or other.interact == null:
			continue
		if not other.interact.enabled or not other.interact.is_player_inside():
			continue
		if other.global_position.distance_squared_to(who.global_position) < mine - 4.0:
			return false
	return true


func _draw() -> void:
	super._draw()
