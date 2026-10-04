class_name VillageWalker
extends Node2D
## A house resident who strolls the green, steps inside, and comes back out.
## While their talk trigger is on, they stay in the hall so the quest can find them.

const WALK_SPEED := 78.0
## Eight frames, two steps a second, so a foot plants instead of the body gliding.
const WALK_FPS := 16.0
const ARRIVE := 8.0
const PAUSE_MIN := 0.55
const PAUSE_MAX := 1.25
const FADE_TIME := 0.32
const FRAME_COUNT := 8
const ART_SCALE := 92.0 / 192.0
const SHEET_DIR := "res://assets/images/characters/npc_walk/"

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
## Returns the house the player is standing in, or 0 on the green.
var space_of: Callable = Callable()
var speak_prompt := "Speak"
var chat_lines: Array = []

signal chatted(walker: VillageWalker)
## chief / fun / queen. Walk strips live in npc_walk/.
var sheet_id := ""
## Matches S'lang inside a painted house. The green stays at 1.
var interior_scale := 2.6

var _sprite: CanvasItem
var _animated: AnimatedSprite2D
var _chat: Interactable
var _held := false
var _inside := false
var _points: Array[Vector2] = []
var _index := 0
var _pause := 0.0
var _fading := 0.0
var _fade_out := false
var _bob := 0.0
var _stay_inside := false
var _space_scale := 1.0
var _gait := 0.0


func setup(texture_path: String, _prop_size: Vector2) -> void:
	if not _build_sheet():
		_build_still(texture_path)
	if _sprite != null:
		add_child(_sprite)
	_build_chat()
	_claim_stand_in()
	_inside = randf() < 0.4
	_apply_art_scale()
	_rebuild_route()
	if _points.is_empty():
		return
	_index = randi() % _points.size()
	global_position = _points[_index]
	_pause = randf_range(0.2, 1.1)


func _claim_stand_in() -> void:
	if stand_in == null:
		return
	stand_in.float_amplitude = 0.0
	stand_in.set_process(false)
	var spr := stand_in.get_sprite()
	if spr != null:
		spr.visible = false


func release() -> void:
	if stand_in != null and is_instance_valid(stand_in):
		var spr := stand_in.get_sprite()
		if spr != null:
			spr.visible = true
		stand_in.visible = true
	queue_free()


func _process(delta: float) -> void:
	var stay := talk_trigger != null and is_instance_valid(talk_trigger) and talk_trigger.enabled
	if stay != _stay_inside:
		_stay_inside = stay
		if _fading <= 0.0:
			_rebuild_route()
	if _stay_inside and not _inside and _fading <= 0.0:
		_begin_fade(true)
	if _fading > 0.0:
		_tick_fade(delta)
	elif _player_close():
		_face(_to_player(), false)
	elif _pause > 0.0:
		_pause = maxf(0.0, _pause - delta)
		_face(_facing_delta(), false)
		_bob_sprite(false, delta)
	else:
		_tick_walk(delta)
	_apply_art_scale()
	_apply_presence()
	queue_redraw()


func _tick_walk(delta: float) -> void:
	if _points.is_empty():
		_rebuild_route()
		return
	var target := _points[_index]
	var delta_pos := target - global_position
	var dist := delta_pos.length()
	if dist <= ARRIVE:
		_arrive()
		return
	var step := minf(dist, WALK_SPEED * delta)
	global_position += delta_pos / dist * step
	_gait += delta
	_face(delta_pos, true)
	_bob_sprite(true, delta)


func _arrive() -> void:
	var last := _index >= _points.size() - 1
	if last and _switches_space():
		_begin_fade(not _inside)
		return
	_index += 1
	if _index >= _points.size():
		_rebuild_route()
		_index = 0
	_pause = randf_range(PAUSE_MIN, PAUSE_MAX)


func _switches_space() -> bool:
	if _points.is_empty():
		return false
	if _inside:
		return not _stay_inside
	return true


func _begin_fade(into_house: bool) -> void:
	_fade_out = true
	_fading = FADE_TIME
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
	_pause = 0.4


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


func _bob_sprite(moving: bool, delta: float) -> void:
	if _sprite == null or _animated != null:
		return
	if moving:
		_bob += delta * 7.5
		_sprite.position = Vector2(0.0, -absf(sin(_bob)) * 3.5)
	else:
		_sprite.position = Vector2.ZERO


func _build_sheet() -> bool:
	if sheet_id.is_empty():
		return false
	var frames := SpriteFrames.new()
	var ready := false
	for dir in ["down", "down_right", "right", "up_right", "up"]:
		var image := Palette.read_image(SHEET_DIR + sheet_id + "_" + dir + ".png")
		if image == null or image.get_width() < 256:
			continue
		var count := FRAME_COUNT
		if image.get_width() % 256 == 0:
			count = int(image.get_width() / 256)
		ready = true
		var cell_w := int(image.get_width() / count)
		var cell_h := image.get_height()
		var walk_name: String = "walk_" + dir
		var idle_name: String = "idle_" + dir
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, WALK_FPS)
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, false)
		frames.set_animation_speed(idle_name, 1.0)
		# Each cell becomes its own texture. A shared atlas was showing the
		# same picture every frame, so the body slid with no step.
		for i in count:
			var cell := image.get_region(Rect2i(i * cell_w, 0, cell_w, cell_h))
			var frame_tex := ImageTexture.create_from_image(cell)
			frames.add_frame(walk_name, frame_tex)
			if i == 0:
				frames.add_frame(idle_name, frame_tex)
	if not ready:
		return false
	_animated = AnimatedSprite2D.new()
	_animated.name = "Sprite"
	_animated.sprite_frames = frames
	_animated.centered = true
	_animated.offset = Vector2(0.0, -46.0)
	_animated.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animated.play("idle_down")
	_sprite = _animated
	return true


