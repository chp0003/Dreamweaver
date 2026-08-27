class_name HubTerrain
extends Node2D
## Village green from project iso_tiles (tile_XXX.png).
## Clean grass field + brick/dirt path X that runs flush into each house porch,
## so roads and foundations share one isometric grid (Stardew / Octopath clarity).

const TILE_DIR := "res://assets/images/environments/iso_tiles"

const GRASS := ["tile_023.png", "tile_024.png", "tile_037.png", "tile_038.png"]
const GRASS_LUSH := ["tile_027.png", "tile_039.png"]
const DIRT := ["tile_000.png", "tile_001.png", "tile_005.png"]
const DIRT_EDGE := ["tile_019.png", "tile_020.png", "tile_025.png"]
const PATH_BRICK := "tile_016.png"
const PATH_STONE := "tile_013.png"
const PATH_FLAG := "tile_011.png"
const PATH_DIRT := "tile_008.png"
const WATER := "tile_088.png"
const WATER_RIPPLE := ["tile_087.png", "tile_089.png"]
const WATER_SHALLOW := ["tile_104.png", "tile_105.png"]
const WATER_SHINE := "tile_114.png"
const WATER_ROCK := ["tile_070.png", "tile_075.png"]

const DECOR_BUSH := ["tile_029.png", "tile_030.png", "tile_043.png"]
const DECOR_FLOWER := ["tile_041.png", "tile_046.png", "tile_047.png"]
const DECOR_ROCK := ["tile_053.png", "tile_058.png", "tile_062.png"]

var plaza_cell := Vector2.ZERO
var house_cells: Array[Vector2] = []
var origin_cell := Vector2i(-16, -16)
var cols := 32
var rows := 32

var _tiles: Dictionary = {}
var _map: Dictionary = {}
var _decor: Dictionary = {}
var _path_cells: Dictionary = {} ## Vector2i -> true (road network)
var _scale := 2.0
var _draw_order: Array[Vector2i] = []


func _ready() -> void:
	z_index = -95
	z_as_relative = false
	y_sort_enabled = false
	_load_tiles()
	if _tiles.is_empty():
		push_warning("HubTerrain: no tile_*.png found in %s" % TILE_DIR)
		return
	var sample: Texture2D = _tiles.values()[0]
	_scale = Iso.TILE.x / float(sample.get_width())
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
	return _path_cells.has(Vector2i(roundi(cell.x), roundi(cell.y)))


func is_near_path(cell: Vector2, radius: int = 1) -> bool:
	var c := Vector2i(roundi(cell.x), roundi(cell.y))
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			if _path_cells.has(c + Vector2i(ox, oy)):
				return true
	return false


func rebuild() -> void:
	_map.clear()
	_decor.clear()
	_path_cells.clear()
	_paint_field()
	_paint_roads()
	_paint_plaza()
	_paint_house_foundations()
	_paint_midring()
	_paint_farmland()
	_paint_quadrant_features()
	_scatter_decor()
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
		if entry.begins_with("tile_") and entry.ends_with(".png"):
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


func _paint_field() -> void:
	# Mostly uniform grass — crisp, readable field, not noisy dirt checker.
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(origin_cell.x + x, origin_cell.y + y)
			var n := _hash(cell)
			if n % 17 == 0:
				_set_tile(cell, _pick(GRASS_LUSH, cell))
			else:
				_set_tile(cell, _pick(GRASS, cell))


func _paint_roads() -> void:
	# Straight diagonal brick arms from plaza through each house cell — no gap.
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for house in house_cells:
		var dest := Vector2i(roundi(house.x), roundi(house.y))
		_paint_path_arm(plaza, dest)


func _paint_path_arm(from: Vector2i, to: Vector2i) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	var along_x := absi(delta.x) >= absi(delta.y)
	for i in range(steps + 1):
		var t := 0.0 if steps == 0 else float(i) / float(steps)
		var c := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		# 3-wide brick road centered on the arm axis.
		_mark_path(c, PATH_BRICK)
		if along_x:
			_mark_path(c + Vector2i(0, 1), PATH_STONE if i % 2 == 0 else PATH_BRICK)
			_mark_path(c + Vector2i(0, -1), PATH_STONE if i % 2 == 1 else PATH_BRICK)
			_set_tile_soft(c + Vector2i(0, 2), _pick(DIRT_EDGE, c))
			_set_tile_soft(c + Vector2i(0, -2), _pick(DIRT_EDGE, c + Vector2i(1, 0)))
		else:
			_mark_path(c + Vector2i(1, 0), PATH_STONE if i % 2 == 0 else PATH_BRICK)
			_mark_path(c + Vector2i(-1, 0), PATH_STONE if i % 2 == 1 else PATH_BRICK)
			_set_tile_soft(c + Vector2i(2, 0), _pick(DIRT_EDGE, c))
			_set_tile_soft(c + Vector2i(-2, 0), _pick(DIRT_EDGE, c + Vector2i(0, 1)))


