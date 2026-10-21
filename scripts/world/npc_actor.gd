class_name NpcActor
extends CharacterBody2D
## Reusable 2D NPC. Movement sets velocity; animation only reads the slide.
##
## AnimatedSprite2D is used (not AnimationPlayer) because these are looping
## 8-dir cycles with no per-frame hitboxes. Swap `sheet_id` or `sprite_frames`.
## Walk frames are driven by DISTANCE TRAVELLED, not by time: one stride of
## real movement = one full cycle of the strip. Feet cannot skate because the
## animation can never run faster or slower than the body. A blocked NPC drops
## to idle even if the state is still WANDERING.

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
## Off = smooth motion. On = sprite snapped to whole world pixels (stutters).
const SNAP_SPRITE_TO_PIXELS := false
## Below the stop speed the sheet is idle, so a creep does not play a stride.
const WALK_START_SPEED := 30.0
const WALK_STOP_SPEED := 10.0
## Directions with no drawn walk strip waddle instead: hop, rock, squash.
const WADDLE_HOP := 9.0
const WADDLE_ROCK_DEG := 4.5
## Stay on the current octant until the heading is clearly in the next one.
const FACE_DEAD_ZONE := PI * 0.20
## Painted sole row on the 192 px canvas. Center of that canvas is y = 96.
const SOLE_ROW := 180.0

@export var use_avoidance := false
@export var walk_speed := 78.0
@export var debug_ground := false
@export var accel := 700.0
@export var decel := 900.0
## Scale walk_speed by the art scale so small/far NPCs don't slide.
@export var scale_speed_with_art := true
@export var arrive_distance := 12.0
@export var pause_min := 0.8
@export var pause_max := 2.2
@export var wander_radius := 0.0
@export var stuck_seconds := 0.7
@export var move_epsilon := 8.0
@export var interact_radius := 74.0
@export var talk_stop_range := 56.0
@export var interact_prompt := "Speak"
@export var prompt_offset := Vector2(0.0, -76.0)
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
var _walking := false
var _avoidance_waiting := false
var _avoidance_velocity := Vector2.ZERO
var _avoidance_failed := false
var _check_stuck := false
## 0..1 progress through one full walk cycle. Advanced by distance, not time.
var _stride_phase := 0.0


func _ready() -> void:
	_home = global_position
	y_sort_enabled = true
	add_to_group("talkable_npc")
	_ensure_body()
	PhysicsLayers.configure_npc(self)
	_build_visuals()
	_build_agent()
	_build_click()
	_build_interact()
	set_physics_process(true)
	set_process(false)
	_boot_nav.call_deferred()


func _physics_process(delta: float) -> void:
	_talk_pulse += delta * 3.1
	# Avoidance answers later in the frame. If it never did, steer without it.
	_avoidance_failed = false
	if _avoidance_waiting:
		_avoidance_waiting = false
		_avoidance_failed = true
		velocity = _avoidance_velocity
	if _wants_talk_pose():
		if state != State.TALKING:
			_enter_talk()
		_tick_talk(delta)
		return
	if state == State.TALKING:
		_exit_talk()
	if movement_locked:
		_request_motion(Vector2.ZERO, delta, false)
		return
	match state:
		State.WANDERING, State.MOVING_TO_TARGET:
			_tick_move(delta)
		_:
			_tick_idle(delta)


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
	_place_feet()
	if _agent != null:
		_agent.max_speed = _effective_speed() * 1.3


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
	slide_on_ceiling = true
	floor_stop_on_slope = false
	z_as_relative = true
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	shape_node.shape = PhysicsLayers.feet_circle(14.0)
	shape_node.disabled = false
	_place_feet()


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
		_animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	_agent.path_desired_distance = 6.0
	_agent.target_desired_distance = 8.0
	_agent.radius = PhysicsLayers.NPC_AGENT_RADIUS
	_agent.avoidance_enabled = use_avoidance
	_agent.max_speed = _effective_speed() * 1.3
	_agent.debug_enabled = false
	if not _agent.velocity_computed.is_connected(_on_velocity_computed):
		_agent.velocity_computed.connect(_on_velocity_computed)


func _boot_nav() -> void:
	await get_tree().physics_frame
	NpcNav.ensure_near(self)
	_nav_ready = true
	if _has_destination and _agent != null:
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
	# Ease to a stop. Never snap velocity to zero.
	var target := velocity.move_toward(Vector2.ZERO, decel * delta)
	_request_motion(target, delta, false)
	_pause_left = maxf(0.0, _pause_left - delta)
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
	# A straight line into a wall reads as a slide. Wait until the map exists.
	if not _map_synced():
		var coast := velocity.move_toward(Vector2.ZERO, decel * delta)
		_request_motion(coast, delta, false)
		return
	var wish := _steer()
	if wish.length_squared() < 0.01:
		_arrive()
		return
	var target := velocity.move_toward(wish * _effective_speed(), accel * delta)
	_request_motion(target, delta, true)


