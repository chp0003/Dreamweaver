extends Node
## Aggressive black-matte key for shadow_minion using the corner color as the plate.


const PATH := "res://assets/images/enemies/shadow_minion.png"


func _ready() -> void:
	var image := Image.new()
	var err := image.load(PATH)
	if err != OK:
		push_error("load failed")
		get_tree().quit(1)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var plate := image.get_pixel(0, 0)
	print("plate corner rgba=(%.3f,%.3f,%.3f,%.3f)" % [plate.r, plate.g, plate.b, plate.a])
	var cleared := _flood_similar(image, plate, 0.12)
	# Second pass: any remaining near-black edge pixels.
	cleared += _clear_dark_edges(image)
	_print_stats(image, "after_key")
	image = _crop_to_alpha(image)
	image = _fit_bottom(image, 48, 64)
	err = image.save_png(ProjectSettings.globalize_path(PATH))
	print("saved cleared=%d corner_a=%.3f err=%d" % [cleared, image.get_pixel(0, 0).a, err])
	get_tree().quit(0 if image.get_pixel(0, 0).a < 0.05 else 1)


func _flood_similar(image: Image, plate: Color, tol: float) -> int:
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
		if c.a < 0.05:
			stack.append(Vector2i(p.x + 1, p.y))
			stack.append(Vector2i(p.x - 1, p.y))
			stack.append(Vector2i(p.x, p.y + 1))
			stack.append(Vector2i(p.x, p.y - 1))
			continue
		if not _near_plate(c, plate, tol):
			continue
		c.a = 0.0
		image.set_pixel(p.x, p.y, c)
		cleared += 1
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	return cleared


func _near_plate(c: Color, plate: Color, tol: float) -> bool:
	# Keep anything with visible purple / chroma (eyes, aura).
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	if chroma > 0.08 and c.b > c.g + 0.02:
		return false
	var dr := absf(c.r - plate.r)
	var dg := absf(c.g - plate.g)
	var db := absf(c.b - plate.b)
	return dr <= tol and dg <= tol and db <= tol


func _clear_dark_edges(image: Image) -> int:
	var w := image.get_width()
	var h := image.get_height()
	var cleared := 0
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if luma > 0.14 or chroma > 0.07:
				continue
			if not _touches_clear(image, x, y):
				continue
			c.a = 0.0
			image.set_pixel(x, y, c)
			cleared += 1
	return cleared


func _touches_clear(image: Image, x: int, y: int) -> bool:
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


func _print_stats(image: Image, tag: String) -> void:
	var opaque := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.08:
				opaque += 1
	print("%s opaque=%d / %d" % [tag, opaque, w * h])


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
	min_x = maxi(0, min_x - 2)
	min_y = maxi(0, min_y - 2)
	max_x = mini(w - 1, max_x + 2)
	max_y = mini(h - 1, max_y + 2)
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


func _fit_bottom(src: Image, tw: int, th: int) -> Image:
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var sw := float(src.get_width())
	var sh := float(src.get_height())
	var scale := minf(float(tw) / sw, float(th) / sh)
	var nw := maxi(1, int(sw * scale))
	var nh := maxi(1, int(sh * scale))
	src.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(src, Rect2i(0, 0, nw, nh), Vector2i((tw - nw) / 2, th - nh))
	return out
