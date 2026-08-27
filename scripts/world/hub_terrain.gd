class_name HubTerrain
extends Node2D
## Paints the village green from the project's iso_tiles pack
## (res://assets/images/environments/iso_tiles/tile_XXX.png).
## Grass field, wooden boardwalk X, cobble plaza, ponds and gardens fill the
## diamond so the hub reads as a modern park instead of empty checkerboard.

const TILE_DIR := "res://assets/images/environments/iso_tiles"

# --- floor ---
const GRASS := ["tile_023.png", "tile_024.png", "tile_037.png", "tile_038.png", "tile_039.png"]
const GRASS_LUSH := ["tile_027.png", "tile_028.png"]
const DIRT := ["tile_000.png", "tile_001.png", "tile_002.png", "tile_005.png", "tile_008.png"]
const DIRT_MOSS := ["tile_019.png", "tile_020.png", "tile_025.png", "tile_026.png"]
const PATH_WOOD_A := "tile_014.png"
const PATH_WOOD_B := "tile_015.png"
const PATH_STONE := "tile_013.png"
const PATH_BRICK := "tile_016.png"
const PATH_FLAG := "tile_011.png"
const WATER := "tile_088.png"
const WATER_RIPPLE := ["tile_087.png", "tile_089.png", "tile_096.png", "tile_097.png"]
const WATER_SHALLOW := ["tile_104.png", "tile_105.png", "tile_112.png"]
const WATER_SHINE := "tile_114.png"
const WATER_ROCK := ["tile_070.png", "tile_071.png", "tile_075.png", "tile_078.png"]

# --- decor stamps (same footprint, drawn after floor) ---
const DECOR_BUSH := ["tile_029.png", "tile_030.png", "tile_031.png", "tile_043.png", "tile_044.png"]
const DECOR_FLOWER := ["tile_041.png", "tile_042.png", "tile_046.png", "tile_047.png"]
const DECOR_ROCK := ["tile_053.png", "tile_055.png", "tile_058.png", "tile_062.png", "tile_065.png"]
const DECOR_LOG := ["tile_048.png", "tile_050.png", "tile_051.png"]
const DECOR_TALL := ["tile_034.png", "tile_035.png", "tile_036.png"]

var plaza_cell := Vector2.ZERO
var house_cells: Array[Vector2] = []
var origin_cell := Vector2i(-16, -16)
var cols := 32
var rows := 32

var _tiles: Dictionary = {} ## filename -> Texture2D
var _map: Dictionary = {} ## Vector2i -> filename
var _decor: Dictionary = {} ## Vector2i -> filename
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
	var key := Vector2i(roundi(cell.x), roundi(cell.y))
	var name := str(_map.get(key, ""))
	return name in [PATH_WOOD_A, PATH_WOOD_B, PATH_STONE, PATH_BRICK, PATH_FLAG]


func rebuild() -> void:
	_map.clear()
	_decor.clear()
	_paint_field()
	_paint_quadrant_features()
	_paint_ring()
	_paint_roads()
	_paint_house_yards()
	_paint_plaza()
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
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(origin_cell.x + x, origin_cell.y + y)
			var n := _hash(cell)
			if n % 11 == 0:
				_set_tile(cell, _pick(DIRT_MOSS, cell))
			elif n % 7 == 0:
				_set_tile(cell, _pick(GRASS_LUSH, cell))
			else:
				_set_tile(cell, _pick(GRASS, cell))


func _paint_roads() -> void:
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for house in house_cells:
		var stop := _approach(house)
		var a := plaza
		var b := Vector2i(roundi(stop.x), roundi(stop.y))
		var delta := b - a
		var along_x := absi(delta.x) >= absi(delta.y)
		var wood := PATH_WOOD_A if along_x else PATH_WOOD_B
		_paint_run(a, b, wood, wood)
		# Twin-plank width + moss shoulders so the X reads as a real boardwalk.
		var steps := maxi(absi(delta.x), absi(delta.y))
		for i in range(steps + 1):
			var t := 0.0 if steps == 0 else float(i) / float(steps)
			var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
			if along_x:
				_set_tile(c + Vector2i(0, 1), wood)
				_set_tile_soft(c + Vector2i(0, 2), _pick(DIRT_MOSS, c))
				_set_tile_soft(c + Vector2i(0, -1), _pick(DIRT_MOSS, c + Vector2i(1, 0)))
			else:
				_set_tile(c + Vector2i(1, 0), wood)
				_set_tile_soft(c + Vector2i(2, 0), _pick(DIRT_MOSS, c))
				_set_tile_soft(c + Vector2i(-1, 0), _pick(DIRT_MOSS, c + Vector2i(0, 1)))


