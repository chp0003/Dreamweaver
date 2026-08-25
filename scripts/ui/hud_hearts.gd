class_name HudHearts
extends Control
## Three diamond "lives" pips. A Western heart does not belong on T'nalak cloth;
## a lozenge does. Filled pips glow like lanterns; spent ones are hollow frost.

const PIP := 18.0
const GAP := 8.0


func _ready() -> void:
	custom_minimum_size = Vector2(GameState.MAX_LIVES * (PIP + GAP) - GAP, PIP + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_lives(_lives: int) -> void:
	queue_redraw()


func _draw() -> void:
	for i in range(GameState.MAX_LIVES):
		var cx := PIP * 0.5 + float(i) * (PIP + GAP)
		var cy := size.y * 0.5
		_draw_lozenge(Vector2(cx, cy), i < GameState.lives)


func _draw_lozenge(centre: Vector2, filled: bool) -> void:
	var s := PIP * 0.5
	var diamond := PackedVector2Array([
		centre + Vector2(0.0, -s),
		centre + Vector2(s * 0.72, 0.0),
		centre + Vector2(0.0, s),
		centre + Vector2(-s * 0.72, 0.0),
	])
	if filled:
		draw_circle(centre, s + 4.0, Palette.alpha(Palette.RED_EMBER, 0.22))
		draw_colored_polygon(diamond, Palette.RED_SACRED)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Palette.RED_EMBER, 1.4)
		draw_circle(centre + Vector2(-1.5, -2.0), 2.0, Palette.alpha(Palette.GOLD_SUN, 0.55))
	else:
		draw_polyline(diamond + PackedVector2Array([diamond[0]]),
			Palette.alpha(Palette.DREAM_MIST, 0.4), 1.6)
