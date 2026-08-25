extends Node
## Keys S'lang idle + walk/attack strips (studio white or black plate).

const IDLE := "res://assets/images/characters/slang.png"
const WALK := "res://assets/images/characters/slang_walk_cycle.png"
const ATTACK := "res://assets/images/characters/slang_attack_swing.png"


func _ready() -> void:
	var ok := _key_idle(IDLE) and _key_strip(WALK) and _key_strip(ATTACK)
	get_tree().quit(0 if ok else 1)


func _key_idle(path: String) -> bool:
	var image := _load(path)
	if image == null:
		return false
	_flood_plate(image)
	_clear_white_islands(image)
	for _i in range(4):
		_defringe(image)
	image = _crop(image)
	for _i in range(3):
		_defringe(image)
	return _save(image, path)


func _key_strip(path: String) -> bool:
	var image := _load(path)
	if image == null:
		return false
	_flood_plate(image)
	_defringe(image)
	return _save(image, path)


func _load(path: String) -> Image:
	var image := Image.new()
	if image.load(path) != OK:
		push_error("load failed: " + path)
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, path: String) -> bool:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	print("%s saved err=%d %dx%d a=%.2f" % [
		path, err, image.get_width(), image.get_height(), image.get_pixel(0, 0).a])
	return err == OK


func _flood_plate(image: Image) -> void:
	var plate := image.get_pixel(0, 0)
	var w := image.get_width()
	var h := image.get_height()
	var stack: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if seen[idx] == 1:
			continue
		seen[idx] = 1
		var c := image.get_pixel(p.x, p.y)
		if c.a < 0.06:
			stack.append_array([
				Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y),
				Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1),
			])
			continue
		if not _same_plate(c, plate):
			continue
		c.a = 0.0
		image.set_pixel(p.x, p.y, c)
		stack.append_array([
			Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y),
			Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1),
		])


func _same_plate(c: Color, plate: Color) -> bool:
	if c.a < 0.06:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	# Studio white.
	if luma > 0.88 and chroma < 0.10:
		return true
	# Flat black / near-black backdrop.
	if luma < 0.10 and chroma < 0.08:
		return true
	var dr := absf(c.r - plate.r)
	var dg := absf(c.g - plate.g)
	var db := absf(c.b - plate.b)
	return dr < 0.12 and dg < 0.12 and db < 0.12


func _crop(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return image
	min_x = maxi(0, min_x - 6)
	min_y = maxi(0, min_y - 6)
	max_x = mini(w - 1, max_x + 6)
	max_y = mini(h - 1, max_y + 6)
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


func _defringe(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var kill: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a < 0.08:
				continue
			if not _near_clear(image, x, y):
				continue
			var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			# Pale halo from a white studio plate. Keep dyed cloth and gold.
			if luma > 0.58 and chroma < 0.24:
				kill.append(Vector2i(x, y))
			elif c.a < 0.62 and luma > 0.48:
				kill.append(Vector2i(x, y))
	for p in kill:
		var c := image.get_pixel(p.x, p.y)
		c.a = 0.0
		image.set_pixel(p.x, p.y, c)


func _near_clear(image: Image, x: int, y: int) -> bool:
	var w := image.get_width()
	var h := image.get_height()
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var nx := x + ox
			var ny := y + oy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				return true
			if image.get_pixel(nx, ny).a < 0.08:
				return true
	return false


func _is_plate_white(c: Color) -> bool:
	if c.a < 0.06:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return luma > 0.86 and chroma < 0.11


func _clear_white_islands(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for y in range(h):
		for x in range(w):
			var idx := y * w + x
			if seen[idx] == 1:
				continue
			var c := image.get_pixel(x, y)
			if c.a < 0.06 or not _is_plate_white(c):
				seen[idx] = 1
				continue
			var blob: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
					continue
				var i2 := p.y * w + p.x
				if seen[i2] == 1:
					continue
				var pc := image.get_pixel(p.x, p.y)
				if pc.a < 0.06 or not _is_plate_white(pc):
					continue
				seen[i2] = 1
				blob.append(p)
				stack.append(Vector2i(p.x + 1, p.y))
				stack.append(Vector2i(p.x - 1, p.y))
				stack.append(Vector2i(p.x, p.y + 1))
				stack.append(Vector2i(p.x, p.y - 1))
			if blob.size() >= 18 and blob.size() <= 6000:
				for p in blob:
					var k := image.get_pixel(p.x, p.y)
					k.a = 0.0
					image.set_pixel(p.x, p.y, k)
