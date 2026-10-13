class_name Slang
extends CharacterBody2D

## S'lang, the Dreamweaver.
##
## Movement uses CharacterBody2D + move_and_slide() against world solids on
## PhysicsLayers.LAYER_WORLD (props, room bounds, fences). WASD is the direction
## she moves and faces. Space swings that way. A left click can still lock an
## enemy and run her in.
##
## Visuals are an AnimatedSprite2D driven from velocity in 8 directions:
##   down, down_right, right, up_right, up, and the three west mirrors via flip_h.
## Sheets live in SlangFrames / slang_8dir.
##
## Combat (once the Lewet Staff is equipped):
##   Space             - melee staff sweep along WASD, or her current facing
##   Shift / RMB       - dodge roll with i-frames
##   1                 - woven ward, a damage barrier that holds for a few seconds
##   2                 - light beam, unlocked after Chapter 5 waves 1–3
##   Q                 - sonic shockwave around her feet
##   Left-click enemy  - lock, run in, then melee when she is close enough

signal health_changed(current: float, maximum: float)
signal died
signal attacked(swing_position: Vector2, facing: Vector2)
signal chimed(origin: Vector2, radius: float)
signal staff_acquired
signal attack_hit(hit: Node2D)
signal dodged
signal ward_raised
signal warded(perfect: bool)

@export var speed: float = 190.0
@export var acceleration: float = 1500.0
@export var friction: float = 1800.0

const ATTACK_COOLDOWN := 0.58
const ATTACK_ANIM := 0.52
const ATTACK_DAMAGE := 58.0
const MELEE_REACH := 128.0
const MELEE_ARC := 1.45
const CLICK_PICK_RADIUS := 96.0

const CHIME_COOLDOWN := 2.6
const CHIME_RADIUS := 190.0
const CHIME_DAMAGE := 32.0
const LIFE_THREAD_VINE_DAMAGE := 92.0
const SHOCKWAVE_PATH := "res://assets/images/vfx/slang_shockwave.png"
const SHOCKWAVE_FRAMES := 8
const SHOCKWAVE_FPS := 7.0

const INVULNERABLE_TIME := 0.55
const DODGE_COOLDOWN := 0.68
const DODGE_TIME := 0.24
const DODGE_SPEED := 540.0
const DODGE_IFRAMES := 0.38
const WARD_TIME := 4.5
const WARD_PERFECT := 0.22
const WARD_COOLDOWN := 6.5
const WARD_BARRIER := 100.0
const WARD_SLOW := 0.82
const WARD_COLOR := Color(1.0, 0.82, 0.38)
const WARD_SHEET := "res://assets/images/vfx/slang_ward.png"
const WARD_SHEET_FRAMES := 8
const BEAM_COOLDOWN := 10.0
const BEAM_DAMAGE := 230.0
const BEAM_LENGTH := 560.0
const BEAM_HALF_WIDTH := 38.0
const BEAM_CHARGE := 0.48
const BEAM_GOLD := Color(1.55, 1.22, 0.55, 0.96)
const BEAM_BURST := "res://assets/images/vfx/weave_bolt_burst.png"
## Set false to go back to the single down_right sheet for every facing.
const USE_DIRECTIONAL_SHEETS := true
## Walk starts above START, stops below STOP. The gap stops walk/idle flicker.
const WALK_START_SPEED := 30.0
const WALK_STOP_SPEED := 10.0
## Movement multiplier while a staff swing animation plays (stops attack-sliding).
const ATTACK_MOVE_MULT := 0.35

@export var max_health := 100.0
@export var has_staff := false:
	set(value):
		has_staff = value
		_apply_staff_visual()
@export var has_light_beam := false
@export var has_life_thread := false
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
var _ward_left := 0.0
var _ward_hp := 0.0
var _ward_timer := 0.0
var _ward_fx: Node2D
var _ward_frames: SpriteFrames
var _beam_timer := 0.0
var _beam_root := 0.0
var _beam_charge: Node2D
## Locked target. Clicking one out of range makes her chase until she can swing.
var _locked_target: Node2D
var _chasing := false
var _talk_npc: Node2D
var _approaching_talk := false
var _shockwave_frames: SpriteFrames

var _animated: AnimatedSprite2D
var _swing: Node2D
var _light: PointLight2D
var _staff_gem: Sprite2D
var _shadow: Sprite2D
var _base_sprite_scale := Vector2.ONE
var _base_sprite_offset := Vector2(0.0, -46.0)
var _depth_scale := 1.0
var _stride_speed := 190.0
var _idle_time := 0.0
var _walking := false


