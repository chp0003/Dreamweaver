class_name TnalakOverlay
extends Control
## Full-screen geometric T'nalak overlay used during the Finishing Stitch QTE.
##
## Drawn as a kleng (zigzag lightning) lattice in the three sacred dyes so the
## last stitch reads as cloth, not as a UI prompt floating on black.

var _pulse := 0.0
var _strength := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 1.4, TAU)
	queue_redraw()


func fade_in(duration := 0.55) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)


func fade_out(duration := 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)


func strike() -> void:
	_strength = 1.0
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _strength = v, 1.0, 0.0, 0.28)


func _draw() -> void:
	var size := get_size()
	if size.x < 8.0 or size.y < 8.0:
		return
	var glow := 0.18 + _strength * 0.35 + sin(_pulse) * 0.04
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.03, 0.42 + _strength * 0.12))

	var cols := 9
	var rows := 7
	var cell := Vector2(size.x / float(cols), size.y / float(rows))
	for y in range(rows):
		for x in range(cols):
			var origin := Vector2(cell.x * float(x), cell.y * float(y))
			var diamond := PackedVector2Array([
				origin + Vector2(cell.x * 0.5, cell.y * 0.08),
				origin + Vector2(cell.x * 0.92, cell.y * 0.5),
				origin + Vector2(cell.x * 0.5, cell.y * 0.92),
				origin + Vector2(cell.x * 0.08, cell.y * 0.5),
			])
			var sacred := (x + y) % 3
			var color := Color(0.12, 0.1, 0.09, glow)
			match sacred:
				0:
					color = Color(0.12, 0.1, 0.09, glow + 0.08)
				1:
					color = Color(0.62, 0.16, 0.14, glow)
				_:
					color = Color(0.82, 0.68, 0.28, glow * 0.85)
			draw_colored_polygon(diamond, color)

	# Kleng lightning bands across the cloth.
	var ink := Color(0.93, 0.86, 0.55, 0.22 + _strength * 0.45)
	for band in range(4):
		var y := size.y * (0.18 + float(band) * 0.2) + sin(_pulse + float(band)) * 6.0
		var points := PackedVector2Array()
		var zig := 18.0
		var x := 0.0
		var up := true
		while x <= size.x:
			points.append(Vector2(x, y + (-zig if up else zig)))
			x += 36.0
			up = not up
		if points.size() >= 2:
			draw_polyline(points, ink, 2.4 + _strength * 3.0)
