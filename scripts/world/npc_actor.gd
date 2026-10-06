class_name NpcActor
extends CharacterBody2D
## Reusable 2D NPC. Movement sets velocity; animation only reads it.
##
## AnimatedSprite2D is used (not AnimationPlayer) because these are looping
## 8-dir cycles with no per-frame hitboxes. Swap `sheet_id` or `sprite_frames`.

signal talked
signal arrived

enum State { IDLE, WANDERING, MOVING_TO_TARGET, TALKING }

const OCTANTS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const FLIP_SHEET := {
	"left": "right",
	"up_left": "up_right",
	"down_left": "down_right",
}
const HOVER_TINT := Color(1.18, 1.12, 0.92)
const SELECT_TINT := Color(1.28, 1.18, 0.78)

@export var walk_speed := 78.0
@export var walk_fps := 2.0
@export var arrive_distance := 12.0
@export var pause_min := 0.8
@export var pause_max := 2.2
@export var wander_radius := 0.0
@export var stuck_seconds := 0.7
@export var move_epsilon := 8.0
@export var interact_radius := 74.0
@export var talk_stop_range := 56.0
@export var interact_prompt := "Speak"
@export var prompt_offset := Vector2(0.0, -112.0)
@export var sheet_id := ""
@export var sprite_frames: SpriteFrames
@export var idle_prefix := "idle_"
@export var walk_prefix := "walk_"
@export var art_scale := 92.0 / 192.0
@export var still_texture_path := ""
@export var still_label := ""

var state: State = State.IDLE
var last_direction := "down"
var movement_locked := false
var interact: Interactable

var _animated: AnimatedSprite2D
var _sprite: CanvasItem
var _agent: NavigationAgent2D
var _click: Area2D
var _octant_idx := 2
var _pause_left := 0.0
var _stuck := 0.0
var _destination := Vector2.ZERO
var _has_destination := false
var _talk_hold := false
var _space_scale := 1.0
var _base_offset := Vector2(0.0, -46.0)
var _interact_busy := false
var _home := Vector2.ZERO
var _nav_ready := false
var _hovered := false
var _selected := false
var _resume_after_talk: State = State.IDLE
var _repath_tries := 0
var _talk_pulse := 0.0


func _ready() -> void:
	_home = global_position
	y_sort_enabled = true
	add_to_group("talkable_npc")
	_ensure_body()
	_build_visuals()
	_build_agent()
	_build_click()
	_build_interact()
	set_physics_process(true)
	set_process(false)
	_boot_nav.call_deferred()


func _physics_process(delta: float) -> void:
	_talk_pulse += delta * 3.1
	_sync_collision()
	if _wants_talk_pose():
		if state != State.TALKING:
			_enter_talk()
		_tick_talk(delta)
		return
	if state == State.TALKING:
		_exit_talk()
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO, false)
		_ground_sprite()
		return
	match state:
		State.WANDERING, State.MOVING_TO_TARGET:
			_tick_move(delta)
		_:
			_tick_idle(delta)


func _sync_collision() -> void:
	collision_layer = PhysicsLayers.LAYER_ENEMIES
	collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	var feet := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet != null:
		feet.disabled = false
		if feet.shape == null:
			feet.shape = PhysicsLayers.feet_circle(14.0)
			feet.position = Vector2(0.0, -2.0)


func walk_to(world_pos: Vector2) -> void:
	_set_destination(world_pos, State.MOVING_TO_TARGET)


func wander_to(world_pos: Vector2) -> void:
	_set_destination(world_pos, State.WANDERING)


func idle_for(seconds: float = -1.0) -> void:
	_has_destination = false
	_pause_left = seconds if seconds >= 0.0 else randf_range(pause_min, pause_max)
	if state != State.TALKING:
		_set_state(State.IDLE)


func begin_talk() -> void:
	_talk_hold = true
	_enter_talk()


func end_talk() -> void:
	_talk_hold = false
	if state == State.TALKING and not _dialogue_open():
		_exit_talk()


func hold_chat(on: bool) -> void:
	if on:
		begin_talk()
	else:
		end_talk()


func receive_player_talk() -> void:
	if _interact_busy or state == State.TALKING or _talk_hold:
		return
	_on_interact()


func set_selected(on: bool) -> void:
	_selected = on
	_refresh_tint()


func talk_stop_distance() -> float:
	return talk_stop_range


func can_be_clicked_at(world_point: Vector2) -> bool:
	if not visible or _talk_hold or state == State.TALKING:
		return false
	var body := global_position + Vector2(0.0, -36.0)
	return world_point.distance_to(body) <= 52.0 \
		or world_point.distance_to(global_position) <= 36.0


