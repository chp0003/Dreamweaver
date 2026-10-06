class_name ShadowMinion
extends CharacterBody2D

## A minor shadow that hunts S'lang in the world (AQ Worlds style).
## Used by Chapter 2 and Chapter 5.

signal died(minion: ShadowMinion)
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)

const AGGRO_RANGE := 240.0
const ATTACK_RANGE := 52.0
const TOUCH_COOLDOWN := 1.1
const SPECIAL_RANGE := 210.0
## Casters still walk in from this far. They only loose a bolt inside CASTER_FIRE_RANGE.
const CASTER_SIGHT := 920.0
## Close enough to shoot. Matches the outer edge of their strafe band.
const CASTER_FIRE_RANGE := 460.0
## Heal on a normal kill, as a fraction of S'lang's max health. Boss adds pay nothing.
const KILL_HEAL_RATIO := 0.04
## Chaser tell before the swing. The hit is checked again when this ends.
const CHASER_WINDUP := 0.28
## Bolts steer only this long after launch, then fly straight.
const BOLT_HOMING_TIME := 0.18
const SHEET_DIR := "res://assets/images/enemies/minion/"
const COMBAT_FRAMES := 8
## Packed cells are 160 px square with the feet on y = 152.
const CELL_FEET_OFFSET := 72.0
const BODY_SCALE := 1.05
## name -> [fps, loop]
const BODY_ANIMS := {
	&"spawn": [14.0, false],
	&"idle": [7.0, true],
	&"walk": [11.0, true],
	&"attack": [18.0, false],
	&"dash": [16.0, false],
	&"cast": [14.0, false],
	&"hurt": [22.0, false],
	&"death": [12.0, false],
}
## Frames 0..DASH_WINDUP_FRAMES hold the crouch while the tell pulses.
const DASH_WINDUP_FRAMES := 2
const CAST_WINDUP_FRAMES := 3

static var _body_frames: SpriteFrames

@export var max_health := 60.0
@export var touch_damage := 14.0
@export var speed := 88.0
@export var spawn_delay := 0.35
## Chapter 5 mixes these roles. Other chapters retain the classic chaser.
@export_enum("chaser", "stalker", "dasher", "caster") var combat_style := "chaser"

var health := 60.0

var _player: Slang
var _spawning := true
var _dying := false
var _touch_timer := 0.0
var _hurt_lock := 0.0
var _art: PlaceholderProp
var _anim: AnimatedSprite2D
var _hp_bar: ProgressBar
var _select_ring: Polygon2D
var _action_tell: Polygon2D
var _facing_left := false
var _action_timer := 1.4
var _windup_left := 0.0
var _windup_total := 0.0
var _dash_left := 0.0
var _dash_velocity := Vector2.ZERO
var _strafe_sign := 1.0
var _last_hit_by: Node
## One-shot body anims (attack, hurt, dash strike, cast release) own the sprite
## until they finish; locomotion waits.
var _anim_locked := false
var _ghost_cd := 0.0


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("shadow_minion")
	health = max_health
	collision_layer = PhysicsLayers.LAYER_ENEMIES
	collision_mask = PhysicsLayers.LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Stop the grayscale veil from leaving afterimage trails on this body.
	z_as_relative = true
	_build_visuals()
	_action_timer = randf_range(0.25, 0.55) if combat_style == "caster" else randf_range(0.8, 1.8)
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	_rise_from_the_floor()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if _dying or _spawning:
		velocity = Vector2.ZERO
		return
	_touch_timer = maxf(0.0, _touch_timer - delta)
	_hurt_lock = maxf(0.0, _hurt_lock - delta)
	_action_timer = maxf(0.0, _action_timer - delta)
	_tick(delta)
	_update_body_anim(delta)