func _paint_plaza() -> void:
	# Wide town square — enough brick that the crossing reads as a plaza.
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for oy in range(-5, 6):
		for ox in range(-5, 6):
			var c := plaza + Vector2i(ox, oy)
			var d := maxi(absi(ox), absi(oy))
			if d <= 2:
				_mark_path(c, PATH_BRICK)
			elif d == 3:
				_mark_path(c, PATH_STONE)
			elif d == 4 and (ox == 0 or oy == 0 or absi(ox) == absi(oy)):
				_mark_path(c, PATH_FLAG)
			elif d == 5 and (ox == 0 or oy == 0):
				_mark_path(c, PATH_FLAG)


func _paint_midring() -> void:
	# Secondary walk ring through the mid-zone so expanded space is usable.
	var ring: Array[Vector2i] = [
		Vector2i(6, 6), Vector2i(6, -6), Vector2i(-6, -6), Vector2i(-6, 6), Vector2i(6, 6),
	]
	for i in range(ring.size() - 1):
		_paint_run_dirt(ring[i], ring[i + 1])


func _paint_run_dirt(from: Vector2i, to: Vector2i) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	for i in range(steps + 1):
		var t := 0.0 if steps == 0 else float(i) / float(steps)
		var c := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		if _path_cells.has(c):
			continue
		_mark_path(c, PATH_FLAG if i % 2 == 0 else PATH_DIRT)
		_set_tile_soft(c + Vector2i(1, 0), _pick(DIRT_EDGE, c))
		_set_tile_soft(c + Vector2i(-1, 0), _pick(DIRT_EDGE, c + Vector2i(0, 1)))


func _paint_farmland() -> void:
	# Mid-zone farm / garden plots between the path arms — fills the diamond.
	var plots: Array[Vector2i] = [
		Vector2i(-5, -9), Vector2i(5, -9), Vector2i(-9, -5), Vector2i(9, -5),
		Vector2i(-5, 9), Vector2i(5, 9), Vector2i(-9, 5), Vector2i(9, 5),
		Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-3, -6), Vector2i(6, 3),
	]
	for center in plots:
		if _near_any_house(center, 4):
			continue
		_paint_feature_blob(center, 2, _pick(DIRT, center), false)
		# Crop rows / flower beds on top of tilled dirt.
		_set_decor(center, _pick(DECOR_FLOWER, center))
		_set_decor(center + Vector2i(1, 0), _pick(DECOR_FLOWER, center + Vector2i(1, 0)))
		_set_decor(center + Vector2i(0, 1), _pick(DECOR_BUSH, center + Vector2i(0, 1)))
		# Soft dirt path spur from nearest ring toward the plot.
		var spur := Vector2i(
			clampi(center.x, -6, 6),
			clampi(center.y, -6, 6)
		)
		_paint_run_dirt(spur, center)


func _paint_house_foundations() -> void:
	# Porch pad is the same brick language as the road — seamless door connection.
	for house in house_cells:
		var h := Vector2i(roundi(house.x), roundi(house.y))
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var c := h + Vector2i(ox, oy)
				var d := maxi(absi(ox), absi(oy))
				if d == 0:
					_mark_path(c, PATH_BRICK)
				elif d == 1:
					_mark_path(c, PATH_STONE)
				elif d == 2 and (ox == 0 or oy == 0):
					_mark_path(c, PATH_FLAG)
				_decor.erase(c)
		# Stoop toward the plaza so the staircase foot sits on brick, not grass.
		var toward := Vector2(plaza_cell) - Vector2(h)
		var sx := 0 if absf(toward.x) < 0.1 else (1 if toward.x > 0.0 else -1)
		var sy := 0 if absf(toward.y) < 0.1 else (1 if toward.y > 0.0 else -1)
		for step_i in range(1, 3):
			var stoop := h + Vector2i(sx * step_i, sy * step_i)
			_mark_path(stoop, PATH_BRICK)
			if sx != 0 and sy == 0:
				_mark_path(stoop + Vector2i(0, 1), PATH_STONE)
				_mark_path(stoop + Vector2i(0, -1), PATH_STONE)
			elif sy != 0 and sx == 0:
				_mark_path(stoop + Vector2i(1, 0), PATH_STONE)
				_mark_path(stoop + Vector2i(-1, 0), PATH_STONE)
			else:
				_mark_path(stoop + Vector2i(sx, 0), PATH_STONE)
				_mark_path(stoop + Vector2i(0, sy), PATH_STONE)
		# Dirt apron just outside the porch so the foundation reads against grass.
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				var c := h + Vector2i(ox, oy)
				var d := maxi(absi(ox), absi(oy))
				if d == 3 and (ox == 0 or oy == 0 or absi(ox) == absi(oy)):
					if not _path_cells.has(c):
						_set_tile(c, _pick(DIRT, c))


