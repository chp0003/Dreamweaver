class_name HubTerrain
extends Node2D
## Paints the village green from Kenney isometric landscape tiles in
## res://assets/images/environments/iso_tiles/. Full tile sprites (with
## thickness) are stamped on the grid so grass, roads, water and plazas read
## as one modern park instead of a flat checkerboard.

const TILE_DIR := "res://assets/images/environments/iso_tiles"

const GRASS := "landscapeTiles_067.png"
const DIRT := "landscapeTiles_073.png"
const WATER := "landscapeTiles_066.png"
const WATER_SHINE := "landscapeTiles_037.png"
const ROAD := "landscapeTiles_081.png"
const ROAD_EDGE := "landscapeTiles_082.png"
const ROAD_LANE := "landscapeTiles_074.png"
const PLAZA := "landscapeTiles_090.png"
const SAND := "landscapeTiles_083.png"
const CANAL := "landscapeTiles_012.png"
const TALL_GRASS := "landscapeTiles_075.png"

var plaza_cell := Vector2.ZERO
var house_cells: Array[Vector2] = []
var origin_cell := Vector2i(-16, -16)
var cols := 32
var rows := 32

var _tiles: Dictionary = {} ## filename -> Texture2D
var _map: Dictionary = {} ## Vector2i -> filename
var _scale := 1.0
var _draw_order: Array[Vector2i] = []


func _ready() -> void:
	z_index = -95
	z_as_relative = false
	y_sort_enabled = false
	_load_tiles()
	if _tiles.is_empty():
		push_warning("HubTerrain: no tiles found in %s" % TILE_DIR)
		return
	_scale = Iso.TILE.x / 132.0
	rebuild()


func setup(plaza: Vector2, houses: Array[Vector2], origin: Vector2i, map_cols: int, map_rows: int) -> void:
	plaza_cell = plaza
	house_cells = houses
	origin_cell = origin
	cols = map_cols
	rows = map_rows
	if not _tiles.is_empty():
		rebuild()


func is_path_cell(cell: Vector2) -> bool:
	var key := Vector2i(roundi(cell.x), roundi(cell.y))
	var name := str(_map.get(key, ""))
	return name in [ROAD, ROAD_EDGE, ROAD_LANE, PLAZA, SAND]


func rebuild() -> void:
	_map.clear()
	_paint_field(GRASS)
	_paint_quadrant_features()
	_paint_ring()
	_paint_roads()
	_paint_house_yards()
	_paint_plaza()
	_rebuild_draw_order()
	queue_redraw()