func _tick(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Slang
	if _player == null or _player.is_dead() or not _player.input_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	var away := global_position - _player.global_position
	if _hurt_lock > 0.0:
		_cancel_special()
		velocity = away.normalized() * 150.0 if away.length() > 0.01 else Vector2.ZERO
		move_and_slide()
		return

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_velocity
		move_and_slide()
		if Iso.iso_distance(global_position, _player.global_position) <= ATTACK_RANGE * 1.25:
			_try_touch()
			_dash_left = 0.0
		return

	if _windup_left > 0.0:
		_windup_left -= delta
		velocity = Vector2.ZERO
		_pulse_action_tell()
		if _windup_left <= 0.0:
			_commit_special()
		move_and_slide()
		return

	var dist := Iso.iso_distance(global_position, _player.global_position)
	var aggro := CASTER_SIGHT if combat_style == "caster" else AGGRO_RANGE
	if dist > aggro:
		velocity = velocity.move_toward(Vector2.ZERO, 280.0 * delta)
		move_and_slide()
		return

	_face_toward(_player.global_position)

	if combat_style == "caster":
		_move_caster(dist)
		move_and_slide()
		return
	if combat_style == "dasher" and _action_timer <= 0.0 and dist < SPECIAL_RANGE:
		_begin_special(0.48)
		move_and_slide()
		return
	if combat_style == "stalker":
		_move_stalker(dist)
		move_and_slide()
		return

	if dist <= ATTACK_RANGE:
		velocity = Vector2.ZERO
		move_and_slide()
		if _touch_timer <= 0.0:
			_begin_chaser_windup()
		return

	var to_player := (_player.global_position - global_position).normalized()
	velocity = to_player * speed
	move_and_slide()


func _move_caster(dist: float) -> void:
	var toward := (_player.global_position - global_position).normalized()
	var tangent := Vector2(-toward.y, toward.x) * _strafe_sign
	if dist < 160.0:
		velocity = -toward * speed
	elif dist > 420.0:
		velocity = toward * speed * 0.55
	else:
		velocity = tangent * speed * 0.62
	if _action_timer <= 0.0 and dist <= CASTER_FIRE_RANGE:
		_begin_special(0.48)


func _move_stalker(dist: float) -> void:
	var toward := (_player.global_position - global_position).normalized()
	var tangent := Vector2(-toward.y, toward.x) * _strafe_sign
	if dist > 125.0:
		velocity = (toward * 0.76 + tangent * 0.36).normalized() * speed
	elif dist < 68.0:
		velocity = -toward * speed * 0.7
	else:
		velocity = tangent * speed * 0.82
		if _action_timer <= 0.0:
			_strafe_sign *= -1.0
			_begin_special(0.34)


func _begin_chaser_windup() -> void:
	_windup_left = CHASER_WINDUP
	_windup_total = CHASER_WINDUP
	velocity = Vector2.ZERO
	if _action_tell != null:
		_action_tell.visible = true
		_action_tell.scale = Vector2(1.8, 1.8)


func _begin_special(duration: float) -> void:
	_windup_left = duration
	_windup_total = duration
	_action_timer = randf_range(2.0, 3.2)
	velocity = Vector2.ZERO
	_anim_locked = false
	if _action_tell != null:
		_action_tell.visible = true
		_action_tell.scale = Vector2(1.8, 1.8)


func _commit_special() -> void:
	if _action_tell != null:
		_action_tell.visible = false
	if _player == null or not is_instance_valid(_player):
		return
	var toward := (_player.global_position - global_position).normalized()
	match combat_style:
		"chaser":
			if Iso.iso_distance(global_position, _player.global_position) <= ATTACK_RANGE:
				_try_touch()
			else:
				_touch_timer = TOUCH_COOLDOWN
		"caster":
			_play_combat_anim(&"cast", CAST_WINDUP_FRAMES + 1)
			Audio.play_fx("minion_cast", -2.0)
			var fire := get_tree().create_timer(0.1)
			fire.timeout.connect(_cast_thread_bolt, CONNECT_ONE_SHOT)
		"stalker":
			_play_combat_anim(&"dash", DASH_WINDUP_FRAMES + 1)
			_dash_velocity = toward * speed * 2.25
			_dash_left = 0.24
			_dash_kickoff()
		"dasher":
			_play_combat_anim(&"dash", DASH_WINDUP_FRAMES + 1)
			_dash_velocity = toward * speed * 3.0
			_dash_left = 0.34
			_dash_kickoff()


func _dash_kickoff() -> void:
	Audio.play_fx("minion_dash", -3.0)
	ShadowFx.burst(get_parent(), ShadowFx.DASH_BURST, global_position + Vector2(0.0, -24.0),
			22.0, Vector2(0.42, 0.36), 0.0, z_index + 1)


func _cast_thread_bolt() -> void:
	if _dying or not is_inside_tree():
		return
	if _player == null or not is_instance_valid(_player) or _player.is_dead():
		return
	var host := get_parent()
	if host == null:
		return
	var bolt := _ShadowBolt.new()
	bolt.source = self
	bolt.target = _player
	bolt.damage = touch_damage * 0.7
	host.add_child(bolt)
	bolt.global_position = global_position + Vector2(24.0 * (-1.0 if _facing_left else 1.0), -64.0)
	bolt.aim_at_target()


func _pulse_action_tell() -> void:
	if _action_tell == null:
		return
	var pulse := 1.0 + 0.16 * sin(Time.get_ticks_msec() * 0.025)
	_action_tell.scale = Vector2(pulse, pulse)


func _cancel_special() -> void:
	_windup_left = 0.0
	_dash_left = 0.0
	if _action_tell != null:
		_action_tell.visible = false


func is_defeated() -> bool:
	return _dying or health <= 0.0


func is_hittable() -> bool:
	return is_inside_tree() and not _dying and not _spawning and health > 0.0


func _refresh_hp() -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	_hp_bar.visible = health > 0.0 and (health < max_health or (_select_ring != null and _select_ring.visible))


func set_selected(on: bool) -> void:
	if _select_ring != null:
		_select_ring.visible = on
	_refresh_hp()


func take_damage(amount: float, source: Node = null) -> bool:
	if _dying or _spawning or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	_last_hit_by = source
	_hurt_lock = 0.16
	_flash()
	_refresh_hp()
	health_changed.emit(health, max_health)
	damaged.emit(amount, source)
	_hit_spark()
	Audio.play_fx("shadow_hit", -2.0)
	if source is Node2D:
		var from := (source as Node2D).global_position
		var push := global_position - from
		if push.length() > 0.01:
			velocity = push.normalized() * 200.0
	if health <= 0.0:
		_die()
	else:
		Audio.play_fx("minion_hurt", -6.0, 0.12)
		_play_combat_anim(&"hurt", 1)
	return true


func stun(_duration: float) -> void:
	_hurt_lock = maxf(_hurt_lock, 0.4)


func _try_touch() -> void:
	if _touch_timer > 0.0 or _player == null or not is_instance_valid(_player):
		return
	_touch_timer = TOUCH_COOLDOWN
	_face_toward(_player.global_position)
	_play_combat_anim(&"attack", 1)
	Audio.play_fx("minion_attack", -2.0, 0.1)
	var toward := _player.global_position - global_position
	ShadowFx.burst(get_parent(), ShadowFx.CLAW_SWIPE,
			_player.global_position + Vector2(0.0, -40.0), 26.0,
			Vector2(-0.5 if toward.x < 0.0 else 0.5, 0.5), 0.0, 24)
	_player.take_damage(touch_damage, self)
	Fx.hit_flash(_player, Palette.RED_EMBER)
	if _anim == null:
		Fx.punch(self, 0.1)


func _die() -> void:
	if _dying:
		return
	_dying = true
	_cancel_special()
	velocity = Vector2.ZERO
	collision_layer = 0
	remove_from_group("hittable")
	set_selected(false)
	var boss_add := bool(get_meta("boss_add", false))
	if not boss_add:
		GameState.add_score(25)
	died.emit(self)
	if not boss_add:
		_grant_kill_heal()
	Audio.play_fx("minion_death", -2.0, 0.1)
	Fx.fiber_burst(self, Color(0.28, 0.22, 0.32))
	Fx.hit_flash(self, Color(0.55, 0.42, 0.7))

	if _anim != null and _anim.sprite_frames.has_animation(&"death"):
		_anim_locked = true
		_anim.modulate = Color.WHITE
		_anim.play(&"death")
		var fade := create_tween()
		fade.tween_interval(_anim_length(&"death") * 0.8)
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		fade.tween_callback(queue_free)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 0.12), 0.26)
	tween.tween_property(self, "modulate:a", 0.0, 0.26)
	tween.chain().tween_callback(queue_free)