func _paint_quadrant_features() -> void:
	# Outer framing only — small ponds/gardens near the diamond rim.
	_paint_feature_blob(Vector2i(-13, -13), 2, WATER, true)
	_set_tile(Vector2i(-13, -13), WATER_SHINE)
	_set_tile(Vector2i(-12, -14), _pick(WATER_ROCK, Vector2i(-12, -14)))

	_paint_feature_blob(Vector2i(13, -13), 2, _pick(DIRT, Vector2i(13, -13)), false)
	_set_decor(Vector2i(13, -13), _pick(DECOR_FLOWER, Vector2i(13, -13)))
	_set_decor(Vector2i(14, -12), _pick(DECOR_BUSH, Vector2i(14, -12)))

	_paint_feature_blob(Vector2i(-13, 13), 2, _pick(DIRT, Vector2i(-13, 13)), false)
	_set_decor(Vector2i(-13, 12), _pick(DECOR_ROCK, Vector2i(-13, 12)))
	_set_decor(Vector2i(-12, 14), _pick(DECOR_ROCK, Vector2i(-12, 14)))

	_paint_feature_blob(Vector2i(14, 4), 2, _pick(WATER_SHALLOW, Vector2i(14, 4)), true)
	_set_tile(Vector2i(14, 4), WATER_SHINE)
	_set_tile(Vector2i(15, 3), _pick(WATER_RIPPLE, Vector2i(15, 3)))


func _paint_feature_blob(center: Vector2i, radius: int, tile: String, is_water: bool) -> void:
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			if ox * ox + oy * oy > radius * radius + radius:
				continue
			var c := center + Vector2i(ox, oy)
			if _path_cells.has(c) or _near_any_house(c, 3):
				continue
			_set_tile(c, tile)
			if is_water:
				_decor.erase(c)


func _scatter_decor() -> void:
	# Frame the roads from a distance — never on path, porch, or road shoulder.
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(origin_cell.x + x, origin_cell.y + y)
			if _decor.has(cell) or _path_cells.has(cell):
				continue
			if _near_any_house(cell, 4):
				continue
			if is_near_path(Vector2(cell), 2):
				continue
			var floor_name := str(_map.get(cell, ""))
			if floor_name in [WATER, WATER_SHINE] or floor_name.begins_with("tile_07") \
					or floor_name.begins_with("tile_08") or floor_name.begins_with("tile_10") \
					or floor_name.begins_with("tile_11"):
				if floor_name in [
					WATER, WATER_SHINE, "tile_070.png", "tile_075.png",
					"tile_087.png", "tile_088.png", "tile_089.png",
					"tile_104.png", "tile_105.png", "tile_114.png",
				]:
					continue
			var n := _hash(cell)
			if n % 29 == 0:
				_set_decor(cell, _pick(DECOR_BUSH, cell))
			elif n % 41 == 0:
				_set_decor(cell, _pick(DECOR_FLOWER, cell))
			elif n % 53 == 0:
				_set_decor(cell, _pick(DECOR_ROCK, cell))


func _mark_path(cell: Vector2i, tile: String) -> void:
	if not _in_bounds(cell):
		return
	if not _tiles.has(tile):
		return
	_map[cell] = tile
	_path_cells[cell] = true
	_decor.erase(cell)


func _set_tile(cell: Vector2i, tile: String) -> void:
	if not _in_bounds(cell):
		return
	if not _tiles.has(tile):
		return
	_map[cell] = tile


func _set_tile_soft(cell: Vector2i, tile: String) -> void:
	if _path_cells.has(cell):
		return
	_set_tile(cell, tile)


func _set_decor(cell: Vector2i, tile: String) -> void:
	if not _in_bounds(cell) or not _tiles.has(tile):
		return
	if _path_cells.has(cell) or _near_any_house(cell, 3):
		return
	_decor[cell] = tile


func _near_any_house(cell: Vector2i, radius: int) -> bool:
	for house in house_cells:
		var h := Vector2i(roundi(house.x), roundi(house.y))
		if maxi(absi(cell.x - h.x), absi(cell.y - h.y)) <= radius:
			return true
	return false


func _pick(options: Array, cell: Vector2i) -> String:
	if options.is_empty():
		return ""
	return str(options[_hash(cell) % options.size()])


func _hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= origin_cell.x and cell.y >= origin_cell.y \
		and cell.x < origin_cell.x + cols and cell.y < origin_cell.y + rows


func _rebuild_draw_order() -> void:
	_draw_order = []
	var seen: Dictionary = {}
	for key in _map.keys():
		seen[key] = true
		_draw_order.append(key)
	for key in _decor.keys():
		if not seen.has(key):
			_draw_order.append(key)
	_draw_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x + a.y) < (b.x + b.y)
	)


func _draw() -> void:
	if _draw_order.is_empty():
		return
	for cell in _draw_order:
		_blit(cell, str(_map.get(cell, "")))
		if _decor.has(cell):
			_blit(cell, str(_decor[cell]))


func _blit(cell: Vector2i, name: String) -> void:
	if name == "":
		return
	var tex: Texture2D = _tiles.get(name) as Texture2D
	if tex == null:
		return
	var center := Iso.cell_to_world(Vector2(cell))
	var size := tex.get_size() * _scale
	var origin := Vector2(
		center.x - size.x * 0.5,
		center.y - size.y * 0.62
	)
	draw_texture_rect(tex, Rect2(origin, size), false)
