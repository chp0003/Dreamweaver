class_name ShadowWeaverBoss
extends Node2D
## The Shadow Weaver: smoke and unravelled thread, final opponent of Chapter 5.
##
## The boss runs a simple loop of telegraphed "Bleach Attacks". Chapter 5 turns
## that loop into the Duel of Rhythms:
##
##   Defend Mode - `telegraph_started` opens a parry window. The chapter calls
##                 `try_parry()` when the player presses the attack key. A hit
##                 parry chips the boss; a miss damages S'lang and the loom.
##   Weave Mode  - after `heavy_windup` parries the boss overextends and calls
##                 `stagger()`, emitting `staggered`. While staggered the loom
##                 can be used, and each rhythm note feeds `take_damage()`.

signal health_changed(current: float, maximum: float)
signal telegraph_started(window: float)
signal telegraph_resolved(parried: bool)
signal staggered(duration: float)
signal recovered
signal defeated

const PARRY_GRACE := 0.12

@export var max_health := 100.0
## Seconds of telegraph before a Bleach Attack lands. Shrinks as the boss weakens.
@export var telegraph_window := 1.05
@export var attack_interval := 1.5
@export var bleach_damage := 16.0
## Parries needed before the boss overextends into a stagger.
@export var parries_to_stagger := 3
@export var stagger_duration := 7.0

var health := 100.0

var _active := false
var _telegraphing := false
var _resolved := false
var _timer := 0.0
var _window_left := 0.0
var _parry_streak := 0
var _staggered := false
var _stagger_left := 0.0
var _dead := false

var _art: PlaceholderProp
var _tell: Node2D


func _ready() -> void:
	# Deliberately not in the "hittable" group: the Shadow Weaver cannot be
	# mashed down with melee. It only takes damage from clean parries and from
	# struck notes on the loom, which is what makes the duel a duel.
	add_to_group("boss")
	health = max_health
	_build_visuals()
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	if not _active or _dead:
		return

	if _staggered:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			_end_stagger()
		return

	if _telegraphing:
		_window_left -= delta
		_update_tell(1.0 - clampf(_window_left / telegraph_window, 0.0, 1.0))
		if _window_left <= -PARRY_GRACE and not _resolved:
			_resolve_telegraph(false)
		return

	_timer -= delta
	if _timer <= 0.0:
		_begin_telegraph()


# --------------------------------------------------------------------------
# Fight control
# --------------------------------------------------------------------------

func begin_duel() -> void:
	_active = true
	_timer = attack_interval


func end_duel() -> void:
	_active = false
	_telegraphing = false
	_hide_tell()


func is_staggered() -> bool:
	return _staggered


func is_telegraphing() -> bool:
	return _telegraphing and not _resolved


## Called when the player presses the attack key. Returns true on a clean parry.
func try_parry() -> bool:
	if not is_telegraphing():
		return false
	# The window is generous right at the end of the wind-up.
	if _window_left > telegraph_window * 0.55:
		return false
	_resolve_telegraph(true)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_flash(Color(1.8, 1.5, 1.5))

	# The Shadow Weaver frays faster as it loses hold of the pattern.
	var ratio := health / max_health
	telegraph_window = lerpf(0.68, 1.05, ratio)
	attack_interval = lerpf(1.05, 1.5, ratio)

	if health <= 0.0:
		_dead = true
		_active = false
		_hide_tell()
		defeated.emit()


## Forces the boss into its vulnerable Weave Mode window.
func stagger(duration: float = -1.0) -> void:
	if _dead or _staggered:
		return
	_staggered = true
	_telegraphing = false
	_hide_tell()
	_stagger_left = stagger_duration if duration < 0.0 else duration
	_parry_streak = 0
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	_flash(Color(1.4, 1.3, 0.9))
	staggered.emit(_stagger_left)


func end_stagger_early() -> void:
	if _staggered:
		_end_stagger()


func health_ratio() -> float:
	return health / max_health


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _begin_telegraph() -> void:
	_telegraphing = true
	_resolved = false
	_window_left = telegraph_window
	_show_tell()
	telegraph_started.emit(telegraph_window)


func _resolve_telegraph(parried: bool) -> void:
	_resolved = true
	_telegraphing = false
	_hide_tell()
	_timer = attack_interval

	if parried:
		_parry_streak += 1
		Audio.play_sfx(Audio.Sfx.PARRY)
		take_damage(4.0)
		GameState.add_score(30)
		if _parry_streak >= parries_to_stagger:
			# Deferred so the chapter sees `telegraph_resolved` first.
			telegraph_resolved.emit(true)
			stagger()
			return
	else:
		_parry_streak = 0
		Audio.play_sfx(Audio.Sfx.FAIL)

	telegraph_resolved.emit(parried)


func _end_stagger() -> void:
	_staggered = false
	_stagger_left = 0.0
	_timer = attack_interval * 0.8
	recovered.emit()


func _build_visuals() -> void:
	_art = PlaceholderProp.new()
	_art.name = "Art"
	_art.prop_label = "SHADOW WEAVER BOSS"
	_art.texture_path = "res://assets/images/enemies/shadow_weaver_boss.png"
	_art.prop_size = Vector2(110.0, 168.0)
	_art.body_color = Color(0.12, 0.11, 0.15)
	_art.accent_color = Color(0.42, 0.3, 0.42)
	_art.float_amplitude = 6.0
	_art.float_speed = 1.1
	add_child(_art)

	_tell = Node2D.new()
	_tell.name = "Telegraph"
	_tell.visible = false
	_tell.z_index = 12
	add_child(_tell)

	var ring := Polygon2D.new()
	ring.name = "Ring"
	var points := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		points.append(Vector2(cos(a) * 78.0, sin(a) * 40.0))
	ring.polygon = points
	ring.color = Color(0.9, 0.85, 0.8, 0.35)
	_tell.add_child(ring)


func _show_tell() -> void:
	if _tell != null:
		_tell.visible = true
		_tell.scale = Vector2(1.6, 1.6)


func _hide_tell() -> void:
	if _tell != null:
		_tell.visible = false


## Wind-up ring shrinks toward the boss; parry when it is tight.
func _update_tell(progress: float) -> void:
	if _tell == null:
		return
	var s := lerpf(1.6, 0.85, clampf(progress, 0.0, 1.0))
	_tell.scale = Vector2(s, s)
	var ring := _tell.get_node_or_null("Ring") as Polygon2D
	if ring != null:
		ring.color = Color(0.95, 0.88, 0.8).lerp(Color(0.95, 0.4, 0.35), progress)
		ring.color.a = 0.3 + progress * 0.4


func _flash(tint: Color) -> void:
	if _art == null:
		return
	_art.set_tint(tint)
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_art):
			_art.set_tint(Color.WHITE))