func _rise_from_the_floor() -> void:
	if _anim != null and _anim.sprite_frames.has_animation(&"spawn"):
		# Boss adds pop in faster than chapter spawns.
		var rise := maxf(0.4, spawn_delay * 1.6)
		_anim.speed_scale = _anim_length(&"spawn") / rise
		_anim.play(&"spawn")
		modulate.a = 0.0
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 1.0, 0.12)
		fade.tween_interval(rise - 0.12)
		fade.tween_callback(_finish_spawn)
		Audio.play_fx("minion_spawn", -5.0, 0.1)
		return

	# Animate the art, not this node's scale — chapters set a display scale
	# (Chapter 5 uses 2.15x) and a scale tween here was flattening some bodies.
	modulate.a = 0.0
	if _art != null:
		_art.scale = Vector2(1.12, 0.12)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, spawn_delay)
	if _art != null:
		tween.tween_property(_art, "scale", Vector2.ONE, spawn_delay)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(_finish_spawn)


func _finish_spawn() -> void:
	if _dying:
		return
	_spawning = false
	if _anim != null:
		_anim.speed_scale = 1.0
		_anim.play(&"idle")


func _face_toward(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	if _art != null and _art.has_method("set_flip_h"):
		_art.set_flip_h(_facing_left)
	if _anim != null:
		_anim.flip_h = _facing_left


func _flash() -> void:
	if _anim != null:
		_anim.modulate = Color(2.2, 1.6, 2.2)
	elif _art != null:
		_art.set_tint(Color(2.0, 1.35, 1.35))
	else:
		return
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_art):
			_art.set_tint(Color.WHITE)
		if is_instance_valid(_anim):
			_anim.modulate = Color.WHITE)


