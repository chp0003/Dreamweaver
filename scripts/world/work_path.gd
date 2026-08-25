class_name WorkPath
extends Node2D
## Floor map of a House's beats. Numbered diamonds plus a gold runner so the
## next station is readable from across a gray room.

const FONT := preload("res://assets/fonts/Cinzel-Bold.ttf")

var _stations: Array[Dictionary] = []
var _active_id := ""
var _pulse := 0.0


func _ready() -> void:
	z_as_relative = true
	z_index = -2
	y_sort_enabled = false
	add_to_group("world_chrome")
	set_process(true)


func setup(stations: Array) -> void:
	_stations.clear()
	for item in stations:
		if item is Dictionary:
			_stations.append(item)
	queue_redraw()


func set_active(id: String) -> void:
	_active_id = id
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta * 3.0
	queue_redraw()


func _draw() -> void:
	if _stations.is_empty():
		return
	_draw_runners()
	for station in _stations:
		_draw_glyph(station)


func _draw_runners() -> void:
	var work: Array[Vector2] = []
	var garden := Vector2.ZERO
	var has_garden := false
	for station in _stations:
		var pos: Vector2 = station.get("pos", Vector2.ZERO)
		if str(station.get("id", "")) == "garden":
			garden = pos
			has_garden = true
		else:
			work.append(pos)
	work.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	if work.size() >= 2:
		draw_polyline(PackedVector2Array(work), Palette.alpha(Palette.GOLD_BRASS, 0.38), 3.2, true)
		draw_polyline(PackedVector2Array(work), Palette.alpha(Palette.GOLD_SUN, 0.16), 7.0, true)
	if has_garden and work.size() >= 2:
		var mid: Vector2 = work[work.size() / 2]
		draw_line(mid, garden, Palette.alpha(Palette.GOLD_BRASS, 0.3), 2.6, true)


func _draw_glyph(station: Dictionary) -> void:
	var pos: Vector2 = station.get("pos", Vector2.ZERO)
	var n := int(station.get("n", 0))
	var title := str(station.get("title", "")).to_upper()
	var active := str(station.get("id", "")) == _active_id
	var t := 0.55 + 0.45 * sin(_pulse)
	var fill := Palette.GOLD_SUN if active else Palette.GOLD_BRASS
	var ring_a := (0.55 + t * 0.4) if active else 0.34
	var scale := 1.22 if active else 0.92
	draw_colored_polygon(
		Iso.diamond(pos, scale),
		Palette.alpha(fill, 0.2 + (t * 0.18 if active else 0.0))
	)
	draw_polyline(
		_closed(Iso.diamond(pos, scale)),
		Palette.alpha(fill, ring_a),
		2.4 if active else 1.6
	)
	var numeral := str(n)
	var num_size := 15 if active else 13
	var num_w := FONT.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	draw_string(
		FONT,
		pos + Vector2(-num_w * 0.5, 5.0),
		numeral,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		num_size,
		Palette.GOLD_SUN if active else Palette.alpha(Palette.CREAM_WARP, 0.88)
	)
	if title.is_empty():
		return
	var title_size := 10
	var title_w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(
		FONT,
		pos + Vector2(-title_w * 0.5, 22.0),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		title_size,
		Palette.GOLD_SACRED if active else Palette.alpha(Palette.CREAM_STONE, 0.72)
	)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out