func _tick_talk(delta: float) -> void:
	_face_world(_player_delta())
	_request_motion(Vector2.ZERO, delta, false)
	if interact != null:
		interact.set_prompt_visible(false)


## One slide per frame. Avoidance reports a safe velocity later in the same frame.
func _request_motion(target_vel: Vector2, delta: float, check_stuck: bool) -> void:
	_check_stuck = check_stuck
	var defer_slide := _agent != null and _agent.avoidance_enabled and not _avoidance_failed \
			and _map_synced() and target_vel.length_squared() > 1.0
	if defer_slide:
		_avoidance_velocity = target_vel
		_avoidance_waiting = true
		_agent.velocity = target_vel
		return
	_avoidance_waiting = false
	velocity = target_vel
	_commit_motion(delta)


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if not _avoidance_waiting:
		return
	_avoidance_waiting = false
	velocity = safe_velocity
	_commit_motion(get_physics_process_delta_time())


func _commit_motion(delta: float) -> void:
	var before := global_position
	move_and_slide()
	if _check_stuck:
		_note_stuck(before, delta)
	# Walk vs idle follows the slide, not the wish direction or the state.
	_update_animation(delta)
	_ground_sprite()


func _note_stuck(before: Vector2, delta: float) -> void:
	var traveled := (global_position - before).length()
	if traveled < move_epsilon * delta:
		_stuck += delta
		if _stuck >= stuck_seconds:
			if _repath_tries < 2 and _repath():
				_repath_tries += 1
				_stuck = 0.0
				return
			_arrive()
			return
	_stuck = 0.0


func _map_synced() -> bool:
	if _agent == null:
		return false
	var map := _agent.get_navigation_map()
	if map == RID():
		return false
	return NavigationServer2D.map_get_iteration_id(map) != 0


func _arrive() -> void:
	_has_destination = false
	_stuck = 0.0
	_repath_tries = 0
	_set_state(State.IDLE)
	_pause_left = randf_range(pause_min, pause_max)
	_ground_sprite()
	arrived.emit()


func _steer() -> Vector2:
	var to_goal := _destination - global_position
	if to_goal.length() <= arrive_distance:
		return Vector2.ZERO
	# Target is set in _set_destination / _repath / _boot_nav, not every frame.
	if _agent == null or not _map_synced() or _agent.is_navigation_finished():
		return to_goal.normalized()
	var next := _agent.get_next_path_position()
	if next.distance_to(global_position) <= 2.0:
		return to_goal.normalized()
	return global_position.direction_to(next)


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


func _effective_speed() -> float:
	return walk_speed * (_space_scale if scale_speed_with_art else 1.0)


## Painted sole, in this node's local pixels. The sprite offset is left alone so
## y-sort stays on the node origin; the shadow and the feet circle move down to here.
func _sole_local_y() -> float:
	return (_base_offset.y + (SOLE_ROW - 96.0)) * art_scale * _space_scale


func _place_feet() -> void:
	var feet := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet == null:
		return
	var radius := 14.0
	if feet.shape is CircleShape2D:
		radius = (feet.shape as CircleShape2D).radius
	feet.position = Vector2(0.0, _sole_local_y() - radius)


func _update_animation(delta: float) -> void:
	var vel := get_real_velocity()
	var spd := vel.length()
	_walking = (spd > WALK_STOP_SPEED) if _walking else (spd > WALK_START_SPEED)
	if _animated == null:
		if _sprite is Sprite2D and _walking and absf(vel.x) > 6.0:
			(_sprite as Sprite2D).flip_h = vel.x < 0.0
		return
	var hop := 0.0
	var rock := 0.0
	var squash := 0.0
	if _walking:
		_face_world(vel)
		var walk_anim := _anim_name(walk_prefix, last_direction)
		if _has_real_walk(walk_anim):
			_drive_walk(walk_anim, spd * delta)
		else:
			var stride := NpcFrames.STRIDE_SRC_PX * art_scale * _space_scale
			_stride_phase = fposmod(_stride_phase + spd * delta / maxf(stride, 1.0), 1.0)
			_hold_pose(_anim_name(idle_prefix, last_direction))
			rock = sin(_stride_phase * TAU)
			hop = absf(rock)
			squash = 1.0 - hop
	else:
		_stride_phase = 0.0
		_play_anim(_anim_name(idle_prefix, last_direction))
	var base := Vector2(art_scale, art_scale) * _space_scale
	_animated.flip_h = FLIP_SHEET.has(last_direction)
	_animated.offset = _base_offset + Vector2(0.0, -WADDLE_HOP * hop)
	_animated.rotation = deg_to_rad(WADDLE_ROCK_DEG) * rock
	_animated.scale = Vector2(base.x * (1.0 + 0.03 * squash), base.y * (1.0 - 0.04 * squash))
	if not _walking:
		_animated.speed_scale = 1.0