func _hit_spark() -> void:
	var jitter := Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 10.0))
	ShadowFx.burst(get_parent(), ShadowFx.HIT_SPARK,
			global_position + Vector2(0.0, -62.0) * scale + jitter, 30.0,
			Vector2(0.55, 0.55), randf() * TAU, 26)


# --------------------------------------------------------------------------
# Body animation
# --------------------------------------------------------------------------

func _update_body_anim(delta: float) -> void:
	if _anim == null or _dying or _spawning:
		return
	if _dash_left > 0.0:
		_ghost_cd -= delta
		if _ghost_cd <= 0.0:
			_ghost_cd = 0.04
			_drop_afterimage()
	if _windup_left > 0.0:
		_hold_windup_pose()
		return
	if _anim_locked:
		return
	var moving := velocity.length() > 14.0
	var wanted := &"walk" if moving else &"idle"
	if _anim.animation != wanted or not _anim.is_playing():
		_anim.play(wanted)
	_anim.speed_scale = clampf(velocity.length() / maxf(1.0, speed), 0.7, 1.6) if moving else 1.0


## The crouch before a dash, or the orb gathering before a cast, tracks the
## windup timer so the tell and the pose finish together.
func _hold_windup_pose() -> void:
	var anim := &"cast" if combat_style == "caster" else (&"attack" if combat_style == "chaser" else &"dash")
	if not _anim.sprite_frames.has_animation(anim):
		return
	var last := CAST_WINDUP_FRAMES if anim == &"cast" else DASH_WINDUP_FRAMES
	var progress := 1.0 - clampf(_windup_left / maxf(0.05, _windup_total), 0.0, 1.0)
	_anim.animation = anim
	_anim.pause()
	_anim.frame = mini(last, int(progress * float(last + 1)))


func _play_combat_anim(anim_name: StringName, from_frame := 0) -> void:
	if _anim == null or _anim.sprite_frames == null or not _anim.sprite_frames.has_animation(anim_name):
		if _art != null:
			Fx.punch(_art, 0.08)
		return
	if _dying:
		return
	# A hurt flinch must not cut off the minion's own strike.
	if anim_name == &"hurt" and _anim_locked and _anim.animation != &"hurt":
		return
	_anim_locked = true
	_anim.flip_h = _facing_left
	_anim.speed_scale = 1.0
	_anim.play(anim_name)
	_anim.frame = clampi(from_frame, 0, _anim.sprite_frames.get_frame_count(anim_name) - 1)


