class_name WovenFrame
extends PanelContainer
## Lit-glass pane with T'nalak corner work.
##
## The fill is a translucent twilight wash (so the world still shows through).
## The ornament is a thin gold hairline, diamond bosses at the corners, and a
## kleng zigzag along the top and bottom - the same motif as the Gateway clouds,
## scaled down to jewellery. Together they read as a storybook plate rather than
## a programmer's rectangle.

@export var fill := Color(0.055, 0.075, 0.149, 0.82)
@export var border := Color(0.69, 0.541, 0.18, 0.45)
@export var pad := 18
@export var draw_kleng := true
@export var header_band := false
@export var accent_bar := false
@export var lit := false
@export var accent := Color(0.929, 0.82, 0.447, 1)
var _quiet := false


func set_quiet(on: bool) -> void:
	_quiet = on
	if on:
		lit = false
		accent = Palette.CREAM_STONE
		border = Palette.alpha(Palette.CREAM_STONE, 0.28)
	_apply_style()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	resized.connect(queue_redraw)
	resized.connect(_apply_style)


func _apply_style() -> void:
	var box: StyleBoxFlat
	if lit:
		box = UiStyle.glass_lit(Palette.DREAM_INDIGO, maxf(fill.a, 0.88), pad)
	else:
		box = UiStyle.glass(Palette.DREAM_NIGHT, maxf(fill.a, 0.78), pad, Palette.GOLD_BRASS, maxf(border.a, 0.45))
	if accent_bar:
		box.border_width_left = 3
		box.border_color = Palette.alpha(accent, 0.7)
	add_theme_stylebox_override("panel", box)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 24.0 or r.size.y < 24.0:
		return
	_draw_inner_glow(r)
	if header_band:
		_draw_header(r)
	if draw_kleng:
		_draw_kleng_edge(r, 10.0)
		_draw_kleng_edge(r, r.size.y - 10.0)
	_draw_corners(r)


func _draw_inner_glow(r: Rect2) -> void:
	var inset := r.grow(-7.0)
	draw_rect(inset, Palette.alpha(Palette.DREAM_LANTERN, 0.035), false, 1.0)
	if lit:
		draw_rect(r.grow(-3.0), Palette.alpha(accent, 0.08))


func _draw_header(r: Rect2) -> void:
	var band := Rect2(r.position.x + 12.0, r.position.y + 8.0, r.size.x - 24.0, 3.0)
	draw_rect(band, Palette.alpha(accent, 0.55))
	draw_rect(Rect2(band.position + Vector2(0.0, 3.0), Vector2(band.size.x, 1.0)),
		Palette.alpha(Palette.RED_SACRED, 0.35))


func _draw_kleng_edge(r: Rect2, y: float) -> void:
	var step := 10.0
	var amp := 3.5
	var start_x := 18.0
	var end_x := r.size.x - 18.0
	if end_x - start_x < step * 2.0:
		return
	var points := PackedVector2Array()
	var x := start_x
	var up := true
	while x <= end_x:
		points.append(Vector2(x, y + (-amp if up else amp)))
		x += step
		up = not up
	var ink := Palette.CREAM_STONE if _quiet else Palette.GOLD_BRASS
	draw_polyline(points, Palette.alpha(ink, 0.38), 1.2, true)


func _draw_corners(r: Rect2) -> void:
	var inset := 11.0
	var bosses := [
		Vector2(inset, inset),
		Vector2(r.size.x - inset, inset),
		Vector2(inset, r.size.y - inset),
		Vector2(r.size.x - inset, r.size.y - inset),
	]
	for centre in bosses:
		_draw_boss(centre)
	_draw_curl(bosses[0], Vector2(1, 1))
	_draw_curl(bosses[1], Vector2(-1, 1))
	_draw_curl(bosses[2], Vector2(1, -1))
	_draw_curl(bosses[3], Vector2(-1, -1))


func _draw_boss(centre: Vector2) -> void:
	var s := 4.5
	var diamond := PackedVector2Array([
		centre + Vector2(0.0, -s),
		centre + Vector2(s * 0.7, 0.0),
		centre + Vector2(0.0, s),
		centre + Vector2(-s * 0.7, 0.0),
	])
	var boss := Palette.CREAM_STONE if _quiet else Palette.GOLD_SACRED
	draw_colored_polygon(diamond, boss)
	draw_polyline(diamond + PackedVector2Array([diamond[0]]),
		Palette.alpha(Palette.DREAM_LANTERN, 0.9), 1.0)
	draw_circle(centre, 1.3, Palette.GOLD_SUN)


func _draw_curl(origin: Vector2, dir: Vector2) -> void:
	var ink := Palette.alpha(Palette.GOLD_BRASS, 0.55)
	var a := origin + Vector2(8.0 * dir.x, 1.5 * dir.y)
	var b := origin + Vector2(16.0 * dir.x, 6.0 * dir.y)
	var c := origin + Vector2(12.0 * dir.x, 12.0 * dir.y)
	draw_polyline(PackedVector2Array([origin, a, b]), ink, 1.2, true)
	draw_polyline(PackedVector2Array([
		origin,
		origin + Vector2(1.5 * dir.x, 8.0 * dir.y),
		origin + Vector2(6.0 * dir.x, 16.0 * dir.y),
		c,
	]), ink, 1.2, true)