func _paint_plaza() -> void:
	var plaza := Vector2i(roundi(plaza_cell.x), roundi(plaza_cell.y))
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			var c := plaza + Vector2i(ox, oy)
			var d := maxi(absi(ox), absi(oy))
			if d == 0:
				_set_tile(c, PATH_BRICK)
			elif d <= 1:
				_set_tile(c, PATH_STONE)
			elif d == 2:
				_set_tile(c, PATH_FLAG)
			elif d == 3 and (ox == 0 or oy == 0 or absi(ox) == absi(oy)):
				_set_tile_soft(c, PATH_FLAG)


func _paint_house_yards() -> void:
	for house in house_cells:
		var h := Vector2i(roundi(house.x), roundi(house.y))
		# Clear stone porch under each Guno Bong so the house reads as a landmark.
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				var c := h + Vector2i(ox, oy)
				var d := maxi(absi(ox), absi(oy))
				if d == 0:
					_set_tile(c, PATH_STONE)
					_decor.erase(c)
				elif d == 1:
					_set_tile(c, PATH_FLAG)
					_decor.erase(c)
				elif d == 2 and (ox == 0 or oy == 0 or absi(ox) == absi(oy)):
					_set_tile_soft(c, PATH_FLAG)
					_decor.erase(c)
				elif d == 3 and (ox == 0 or oy == 0):
					_set_tile_soft(c, _pick(DIRT_MOSS, c))
					_decor.erase(c)


func _paint_ring() -> void:
	# Dirt / stone loop through the four wedges so empty space becomes walkable park.
	var ring: Array[Vector2i] = [
		Vector2i(5, 5), Vector2i(5, -5), Vector2i(-5, -5), Vector2i(-5, 5), Vector2i(5, 5),
	]
	for i in range(ring.size() - 1):
		_paint_run(ring[i], ring[i + 1], PATH_FLAG, _pick(DIRT, ring[i]))