func _on_body_anim_finished() -> void:
	if _dying or _spawning:
		return
	_anim_locked = false
	_anim.play(&"idle")


func _drop_afterimage() -> void:
	var host := get_parent()
	if host == null or _anim == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
	ghost.flip_h = _anim.flip_h
	ghost.centered = true
	ghost.modulate = Color(0.62, 0.3, 0.95, 0.55)
	ghost.material = ShadowFx.additive()
	ghost.z_index = z_index - 1
	host.add_child(ghost)
	ghost.global_transform = _anim.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


func _anim_length(anim_name: StringName) -> float:
	var sprite_frames := _anim.sprite_frames
	return float(sprite_frames.get_frame_count(anim_name)) / maxf(1.0, sprite_frames.get_animation_speed(anim_name))


# --------------------------------------------------------------------------
# Visuals
# --------------------------------------------------------------------------

func _build_visuals() -> void:
	if not has_node("CollisionShape2D"):
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		var shape := CollisionShape2D.new()
		shape.shape = circle
		add_child(shape)

	var frames := _shared_body_frames()
	if frames != null:
		_anim = AnimatedSprite2D.new()
		_anim.name = "Body"
		_anim.sprite_frames = frames
		_anim.centered = true
		_anim.position = Vector2(0.0, 4.0 - CELL_FEET_OFFSET * BODY_SCALE)
		_anim.scale = Vector2(BODY_SCALE, BODY_SCALE)
		_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_anim.animation_finished.connect(_on_body_anim_finished)
		add_child(_anim)
		_add_foot_shadow()
	else:
		_art = PlaceholderProp.new()
		_art.name = "Art"
		_art.prop_label = "SHADOW"
		_art.texture_path = "res://assets/images/enemies/shadow_minion.png"
		_art.prop_size = Vector2(84.0, 118.0)
		_art.body_color = Color(0.1, 0.09, 0.12)
		_art.accent_color = Color(0.35, 0.3, 0.4)
		_art.show_label = false
		_art.blocks_movement = false
		_art.cast_shadow = true
		# No float bob — it made the grayscale veil leave ghost trails.
		_art.float_amplitude = 0.0
		add_child(_art)

	_select_ring = Polygon2D.new()
	_select_ring.name = "SelectRing"
	_select_ring.polygon = Iso.diamond(Vector2(0.0, 6.0), 2.05)
	_select_ring.color = Palette.alpha(Palette.GOLD_SUN, 0.55)
	_select_ring.z_index = -1
	_select_ring.visible = false
	add_child(_select_ring)
	move_child(_select_ring, 0)

	_action_tell = Polygon2D.new()
	_action_tell.name = "ActionTell"
	_action_tell.polygon = Iso.diamond(Vector2.ZERO, 2.7)
	_action_tell.color = (
		Color(0.65, 0.22, 0.86, 0.48)
		if combat_style == "caster"
		else Color(0.95, 0.28, 0.22, 0.44)
	)
	_action_tell.z_index = -2
	_action_tell.visible = false
	add_child(_action_tell)
	move_child(_action_tell, 0)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(64.0, 7.0)
	_hp_bar.size = Vector2(64.0, 7.0)
	_hp_bar.position = Vector2(-32.0, -132.0)
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	_hp_bar.visible = false
	_hp_bar.add_theme_stylebox_override("background", UiStyle.bar_track(6))
	_hp_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(Palette.RED_SACRED, 6))
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.z_index = 30
	add_child(_hp_bar)


func _add_foot_shadow() -> void:
	var shadow := Polygon2D.new()
	shadow.name = "FootShadow"
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 26.0, sin(a) * 9.0 + 2.0))
	shadow.polygon = pts
	shadow.color = Color(0.02, 0.02, 0.04, 0.38)
	shadow.z_index = -1
	add_child(shadow)
	move_child(shadow, 0)


