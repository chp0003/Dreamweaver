class_name HubBoardwalk
extends Node2D
## Wooden X of the village green: a plaza crossing with boardwalk arms out to
## each House, edged in dark hedge so the paths read against the grass.

const WOOD_A := Color(0.78, 0.62, 0.38, 1.0)
const WOOD_B := Color(0.70, 0.54, 0.32, 1.0)
const WOOD_EDGE := Color(0.42, 0.30, 0.16, 0.95)
const WOOD_PLANK := Color(0.52, 0.38, 0.20, 0.55)
const HEDGE := Color(0.16, 0.34, 0.14, 1.0)
const HEDGE_TIP := Color(0.28, 0.48, 0.18, 0.95)
const PLAZA_INK := Color(0.86, 0.70, 0.42, 1.0)

var plaza_cell := Vector2.ZERO
var destinations: Array[Vector2] = []
var path_lookup: Dictionary = {} ## Vector2i -> "plaza" | "path"
var hedge_cells: Array[Vector2i] = []


func _ready() -> void:
	z_index = -90
	z_as_relative = false
	y_sort_enabled = false
	queue_redraw()


func setup(plaza: Vector2, houses: Array[Vector2]) -> void:
	plaza_cell = plaza
	destinations = houses
	_rebuild()
	queue_redraw()


func is_path_cell(cell: Vector2) -> bool:
	return path_lookup.has(Vector2i(roundi(cell.x), roundi(cell.y)))


func _rebuild() -> void:
	path_lookup.clear()
	hedge_cells.clear()
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			path_lookup[plaza + Vector2i(ox, oy)] = "plaza"
	for dest in destinations:
		var stop := _path_end(dest)
		_paint_run(plaza, Vector2i(roundi(stop.x), roundi(stop.y)))
	_collect_hedges()


func _path_end(house_cell: Vector2) -> Vector2:
	var delta := plaza_cell - house_cell
	if delta.length() < 0.01:
		return house_cell
	return house_cell + delta.normalized()


func _paint_run(from: Vector2i, to: Vector2i) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		_mark_path(from)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := Vector2(from).lerp(Vector2(to), t)
		var c := Vector2i(roundi(p.x), roundi(p.y))
		_mark_path(c)
		if absi(delta.x) >= absi(delta.y):
			_mark_path(c + Vector2i(0, 1))
		else:
			_mark_path(c + Vector2i(1, 0))
		if absi(delta.x) == absi(delta.y) and delta.x != 0:
			_mark_path(c + Vector2i(1, 0))


func _mark_path(cell: Vector2i) -> void:
	if path_lookup.get(cell, "") == "plaza":
		return
	path_lookup[cell] = "path"


func _collect_hedges() -> void:
	var seen := {}
	for cell in path_lookup.keys():
		var c: Vector2i = cell
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var h: Vector2i = c + n
			if path_lookup.has(h) or seen.has(h):
				continue
			if _too_close_to_house(h):
				continue
			seen[h] = true
			hedge_cells.append(h)


func _too_close_to_house(cell: Vector2i) -> bool:
	for dest in destinations:
		if Vector2(cell).distance_to(dest) < 1.6:
			return true
	return false


func _draw() -> void:
	var cells: Array = path_lookup.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x + a.y) < (b.x + b.y)
	)
	for cell in hedge_cells:
		_draw_hedge(cell)
	for cell in cells:
		var kind := str(path_lookup[cell])
		_draw_plank(cell, kind == "plaza")
	_draw_plaza_knot()


func _draw_plank(cell: Vector2i, plaza: bool) -> void:
	var center := Iso.cell_to_world(Vector2(cell))
	var fill := PLAZA_INK if plaza else (WOOD_A if (cell.x + cell.y) % 2 == 0 else WOOD_B)
	draw_colored_polygon(Iso.diamond(center, 1.02), fill)
	draw_polyline(_closed(Iso.diamond(center, 1.02)), WOOD_EDGE, 1.4)
	var inset := Iso.diamond(center, 0.62)
	if inset.size() >= 4:
		draw_line(inset[0], inset[2], WOOD_PLANK, 1.1)
		draw_line(inset[1], inset[3], Palette.alpha(WOOD_PLANK, 0.45), 1.0)


func _draw_hedge(cell: Vector2i) -> void:
	var center := Iso.cell_to_world(Vector2(cell))
	draw_colored_polygon(Iso.diamond(center, 0.92), HEDGE)
	draw_colored_polygon(Iso.diamond(center + Vector2(0.0, -3.0), 0.55), HEDGE_TIP)


func _draw_plaza_knot() -> void:
	var center := Iso.cell_to_world(plaza_cell)
	var gold := Palette.alpha(Palette.GOLD_BRASS, 0.55)
	draw_colored_polygon(Iso.diamond(center, 1.35), Palette.alpha(PLAZA_INK, 0.95))
	draw_polyline(_closed(Iso.diamond(center, 1.35)), gold, 2.0)
	draw_polyline(_closed(Iso.diamond(center, 0.7)), Palette.alpha(Palette.GOLD_SACRED, 0.7), 1.6)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out
