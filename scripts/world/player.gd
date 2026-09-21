class_name Slang
extends CharacterBody2D
## S'lang, the Dreamweaver.
##
## Movement uses CharacterBody2D + move_and_slide() against world solids on
## PhysicsLayers.LAYER_WORLD (props, room bounds, fences). Input is WASD in
## screen space (squashed vertically to match the isometric tiles).
##
## Visuals are an AnimatedSprite2D driven from velocity in 8 directions:
##   down, down_right, right, up_right, up, and the three west mirrors via flip_h.
## Sheets live in SlangFrames / slang_8dir.
##
## Combat (once the Lewet Staff is equipped):
##   Space             - staff sweep; bolts only if nothing is in reach
##   Shift / RMB       - dodge roll with i-frames
##   Q                 - sonic chime
##   Left-click enemy  - lock target (auto-bolts on minions, not the boss)

signal health_changed(current: float, maximum: float)
signal died
signal attacked(swing_position: Vector2, facing: Vector2)
signal chimed(origin: Vector2, radius: float)
signal staff_acquired
signal attack_hit(hit: Node2D)

const WeaveBoltScene := preload("res://scripts/world/weave_bolt.gd")

@export var speed: float = 190.0
@export var acceleration: float = 1500.0
@export var friction: float = 1800.0

const ATTACK_COOLDOWN := 0.58
const ATTACK_ANIM := 0.52
const ATTACK_DAMAGE := 34.0
const MELEE_REACH := 110.0
const MELEE_ARC := 1.45
const BOLT_DELAY := 0.28
const AUTO_ATTACK_RANGE := 380.0
const CLICK_PICK_RADIUS := 96.0

const CHIME_COOLDOWN := 2.6
const CHIME_RADIUS := 190.0
const CHIME_DAMAGE := 18.0

const INVULNERABLE_TIME := 0.55
const DODGE_COOLDOWN := 0.72
const DODGE_TIME := 0.20
const DODGE_SPEED := 520.0
const DODGE_IFRAMES := 0.26

@export var max_health := 100.0
@export var has_staff := false
@export var staff_light_enabled := false
@export var staff_light_radius := 210.0

var health := 100.0
var facing := Vector2(0.0, 1.0)
var input_enabled := true
## Last facing used for idle / walk animation names (8-dir).
var last_direction := "down"
var _octant_idx := 2

const OCTANTS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const FLIP_SHEET := {
	"left": "right",
	"up_left": "up_right",
	"down_left": "down_right",
}

var _attack_timer := 0.0
var _chime_timer := 0.0
var _invulnerable := 0.0
var _dead := false
var _hurt_flash := 0.0
var _attacking := false
var _attack_anim_left := 0.0
var _dodge_timer := 0.0
var _dodge_left := 0.0
var _dodge_dir := Vector2.ZERO
## Locked AQW-style target. Bolts auto-fire while this stays valid.
var _locked_target: Node2D
## One-shot aim for the bolt currently being cast.
var _bolt_target: Node2D

var _animated: AnimatedSprite2D
var _swing: Node2D
var _light: PointLight2D
var _staff_gem: Sprite2D
var _shadow: Sprite2D
var _base_sprite_scale := Vector2.ONE
var _base_sprite_offset := Vector2(0.0, -46.0)
var _depth_scale := 1.0
var _idle_time := 0.0


