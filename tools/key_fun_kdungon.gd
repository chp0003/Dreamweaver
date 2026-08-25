extends Node
## One-shot: knock the studio-white (and ground disc) off Fun Kdungon's sprite
## so she composites as a character, not a sticker.

const PATHS := [
	"res://assets/images/characters/fun_kdungon.png",
	"res://assets/images/story/intro_03_fun_kdungon.png",
]


func _ready() -> void:
	var src := Image.new()
	var err := src.load("res://assets/images/characters/fun_kdungon.png")
	if err != OK:
		push_error("Could not load Fun Kdungon sprite")
		get_tree().quit(1)
		return
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)

	var cleared := _clear_matte(src)
	cleared += _clear_ground_disc(src)
	_soften_fringe(src)
	src = _crop_to_alpha(src)
	_soften_fringe(src)

	var dest := ProjectSettings.globalize_path(PATHS[0])
	err = src.save_png(dest)
	if err != OK:
		push_error("Save failed: %s" % dest)
		get_tree().quit(1)
		return
	err = src.save_png(ProjectSettings.globalize_path(PATHS[1]))
	print("Fun Kdungon keyed: %dx%d  matte/dirt cleared=%d  corner_a=%.2f" % [
		src.get_width(), src.get_height(), cleared, src.get_pixel(0, 0).a])
	get_tree().quit(0 if src.get_pixel(0, 0).a < 0.05 else 1)


func _clear_matte(image: Image) -> int:
	var w := image.get_width()
	var h := image.get_height()
	var stack: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var cleared := 0
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
		if not _is_studio_white(c):
			continue
		if c.a > 0.01:
			c.a = 0.0
			image.set_pixel(p.x, p.y, c)
			cleared += 1
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	return cleared


func _clear_ground_disc(image: Image) -> int:
	var w := image.get_width()
	var h := image.get_height()
	var y0 := int(float(h) * 0.70)
	var stack: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var cleared := 0
	for x in range(w):
		for y in range(h - 1, y0, -1):
			if _is_dirt(image.get_pixel(x, y)):
				stack.append(Vector2i(x, y))
				break
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < y0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if seen[idx] == 1:
			continue
		seen[idx] = 1
		var c := image.get_pixel(p.x, p.y)
		if not _is_dirt(c):
			continue
		c.a = 0.0
		image.set_pixel(p.x, p.y, c)
		cleared += 1
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	return cleared


func _is_studio_white(c: Color) -> bool:
	if c.a < 0.05:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return luma > 0.90 and chroma < 0.08


func _is_dirt(c: Color) -> bool:
	if c.a < 0.05:
		return true
	if _is_studio_white(c):
		return true
	# Flat brown ellipse under her feet — not black/red T'nalak, not gold.
	if c.v < 0.16 or c.v > 0.62:
		return false
	if c.s < 0.16 or c.s > 0.70:
		return false
	return c.h > 0.04 and c.h < 0.14


func _soften_fringe(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if luma < 0.82 or chroma > 0.16:
				continue
			if _has_clear_neighbour(image, x, y):
				c.a = 0.0
				image.set_pixel(x, y, c)


func _has_clear_neighbour(image: Image, x: int, y: int) -> bool:
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


func _crop_to_alpha(image: Image) -> Image:
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
	min_x = maxi(0, min_x - 4)
	min_y = maxi(0, min_y - 4)
	max_x = mini(w - 1, max_x + 4)
	max_y = mini(h - 1, max_y + 4)
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
