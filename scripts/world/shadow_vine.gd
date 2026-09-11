class_name ShadowVine
extends Node2D
## Animated Shadow Vines barring the door of the House of Red Courage.
##
## Each vine takes several staff hits. Chapter 2 spawns a row of them across the
## doorway and waits for all of them to report `cleared`.

signal cleared(vine: ShadowVine)

@export var max_health := 100.0
@export var sway_speed := 1.7
@export var sway_degrees := 7.0
@export var art_size := Vector2(40.0, 120.0)

var health := 100.0

var _art: PlaceholderProp
var _time := 0.0
var _dying := false


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("shadow_vine")
	health = max_health
	_time = randf() * TAU
	_build_art()


func _process(delta: float) -> void:
	if _dying:
		return
	_time += delta * sway_speed
	# Vines are anchored at the top of the doorway, so they swing like curtains.
	rotation = deg_to_rad(sin(_time) * sway_degrees)


func take_damage(amount: float, _source: Node = null) -> void:
	if _dying:
		return
	health -= amount
	Audio.play_sfx(Audio.Sfx.HIT)
	_recoil()
	if health <= 0.0:
		_clear()
	elif _art != null:
		# Visibly fray as it loses health.
		_art.set_tint(Color(1.0, 1.0, 1.0, maxf(0.35, health / max_health)))


func _clear() -> void:
	_dying = true
	remove_from_group("hittable")
	GameState.add_score(60)
	cleared.emit(self)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.7, 0.05), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _recoil() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 0.9), 0.07)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func _build_art() -> void:
	_art = PlaceholderProp.new()
	_art.name = "Art"
	_art.prop_label = "SHADOW VINE"
	_art.texture_path = "res://assets/images/enemies/shadow_vine.png"
	_art.prop_size = art_size
	_art.body_color = Color(0.11, 0.1, 0.13)
	_art.accent_color = Color(0.3, 0.22, 0.3)
	_art.show_label = false
	_art.cast_shadow = false
	_art.blocks_movement = false
	add_child(_art)
