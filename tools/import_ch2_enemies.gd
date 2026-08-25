extends Node
## One-shot reimport for dark Chapter 2 enemies (white-matte sources).

const SRC := "C:/Users/Admin/.cursor/projects/e-dreamweaver/assets"


func _ready() -> void:
	_import("shadow_vine.png", "res://assets/images/enemies/shadow_vine.png", 40, 120, true)
	_import("shadow_minion.png", "res://assets/images/enemies/shadow_minion.png", 48, 64, false)
	get_tree().quit(0)


func _import(src_name: String, dest_path: String, tw: int, th: int, hang_from_top: bool) -> void:
	var src_path := SRC.path_join(src_name)
	var image := Image.new()
	var err := image.load(src_path)
	if err != OK:
		print("LOAD FAIL %s" % src_path)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var cleared := _clear_matte(image)
	image = _crop_to_alpha(image)
	if hang_from_top:
		image = _fit_top(image, tw, th)
	else:
		image = _fit_bottom(image, tw, th)
	DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
	err = image.save_png(ProjectSettings.globalize_path(dest_path))
	print("OK %s -> %s cleared=%d err=%d" % [src_name, dest_path, cleared, err])


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
		if not _is_matte(c):
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


func _is_matte(c: Color) -> bool:
	if c.a < 0.05:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	if chroma > 0.14:
		return false
	# White / near-white studio matte only — keep dark vine/minion pixels.
	return luma > 0.82


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


func _fit_top(src: Image, tw: int, th: int) -> Image:
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
	var ox := (tw - nw) / 2
	out.blit_rect(src, Rect2i(0, 0, nw, nh), Vector2i(ox, 0))
	return out


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
	var ox := (tw - nw) / 2
	var oy := th - nh
	out.blit_rect(src, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))
	return out