func set_art_scale_factor(factor: float) -> void:
	_space_scale = maxf(factor, 0.05)
	_apply_base_scale()


func use_still(texture_path: String, label: String) -> void:
	if _animated != null:
		return
	var still := Sprite2D.new()
	still.name = "Sprite"
	still.centered = false
	still.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := PlaceholderProp.load_cutout_texture(texture_path, label)
	still.texture = tex
	if tex != null:
		var tex_size := tex.get_size()
		if tex_size.y > 1.0:
			still.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	_sprite = still
	add_child(still)
	set_art_scale_factor(_space_scale)


func has_walk_cycle() -> bool:
	return _animated != null


func is_talking() -> bool:
	return state == State.TALKING


func is_traveling() -> bool:
	return state == State.WANDERING or state == State.MOVING_TO_TARGET or _has_destination


func current_destination() -> Vector2:
	return _destination


func _ensure_body() -> void:
	collision_layer = PhysicsLayers.LAYER_ENEMIES
	collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.12
	slide_on_ceiling = true
	floor_stop_on_slope = false
	z_as_relative = true
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	shape_node.shape = PhysicsLayers.feet_circle(14.0)
	shape_node.position = Vector2(0.0, -2.0)
	shape_node.disabled = false


func _build_visuals() -> void:
	if _sprite != null:
		return
	var frames := sprite_frames
	if frames == null and not sheet_id.is_empty():
		frames = NpcFrames.load_or_build(sheet_id, NpcFrames.WALK_CYCLES_PER_SEC)
	if frames != null and not frames.get_animation_names().is_empty():
		_animated = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _animated == null:
			_animated = AnimatedSprite2D.new()
			_animated.name = "AnimatedSprite2D"
			add_child(_animated)
		_animated.sprite_frames = frames
		_animated.centered = true
		_animated.offset = _base_offset
		_animated.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_animated.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		_sprite = _animated
		set_art_scale_factor(_space_scale)
		_play_anim(idle_prefix + "down")
		return
	if not still_texture_path.is_empty():
		use_still(still_texture_path, still_label)


func _build_agent() -> void:
	_agent = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if _agent == null:
		_agent = NavigationAgent2D.new()
		_agent.name = "NavigationAgent2D"
		add_child(_agent)
	_agent.path_desired_distance = 12.0
	_agent.target_desired_distance = arrive_distance
	_agent.radius = 16.0
	_agent.avoidance_enabled = false
	_agent.debug_enabled = false


func _boot_nav() -> void:
	await get_tree().physics_frame
	NpcNav.ensure_near(self)
	_nav_ready = true
	if _has_destination:
		_agent.target_position = _destination


func _build_click() -> void:
	_click = get_node_or_null("ClickArea") as Area2D
	if _click == null:
		_click = Area2D.new()
		_click.name = "ClickArea"
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44.0, 78.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -40.0)
		_click.add_child(shape)
		add_child(_click)
	_click.collision_layer = 0
	_click.collision_mask = 0
	_click.monitorable = false
	_click.monitoring = false
	_click.input_pickable = true
	_click.mouse_entered.connect(_on_click_hover.bind(true))
	_click.mouse_exited.connect(_on_click_hover.bind(false))
	_click.input_event.connect(_on_click_input)


func _build_interact() -> void:
	if interact != null:
		return
	interact = Interactable.new()
	interact.name = "Chat"
	interact.prompt = interact_prompt
	interact.radius = interact_radius
	interact.prompt_offset = prompt_offset
	interact.position = Vector2(0.0, -6.0)
	add_child(interact)
	interact.interacted.connect(_on_interact)


func _tick_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_pause_left = maxf(0.0, _pause_left - delta)
	_update_animation(Vector2.ZERO, false)
	_ground_sprite()
	if _pause_left > 0.0:
		return
	if _has_destination:
		_set_state(State.MOVING_TO_TARGET)
	elif wander_radius > 0.0:
		_pick_wander_point()


func _tick_move(delta: float) -> void:
	if not _has_destination:
		idle_for()
		return
	if global_position.distance_to(_destination) <= arrive_distance:
		_arrive()
		return
	var wish := _steer()
	if wish.length_squared() < 0.01:
		_arrive()
		return
	velocity = wish * walk_speed
	var before := global_position
	move_and_slide()
	var moved := global_position - before
	var traveled := moved.length()
	if traveled < move_epsilon * delta:
		_stuck += delta
		if _stuck >= stuck_seconds:
			if _repath_tries < 2 and _repath():
				_repath_tries += 1
				_stuck = 0.0
				return
			_arrive()
			return
		_update_animation(Vector2.ZERO, false)
	else:
		_stuck = 0.0
		_update_animation(moved, true)
	_ground_sprite()