func _paint_quadrant_features() -> void:
	# NW deep pond with rock accents
	_paint_blob(Vector2i(-7, -7), 4, WATER)
	_set_tile(Vector2i(-7, -7), WATER_SHINE)
	_set_tile(Vector2i(-6, -8), _pick(WATER_RIPPLE, Vector2i(-6, -8)))
	_set_tile(Vector2i(-8, -6), _pick(WATER_ROCK, Vector2i(-8, -6)))
	_set_tile(Vector2i(-5, -7), _pick(WATER_ROCK, Vector2i(-5, -7)))
	_set_tile(Vector2i(-9, -8), _pick(WATER_ROCK, Vector2i(-9, -8)))
	_paint_blob(Vector2i(-10, -5), 2, _pick(DIRT_MOSS, Vector2i(-10, -5)))
	_set_decor(Vector2i(-10, -4), _pick(DECOR_BUSH, Vector2i(-10, -4)))
	_set_decor(Vector2i(-5, -9), _pick(DECOR_TALL, Vector2i(-5, -9)))

	# NE flower / garden patio
	_paint_blob(Vector2i(7, -7), 3, _pick(DIRT, Vector2i(7, -7)))
	_set_tile(Vector2i(7, -7), PATH_BRICK)
	_set_tile(Vector2i(8, -7), PATH_FLAG)
	_set_tile(Vector2i(6, -8), _pick(GRASS_LUSH, Vector2i(6, -8)))
	_set_tile(Vector2i(8, -6), _pick(GRASS_LUSH, Vector2i(8, -6)))
	_set_tile(Vector2i(9, -8), _pick(GRASS_LUSH, Vector2i(9, -8)))
	for flower_cell in [
		Vector2i(6, -7), Vector2i(8, -7), Vector2i(7, -6), Vector2i(7, -8),
		Vector2i(5, -8), Vector2i(9, -6), Vector2i(6, -6), Vector2i(8, -8),
	]:
		_set_decor(flower_cell, _pick(DECOR_FLOWER, flower_cell))
	_set_decor(Vector2i(5, -9), _pick(DECOR_BUSH, Vector2i(5, -9)))
	_set_decor(Vector2i(9, -5), _pick(DECOR_BUSH, Vector2i(9, -5)))

	# SW rock orchard
	_paint_blob(Vector2i(-7, 7), 3, _pick(DIRT, Vector2i(-7, 7)))
	_set_tile(Vector2i(-7, 7), _pick(DIRT_MOSS, Vector2i(-7, 7)))
	_set_tile(Vector2i(-8, 8), _pick(DIRT_MOSS, Vector2i(-8, 8)))
	for rock_cell in [
		Vector2i(-8, 6), Vector2i(-6, 8), Vector2i(-9, 7), Vector2i(-5, 6),
		Vector2i(-7, 5), Vector2i(-6, 6),
	]:
		_set_decor(rock_cell, _pick(DECOR_ROCK, rock_cell))
	_set_decor(Vector2i(-7, 6), _pick(DECOR_LOG, Vector2i(-7, 6)))
	_set_decor(Vector2i(-5, 7), _pick(DECOR_TALL, Vector2i(-5, 7)))
	_set_decor(Vector2i(-9, 5), _pick(DECOR_BUSH, Vector2i(-9, 5)))

	# SE shallow water garden — kept off the Sacred Loom porch at (7,7)
	_paint_blob(Vector2i(11, 3), 3, _pick(WATER_SHALLOW, Vector2i(11, 3)))
	_set_tile(Vector2i(11, 3), WATER_SHINE)
	_set_tile(Vector2i(12, 4), _pick(WATER_ROCK, Vector2i(12, 4)))
	_set_tile(Vector2i(10, 2), _pick(WATER_RIPPLE, Vector2i(10, 2)))
	_set_tile(Vector2i(12, 2), _pick(WATER_ROCK, Vector2i(12, 2)))
	_paint_blob(Vector2i(13, 5), 2, _pick(DIRT_MOSS, Vector2i(13, 5)))
	_set_decor(Vector2i(13, 4), _pick(DECOR_FLOWER, Vector2i(13, 4)))
	_set_decor(Vector2i(9, 4), _pick(DECOR_BUSH, Vector2i(9, 4)))

	# Outer diamond-edge pockets so the rim is not empty grass
	_paint_blob(Vector2i(0, -13), 3, _pick(DIRT, Vector2i(0, -13)))
	_paint_blob(Vector2i(0, 13), 3, _pick(DIRT_MOSS, Vector2i(0, 13)))
	_paint_blob(Vector2i(-13, 0), 3, _pick(DIRT, Vector2i(-13, 0)))
	_paint_blob(Vector2i(13, 0), 3, _pick(DIRT_MOSS, Vector2i(13, 0)))
	_paint_blob(Vector2i(-11, -11), 2, _pick(GRASS_LUSH, Vector2i(-11, -11)))
	_paint_blob(Vector2i(11, -11), 2, _pick(DIRT_MOSS, Vector2i(11, -11)))
	_paint_blob(Vector2i(-11, 11), 2, _pick(DIRT_MOSS, Vector2i(-11, 11)))
	_paint_blob(Vector2i(11, 11), 2, _pick(GRASS_LUSH, Vector2i(11, 11)))
	for rim in [
		Vector2i(-12, -2), Vector2i(12, 2), Vector2i(-2, 12), Vector2i(2, -12),
		Vector2i(-12, 3), Vector2i(12, -3), Vector2i(3, 12), Vector2i(-3, -12),
		Vector2i(-10, -10), Vector2i(10, -10), Vector2i(-10, 10), Vector2i(10, 10),
	]:
		var kind: Array = DECOR_ROCK if _hash(rim) % 3 == 0 else (
			DECOR_BUSH if _hash(rim) % 3 == 1 else DECOR_TALL)
		_set_decor(rim, _pick(kind, rim))

	# Mid-arm garden beds flanking the boardwalk
	for bed in [
		Vector2i(-3, -6), Vector2i(3, -6), Vector2i(-6, -3), Vector2i(6, -3),
		Vector2i(-3, 6), Vector2i(3, 6), Vector2i(-6, 3), Vector2i(6, 3),
		Vector2i(-4, -8), Vector2i(4, -8), Vector2i(-8, -4), Vector2i(8, -4),
		Vector2i(-4, 8), Vector2i(4, 8), Vector2i(-8, 4), Vector2i(8, 4),
	]:
		_set_tile_soft(bed, _pick(DIRT_MOSS, bed))
		var decor_set: Array = DECOR_FLOWER if _hash(bed) % 2 == 0 else DECOR_BUSH
		_set_decor(bed, _pick(decor_set, bed))


