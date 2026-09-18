extends Node2D
## Draws an isometric floor as diamonds instead of using a TileMap.
##
## Optional `terrain_texture_path` points at an isometric tileset sheet (usually
## AI art on a black matte). We key the matte, slice out each diamond tile, and
## bake them into one continuous floor texture so rooms read as wood / earth /
## ridge instead of a flat checkerboard or gappy stamps.

@export var cols := 14
@export var rows := 14
## Cell offset of the top corner, so a room can be centred on the origin.
@export var origin_cell := Vector2i(-7, -7)
@export var base_color := Color(0.2, 0.19, 0.19)
@export var alt_color := Color(0.24, 0.23, 0.22)
@export var grout_color := Color(0.12, 0.11, 0.11, 0.85)
## Draws a woven kleng (lightning) band through the middle of the room.
@export var weave_accent := Color(0.3, 0.27, 0.24, 0.0)
@export var draw_border := true
@export var border_color := Color(0.35, 0.3, 0.24, 0.7)
## Optional tileset sheet. When set, each diamond samples a tile from it.
@export var terrain_texture_path := ""
## Scatter tiny grass / pebble marks on a fraction of tiles (hub look).
@export var scatter_detail := false

var _tiles: Array[Image] = []
var _baked: Texture2D
var _bake_origin := Vector2.ZERO


func _ready() -> void:
	z_index = -100
	_tiles = _load_and_slice_tiles(terrain_texture_path)
	if not _tiles.is_empty():
		_bake_floor()
	else:
		_bake_procedural()
	queue_redraw()


## Chapter 5 Color Burst: the hall floor goes living green.
func restore_living_palette() -> void:
	base_color = Color(0.18, 0.36, 0.20)
	alt_color = Color(0.24, 0.44, 0.24)
	grout_color = Color(0.12, 0.24, 0.12, 0.75)
	weave_accent = Color(0.78, 0.58, 0.22, 0.5)
	border_color = Color(0.42, 0.62, 0.30, 0.85)
	_tiles.clear()
	_bake_procedural()
	queue_redraw()


func _draw() -> void:
	if _baked != null:
		draw_texture(_baked, _bake_origin)
	else:
		_draw_procedural()

	if draw_border:
		_draw_room_border()


func _draw_procedural() -> void:
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2(origin_cell.x + x, origin_cell.y + y)
			var center := Iso.cell_to_world(cell)
			var color := base_color if (x + y) % 2 == 0 else alt_color
			if weave_accent.a > 0.0 and absi((x - y) % 6) <= 1:
				color = color.lerp(weave_accent, weave_accent.a)
			var noise := float(((x * 17) + (y * 31)) % 7) / 28.0 - 0.12
			color = color.lightened(noise)
			draw_colored_polygon(Iso.diamond(center), color)
			if scatter_detail and ((x * 13 + y * 7) % 5) == 0:
				_draw_tuft(center, x + y)
			draw_polyline(_closed(Iso.diamond(center)), grout_color, 1.0)


func _draw_tuft(center: Vector2, seed: int) -> void:
	var ink := Color(base_color.darkened(0.15), 0.7)
	var tip := Color(alt_color.lightened(0.2), 0.85)
	for i in range(3):
		var ox := float((seed + i * 3) % 5) - 2.0
		draw_line(
			center + Vector2(ox * 3.0, 2.0),
			center + Vector2(ox * 3.0 + float(i - 1), -6.0 - float(i)),
			tip if i == 1 else ink,
			1.2
		)