## True when this direction has a drawn walk strip (listed in NpcFrames.STRIDE_OVERRIDE).
## Custom SpriteFrames without the flag count as real, so they keep working.
func _has_real_walk(anim_name: String) -> bool:
	var frames := _animated.sprite_frames
	if frames == null or not frames.has_animation(anim_name):
		return false
	var dir := anim_name.trim_prefix(walk_prefix)
	if dir == "side":
		dir = "right"
	if not frames.has_meta("real_" + dir):
		return true
	return bool(frames.get_meta("real_" + dir))


func _hold_pose(anim_name: String) -> void:
	var frames := _animated.sprite_frames
	if frames == null:
		return
	if not frames.has_animation(anim_name):
		anim_name = idle_prefix + "down"
		if not frames.has_animation(anim_name):
			return
	if _animated.animation != anim_name:
		_animated.animation = anim_name
	if _animated.is_playing():
		_animated.pause()
	if _animated.frame != 0:
		_animated.frame = 0


## Pick the walk frame from how far the body actually moved this physics step.
func _drive_walk(anim_name: String, moved: float) -> void:
	var frames := _animated.sprite_frames
	if frames == null:
		return
	if not frames.has_animation(anim_name):
		anim_name = walk_prefix + "down"
		if not frames.has_animation(anim_name):
			return
	var count := frames.get_frame_count(anim_name)
	if count <= 0:
		return
	var stride := maxf(_stride_world(anim_name), 1.0)
	_stride_phase = fposmod(_stride_phase + moved / stride, 1.0)
	if _animated.animation != anim_name:
		_animated.animation = anim_name
	if _animated.is_playing():
		_animated.pause()
	_animated.speed_scale = 1.0
	var idx := clampi(int(_stride_phase * float(count)), 0, count - 1)
	if _animated.frame != idx:
		_animated.frame = idx


func _stride_world(anim_name: String) -> float:
	var dir := anim_name.trim_prefix(walk_prefix)
	if dir == "side":
		dir = "right"
	var fit := 1.0
	var stride_src := NpcFrames.STRIDE_SRC_PX
	var frames := _animated.sprite_frames
	if frames != null:
		if frames.has_meta("fit_" + dir):
			fit = float(frames.get_meta("fit_" + dir))
		if frames.has_meta("stride_" + dir):
			stride_src = float(frames.get_meta("stride_" + dir))
	return stride_src * fit * art_scale * _space_scale


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
	if SNAP_SPRITE_TO_PIXELS:
		_sprite.position = global_position.round() - global_position
	else:
		_sprite.position = Vector2.ZERO
	if _can_show_talk_mark() or debug_ground:
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
	_animated.play(anim_name)


func _octant_name(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return last_direction
	var idx := posmod(int(round(dir.angle() / (PI * 0.25))), 8)
	if idx != _octant_idx:
		var current_angle := float(_octant_idx) * PI * 0.25
		if absf(angle_difference(dir.angle(), current_angle)) > FACE_DEAD_ZONE:
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
	var sole := _sole_local_y()
	var drop := sole - 4.0 * s
	var oval := PackedVector2Array([
		Vector2(-16.0, -3.0) * s + Vector2(0.0, drop),
		Vector2(-8.0, 4.0) * s + Vector2(0.0, drop),
		Vector2(8.0, 4.0) * s + Vector2(0.0, drop),
		Vector2(16.0, -3.0) * s + Vector2(0.0, drop),
		Vector2(8.0, -7.0) * s + Vector2(0.0, drop),
		Vector2(-8.0, -7.0) * s + Vector2(0.0, drop),
	])
	draw_colored_polygon(oval, Color(0.02, 0.02, 0.03, 0.32))
	if debug_ground:
		draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.2, 0.2, 0.9))
		draw_line(Vector2(-22.0, sole), Vector2(22.0, sole), Color(0.2, 0.9, 0.35), 1.5)
		var feet := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if feet != null and feet.shape is CircleShape2D:
			draw_arc(feet.position, (feet.shape as CircleShape2D).radius, 0.0, TAU, 24, Color(0.3, 0.6, 1.0), 1.5)
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
