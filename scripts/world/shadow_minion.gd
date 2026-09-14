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

@export var max_health := 60.0
@export var touch_damage := 14.0
@export var speed := 88.0
@export var spawn_delay := 0.35

var health := 60.0

var _player: Slang
var _spawning := true
var _dying := false
var _touch_timer := 0.0
var _hurt_lock := 0.0
var _art: PlaceholderProp
var _hp_bar: ProgressBar
var _select_ring: Polygon2D
var _facing_left := false


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("shadow_minion")
	health = max_health
	collision_layer = 2
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Stop the grayscale veil from leaving afterimage trails on this body.
	z_as_relative = true
	_build_visuals()
	_rise_from_the_floor()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if _dying or _spawning:
		velocity = Vector2.ZERO
		return
	_touch_timer = maxf(0.0, _touch_timer - delta)
	_hurt_lock = maxf(0.0, _hurt_lock - delta)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Slang
	if _player == null or _player.is_dead() or not _player.input_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	var away := global_position - _player.global_position
	if _hurt_lock > 0.0:
		velocity = away.normalized() * 150.0 if away.length() > 0.01 else Vector2.ZERO
		move_and_slide()
		return

	var dist := Iso.iso_distance(global_position, _player.global_position)
	if dist > AGGRO_RANGE:
		velocity = velocity.move_toward(Vector2.ZERO, 280.0 * delta)
		move_and_slide()
		return

	_face_toward(_player.global_position)

	if dist <= ATTACK_RANGE:
		velocity = Vector2.ZERO
		move_and_slide()
		_try_touch()
		return

	var to_player := (_player.global_position - global_position).normalized()
	velocity = to_player * speed
	move_and_slide()


func is_defeated() -> bool:
	return _dying or health <= 0.0


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
	_hurt_lock = 0.16
	_flash()
	_refresh_hp()
	health_changed.emit(health, max_health)
	damaged.emit(amount, source)
	if source is Node2D:
		var from := (source as Node2D).global_position
		var push := global_position - from
		if push.length() > 0.01:
			velocity = push.normalized() * 200.0
	if health <= 0.0:
		_die()
	return true


func stun(_duration: float) -> void:
	_hurt_lock = maxf(_hurt_lock, 0.4)


func _try_touch() -> void:
	if _touch_timer > 0.0 or _player == null or not is_instance_valid(_player):
		return
	_touch_timer = TOUCH_COOLDOWN
	_player.take_damage(touch_damage, self)
	Fx.hit_flash(_player, Palette.RED_EMBER)
	Fx.punch(self, 0.1)


func _die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	collision_layer = 0
	remove_from_group("hittable")
	set_selected(false)
	GameState.add_score(25)
	died.emit(self)
	Fx.fiber_burst(self, Color(0.28, 0.22, 0.32))
	Fx.hit_flash(self, Color(0.55, 0.42, 0.7))

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 0.12), 0.26)
	tween.tween_property(self, "modulate:a", 0.0, 0.26)
	tween.chain().tween_callback(queue_free)


func _rise_from_the_floor() -> void:
	scale = Vector2(1.15, 0.08)
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, spawn_delay)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, spawn_delay)
	tween.chain().tween_callback(func() -> void: _spawning = false)


func _face_toward(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	if _art != null:
		_art.scale.x = -1.0 if _facing_left else 1.0


func _flash() -> void:
	if _art == null:
		return
	_art.set_tint(Color(2.0, 1.35, 1.35))
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_art):
			_art.set_tint(Color.WHITE))


func _build_visuals() -> void:
	if not has_node("CollisionShape2D"):
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		var shape := CollisionShape2D.new()
		shape.shape = circle
		add_child(shape)

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