func _tick_talk(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_face_world(_player_delta())
	_update_animation(Vector2.ZERO, false)
	_ground_sprite()
	if interact != null:
		interact.set_prompt_visible(false)


func _arrive() -> void:
	_has_destination = false
	_stuck = 0.0
	_repath_tries = 0
	velocity = Vector2.ZERO
	move_and_slide()
	_set_state(State.IDLE)
	_pause_left = randf_range(pause_min, pause_max)
	_update_animation(Vector2.ZERO, false)
	_ground_sprite()
	arrived.emit()


func _steer() -> Vector2:
	var to_goal := _destination - global_position
	if to_goal.length() <= arrive_distance:
		return Vector2.ZERO
	if _nav_ready and _agent != null:
		_agent.target_position = _destination
		if not _agent.is_navigation_finished():
			var next := _agent.get_next_path_position()
			if next.distance_to(global_position) > 2.0:
				return global_position.direction_to(next)
	return to_goal.normalized()


func _repath() -> bool:
	if not _nav_ready or _agent == null:
		return false
	var map := _agent.get_navigation_map()
	if map == RID():
		return false
	var snapped := NavigationServer2D.map_get_closest_point(map, _destination)
	if snapped.distance_to(_destination) > 90.0:
		return false
	if snapped.distance_to(global_position) < arrive_distance:
		return false
	_destination = snapped
	_agent.target_position = snapped
	return snapped.distance_to(global_position) > arrive_distance


func _set_destination(world_pos: Vector2, next: State) -> void:
	var goal := world_pos
	if _nav_ready and _agent != null:
		var map := _agent.get_navigation_map()
		if map != RID():
			var snapped := NavigationServer2D.map_get_closest_point(map, world_pos)
			if snapped.distance_to(world_pos) <= 90.0:
				goal = snapped
	_destination = goal
	_has_destination = true
	_stuck = 0.0
	_repath_tries = 0
	if _nav_ready and _agent != null:
		_agent.target_position = goal
	if state != State.TALKING and not movement_locked:
		_set_state(next)
	_face_world(goal - global_position)


func _pick_wander_point() -> void:
	var offset := Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius) * 0.5
	)
	var raw := _home + offset
	if _nav_ready and _agent != null:
		var map := _agent.get_navigation_map()
		if map != RID():
			raw = NavigationServer2D.map_get_closest_point(map, raw)
	wander_to(raw)


func _update_animation(move_vec: Vector2, moving: bool) -> void:
	if _animated == null:
		if _sprite is Sprite2D and absf(move_vec.x) > 6.0:
			(_sprite as Sprite2D).flip_h = move_vec.x < 0.0
		return
	if moving:
		last_direction = _octant_name(move_vec)
		_animated.speed_scale = clampf(move_vec.length() / maxf(walk_speed, 1.0), 0.85, 1.1)
		_play_anim(_anim_name(walk_prefix, last_direction))
	else:
		_animated.speed_scale = 1.0
		_play_anim(_anim_name(idle_prefix, last_direction))
	_animated.flip_h = FLIP_SHEET.has(last_direction)


func _anim_name(prefix: String, dir: String) -> String:
	var sheet := _sheet_dir(dir)
	var exact := prefix + sheet
	if _animated != null and _animated.sprite_frames != null:
		if _animated.sprite_frames.has_animation(exact):
			return exact
		if sheet == "right" and _animated.sprite_frames.has_animation(prefix + "side"):
			return prefix + "side"
	return exact


func _ground_sprite() -> void:
	if _sprite == null:
		return
	_sprite.position = global_position.round() - global_position
	if _animated != null:
		_animated.rotation_degrees = 0.0
		_animated.offset = _base_offset
	queue_redraw()


func _apply_base_scale() -> void:
	if _animated != null:
		_animated.scale = Vector2(art_scale, art_scale) * _space_scale
		return
	if _sprite is Sprite2D:
		var still := _sprite as Sprite2D
		if still.texture != null and still.texture.get_height() > 1.0:
			var fit := (92.0 * _space_scale) / still.texture.get_height()
			still.scale = Vector2(fit, fit)


func _play_anim(anim_name: String) -> void:
	if _animated == null or _animated.sprite_frames == null:
		return
	if not _animated.sprite_frames.has_animation(anim_name):
		anim_name = idle_prefix + "down" if anim_name.begins_with(idle_prefix) else walk_prefix + "down"
		if not _animated.sprite_frames.has_animation(anim_name):
			return
	if _animated.animation == anim_name:
		if not _animated.is_playing():
			_animated.play(anim_name)
		return
	var keep_stride := _animated.animation.begins_with(walk_prefix) and anim_name.begins_with(walk_prefix)
	var frame := _animated.frame
	var progress := _animated.frame_progress
	_animated.play(anim_name)
	if keep_stride:
		var count := _animated.sprite_frames.get_frame_count(anim_name)
		if count > 0:
			_animated.frame = frame % count
			_animated.frame_progress = progress


