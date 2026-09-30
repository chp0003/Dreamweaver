class_name HouseNextMark
extends Node2D
## Gold arrow over the House S'lang is meant to enter next.


var _pulse := 0.0
var _shown := false


func _ready() -> void:
	z_index = 52
	z_as_relative = false
	light_mask = 0
	visible = false
	set_process(true)


func set_shown(on: bool) -> void:
	_shown = on
	visible = on
	queue_redraw()


func _process(delta: float) -> void:
	if not _shown:
		visible = false
		return
	if not is_visible_in_tree():
		return
	_pulse += delta * 3.2
	queue_redraw()


func _draw() -> void:
	var bob := sin(_pulse) * 6.0
	var center := Vector2(0.0, bob)
	var wave := fposmod(_pulse * 0.28, 1.0)
	var radius := lerpf(8.0, 18.0, wave)
	draw_arc(center, radius, 0.0, TAU, 28, Palette.alpha(Palette.GOLD_SUN, (1.0 - wave) * 0.55), 2.0, true)

	var tip := center + Vector2(0.0, 14.0)
	var left := center + Vector2(-13.0, -8.0)
	var right := center + Vector2(13.0, -8.0)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0.0, 3.0),
		left + Vector2(-2.5, -2.0),
		right + Vector2(2.5, -2.0),
	]), Palette.alpha(Palette.DREAM_ABYSS, 0.82))
	var gold := Palette.GOLD_SUN
	gold.a = 0.84 + 0.16 * sin(_pulse)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), gold)
	draw_polyline(PackedVector2Array([left, tip, right]), Palette.GOLD_SACRED, 2.0, true)

	var lift := Vector2(0.0, -20.0)
	var echo := 0.35 + 0.25 * sin(_pulse + 0.8)
	draw_polyline(PackedVector2Array([
		left + lift, tip + lift + Vector2(0.0, 6.0), right + lift,
	]), Palette.alpha(Palette.GOLD_SUN, echo), 2.2, true)