func _ready() -> void:
	add_to_group("player")
	health = max_health
	collision_layer = PhysicsLayers.LAYER_PLAYER
	collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	z_index = 0
	z_as_relative = true
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_ensure_feet_collision()
	_build_visuals()
	_apply_light()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_chime_timer = maxf(0.0, _chime_timer - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_attack_anim_left = maxf(0.0, _attack_anim_left - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_left = maxf(0.0, _dodge_left - delta)
	if _attack_anim_left <= 0.0:
		_attacking = false
		if _animated != null:
			_animated.rotation_degrees = 0.0

	_validate_locked_target()
	_try_auto_attack()
	_face_locked_target()

	var input_vector := Vector2.ZERO
	if input_enabled and not _dead:
		var up_down_neg := "move_up" if InputMap.has_action("move_up") else "move_forward"
		var up_down_pos := "move_down" if InputMap.has_action("move_down") else "move_back"
		input_vector = Input.get_vector("move_left", "move_right", up_down_neg, up_down_pos)

	_update_animation(input_vector)

	if _dodge_left > 0.0:
		velocity = _dodge_dir * DODGE_SPEED
	else:
		var direction := Iso.screen_direction(input_vector)
		if direction != Vector2.ZERO:
			if _locked_target == null:
				facing = direction
			velocity = velocity.move_toward(direction * speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	if collision_mask != PhysicsLayers.MASK_PLAYER_MOVES:
		collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	_update_hurt_flash()
	_update_idle_breathe(delta, input_vector)
	_sync_walk_stride()
	_sync_body_shadow()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or _dead or event.is_echo():
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_handle_aqw_click(get_global_mouse_position())
			return
	if event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		try_dodge()
	elif event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		try_attack()
	elif event.is_action_pressed("ability"):
		get_viewport().set_input_as_handled()
		try_chime()


# --------------------------------------------------------------------------
# Animation
# --------------------------------------------------------------------------

func _update_animation(input_vector: Vector2) -> void:
	if _animated == null:
		return

	if input_vector != Vector2.ZERO:
		last_direction = _octant_name(input_vector)

	var prefix := "attack" if _attacking else ("walk" if input_vector != Vector2.ZERO else "idle")
	_play_facing(prefix)


func _octant_name(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return last_direction
	var idx := posmod(int(round(dir.angle() / (PI * 0.25))), 8)
	# Stay on the current octant until the stick is clearly in a neighbour.
	# Stops left/right flip_h from flickering on a noisy down-ish walk.
	if idx != _octant_idx:
		var current_angle := float(_octant_idx) * PI * 0.25
		if absf(angle_difference(dir.angle(), current_angle)) > PI * 0.20:
			_octant_idx = idx
	return OCTANTS[_octant_idx]


func _play_facing(prefix: String) -> void:
	# One three-quarter model for every facing. The directional sheets are
	# different drawings of S'lang, so swapping octants popped costume, scale,
	# and stride. West still mirrors the east sheet.
	_animated.flip_h = FLIP_SHEET.has(last_direction)
	_play_anim("%s_down_right" % prefix)


func _play_anim(anim_name: String) -> void:
	if _animated.sprite_frames == null or not _animated.sprite_frames.has_animation(anim_name):
		return
	if _animated.animation == anim_name and _animated.is_playing():
		return
	var keep_stride := _animated.animation.begins_with("walk_") and anim_name.begins_with("walk_")
	var frame := _animated.frame
	var progress := _animated.frame_progress
	_animated.play(anim_name)
	if keep_stride:
		var count := _animated.sprite_frames.get_frame_count(anim_name)
		if count > 0:
			_animated.frame = frame % count
			_animated.frame_progress = progress


func apply_depth_scale(ratio: float) -> void:
	_depth_scale = ratio
	if _animated != null:
		_animated.scale = _base_sprite_scale * _depth_scale


func _update_idle_breathe(delta: float, input_vector: Vector2) -> void:
	if _animated == null or _dead:
		return
	if input_vector != Vector2.ZERO or _attack_timer > 0.0:
		_idle_time = 0.0
		_animated.offset = _base_sprite_offset
		return
	_idle_time += delta
	var bob := sin(_idle_time * 2.2) * 1.4
	_animated.offset = _base_sprite_offset + Vector2(0.0, bob)
	_animated.speed_scale = 1.0


func _sync_walk_stride() -> void:
	if _animated == null or _dead:
		return
	var anim := _animated.animation
	if anim.begins_with("walk"):
		var spd := velocity.length()
		_animated.speed_scale = clampf(spd / maxf(speed, 1.0), 0.82, 1.06)
		_animated.offset = _base_sprite_offset
		return
	if not anim.begins_with("attack"):
		_animated.speed_scale = 1.0


func _update_hurt_flash() -> void:
	if _animated == null or _dead:
		return
	if _dodge_left > 0.0 and _animated != null:
		_animated.modulate = Color(1.2, 1.25, 1.45)
		return
	_animated.modulate = Color(1.6, 0.7, 0.6) if _hurt_flash > 0.0 else Color.WHITE
	if _light != null:
		_light.position = Vector2(facing.x * 12.0, -24.0)
	if _staff_gem != null:
		# New staff art already has bells. Do not overlay a white glow on her torso.
		_staff_gem.visible = false


func _apply_light() -> void:
	var wants_light := staff_light_enabled and has_staff
	if wants_light and _light == null:
		_light = PointLight2D.new()
		_light.name = "StaffLight"
		_light.texture = _radial_texture()
		_light.color = Color(1.0, 0.88, 0.62)
		_light.energy = 1.5
		_light.texture_scale = staff_light_radius / 128.0
		add_child(_light)
	elif _light != null:
		_light.visible = wants_light
	if _staff_gem != null:
		_staff_gem.visible = false


# --------------------------------------------------------------------------
# Abilities
# --------------------------------------------------------------------------

func try_attack() -> bool:
	if _dodge_left > 0.0:
		return false
	var boss := get_tree().get_first_node_in_group("boss") as Node2D
	if boss != null and is_instance_valid(boss) \
			and Iso.iso_distance(global_position, boss.global_position) <= MELEE_REACH + 64.0:
		_set_locked_target(boss)
		return _cast_bolt_at(boss, boss.global_position)
	if _locked_target != null and is_instance_valid(_locked_target):
		return _cast_bolt_at(_locked_target, _locked_target.global_position)
	return try_attack_at(get_global_mouse_position())


func try_dodge() -> bool:
	if not input_enabled or _dead or _dodge_timer > 0.0:
		return false
	var up_down_neg := "move_up" if InputMap.has_action("move_up") else "move_forward"
	var up_down_pos := "move_down" if InputMap.has_action("move_down") else "move_back"
	var stick := Input.get_vector("move_left", "move_right", up_down_neg, up_down_pos)
	var dir := Iso.screen_direction(stick)
	if dir == Vector2.ZERO:
		dir = facing if facing != Vector2.ZERO else Vector2(0, 1)
	_dodge_dir = dir
	_dodge_left = DODGE_TIME
	_dodge_timer = DODGE_COOLDOWN
	_invulnerable = maxf(_invulnerable, DODGE_IFRAMES)
	_attacking = false
	velocity = _dodge_dir * DODGE_SPEED
	Audio.play_sfx(Audio.Sfx.HIT)
	Fx.punch(self, 0.08)
	if _animated != null:
		_animated.modulate = Color(1.35, 1.4, 1.6)
	return true


func apply_knockback(from_world: Vector2, force := 280.0) -> void:
	if _dead or _dodge_left > 0.0:
		return
	var away := global_position - from_world
	if away.length() < 4.0:
		away = Vector2(0, 1)
	velocity = away.normalized() * force


## AQ Worlds style: left-click locks a monster; bolts auto-fire while locked.
func try_attack_at(world_point: Vector2) -> bool:
	var clicked := _pick_click_target(world_point)
	if clicked != null:
		_set_locked_target(clicked)
		return _cast_bolt_at(clicked, clicked.global_position)
	return _cast_bolt_at(null, world_point)


func _handle_aqw_click(world_point: Vector2) -> void:
	var clicked := _pick_click_target(world_point)
	if clicked != null:
		_set_locked_target(clicked)
		_cast_bolt_at(clicked, clicked.global_position)
		return
	# Empty ground clears the lock so you can re-pick, AQW-style.
	_set_locked_target(null)
	_cast_bolt_at(null, world_point)


func _try_auto_attack() -> void:
	if not input_enabled or _dead or not has_staff:
		return
	if _locked_target != null and _locked_target.is_in_group("boss"):
		return
	if _locked_target == null or _attack_timer > 0.0:
		return
	if not is_instance_valid(_locked_target) or not _locked_target.is_inside_tree():
		return
	if Iso.iso_distance(global_position, _locked_target.global_position) > AUTO_ATTACK_RANGE:
		return
	_cast_bolt_at(_locked_target, _locked_target.global_position)


func _cast_bolt_at(target: Node2D, world_point: Vector2) -> bool:
	if not has_staff or _attack_timer > 0.0 or _dead:
		return false
	_bolt_target = target
	if target != null and is_instance_valid(target):
		_face_vector(target.global_position - global_position)
	else:
		_face_vector(world_point - global_position)
	_attack_timer = ATTACK_COOLDOWN
	_attacking = true
	_attack_anim_left = ATTACK_ANIM
	Audio.play_sfx(Audio.Sfx.BELL)
	Audio.play_sfx(Audio.Sfx.HIT)
	_play_cast_pose()
	_play_cast_flash()
	Fx.staff_trail(self, facing, 72.0)
	Fx.punch(self, 0.05)
	var swing_point := global_position + facing * 48.0
	attacked.emit(swing_point, facing)
	# Close-range staff sweep is the primary strike. Bolts only fly when the
	# arc does not connect, so Chapter 5 plays as melee + Q shockwave.
	if _staff_melee() <= 0:
		var fire := get_tree().create_timer(BOLT_DELAY)
		fire.timeout.connect(_fire_weave_bolt, CONNECT_ONE_SHOT)
	else:
		_bolt_target = null
	return true


func _set_locked_target(target: Node2D) -> void:
	if _locked_target == target:
		if target != null and target.has_method("set_selected"):
			target.set_selected(true)
		return
	if _locked_target != null and is_instance_valid(_locked_target) \
			and _locked_target.has_method("set_selected"):
		_locked_target.set_selected(false)
	_locked_target = target
	if _locked_target != null and _locked_target.has_method("set_selected"):
		_locked_target.set_selected(true)


func _validate_locked_target() -> void:
	if _locked_target == null:
		return
	if not is_instance_valid(_locked_target) or not _locked_target.is_inside_tree():
		_locked_target = null
		return
	if _locked_target.has_method("is_defeated") and _locked_target.is_defeated():
		_set_locked_target(null)
		return
	if _locked_target is ShadowMinion and (_locked_target as ShadowMinion).health <= 0.0:
		_set_locked_target(null)


func _face_locked_target() -> void:
	if _dodge_left > 0.0:
		return
	if _locked_target == null or not is_instance_valid(_locked_target):
		return
	_face_vector(_locked_target.global_position - global_position)


## Prefer the hittable under the cursor; otherwise the closest near the click.
func _pick_click_target(world_point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := CLICK_PICK_RADIUS
	for node in get_tree().get_nodes_in_group("hittable"):
		var target := node as Node2D
		if target == null or not target.is_inside_tree():
			continue
		if target.has_method("is_defeated") and target.is_defeated():
			continue
		# Prefer enemies near the cursor; also accept clicks a little below their feet.
		var d := minf(
			world_point.distance_to(target.global_position + Vector2(0.0, -28.0)),
			world_point.distance_to(target.global_position)
		)
		if d < best_d:
			best_d = d
			best = target
	return best


func try_chime() -> bool:
	if not has_staff or _chime_timer > 0.0 or _dead:
		return false
	_chime_timer = CHIME_COOLDOWN
	Audio.play_sfx(Audio.Sfx.CHIME)
	_play_shockwave()
	Fx.punch(self, 0.08)

	for target in _targets_in_range(global_position, CHIME_RADIUS):
		if target.has_method("stun"):
			target.stun(1.2)
		if target.has_method("take_damage"):
			target.take_damage(CHIME_DAMAGE, self)
			Fx.hit_flash(target, Palette.GOLD_SACRED)
	chimed.emit(global_position, CHIME_RADIUS)
	return true


func _aim_from_mouse() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 18.0:
		_face_vector(to_mouse)
	elif facing == Vector2.ZERO:
		_face_vector(Vector2(0, 1))


func _face_vector(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	_octant_idx = posmod(int(round(facing.angle() / (PI * 0.25))), 8)
	last_direction = OCTANTS[_octant_idx]


func _play_cast_pose() -> void:
	if _animated == null:
		return
	_play_facing("attack")
	# The attack sheet already carries the swing. Tilting the whole actor
	# pivoted her feet off the floor and made every strike look like a flop.
	_animated.rotation_degrees = 0.0


func _fire_weave_bolt() -> void:
	if not is_inside_tree() or _dead or not has_staff:
		return
	var aim: Node2D = null
	if _bolt_target != null and is_instance_valid(_bolt_target):
		aim = _bolt_target
	elif _locked_target != null and is_instance_valid(_locked_target):
		aim = _locked_target
	if aim != null:
		_face_vector(aim.global_position - global_position)
	var bolt := WeaveBoltScene.new()
	bolt.direction = facing if facing != Vector2.ZERO else Vector2(0, 1)
	bolt.damage = ATTACK_DAMAGE
	bolt.source = self
	if aim != null:
		bolt.target = aim
	bolt.global_position = global_position + bolt.direction * 22.0 + Vector2(0.0, -36.0)
	var host: Node = get_parent()
	if host != null:
		host.add_child(bolt)
	else:
		add_child(bolt)
	_bolt_target = null


## Battle UI spends the chime cooldown and plays the pulse without re-targeting.
func force_chime_pulse() -> void:
	if not has_staff:
		return
	_chime_timer = CHIME_COOLDOWN
	Audio.play_sfx(Audio.Sfx.CHIME)
	_play_shockwave()
	chimed.emit(global_position, CHIME_RADIUS)


func chime_ready() -> bool:
	return has_staff and _chime_timer <= 0.0


func chime_cooldown_ratio() -> float:
	return 1.0 - (_chime_timer / CHIME_COOLDOWN)


func equip_staff() -> void:
	if has_staff:
		staff_acquired.emit()
		return
	has_staff = true
	GameState.add_item("lewet_staff")
	_apply_light()
	staff_acquired.emit()


func set_light_enabled(value: bool) -> void:
	staff_light_enabled = value
	_apply_light()


# --------------------------------------------------------------------------
# Damage
# --------------------------------------------------------------------------

func take_damage(amount: float, _source: Node = null) -> void:
	if _dead or _invulnerable > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_invulnerable = INVULNERABLE_TIME
	_hurt_flash = 0.25
	Audio.play_sfx(Audio.Sfx.THUD)
	Fx.punch(self, 0.14)
	Fx.hit_flash(self, Palette.RED_EMBER)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_dead = true
		input_enabled = false
		velocity = Vector2.ZERO
		_set_locked_target(null)
		if _animated != null:
			var fade := create_tween()
			fade.tween_property(_animated, "modulate", Color(0.45, 0.42, 0.4, 0.35), 0.45)
		died.emit()


func heal_full() -> void:
	_dead = false
	health = max_health
	_invulnerable = INVULNERABLE_TIME
	if _animated != null:
		_animated.modulate = Color.WHITE
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return _dead


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		velocity = Vector2.ZERO


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

## Lewet Staff melee: hit every nearby enemy inside a facing cone.
func _staff_melee() -> int:
	if not has_staff or _dead:
		return 0
	var hits := 0
	var origin := global_position
	var aim := facing if facing != Vector2.ZERO else Vector2(0, 1)
	for target in _targets_in_range(origin, MELEE_REACH):
		var to_target := target.global_position - origin
		if to_target.length() > 14.0:
			var aligned := aim.normalized().dot(to_target.normalized())
			if aligned < cos(MELEE_ARC):
				continue
		if target.has_method("take_damage"):
			target.take_damage(ATTACK_DAMAGE, self)
			Fx.hit_flash(target, Palette.GOLD_SUN)
			Fx.punch(target, 0.1)
			attack_hit.emit(target)
			hits += 1
	return hits


func _targets_in_range(origin: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("hittable"):
		var target := node as Node2D
		if target == null or not target.is_inside_tree():
			continue
		var extra := 24.0
		if target.has_method("hit_radius"):
			extra = float(target.call("hit_radius"))
		if Iso.iso_distance(origin, target.global_position) <= radius + extra:
			found.append(target)
	return found


## Small circle at the feet so tall props occlude correctly while still blocking.
func _ensure_feet_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	shape_node.shape = PhysicsLayers.feet_circle(14.0)
	shape_node.position = Vector2(0.0, -2.0)
	shape_node.disabled = false
	collision_layer = PhysicsLayers.LAYER_PLAYER
	collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	# Top-down style: collide with walls/props, ignore floor concepts.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.08
	slide_on_ceiling = true
	floor_stop_on_slope = false
	# Make sure physics queries see us every frame.
	set_physics_process(true)


func _build_visuals() -> void:
	_animated = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _animated == null:
		_animated = AnimatedSprite2D.new()
		_animated.name = "AnimatedSprite2D"
		add_child(_animated)

	_animated.sprite_frames = SlangFrames.load_or_build()
	_animated.centered = true
	# Locked for every animation — see SlangFrames header comments.
	# Frame canvas: 256×192 px, feet at bottom-centre. Keep a uniform scale:
	# scaling X by canvas width would squash S'lang after widening attack cells.
	# offset (0,-46) places those feet on this CharacterBody2D origin.
	_base_sprite_offset = Vector2(0.0, -46.0)
	var art_scale := 92.0 / float(SlangFrames.FRAME_H)
	_base_sprite_scale = Vector2(art_scale, art_scale)
	_animated.offset = _base_sprite_offset
	_animated.scale = _base_sprite_scale
	_animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_animated.play("idle_down_right")
	_build_shadow()
	_build_staff_gem()

	_swing = get_node_or_null("Swing") as Node2D
	if _swing == null:
		_swing = Node2D.new()
		_swing.name = "Swing"
		add_child(_swing)
	_swing.visible = false
	_swing.z_index = 10


func _build_shadow() -> void:
	if _shadow != null:
		return
	_shadow = Sprite2D.new()
	_shadow.name = "BodyShadow"
	_shadow.centered = true
	_shadow.z_as_relative = true
	_shadow.z_index = -1
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Flattened silhouette on the ground — not a floor diamond.
	_shadow.modulate = Color(0.04, 0.03, 0.05, 0.40)
	_shadow.skew = deg_to_rad(22.0)
	add_child(_shadow)
	move_child(_shadow, 0)
	_sync_body_shadow()


func _sync_body_shadow() -> void:
	if _shadow == null or _animated == null:
		return
	if _dead or _animated.sprite_frames == null:
		_shadow.visible = false
		return
	var anim := _animated.animation
	if anim.is_empty() or not _animated.sprite_frames.has_animation(anim):
		_shadow.visible = false
		return
	var frame := clampi(_animated.frame, 0, _animated.sprite_frames.get_frame_count(anim) - 1)
	_shadow.texture = _animated.sprite_frames.get_frame_texture(anim, frame)
	_shadow.flip_h = _animated.flip_h
	_shadow.offset = _animated.offset
	_shadow.scale = Vector2(_animated.scale.x * 1.08, _animated.scale.y * 0.22)
	# Iso light from the upper-left; the shadow falls down-right of her feet.
	_shadow.position = Vector2(9.0, 4.0)
	_shadow.visible = true


func _build_staff_gem() -> void:
	if _staff_gem != null:
		return
	_staff_gem = Sprite2D.new()
	_staff_gem.name = "LewetGem"
	_staff_gem.visible = false
	add_child(_staff_gem)


func _radial_texture() -> GradientTexture2D:
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


func _play_cast_flash() -> void:
	if _swing == null:
		return
	var spark := Sprite2D.new()
	spark.texture = _radial_texture()
	spark.modulate = Color(1.15, 0.95, 0.28, 0.95)
	spark.scale = Vector2(0.1, 0.1)
	spark.position = facing * 18.0 + Vector2(0.0, -40.0)
	_swing.add_child(spark)
	_swing.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(0.42, 0.28), 0.16)
	tween.tween_property(spark, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(spark.queue_free)


func _play_shockwave() -> void:
	var ring := Sprite2D.new()
	ring.texture = _radial_texture()
	ring.modulate = Color(0.95, 0.88, 0.62, 0.75)
	ring.scale = Vector2(0.1, 0.06)
	ring.z_index = 8
	add_child(ring)

	var target_scale := (CHIME_RADIUS * 2.0) / 256.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(target_scale, target_scale * 0.6), 0.45)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)
