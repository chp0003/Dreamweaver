class_name HouseLockMark
extends Node2D
## Padlock badge on a House that S'lang cannot enter yet.


var _pulse := 0.0
var _shown := false


func _ready() -> void:
	z_index = 46
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
	_pulse += delta * 2.1
	queue_redraw()


func _draw() -> void:
	var c := Vector2.ZERO
	var rim := 0.62 + 0.38 * sin(_pulse)
	draw_circle(c + Vector2(1.5, 4.0), 22.0, Palette.alpha(Palette.DREAM_ABYSS, 0.42))
	draw_circle(c, 20.0, Palette.alpha(Palette.DREAM_ABYSS, 0.9))
	draw_arc(c, 18.5, 0.0, TAU, 28, Palette.alpha(Palette.CREAM_WARP, rim), 2.2, true)

	var shackle := PackedVector2Array()
	for i in 9:
		var ang := lerpf(PI, TAU, float(i) / 8.0)
		shackle.append(c + Vector2(cos(ang), sin(ang)) * 8.0 + Vector2(0.0, -1.5))
	draw_polyline(shackle, Palette.alpha(Palette.DREAM_ABYSS, 0.95), 5.4, true)
	draw_polyline(shackle, Palette.CREAM_WARP, 2.6, true)

	var body := Rect2(c + Vector2(-10.0, -1.0), Vector2(20.0, 14.0))
	draw_rect(body.grow(1.6), Palette.DREAM_ABYSS)
	draw_rect(body, Palette.CREAM_WARP)
	draw_circle(c + Vector2(0.0, 5.5), 2.0, Palette.DREAM_ABYSS)
	draw_line(c + Vector2(0.0, 6.2), c + Vector2(0.0, 10.0), Palette.DREAM_ABYSS, 1.8, true)