func _octant_name(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return last_direction
	var idx := posmod(int(round(dir.angle() / (PI * 0.25))), 8)
	if idx != _octant_idx:
		var current_angle := float(_octant_idx) * PI * 0.25
		if absf(angle_difference(dir.angle(), current_angle)) > PI * 0.20:
			_octant_idx = idx
	return OCTANTS[_octant_idx]


func _sheet_dir(dir: String) -> String:
	return str(FLIP_SHEET.get(dir, dir))


func _face_world(delta_pos: Vector2) -> void:
	if delta_pos.length_squared() < 4.0:
		return
	last_direction = _octant_name(delta_pos)


func _set_state(next: State) -> void:
	state = next


func _enter_talk() -> void:
	if state != State.TALKING:
		_resume_after_talk = state
	_set_state(State.TALKING)
	_interact_busy = true
	velocity = Vector2.ZERO
	if interact != null:
		interact.set_enabled(false)
		interact.set_prompt_visible(false)


func _exit_talk() -> void:
	_interact_busy = false
	_set_state(State.IDLE)
	set_selected(false)
	if interact != null:
		interact.set_enabled(true)
	if _has_destination:
		_pause_left = 0.15
	elif _resume_after_talk == State.WANDERING and wander_radius > 0.0:
		_pause_left = 0.2


func _wants_talk_pose() -> bool:
	if _talk_hold:
		return true
	return _dialogue_open() and _player_delta().length() <= interact_radius + 24.0


func _dialogue_open() -> bool:
	if not is_inside_tree():
		return false
	var view := get_tree().get_first_node_in_group("dialogue_view")
	return view != null and view.has_method("is_busy") and bool(view.call("is_busy"))


func _on_interact() -> void:
	if _interact_busy or state == State.TALKING or _talk_hold:
		return
	if not _can_accept_talk():
		return
	talked.emit()


func _can_accept_talk() -> bool:
	return true


func _on_click_hover(inside: bool) -> void:
	_hovered = inside
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if inside else Input.CURSOR_ARROW)
	_refresh_tint()


func _on_click_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT or mouse.double_click:
		return
	if _interact_busy or state == State.TALKING or _talk_hold:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("approach_npc"):
		player.call("approach_npc", self)
		get_viewport().set_input_as_handled()


func _refresh_tint() -> void:
	if _sprite == null:
		return
	if _selected:
		_sprite.modulate = SELECT_TINT
	elif _hovered:
		_sprite.modulate = HOVER_TINT
	else:
		_sprite.modulate = Color.WHITE


func _player_delta() -> Vector2:
	var who := get_tree().get_first_node_in_group("player") as Node2D
	if who == null:
		return Vector2(0.0, 1.0)
	var delta := who.global_position - global_position
	if delta.length_squared() < 4.0:
		return Vector2(0.0, 1.0)
	return delta


func _can_show_talk_mark() -> bool:
	if not visible or _talk_hold or state == State.TALKING:
		return false
	return interact != null and interact.enabled


func _draw() -> void:
	if not visible:
		return
	var s := maxf(_space_scale, 0.2)
	var oval := PackedVector2Array([
		Vector2(-16.0, -3.0) * s, Vector2(-8.0, 4.0) * s, Vector2(8.0, 4.0) * s,
		Vector2(16.0, -3.0) * s, Vector2(8.0, -7.0) * s, Vector2(-8.0, -7.0) * s,
	])
	draw_colored_polygon(oval, Color(0.02, 0.02, 0.03, 0.32))
	if not _can_show_talk_mark():
		return
	var vis := art_scale * s
	var bob := sin(_talk_pulse)
	var head := Vector2(0.0, (_base_offset.y - 102.0) * vis + bob * 2.4 * vis)
	var tip := head + Vector2(0.0, 8.0 * vis)
	var left := head + Vector2(-7.5 * vis, -5.5 * vis)
	var right := head + Vector2(7.5 * vis, -5.5 * vis)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0.0, 1.8 * vis),
		left + Vector2(-1.4 * vis, -1.1 * vis),
		right + Vector2(1.4 * vis, -1.1 * vis),
	]), Palette.alpha(Palette.DREAM_ABYSS, 0.78))
	var gold: Color = Palette.GOLD_SUN
	gold.a = 0.82 + 0.16 * bob
	draw_colored_polygon(PackedVector2Array([tip, left, right]), gold)
	draw_polyline(PackedVector2Array([left, tip, right]), Palette.GOLD_SACRED, 1.5, true)