## Every minion shares one SpriteFrames: slicing the strips per spawn stalled
## Chapter 5's waves.
static func _shared_body_frames() -> SpriteFrames:
	if _body_frames != null:
		return _body_frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name in BODY_ANIMS.keys():
		var spec: Array = BODY_ANIMS[anim_name]
		var sheet := Palette.read_image(SHEET_DIR + String(anim_name) + ".png")
		if sheet == null or sheet.get_width() < COMBAT_FRAMES:
			continue
		var cell_w := sheet.get_width() / COMBAT_FRAMES
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(spec[0]))
		frames.set_animation_loop(anim_name, bool(spec[1]))
		for i in range(COMBAT_FRAMES):
			var cell := sheet.get_region(Rect2i(i * cell_w, 0, cell_w, sheet.get_height()))
			frames.add_frame(anim_name, ImageTexture.create_from_image(cell))
	if not frames.has_animation(&"idle") or not frames.has_animation(&"walk"):
		push_warning("ShadowMinion: body sheets missing in %s, using the still art" % SHEET_DIR)
		return null
	_body_frames = frames
	return _body_frames


func _grant_kill_heal() -> void:
	var killer := _last_hit_by if _last_hit_by != null else _player
	if killer == null or not is_instance_valid(killer):
		return
	if not (killer is Slang) or not killer.has_method("heal"):
		return
	var slang := killer as Slang
	var gained := slang.heal(slang.max_health * KILL_HEAL_RATIO)
	if gained <= 0.0:
		return
	Fx.hit_flash(slang, Palette.GOLD_SUN)
	var host: Node = get_parent()
	if host != null:
		Fx.damage_number(host, slang.global_position, int(round(gained)), Palette.GOLD_SUN)


class _ShadowBolt extends Node2D:
	var source: Node2D
	var target: Node2D
	var damage := 10.0
	var speed := 340.0
	var _spent := false
	var _travel := 0.0
	var _age := 0.0
	var _direction := Vector2.RIGHT
	var _sprite: AnimatedSprite2D

	func _ready() -> void:
		z_index = 22
		_sprite = ShadowFx.attach(self, ShadowFx.SHADOW_BOLT, Vector2.ZERO, 14.0, true, Vector2(0.42, 0.42), 0)
		if _sprite != null:
			return
		var orb := Polygon2D.new()
		orb.polygon = PackedVector2Array([
			Vector2(0.0, -10.0), Vector2(8.0, 0.0),
			Vector2(0.0, 10.0), Vector2(-8.0, 0.0),
		])
		orb.color = Color(0.72, 0.28, 0.92, 0.95)
		add_child(orb)
		var halo := Polygon2D.new()
		halo.polygon = PackedVector2Array([
			Vector2(0.0, -16.0), Vector2(13.0, 0.0),
			Vector2(0.0, 16.0), Vector2(-13.0, 0.0),
		])
		halo.color = Color(0.42, 0.12, 0.62, 0.35)
		halo.z_index = -1
		add_child(halo)
		move_child(halo, 0)

	func aim_at_target() -> void:
		if target == null or not is_instance_valid(target):
			return
		var aim := target.global_position + Vector2(0.0, -28.0)
		if aim.distance_to(global_position) > 4.0:
			_direction = (aim - global_position).normalized()

	func _physics_process(delta: float) -> void:
		if _spent:
			return
		_age += delta
		if target != null and is_instance_valid(target) and target.is_inside_tree():
			var aim := target.global_position + Vector2(0.0, -28.0)
			var desired := aim - global_position
			if _age < ShadowMinion.BOLT_HOMING_TIME and desired.length() > 4.0:
				_direction = _direction.lerp(desired.normalized(), minf(1.0, delta * 4.5)).normalized()
			if desired.length() <= 28.0:
				_impact()
				return
		global_position += _direction * speed * delta
		_travel += speed * delta
		if _sprite != null:
			rotation = _direction.angle()
		else:
			rotation += delta * 8.0
		if _travel >= 1100.0:
			queue_free()

	func _impact() -> void:
		_spent = true
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			var attacker: Node = source if is_instance_valid(source) else null
			target.take_damage(damage, attacker)
			Fx.hit_flash(target as Node2D, Color(0.62, 0.28, 0.82))
		Audio.play_fx("weaver_bolt_impact", -7.0, 0.12)
		ShadowFx.burst(get_parent(), ShadowFx.BOLT_IMPACT, global_position, 24.0, Vector2(0.4, 0.4), 0.0, 24)
		queue_free()