func _ready() -> void:
	add_to_group("player")
	_stride_speed = speed
	health = max_health
	if GameState.has_item("light_beam"):
		has_light_beam = true
	collision_layer = PhysicsLayers.LAYER_PLAYER
	collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	z_index = 0
	z_as_relative = true
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_ensure_feet_collision()
	_build_visuals()
	_apply_light()
	attacked.connect(func(_at: Vector2, _dir: Vector2) -> void: Audio.play_house_cue(&"swing"))
	attack_hit.connect(func(_hit: Node2D) -> void: Audio.play_house_cue(&"strike"))
	chimed.connect(func(_at: Vector2, _radius: float) -> void: Audio.play_house_cue(&"skill"))
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_chime_timer = maxf(0.0, _chime_timer - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_attack_anim_left = maxf(0.0, _attack_anim_left - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_left = maxf(0.0, _dodge_left - delta)
	_ward_timer = maxf(0.0, _ward_timer - delta)
	_beam_timer = maxf(0.0, _beam_timer - delta)
	_beam_root = maxf(0.0, _beam_root - delta)
	if _ward_left > 0.0:
		_ward_left = maxf(0.0, _ward_left - delta)
		if _ward_left <= 0.0:
			_ward_hp = 0.0
			_drop_ward_fx()
		else:
			_refresh_ward_tint()
	if _attack_anim_left <= 0.0:
		_attacking = false
		if _animated != null:
			_animated.rotation_degrees = 0.0

	_validate_locked_target()
	var input_vector := _steering()
	if input_vector != Vector2.ZERO:
		_chasing = false
		_clear_talk_approach()
	_try_auto_attack()
	_face_locked_target()

	var chase_dir := _talk_chase_direction()
	if chase_dir == Vector2.ZERO:
		chase_dir = _chase_direction()
	var anim_stick := input_vector if input_vector != Vector2.ZERO else chase_dir

	if _dodge_left > 0.0:
		velocity = _dodge_dir * _dodge_speed()
	else:
		var move_speed := speed * (WARD_SLOW if _ward_left > 0.0 else 1.0)
		if _beam_root > 0.0:
			move_speed *= 0.2
		elif _attacking:
			move_speed *= ATTACK_MOVE_MULT
		var target_vel := Vector2.ZERO
		if input_vector != Vector2.ZERO:
			facing = input_vector.normalized()
			target_vel = facing * move_speed
		elif chase_dir != Vector2.ZERO:
			target_vel = chase_dir.normalized() * move_speed
		# Ease in and out instead of snapping. Uses the exported
		# acceleration / friction that were previously unused.
		var rate := acceleration if target_vel != Vector2.ZERO else friction
		velocity = velocity.move_toward(target_vel, rate * delta)
	if Input.is_action_pressed("attack"):
		try_attack()

	move_and_slide()
	if collision_mask != PhysicsLayers.MASK_PLAYER_MOVES:
		collision_mask = PhysicsLayers.MASK_PLAYER_MOVES
	var spd := velocity.length()
	if _dodge_left > 0.0:
		_walking = false
	elif _walking:
		_walking = spd > WALK_STOP_SPEED
	else:
		_walking = spd > WALK_START_SPEED
	var moving := _walking
	var face_dir := anim_stick if anim_stick != Vector2.ZERO else (velocity if moving else Vector2.ZERO)
	_update_animation(face_dir, moving)
	_update_hurt_flash()
	_update_idle_breathe(delta, moving)
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
	elif event.is_action_pressed("ward"):
		get_viewport().set_input_as_handled()
		try_ward()
	elif InputMap.has_action("beam") and event.is_action_pressed("beam"):
		get_viewport().set_input_as_handled()
		try_beam()
	elif event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		try_attack()
	elif event.is_action_pressed("ability"):
		get_viewport().set_input_as_handled()
		try_chime()


# --------------------------------------------------------------------------
# Animation
# --------------------------------------------------------------------------

func _update_animation(facing_dir: Vector2, moving: bool) -> void:
	if _animated == null:
		return

	if facing_dir != Vector2.ZERO:
		last_direction = _octant_name(facing_dir)

	var prefix := "attack" if _attacking else ("walk" if moving else "idle")
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
	var mirrored := FLIP_SHEET.has(last_direction)
	var sheet: String = FLIP_SHEET.get(last_direction, last_direction)
	var anim_name := "%s_%s" % [prefix, sheet]
	_animated.flip_h = mirrored
	if USE_DIRECTIONAL_SHEETS and _animated.sprite_frames != null \
			and _animated.sprite_frames.has_animation(anim_name):
		_play_anim(anim_name)
	else:
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
	match_stride_to(ratio)


## 190 px/s matches her feet at the house sprite size. A smaller ridge sprite
## needs a slower step or she scoots across the painting.
func match_stride_to(sprite_scale: float, tuned_at := 2.6) -> void:
	if tuned_at <= 0.01:
		return
	speed = _stride_speed * sprite_scale / tuned_at


func _dodge_speed() -> float:
	return DODGE_SPEED * speed / maxf(_stride_speed, 1.0)


func depth_scale() -> float:
	return _depth_scale


func _update_idle_breathe(_delta: float, moving: bool) -> void:
	if _animated == null or _dead:
		return
	if moving or _attack_timer > 0.0:
		_idle_time = 0.0
	_animated.offset = _base_sprite_offset
	if not moving and _attack_timer <= 0.0:
		_animated.speed_scale = 1.0


func _sync_walk_stride() -> void:
	if _animated == null or _dead:
		return
	_animated.offset = _base_sprite_offset
	if _animated.animation.begins_with("walk"):
		var ratio := velocity.length() / maxf(speed, 1.0)
		_animated.speed_scale = clampf(ratio, 0.45, 1.25)
	else:
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
	if not input_enabled or _dead or not has_staff or _attack_timer > 0.0:
		return false
	if _dodge_left > 0.0 or _beam_root > 0.0:
		return false
	_chasing = false
	var stick := _steering()
	var aim := stick if stick != Vector2.ZERO else facing
	if aim == Vector2.ZERO:
		aim = Vector2(0.0, 1.0)
	var assist := _nearest_ahead(aim)
	if assist != null:
		_face_vector(assist.global_position - global_position)
	else:
		_face_vector(aim)
	return _swing_staff(null)


func try_dodge() -> bool:
	if not input_enabled or _dead or _dodge_timer > 0.0 or _beam_root > 0.0:
		return false
	var up_down_neg := "move_up" if InputMap.has_action("move_up") else "move_forward"
	var up_down_pos := "move_down" if InputMap.has_action("move_down") else "move_back"
	var stick := Input.get_vector("move_left", "move_right", up_down_neg, up_down_pos)
	var dir := stick.normalized() if stick != Vector2.ZERO else Vector2.ZERO
	if dir == Vector2.ZERO:
		dir = facing if facing != Vector2.ZERO else Vector2(0, 1)
	_dodge_dir = dir
	_dodge_left = DODGE_TIME
	_dodge_timer = DODGE_COOLDOWN
	_invulnerable = maxf(_invulnerable, DODGE_IFRAMES)
	_attacking = false
	velocity = _dodge_dir * _dodge_speed()
	Audio.play_sfx(Audio.Sfx.HIT)
	Fx.punch(self, 0.08)
	if _animated != null:
		_animated.modulate = Color(1.35, 1.4, 1.6)
	dodged.emit()
	return true


## Raises a woven ward. It soaks a pool of damage, then breaks. A blow caught
## in the first instant is a perfect guard and does not spend the barrier.
func try_ward() -> bool:
	if not input_enabled or _dead or not has_staff or _ward_timer > 0.0 or _dodge_left > 0.0 or _beam_root > 0.0:
		return false
	_ward_left = WARD_TIME
	_ward_hp = WARD_BARRIER
	_ward_timer = WARD_COOLDOWN
	_attacking = false
	velocity *= 0.35
	Audio.play_fx("slang_ward_raise", -2.0, 0.04)
	Audio.play_house_cue(&"ward")
	_raise_ward_fx()
	ward_raised.emit()
	return true


func is_warding() -> bool:
	return _ward_left > 0.0


func ward_cooldown_ratio() -> float:
	return clampf(_ward_timer / WARD_COOLDOWN, 0.0, 1.0)


## The staff gathers, then throws a beam down her facing. Unlocked after the
## first three waves of the Sacred Loom.
func unlock_light_beam() -> void:
	has_light_beam = true
	GameState.add_item("light_beam")


func try_beam() -> bool:
	if not input_enabled or _dead or not has_staff or not has_light_beam:
		return false
	if _beam_timer > 0.0 or _dodge_left > 0.0 or _beam_root > 0.0:
		return false
	var stick := _steering()
	if stick != Vector2.ZERO:
		_face_vector(stick)
	elif _chasing and _is_valid_hit(_locked_target):
		_face_vector(_locked_target.global_position - global_position)
	_beam_timer = BEAM_COOLDOWN
	_beam_root = BEAM_CHARGE
	_attacking = true
	_attack_anim_left = BEAM_CHARGE + 0.45
	velocity *= 0.15
	_play_cast_pose()
	_charge_beam_fx()
	Audio.play_sfx(Audio.Sfx.BELL)
	Audio.play_house_cue(&"skill")
	var aim := facing
	var release := create_tween()
	release.tween_interval(BEAM_CHARGE)
	release.tween_callback(_release_beam.bind(aim))
	return true


func beam_ready() -> bool:
	return has_light_beam and has_staff and _beam_timer <= 0.0 and not _dead


func beam_cooldown_ratio() -> float:
	if not has_light_beam:
		return 0.0
	return 1.0 - (_beam_timer / BEAM_COOLDOWN)


func _charge_beam_fx() -> void:
	_clear_beam_charge()
	var holder := Node2D.new()
	holder.name = "BeamCharge"
	holder.position = Vector2(0.0, -50.0)
	holder.z_index = 22
	holder.scale = Vector2(0.28, 0.28)
	add_child(holder)
	_beam_charge = holder
	var gather := ShadowFx.attach(holder, ShadowFx.CHARGE, Vector2.ZERO, 16.0, true, Vector2(0.85, 0.85), 1)
	if gather != null:
		gather.modulate = BEAM_GOLD
	var core := Sprite2D.new()
	core.texture = Palette.read_texture(BEAM_BURST)
	core.centered = true
	core.scale = Vector2(0.22, 0.22)
	core.modulate = Color(1.15, 1.02, 0.72, 0.85)
	core.material = ShadowFx.additive()
	core.z_index = 2
	holder.add_child(core)
	var grow := holder.create_tween()
	grow.tween_property(holder, "scale", Vector2(1.15, 1.15), BEAM_CHARGE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _clear_beam_charge() -> void:
	if _beam_charge != null and is_instance_valid(_beam_charge):
		_beam_charge.queue_free()
	_beam_charge = null


func _release_beam(aim: Vector2) -> void:
	if _dead or not is_inside_tree():
		return
	_clear_beam_charge()
	if aim.length() < 0.01:
		aim = facing if facing != Vector2.ZERO else Vector2(0, 1)
	aim = aim.normalized()
	facing = aim
	_play_cast_pose()
	_spawn_beam_visual(aim)
	_play_shockwave()
	Audio.play_sfx(Audio.Sfx.CHIME)
	Audio.play_sfx(Audio.Sfx.HIT)
	Fx.punch(self, 0.14)
	var origin := global_position + Vector2(0.0, -46.0)
	for target in _targets_in_beam(aim):
		var along := ((target.global_position + Vector2(0.0, -36.0)) - origin).dot(aim)
		var delay := clampf(along / BEAM_LENGTH, 0.0, 1.0) * 0.2
		var strike := create_tween()
		strike.tween_interval(delay)
		strike.tween_callback(_beam_strike.bind(target))


func _beam_strike(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var result: Variant = target.take_damage(BEAM_DAMAGE, self)
	if result is bool and not result:
		return
	Fx.hit_flash(target, Color(1.0, 0.95, 0.7))
	var host: Node = target.get_parent()
	if host != null and host.is_inside_tree():
		var impact := ShadowFx.burst(host, ShadowFx.BOLT_IMPACT,
				target.global_position + Vector2(0.0, -40.0), 18.0, Vector2(1.35, 1.35), 0.0, 24)
		if impact != null:
			impact.modulate = BEAM_GOLD
		var spark := ShadowFx.burst(host, ShadowFx.HIT_SPARK,
				target.global_position + Vector2(0.0, -48.0), 22.0, Vector2(0.65, 0.65), 0.0, 25)
		if spark != null:
			spark.modulate = BEAM_GOLD
		Fx.damage_number(host, target.global_position, int(BEAM_DAMAGE), Color(1.0, 0.92, 0.55))
	attack_hit.emit(target)


func _targets_in_beam(aim: Vector2) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var origin := global_position + Vector2(0.0, -40.0)
	for node in get_tree().get_nodes_in_group("hittable"):
		if not _is_valid_hit(node):
			continue
		var target := node as Node2D
		var to := target.global_position + Vector2(0.0, -36.0) - origin
		var along := to.dot(aim)
		if along < 12.0 or along > BEAM_LENGTH:
			continue
		var side := (to - aim * along).length()
		var width := BEAM_HALF_WIDTH
		if target.has_method("hit_radius"):
			width += minf(float(target.call("hit_radius")) * 0.22, 42.0)
		if side <= width:
			found.append(target)
	return found


func _spawn_beam_visual(aim: Vector2) -> void:
	var host: Node = get_parent()
	if host == null:
		host = self
	var beam := Node2D.new()
	beam.name = "LightBeam"
	beam.z_index = 18
	host.add_child(beam)
	beam.global_position = global_position + Vector2(0.0, -48.0)
	beam.rotation = aim.angle()

	var core := Sprite2D.new()
	core.texture = Palette.read_texture(BEAM_BURST)
	core.centered = true
	core.position = Vector2(BEAM_LENGTH * 0.48, 0.0)
	core.scale = Vector2(BEAM_LENGTH / 210.0, 0.42)
	core.modulate = Color(1.2, 1.05, 0.7, 0.0)
	core.material = ShadowFx.additive()
	core.z_index = 1
	beam.add_child(core)
	var core_in := core.create_tween()
	core_in.tween_property(core, "modulate:a", 0.9, 0.08)

	var disk := ShadowFx.attach(beam, "res://assets/images/vfx/weaver_nova_ring.png",
			Vector2(36.0, 0.0), 18.0, false, Vector2(0.9, 0.9), 2)
	if disk != null:
		disk.modulate = BEAM_GOLD
	var slam := ShadowFx.attach(beam, "res://assets/images/vfx/weaver_slam_ring.png",
			Vector2(24.0, 0.0), 16.0, false, Vector2(1.15, 0.62), 0)
	if slam != null:
		slam.modulate = BEAM_GOLD
	# The flame sheet grows upward. Turn it so the column runs down the beam.
	var muzzle := ShadowFx.attach(beam, ShadowFx.DASH_BURST,
			Vector2(64.0, 0.0), 18.0, false, Vector2(0.85, 1.45), 3)
	if muzzle != null:
		muzzle.rotation = -PI * 0.5
		muzzle.modulate = BEAM_GOLD

	var span := BEAM_LENGTH - 150.0
	for i in range(8):
		var along := 86.0 + span * float(i) / 7.0
		var bolt := ShadowFx.attach(beam, ShadowFx.SHADOW_BOLT, Vector2(along, 0.0),
				14.0, true, Vector2(0.92, 0.78), 4)
		if bolt == null:
			continue
		bolt.modulate = Color(BEAM_GOLD.r, BEAM_GOLD.g, BEAM_GOLD.b, 0.0)
		bolt.frame = i % 8
		var fade := bolt.create_tween()
		fade.tween_interval(0.025 * float(i))
		fade.tween_property(bolt, "modulate:a", 0.95, 0.06)
		var spark_at := along
		var spark_tw := beam.create_tween()
		spark_tw.tween_interval(0.03 * float(i))
		spark_tw.tween_callback(_beam_spark.bind(beam, spark_at))

	var tip_tw := beam.create_tween()
	tip_tw.tween_interval(0.14)
	tip_tw.tween_callback(_beam_tip.bind(beam))

	var life := beam.create_tween()
	life.tween_interval(0.62)
	life.tween_property(beam, "modulate:a", 0.0, 0.22)
	life.tween_callback(beam.queue_free)


func _beam_tip(beam: Node2D) -> void:
	if not is_instance_valid(beam):
		return
	var tip := ShadowFx.attach(beam, ShadowFx.BOLT_IMPACT, Vector2(BEAM_LENGTH - 16.0, 0.0),
			16.0, false, Vector2(1.45, 1.45), 5)
	if tip != null:
		tip.modulate = BEAM_GOLD


func _beam_spark(beam: Node2D, along: float) -> void:
	if not is_instance_valid(beam):
		return
	var spark := ShadowFx.attach(beam, ShadowFx.HIT_SPARK, Vector2(along, randf_range(-10.0, 10.0)),
			22.0, false, Vector2(0.55, 0.55), 6)
	if spark != null:
		spark.modulate = BEAM_GOLD


## True inside a roll's i-frames or the opening beat of a ward.
func is_perfect_evade() -> bool:
	return is_dodge_invulnerable() or (not _dead and _ward_left > WARD_TIME - WARD_PERFECT)


func _block_with_ward(amount: float) -> void:
	var perfect := _ward_left > WARD_TIME - WARD_PERFECT
	if not perfect:
		_ward_hp = maxf(0.0, _ward_hp - amount)
	Audio.play_fx("slang_ward_block", 0.0 if perfect else -3.0, 0.05)
	Fx.punch(self, 0.06)
	Fx.ring_pulse(self, WARD_COLOR, 110.0 if perfect else 70.0)
	if _ward_fx != null and is_instance_valid(_ward_fx):
		_ward_fx.modulate = Color(2.2, 1.9, 1.3, 1.0)
		var flare := _ward_fx.create_tween()
		flare.tween_property(_ward_fx, "modulate", Color.WHITE, 0.2)
	warded.emit(perfect)
	if _ward_hp <= 0.0:
		_ward_left = 0.0
		_drop_ward_fx()


func _refresh_ward_tint() -> void:
	if _ward_fx == null or not is_instance_valid(_ward_fx):
		return
	var remain := clampf(_ward_hp / WARD_BARRIER, 0.0, 1.0)
	_ward_fx.modulate.a = lerpf(0.78, 0.92, remain)


func _raise_ward_fx() -> void:
	_drop_ward_fx()
	var ward := WardRing.new()
	ward.name = "Ward"
	ward.modulate.a = 0.92
	add_child(ward)
	_ward_fx = ward
	_fit_ward()
	var fitted := ward.scale
	ward.scale = fitted * 0.72
	var grow := ward.create_tween()
	grow.tween_property(ward, "scale", fitted, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ward_sprite_frames() -> SpriteFrames:
	if _ward_frames != null:
		return _ward_frames
	var image := Palette.read_image(WARD_SHEET)
	if image == null:
		return null
	var frames := SpriteFrames.new()
	frames.add_animation(&"hold")
	frames.set_animation_loop(&"hold", true)
	frames.set_animation_speed(&"hold", 8.0)
	var cell_w := maxi(1, int(image.get_width() / float(WARD_SHEET_FRAMES)))
	var cell_h := image.get_height()
	for i in WARD_SHEET_FRAMES:
		var cell := image.get_region(Rect2i(i * cell_w, 0, cell_w, cell_h))
		frames.add_frame(&"hold", ImageTexture.create_from_image(cell))
	_ward_frames = frames
	return frames


## Ward is centered on her and taller than her body, so the cloth covers her.
func _fit_ward() -> void:
	if _ward_fx == null or not is_instance_valid(_ward_fx):
		return
	var body := 92.0 * maxf(_depth_scale, 0.2)
	var tex_size := 1024.0
	if _ward_fx is Sprite2D and (_ward_fx as Sprite2D).texture != null:
		tex_size = (_ward_fx as Sprite2D).texture.get_width()
	var fitted := body * 2.35 / tex_size
	_ward_fx.scale = Vector2(fitted, fitted)
	_ward_fx.position = Vector2(0.0, -body * 0.46)


func _drop_ward_fx() -> void:
	if _ward_fx == null or not is_instance_valid(_ward_fx):
		_ward_fx = null
		return
	var ward := _ward_fx
	_ward_fx = null
	var fade := ward.create_tween()
	fade.set_parallel(true)
	fade.tween_property(ward, "modulate:a", 0.0, 0.14)
	fade.tween_property(ward, "scale", ward.scale * 1.12, 0.14)
	fade.chain().tween_callback(ward.queue_free)


func apply_knockback(from_world: Vector2, force := 280.0) -> void:
	if _dead or _dodge_left > 0.0 or _ward_left > 0.0:
		return
	var away := global_position - from_world
	if away.length() < 4.0:
		away = Vector2(0, 1)
	velocity = away.normalized() * force


## Left-click locks a monster. Out of range she runs in; in range she swings.
func try_attack_at(world_point: Vector2) -> bool:
	var clicked := _pick_click_target(world_point)
	if clicked != null:
		return _engage_target(clicked)
	_face_vector(world_point - global_position)
	return _swing_staff(null)


func _handle_aqw_click(world_point: Vector2) -> void:
	var npc := _pick_talk_npc(world_point)
	if npc != null:
		approach_npc(npc)
		return
	var clicked := _pick_click_target(world_point)
	if clicked != null:
		_clear_talk_approach()
		_engage_target(clicked)
		return
	_clear_talk_approach()
	_set_locked_target(null)


func approach_npc(npc: Node2D) -> void:
	if npc == null or _dead or not input_enabled:
		return
	if _talk_npc == npc and _approaching_talk:
		return
	_clear_talk_approach()
	_set_locked_target(null)
	_chasing = false
	_talk_npc = npc
	_approaching_talk = true
	if npc.has_method("set_selected"):
		npc.call("set_selected", true)
	if _in_talk_range(npc):
		_complete_talk_approach()


func _pick_talk_npc(world_point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 72.0
	for node in get_tree().get_nodes_in_group("talkable_npc"):
		var npc := node as Node2D
		if npc == null or not npc.visible:
			continue
		if npc.has_method("can_be_clicked_at") and not bool(npc.call("can_be_clicked_at", world_point)):
			continue
		var d := minf(
			world_point.distance_to(npc.global_position + Vector2(0.0, -36.0)),
			world_point.distance_to(npc.global_position)
		)
		if d < best_d:
			best_d = d
			best = npc
	return best


func _talk_chase_direction() -> Vector2:
	if not _approaching_talk or _talk_npc == null or not is_instance_valid(_talk_npc):
		if _approaching_talk:
			_clear_talk_approach()
		return Vector2.ZERO
	if _in_talk_range(_talk_npc):
		_complete_talk_approach()
		return Vector2.ZERO
	var to_npc := _talk_npc.global_position - global_position
	if to_npc.length() < 4.0:
		return Vector2.ZERO
	return to_npc.normalized()


func _in_talk_range(npc: Node2D) -> bool:
	var reach := 56.0
	if npc.has_method("talk_stop_distance"):
		reach = float(npc.call("talk_stop_distance"))
	return global_position.distance_to(npc.global_position) <= reach


func _complete_talk_approach() -> void:
	var npc := _talk_npc
	_clear_talk_approach()
	if npc == null or not is_instance_valid(npc):
		return
	_face_vector(npc.global_position - global_position)
	if npc.has_method("receive_player_talk"):
		npc.call("receive_player_talk")


func _clear_talk_approach() -> void:
	if _talk_npc != null and is_instance_valid(_talk_npc) and _talk_npc.has_method("set_selected"):
		_talk_npc.call("set_selected", false)
	_talk_npc = null
	_approaching_talk = false


func _engage_target(target: Variant) -> bool:
	if not _is_valid_hit(target):
		return false
	var node := target as Node2D
	_set_locked_target(node)
	_chasing = true
	_face_vector(node.global_position - global_position)
	if _in_melee_range(node):
		return _swing_staff(node)
	return false


func _try_auto_attack() -> void:
	if not input_enabled or _dead or not has_staff or not _chasing:
		return
	if _steering() != Vector2.ZERO:
		return
	if _locked_target == null or _attack_timer > 0.0 or _dodge_left > 0.0:
		return
	if not _is_valid_hit(_locked_target):
		return
	if not _in_melee_range(_locked_target):
		return
	_swing_staff(_locked_target)


func _in_melee_range(target: Variant) -> bool:
	if not _is_valid_hit(target):
		return false
	var node := target as Node2D
	var extra := 16.0
	if node.has_method("hit_radius"):
		extra = float(node.call("hit_radius")) * 0.35
	return Iso.iso_distance(global_position, node.global_position) <= MELEE_REACH + extra


func _chase_direction() -> Vector2:
	if not _chasing or _dead or _dodge_left > 0.0 or _attacking:
		return Vector2.ZERO
	if not _is_valid_hit(_locked_target):
		return Vector2.ZERO
	if _in_melee_range(_locked_target):
		return Vector2.ZERO
	var to_target := _locked_target.global_position - global_position
	if to_target.length() < 4.0:
		return Vector2.ZERO
	return to_target.normalized()


func _swing_staff(target: Variant) -> bool:
	if not has_staff or _attack_timer > 0.0 or _dead:
		return false
	if target != null:
		if not _is_valid_hit(target) or not _in_melee_range(target):
			return false
		var node := target as Node2D
		_face_vector(node.global_position - global_position)
	_attack_timer = ATTACK_COOLDOWN
	_attacking = true
	_attack_anim_left = ATTACK_ANIM
	Audio.play_sfx(Audio.Sfx.BELL)
	Audio.play_sfx(Audio.Sfx.HIT)
	_play_cast_pose()
	_play_cast_flash()
	Fx.staff_trail(self, facing, 84.0)
	Fx.punch(self, 0.05)
	var swing_point := global_position + facing * 48.0
	attacked.emit(swing_point, facing)
	_staff_melee()
	return true


func _set_locked_target(target: Variant) -> void:
	var node: Node2D = null
	if _is_valid_hit(target):
		node = target as Node2D
	if node == null:
		_chasing = false
	if _locked_target == node:
		if node != null and node.has_method("set_selected"):
			node.set_selected(true)
		return
	if _locked_target != null and is_instance_valid(_locked_target) \
			and _locked_target.has_method("set_selected"):
		_locked_target.set_selected(false)
	_locked_target = node
	if _locked_target != null and _locked_target.has_method("set_selected"):
		_locked_target.set_selected(true)


func _validate_locked_target() -> void:
	if _locked_target == null:
		return
	if not _is_valid_hit(_locked_target):
		_set_locked_target(null)


func _face_locked_target() -> void:
	if _dodge_left > 0.0 or not _chasing or _steering() != Vector2.ZERO:
		return
	if _locked_target == null or not is_instance_valid(_locked_target):
		return
	_face_vector(_locked_target.global_position - global_position)


func _steering() -> Vector2:
	if not input_enabled or _dead:
		return Vector2.ZERO
	var up_down_neg := "move_up" if InputMap.has_action("move_up") else "move_forward"
	var up_down_pos := "move_down" if InputMap.has_action("move_down") else "move_back"
	return Input.get_vector("move_left", "move_right", up_down_neg, up_down_pos)


## Closest enemy in front of `aim`, close enough for the staff to reach.
func _nearest_ahead(aim: Vector2) -> Node2D:
	if aim.length() < 0.01:
		return null
	var aim_n := aim.normalized()
	var best: Node2D = null
	var best_d := MELEE_REACH
	for node in get_tree().get_nodes_in_group("hittable"):
		if not _is_valid_hit(node):
			continue
		var target := node as Node2D
		var to_target := target.global_position - global_position
		if to_target.length() < 1.0:
			continue
		if aim_n.dot(to_target.normalized()) < 0.55:
			continue
		var dist := Iso.iso_distance(global_position, target.global_position)
		if dist > best_d:
			continue
		best_d = dist
		best = target
	return best


## Prefer the hittable under the cursor; otherwise the closest near the click.
func _pick_click_target(world_point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 100000.0
	for node in get_tree().get_nodes_in_group("hittable"):
		if not _is_valid_hit(node):
			continue
		var target := node as Node2D
		if target.has_method("click_points"):
			var pts: Variant = target.call("click_points")
			if pts is PackedVector2Array:
				for point in pts:
					var body_d := world_point.distance_to(point)
					if body_d < 150.0 and body_d < best_d:
						best_d = body_d
						best = target
				continue
		# Prefer enemies near the cursor; also accept clicks a little below their feet.
		var d := minf(
			world_point.distance_to(target.global_position + Vector2(0.0, -28.0)),
			world_point.distance_to(target.global_position)
		)
		if d < CLICK_PICK_RADIUS and d < best_d:
			best_d = d
			best = target
	return best


func try_chime() -> bool:
	if not has_staff or _chime_timer > 0.0 or _dead or _beam_root > 0.0:
		return false
	_chime_timer = CHIME_COOLDOWN
	Audio.play_sfx(Audio.Sfx.CHIME)
	_play_shockwave()
	Fx.punch(self, 0.05)

	for target in _targets_in_range(global_position, CHIME_RADIUS):
		if target.has_method("stun"):
			target.stun(1.2)
		if target.has_method("take_damage"):
			var dmg := CHIME_DAMAGE
			if has_life_thread and target.is_in_group("shadow_vine"):
				dmg = LIFE_THREAD_VINE_DAMAGE
				Fx.fiber_burst(target, Color(0.82, 0.22, 0.18))
			target.take_damage(dmg, self)
			Fx.hit_flash(target, Palette.GOLD_SACRED if not has_life_thread else Color(0.86, 0.28, 0.2))
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


## Battle UI spends the chime cooldown and plays the pulse without re-targeting.
func force_chime_pulse() -> void:
	if not has_staff:
		return
	_chime_timer = CHIME_COOLDOWN
	Audio.play_sfx(Audio.Sfx.CHIME)
	_play_shockwave()
	chimed.emit(global_position, CHIME_RADIUS)


func play_finisher_strike(target: Node2D = null) -> void:
	if _dead or not has_staff:
		return
	if target != null and is_instance_valid(target):
		_face_vector(target.global_position - global_position)
	_attacking = true
	_attack_anim_left = ATTACK_ANIM
	_attack_timer = ATTACK_COOLDOWN
	_play_cast_pose()
	_play_cast_flash()
	Fx.staff_trail(self, facing, 120.0)
	Fx.punch(self, 0.08)
	Audio.play_sfx(Audio.Sfx.HIT)
	Audio.play_sfx(Audio.Sfx.BELL)
	attacked.emit(global_position + facing * 48.0, facing)


func run_finisher_approach(target: Node2D, stand_off := 78.0) -> void:
	if _dead or target == null or not is_instance_valid(target):
		return
	input_enabled = false
	_chasing = false
	_set_locked_target(null)
	velocity = Vector2.ZERO
	var away := global_position - target.global_position
	if away.length() < 20.0:
		away = Vector2(0.0, 86.0)
	var mark := target.global_position + away.normalized() * stand_off
	_face_vector(mark - global_position)
	if _animated != null:
		_play_facing("walk")
	if away.length() <= stand_off + 8.0:
		_face_vector(target.global_position - global_position)
		return
	var dash := create_tween()
	dash.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dash.tween_property(self, "global_position", mark, 0.16)
	await dash.finished
	velocity = Vector2.ZERO
	if is_instance_valid(target):
		_face_vector(target.global_position - global_position)


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

## True only inside the roll's own i-frames, not the grace period after a hit,
## so enemies can reward a dodge that was timed through an attack.
func is_dodge_invulnerable() -> bool:
	return not _dead and _dodge_timer > DODGE_COOLDOWN - DODGE_IFRAMES


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	if _ward_left > 0.0 and _ward_hp > 0.0:
		_block_with_ward(amount)
		return
	if _invulnerable > 0.0:
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


func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := health
	health = minf(max_health, health + amount)
	var gained := health - before
	if gained > 0.0:
		health_changed.emit(health, max_health)
	return gained


func heal_full() -> void:
	if _dead and _chapter_holding_death():
		return
	_dead = false
	health = max_health
	_invulnerable = INVULNERABLE_TIME
	if _animated != null:
		_animated.modulate = Color.WHITE
	health_changed.emit(health, max_health)


func _chapter_holding_death() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node is ChapterBase and (node as ChapterBase)._handling_death:
			return true
		node = node.get_parent()
	return false


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
		if not target.has_method("take_damage"):
			continue
		var result: Variant = target.take_damage(ATTACK_DAMAGE, self)
		if result is bool and not result:
			continue
		Fx.hit_flash(target, Palette.GOLD_SUN)
		Fx.punch(target, 0.1)
		attack_hit.emit(target)
		hits += 1
	return hits


func _is_valid_hit(target: Variant) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not (target is Node2D):
		return false
	var node := target as Node2D
	if not node.is_inside_tree():
		return false
	if node.has_method("is_hittable"):
		return bool(node.call("is_hittable"))
	if not node.is_visible_in_tree():
		return false
	if node.has_method("is_defeated") and node.is_defeated():
		return false
	return true


func _targets_in_range(origin: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("hittable"):
		if not _is_valid_hit(node):
			continue
		var target := node as Node2D
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

	_animated.centered = true
	_animated.z_index = 4
	# Locked for every animation — see SlangFrames header comments.
	# Frame canvas: 256×192 px, feet at bottom-centre. Keep a uniform scale:
	# scaling X by canvas width would squash S'lang after widening attack cells.
	# offset (0,-46) places those feet on this CharacterBody2D origin.
	_base_sprite_offset = Vector2(0.0, -46.0)
	var art_scale := 92.0 / float(SlangFrames.FRAME_H)
	_base_sprite_scale = Vector2(art_scale, art_scale)
	_animated.offset = _base_sprite_offset
	_animated.scale = _base_sprite_scale
	# Art is drawn at 192 px tall and shown at ~92 px (scale 0.479). NEAREST at a
	# non-integer scale crawls and shimmers while moving; mipmapped linear doesn't.
	_animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_apply_staff_visual()
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


func _apply_staff_visual() -> void:
	if _animated == null:
		return
	var frames := SlangFrames.load_or_build() if has_staff else SlangFrames.load_bare()
	if _animated.sprite_frames == frames:
		return
	var anim := String(_animated.animation)
	var frame := _animated.frame
	var progress := _animated.frame_progress
	var playing := _animated.is_playing()
	_animated.sprite_frames = frames
	if anim.is_empty() or not frames.has_animation(anim):
		return
	if playing:
		_animated.play(anim)
	else:
		_animated.animation = anim
	var count := frames.get_frame_count(anim)
	if count > 0:
		_animated.frame = mini(frame, count - 1)
		_animated.frame_progress = progress


func _build_shadow() -> void:
	if _shadow != null:
		return
	_shadow = Sprite2D.new()
	_shadow.name = "BodyShadow"
	_shadow.centered = true
	_shadow.z_as_relative = true
	_shadow.z_index = -1
	_shadow.texture = _foot_shadow_texture()
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow.position = Vector2(3.0, 1.0)
	add_child(_shadow)
	move_child(_shadow, 0)
	_sync_body_shadow()


func _foot_shadow_texture() -> Texture2D:
	var w := 56
	var h := 18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	for y in h:
		for x in w:
			var nx := (float(x) + 0.5 - cx) / (cx - 1.0)
			var ny := (float(y) + 0.5 - cy) / (cy - 1.0)
			var d := nx * nx + ny * ny
			if d >= 1.0:
				continue
			img.set_pixel(x, y, Color(0.02, 0.015, 0.02, (1.0 - d) * 0.42))
	return ImageTexture.create_from_image(img)


func _sync_body_shadow() -> void:
	if _shadow == null:
		return
	_shadow.visible = not _dead
	_shadow.scale = Vector2(_depth_scale, _depth_scale * 0.92)


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
	var sheet := _load_shockwave_texture()
	if sheet == null:
		_play_shockwave_fallback()
		return
	# Built once per session. A replaced PNG is picked up on the next launch.
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Shockwave"
	sprite.sprite_frames = _get_shockwave_frames(sheet)
	sprite.z_index = 5
	sprite.z_as_relative = true
	sprite.position = Vector2(0.0, 10.0)
	sprite.scale = Vector2(1.7, 1.45)
	sprite.modulate = Color(1.08, 1.02, 0.88, 0.95)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	sprite.play("burst")
	sprite.animation_finished.connect(sprite.queue_free, CONNECT_ONE_SHOT)


func _play_shockwave_fallback() -> void:
	var ring := Sprite2D.new()
	ring.texture = _radial_texture()
	ring.modulate = Color(0.95, 0.88, 0.62, 0.75)
	ring.scale = Vector2(0.1, 0.06)
	ring.z_index = 8
	add_child(ring)
	var target_scale := (CHIME_RADIUS * 2.0) / 256.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(target_scale, target_scale * 0.6), 1.05)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 1.05)
	tween.chain().tween_callback(ring.queue_free)


func _get_shockwave_frames(sheet: Texture2D) -> SpriteFrames:
	if _shockwave_frames != null:
		return _shockwave_frames
	var frames := SpriteFrames.new()
	frames.add_animation("burst")
	frames.set_animation_loop("burst", false)
	frames.set_animation_speed("burst", SHOCKWAVE_FPS)
	var fw := maxi(1, int(sheet.get_width() / float(SHOCKWAVE_FRAMES)))
	var fh := sheet.get_height()
	for i in range(SHOCKWAVE_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(float(i * fw), 0.0, float(fw), float(fh))
		frames.add_frame("burst", atlas)
	_shockwave_frames = frames
	return frames


func _load_shockwave_texture() -> Texture2D:
	var packed := Palette.read_texture(SHOCKWAVE_PATH)
	if packed != null:
		return packed
	if ResourceLoader.exists(SHOCKWAVE_PATH):
		var loaded := load(SHOCKWAVE_PATH)
		if loaded is Texture2D:
			return loaded
	return null