func _load_tiles() -> void:
	_tiles.clear()
	var dir := DirAccess.open(TILE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and entry.ends_with(".png"):
			var path := "%s/%s" % [TILE_DIR, entry]
			var tex: Texture2D = null
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
			if tex == null and FileAccess.file_exists(path):
				var img := Image.new()
				if img.load(path) == OK:
					tex = ImageTexture.create_from_image(img)
			if tex != null:
				_tiles[entry] = tex
		entry = dir.get_next()
	dir.list_dir_end()


func _paint_field(tile: String) -> void:
	for y in range(rows):
		for x in range(cols):
			_set_tile(Vector2i(origin_cell.x + x, origin_cell.y + y), tile)


func _paint_roads() -> void:
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for house in house_cells:
		var stop := _approach(house)
		_paint_run(plaza, Vector2i(roundi(stop.x), roundi(stop.y)), ROAD, ROAD)
	# Widen the arms so the paths read as real walkways against the grass.
	for house in house_cells:
		var stop := _approach(house)
		var a := plaza
		var b := Vector2i(roundi(stop.x), roundi(stop.y))
		var delta := b - a
		var steps := maxi(absi(delta.x), absi(delta.y))
		for i in range(steps + 1):
			var t := 0.0 if steps == 0 else float(i) / float(steps)
			var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
			if absi(delta.x) >= absi(delta.y):
				_set_tile(c + Vector2i(0, 1), ROAD_EDGE)
				_set_tile(c + Vector2i(0, -1), ROAD_EDGE)
			else:
				_set_tile(c + Vector2i(1, 0), ROAD_EDGE)
				_set_tile(c + Vector2i(-1, 0), ROAD_EDGE)


func _paint_plaza() -> void:
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var c := plaza + Vector2i(ox, oy)
			if maxi(absi(ox), absi(oy)) <= 1:
				_set_tile(c, PLAZA)
			else:
				_set_tile_soft(c, ROAD)


func _paint_house_yards() -> void:
	for house in house_cells:
		var h := Vector2i(roundi(house.x), roundi(house.y))
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var c := h + Vector2i(ox, oy)
				var d := maxi(absi(ox), absi(oy))
				if d == 0:
					continue
				if d == 1:
					_set_tile_soft(c, SAND)
				elif d == 2 and (ox == 0 or oy == 0):
					_set_tile_soft(c, DIRT)


func _paint_ring() -> void:
	# Soft dirt ring connecting the four arms so the green is usable, not empty.
	var ring: Array[Vector2i] = [
		Vector2i(5, 5), Vector2i(5, -5), Vector2i(-5, -5), Vector2i(-5, 5), Vector2i(5, 5),
	]
	for i in range(ring.size() - 1):
		_paint_run(ring[i], ring[i + 1], DIRT, DIRT)


func _paint_quadrant_features() -> void:
	# NW pond
	_paint_blob(Vector2i(-6, -6), 3, WATER)
	_set_tile(Vector2i(-6, -6), WATER_SHINE)
	_paint_blob(Vector2i(-7, -5), 1, CANAL)
	# NE garden patio
	_paint_blob(Vector2i(6, -6), 2, SAND)
	_set_tile(Vector2i(6, -6), PLAZA)
	_set_tile(Vector2i(7, -7), TALL_GRASS)
	_set_tile(Vector2i(5, -7), TALL_GRASS)
	# SW orchard mound
	_paint_blob(Vector2i(-7, 6), 2, DIRT)
	_set_tile(Vector2i(-7, 6), TALL_GRASS)
	_set_tile(Vector2i(-8, 5), TALL_GRASS)
	_set_tile(Vector2i(-6, 7), TALL_GRASS)
	# SE water garden
	_paint_blob(Vector2i(7, 5), 2, WATER)
	_set_tile(Vector2i(7, 5), WATER_SHINE)
	_paint_blob(Vector2i(8, 7), 1, CANAL)
	# Outer accent pockets so the diamond edge is not empty grass
	_paint_blob(Vector2i(0, -12), 2, DIRT)
	_paint_blob(Vector2i(0, 12), 2, SAND)
	_paint_blob(Vector2i(-12, 0), 2, DIRT)
	_paint_blob(Vector2i(12, 0), 2, SAND)
	_set_tile(Vector2i(-11, -2), TALL_GRASS)
	_set_tile(Vector2i(11, 2), TALL_GRASS)
	_set_tile(Vector2i(-2, 11), TALL_GRASS)
	_set_tile(Vector2i(2, -11), TALL_GRASS)


func _paint_blob(center: Vector2i, radius: int, tile: String) -> void:
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			if ox * ox + oy * oy <= radius * radius + radius:
				_set_tile(center + Vector2i(ox, oy), tile)


func _paint_run(from: Vector2i, to: Vector2i, primary: String, fill: String) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		_set_tile(from, primary)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var c := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		_set_tile(c, primary if i % 2 == 0 else fill)


func _approach(house: Vector2) -> Vector2:
	var delta := plaza_cell - house
	if delta.length() < 0.01:
		return house
	return house + delta.normalized() * 1.4


func _set_tile(cell: Vector2i, tile: String) -> void:
	if not _in_bounds(cell):
		return
	if not _tiles.has(tile):
		return
	_map[cell] = tile


func _set_tile_soft(cell: Vector2i, tile: String) -> void:
	# Do not overwrite plaza / primary road / water features.
	var cur := str(_map.get(cell, ""))
	if cur in [PLAZA, WATER, WATER_SHINE, CANAL, TALL_GRASS]:
		return
	if cur in [ROAD, ROAD_LANE] and tile in [ROAD_EDGE, DIRT, SAND]:
		return
	_set_tile(cell, tile)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= origin_cell.x and cell.y >= origin_cell.y \
		and cell.x < origin_cell.x + cols and cell.y < origin_cell.y + rows


func _rebuild_draw_order() -> void:
	_draw_order = []
	for key in _map.keys():
		_draw_order.append(key)
	_draw_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x + a.y) < (b.x + b.y)
	)


func _draw() -> void:
	if _draw_order.is_empty():
		return
	for cell in _draw_order:
		var name := str(_map.get(cell, ""))
		var tex: Texture2D = _tiles.get(name) as Texture2D
		if tex == null:
			continue
		var center := Iso.cell_to_world(Vector2(cell))
		var size := tex.get_size() * _scale
		# Kenney landscape tiles: top diamond sits in the upper half; hang the
		# brown thickness below the cell centre so neighbours knit cleanly.
		var origin := Vector2(
			center.x - size.x * 0.5,
			center.y - size.y * 0.55
		)
		draw_texture_rect(tex, Rect2(origin, size), false)