func _draw_room_border() -> void:
	var top := Iso.cell_to_world(Vector2(origin_cell.x, origin_cell.y))
	var right := Iso.cell_to_world(Vector2(origin_cell.x + cols, origin_cell.y))
	var bottom := Iso.cell_to_world(Vector2(origin_cell.x + cols, origin_cell.y + rows))
	var left := Iso.cell_to_world(Vector2(origin_cell.x, origin_cell.y + rows))
	var outline := PackedVector2Array([top, right, bottom, left, top])
	draw_polyline(outline, border_color, 2.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	return closed


## Cell bounds the player is allowed to walk in, used to build room walls.
func floor_rect() -> Rect2:
	return Rect2(Vector2(origin_cell), Vector2(cols, rows))


# --------------------------------------------------------------------------
# Bake a continuous isometric floor from sliced atlas tiles
# --------------------------------------------------------------------------

func _bake_floor() -> void:
	# World-space bounds of the diamond grid, padded for slab thickness.
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for y in range(rows):
		for x in range(cols):
			var c := Iso.cell_to_world(Vector2(origin_cell.x + x, origin_cell.y + y))
			min_x = minf(min_x, c.x - Iso.HALF.x)
			max_x = maxf(max_x, c.x + Iso.HALF.x)
			min_y = minf(min_y, c.y - Iso.HALF.y - 8.0)
			max_y = maxf(max_y, c.y + Iso.HALF.y + 18.0)

	var pad := 4.0
	min_x -= pad
	min_y -= pad
	max_x += pad
	max_y += pad
	var width := int(ceili(max_x - min_x))
	var height := int(ceili(max_y - min_y))
	if width < 8 or height < 8:
		return

	var canvas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	# Back-to-front so lower cells cover the thickness lips of upper ones.
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2(origin_cell.x + x, origin_cell.y + y)
			var center := Iso.cell_to_world(cell)
			var under := base_color if (x + y) % 2 == 0 else alt_color
			_fill_diamond(canvas, center - Vector2(min_x, min_y), under)
			var tile: Image = _tiles[_tile_index(x, y)]
			_stamp_tile_into_diamond(canvas, tile, center - Vector2(min_x, min_y))

	_bake_origin = Vector2(min_x, min_y)
	_baked = ImageTexture.create_from_image(canvas)


func _bake_procedural() -> void:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for y in range(rows):
		for x in range(cols):
			var c := Iso.cell_to_world(Vector2(origin_cell.x + x, origin_cell.y + y))
			min_x = minf(min_x, c.x - Iso.HALF.x)
			max_x = maxf(max_x, c.x + Iso.HALF.x)
			min_y = minf(min_y, c.y - Iso.HALF.y - 8.0)
			max_y = maxf(max_y, c.y + Iso.HALF.y + 18.0)
	var pad := 4.0
	min_x -= pad
	min_y -= pad
	max_x += pad
	max_y += pad
	var width := int(ceili(max_x - min_x))
	var height := int(ceili(max_y - min_y))
	if width < 8 or height < 8:
		return
	var canvas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2(origin_cell.x + x, origin_cell.y + y)
			var center := Iso.cell_to_world(cell) - Vector2(min_x, min_y)
			var color := base_color if (x + y) % 2 == 0 else alt_color
			var noise := float(((x * 17) + (y * 31)) % 7) / 28.0 - 0.12
			color = color.lightened(noise)
			_fill_diamond(canvas, center, color)
	_bake_origin = Vector2(min_x, min_y)
	_baked = ImageTexture.create_from_image(canvas)


func _tile_index(x: int, y: int) -> int:
	return int(absi(x * 17 + y * 29)) % _tiles.size()


func _fill_diamond(canvas: Image, center: Vector2, color: Color) -> void:
	var w := int(Iso.TILE.x)
	var h := int(Iso.TILE.y)
	var ox := int(round(center.x - Iso.HALF.x))
	var oy := int(round(center.y - Iso.HALF.y))
	for py in range(h):
		for px in range(w):
			if not _inside_diamond(px, py, w, h):
				continue
			var dx := ox + px
			var dy := oy + py
			if dx < 0 or dy < 0 or dx >= canvas.get_width() or dy >= canvas.get_height():
				continue
			canvas.set_pixel(dx, dy, color)


## Samples the source tile's opaque diamond into the destination cell diamond.
func _stamp_tile_into_diamond(canvas: Image, tile: Image, center: Vector2) -> void:
	var tw := tile.get_width()
	var th := tile.get_height()
	if tw < 2 or th < 2:
		return

	# Map the destination diamond AABB onto the source tile AABB.
	var dw := int(Iso.TILE.x)
	var dh := int(Iso.TILE.y)
	var ox := int(round(center.x - Iso.HALF.x))
	var oy := int(round(center.y - Iso.HALF.y))

	# Sample the interior of the source tile face (skip transparent corners /
	# thickness lips that create bright wedges on the game diamond).
	var u0 := 0.18
	var u1 := 0.82
	var v0 := 0.10
	var v1 := 0.62

	for py in range(dh):
		for px in range(dw):
			if not _inside_diamond(px, py, dw, dh):
				continue
			var u := u0 + (u1 - u0) * float(px) / float(maxi(1, dw - 1))
			var v := v0 + (v1 - v0) * float(py) / float(maxi(1, dh - 1))
			var sx := int(clampf(u * float(tw - 1), 0.0, float(tw - 1)))
			var sy := int(clampf(v * float(th - 1), 0.0, float(th - 1)))
			var sample := tile.get_pixel(sx, sy)
			if sample.a < 0.2:
				sample = _sample_nearest_opaque(tile, sx, sy)
				if sample.a < 0.2:
					continue
			# Keep floors readable under the grayscale curse veil.
			sample = sample.lightened(0.08)
			sample.a = 1.0
			var dx := ox + px
			var dy := oy + py
			if dx < 0 or dy < 0 or dx >= canvas.get_width() or dy >= canvas.get_height():
				continue
			canvas.set_pixel(dx, dy, sample)


func _sample_nearest_opaque(tile: Image, x: int, y: int) -> Color:
	var best := Color(0, 0, 0, 0)
	var best_d := 999999
	var tw := tile.get_width()
	var th := tile.get_height()
	for r in range(1, 6):
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var nx := x + ox
				var ny := y + oy
				if nx < 0 or ny < 0 or nx >= tw or ny >= th:
					continue
				var c := tile.get_pixel(nx, ny)
				if c.a < 0.2:
					continue
				var d := ox * ox + oy * oy
				if d < best_d:
					best_d = d
					best = c
		if best.a >= 0.2:
			return best
	return best


func _inside_diamond(px: int, py: int, w: int, h: int) -> bool:
	# Standard iso diamond: |nx| / half_w + |ny| / half_h <= 1
	var nx := absf(float(px) + 0.5 - float(w) * 0.5)
	var ny := absf(float(py) + 0.5 - float(h) * 0.5)
	return (nx / (float(w) * 0.5) + ny / (float(h) * 0.5)) <= 1.02


# --------------------------------------------------------------------------
# Tileset loading / slicing
# --------------------------------------------------------------------------

func _load_and_slice_tiles(path: String) -> Array[Image]:
	var empty: Array[Image] = []
	if path.is_empty():
		return empty

	var image := Image.new()
	var loaded := false
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var from_tex := tex.get_image()
			if from_tex != null:
				image.copy_from(from_tex)
				loaded = true
	if not loaded and FileAccess.file_exists(path):
		if image.load(path) == OK:
			loaded = true
	if not loaded:
		push_warning("IsoFloor: could not load terrain '%s'" % path)
		return empty

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_key_matte(image)

	var tiles := _extract_tile_images(image)
	if tiles.is_empty():
		push_warning("IsoFloor: no diamond tiles found in '%s'" % path)
	return tiles


func _key_matte(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a < 0.05 or (c.r + c.g + c.b) < 0.14:
				image.set_pixel(x, y, Color(0, 0, 0, 0))


func _extract_tile_images(image: Image) -> Array[Image]:
	var w := image.get_width()
	var h := image.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)

	var boxes: Array[Rect2i] = []
	for y in range(h):
		for x in range(w):
			if visited[y * w + x] == 1:
				continue
			if image.get_pixel(x, y).a < 0.08:
				visited[y * w + x] = 1
				continue
			var box := _flood_bounds(image, visited, x, y)
			if box.size.x >= 40 and box.size.y >= 24 and box.size.x <= 220 and box.size.y <= 200:
				boxes.append(box)

	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		if a.position.y == b.position.y:
			return a.position.x < b.position.x
		return a.position.y < b.position.y
	)

	var tiles: Array[Image] = []
	var median_h := 64
	if not boxes.is_empty():
		var heights: Array[int] = []
		for b in boxes:
			heights.append(b.size.y)
		heights.sort()
		median_h = heights[heights.size() / 2]

	for box in boxes:
		if box.size.y > int(median_h * 1.85):
			continue
		var crop := image.get_region(box)
		if _opaque_ratio(crop) < 0.12:
			continue
		if _average_luma(crop) < 0.14:
			continue
		tiles.append(crop)
		if tiles.size() >= 48:
			break
	return tiles


func _flood_bounds(image: Image, visited: PackedByteArray, start_x: int, start_y: int) -> Rect2i:
	var w := image.get_width()
	var h := image.get_height()
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var min_x := start_x
	var max_x := start_x
	var min_y := start_y
	var max_y := start_y
	var count := 0
	const MAX_PIXELS := 28000

	while not stack.is_empty() and count < MAX_PIXELS:
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		if image.get_pixel(p.x, p.y).a < 0.08:
			continue
		count += 1
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _opaque_ratio(image: Image) -> float:
	var total := image.get_width() * image.get_height()
	if total <= 0:
		return 0.0
	var opaque := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a >= 0.08:
				opaque += 1
	return float(opaque) / float(total)


func _average_luma(image: Image) -> float:
	var sum := 0.0
	var count := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			if c.a < 0.08:
				continue
			sum += c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			count += 1
	return sum / float(maxi(1, count))