func _scatter_decor() -> void:
	# Fill remaining wedges with sparse bushes / rocks — skip paths and water.
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(origin_cell.x + x, origin_cell.y + y)
			if _decor.has(cell):
				continue
			var floor_name := str(_map.get(cell, ""))
			if _is_hard_floor(floor_name) or _is_water(floor_name):
				continue
			var n := _hash(cell)
			if n % 23 == 0:
				_set_decor(cell, _pick(DECOR_BUSH, cell))
			elif n % 29 == 0:
				_set_decor(cell, _pick(DECOR_ROCK, cell))
			elif n % 31 == 0:
				_set_decor(cell, _pick(DECOR_FLOWER, cell))
			elif n % 43 == 0:
				_set_decor(cell, _pick(DECOR_TALL, cell))
			elif n % 47 == 0:
				_set_decor(cell, _pick(DECOR_LOG, cell))


func _is_hard_floor(name: String) -> bool:
	return name in [PATH_WOOD_A, PATH_WOOD_B, PATH_STONE, PATH_BRICK, PATH_FLAG]


func _is_water(name: String) -> bool:
	return name in [
		WATER, WATER_SHINE,
		"tile_070.png", "tile_071.png", "tile_075.png", "tile_078.png",
		"tile_087.png", "tile_089.png", "tile_096.png", "tile_097.png",
		"tile_104.png", "tile_105.png", "tile_112.png",
	]

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
	# Stop just short of the door cell so the boardwalk meets the porch.
	return house + delta.normalized() * 0.55


func _set_tile(cell: Vector2i, tile: String) -> void:
	if not _in_bounds(cell):
		return
	if not _tiles.has(tile):
		return
	_map[cell] = tile


func _set_tile_soft(cell: Vector2i, tile: String) -> void:
	var cur := str(_map.get(cell, ""))
	if cur in [PATH_STONE, PATH_BRICK, PATH_WOOD_A, PATH_WOOD_B, WATER, WATER_SHINE]:
		return
	if cur in [PATH_FLAG] and tile in [PATH_WOOD_A, PATH_WOOD_B]:
		_set_tile(cell, tile)
		return
	if cur in [PATH_WOOD_A, PATH_WOOD_B, PATH_FLAG] and tile in DIRT + DIRT_MOSS + GRASS + GRASS_LUSH:
		return
	_set_tile(cell, tile)


func _set_decor(cell: Vector2i, tile: String) -> void:
	if not _in_bounds(cell):
		return
	if not _tiles.has(tile):
		return
	var floor_name := str(_map.get(cell, ""))
	if floor_name in [PATH_WOOD_A, PATH_WOOD_B, PATH_STONE, PATH_BRICK]:
		return
	_decor[cell] = tile


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
	# Pixel iso blocks: diamond sits in the upper half; hang thickness below.
	var origin := Vector2(
		center.x - size.x * 0.5,
		center.y - size.y * 0.62
	)
	draw_texture_rect(tex, Rect2(origin, size), false)