func _build_still(texture_path: String) -> void:
	var still := Sprite2D.new()
	still.name = "Sprite"
	still.centered = false
	still.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex := PlaceholderProp.load_cutout_texture(texture_path, resident_name)
	still.texture = tex
	if tex != null:
		var tex_size := tex.get_size()
		if tex_size.y > 1.0:
			still.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	_sprite = still


func _apply_art_scale() -> void:
	_space_scale = interior_scale if _inside else 1.0
	if _animated != null:
		_animated.scale = Vector2(ART_SCALE, ART_SCALE) * _space_scale
		return
	if _sprite is Sprite2D:
		var still := _sprite as Sprite2D
		var tex := still.texture
		if tex != null and tex.get_height() > 1.0:
			var fit := (92.0 * _space_scale) / tex.get_height()
			still.scale = Vector2(fit, fit)


func _facing_delta() -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO
	return _points[_index] - global_position


func _face(delta_pos: Vector2, moving: bool) -> void:
	if _animated == null:
		if _sprite is Sprite2D and absf(delta_pos.x) > 10.0:
			(_sprite as Sprite2D).flip_h = delta_pos.x < 0.0
		return
	var dir := "down"
	var flip := false
	var ax := absf(delta_pos.x)
	var ay := absf(delta_pos.y)
	if delta_pos.y < 0.0 and ax > ay * 0.5:
		dir = "up_right"
		flip = delta_pos.x < 0.0
	elif delta_pos.y < 0.0:
		dir = "up"
	elif delta_pos.y > 0.0 and ax > ay * 0.5:
		dir = "down_right"
		flip = delta_pos.x < 0.0
	elif ax > ay * 0.75:
		dir = "right"
		flip = delta_pos.x < 0.0
	var anim := StringName(("walk_" if moving else "idle_") + dir)
	if not _animated.sprite_frames.has_animation(anim):
		anim = StringName(("walk_" if moving else "idle_") + "down")
	if _animated.animation != anim:
		_animated.animation = anim
	# The clock owns the frame. play() was restarting on the contact pose.
	_animated.pause()
	if moving:
		var n := _animated.sprite_frames.get_frame_count(anim)
		if n > 0:
			_animated.frame = posmod(int(_gait * WALK_FPS), n)
	else:
		_animated.frame = 0
	_animated.flip_h = flip


func hold_chat(on: bool) -> void:
	_held = on
	if _chat != null and on:
		_chat.set_prompt_visible(false)


func pick_lines() -> Array:
	if chat_lines.is_empty():
		return [{"speaker": resident_name, "text": "The path is quiet today."}]
	return [chat_lines[randi() % chat_lines.size()]]


func _build_chat() -> void:
	_chat = Interactable.new()
	_chat.name = "Chat"
	_chat.prompt = speak_prompt
	_chat.radius = 74.0
	add_to_group("village_walker")
	_chat.prompt_offset = Vector2(0.0, -112.0)
	_chat.position = Vector2(0.0, -6.0)
	add_child(_chat)
	_chat.interacted.connect(_on_chat)


func _on_chat() -> void:
	if _held or not _is_nearest_chat():
		return
	if talk_trigger != null and is_instance_valid(talk_trigger) and talk_trigger.enabled:
		talk_trigger.interacted.emit()
		return
	chatted.emit(self)


func _sync_chat(allow: bool) -> void:
	if _chat == null:
		return
	if _chat.enabled != allow:
		_chat.set_enabled(allow)
	var show := allow and not _held and _chat.is_player_inside() and _is_nearest_chat()
	_chat.set_prompt_visible(show)


func _player_close() -> bool:
	if _held:
		return true
	if _chat == null or not _chat.enabled:
		return false
	return _chat.is_player_inside()


func _is_nearest_chat() -> bool:
	var who := get_tree().get_first_node_in_group("player") as Node2D
	if who == null or _chat == null:
		return true
	var mine := global_position.distance_squared_to(who.global_position)
	for node in get_tree().get_nodes_in_group("village_walker"):
		var other := node as VillageWalker
		if other == null or other == self or other._chat == null:
			continue
		if not other._chat.enabled or not other._chat.is_player_inside():
			continue
		if other.global_position.distance_squared_to(who.global_position) < mine - 4.0:
			return false
	return true


func _to_player() -> Vector2:
	var who := get_tree().get_first_node_in_group("player") as Node2D
	if who == null:
		return Vector2(0.0, 1.0)
	var delta := who.global_position - global_position
	if delta.length_squared() < 4.0:
		return Vector2(0.0, 1.0)
	return delta


func _draw() -> void:
	if not visible:
		return
	var s := maxf(_space_scale, 0.2)
	var oval := PackedVector2Array([
		Vector2(-16.0, -3.0) * s, Vector2(-8.0, 4.0) * s, Vector2(8.0, 4.0) * s,
		Vector2(16.0, -3.0) * s, Vector2(8.0, -7.0) * s, Vector2(-8.0, -7.0) * s,
	])
	draw_colored_polygon(oval, Color(0.02, 0.02, 0.03, 0.32))
