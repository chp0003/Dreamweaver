extends Node
## Slice generated 8-dir idle + walk sheets into 128x192 feet-bottom frames.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/PackSlang8Dir.tscn

const SRC := "res://assets/images/characters/slang_8dir_src/"
const OUT := "res://assets/images/characters/slang_8dir/"
const FRAME_W := 128
const FRAME_H := 192


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := true
	ok = _pack_idle("slang_idle_down.png", "idle_down.png") and ok
	ok = _pack_idle("slang_idle_right.png", "idle_right.png") and ok
	ok = _pack_idle("slang_idle_up.png", "idle_up.png") and ok
	ok = _pack_idle("slang_idle_up_right.png", "idle_up_right.png") and ok
	ok = _pack_strip("slang_walk_down_strip.png", "walk_down.png", 4) and ok
	ok = _pack_strip("slang_walk_right_strip.png", "walk_right.png", 4) and ok
	ok = _pack_strip("slang_walk_up_strip.png", "walk_up.png", 4) and ok
	ok = _pack_strip("slang_walk_down_right_strip.png", "walk_down_right.png", 4) and ok
	ok = _pack_strip("slang_walk_up_right_strip.png", "walk_up_right.png", 4) and ok
	ok = _pack_first_frame("slang_walk_down_right_strip.png", "idle_down_right.png", 4) and ok
	print("PackSlang8Dir %s" % ("ok" if ok else "failed"))
	get_tree().quit(0 if ok else 1)


func _pack_idle(src_name: String, out_name: String) -> bool:
	return _pack_idle_from(SRC + src_name, out_name)


func _pack_idle_from(path: String, out_name: String) -> bool:
	var image := _load_keyed(path)
	if image == null:
		return false
	return _save(_fit(image), OUT + out_name)


func _pack_first_frame(src_name: String, out_name: String, count: int) -> bool:
	var image := _load_keyed(SRC + src_name)
	if image == null:
		return false
	var fw := int(image.get_width() / float(count))
	if fw < 8:
		return false
	var cell := image.get_region(Rect2i(0, 0, fw, image.get_height()))
	return _save(_fit(cell), OUT + out_name)


func _pack_strip(src_name: String, out_name: String, count: int) -> bool:
	var image := _load_keyed(SRC + src_name)
	if image == null:
		return false
	var fw := int(image.get_width() / float(count))
	if fw < 8:
		push_error("strip too narrow: " + src_name)
		return false
	var strip := Image.create(FRAME_W * count, FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in range(count):
		var cell := image.get_region(Rect2i(i * fw, 0, fw, image.get_height()))
		var frame := _fit(cell)
		strip.blit_rect(frame, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(i * FRAME_W, 0))
	return _save(strip, OUT + out_name)


func _load_keyed(path: String) -> Image:
	var image := Image.new()
	var abs_path := ProjectSettings.globalize_path(path)
	if image.load(abs_path) != OK:
		push_error("load failed: " + path)
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_key_plate(image)
	return image


func _save(image: Image, path: String) -> bool:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	print("%s  %dx%d  err=%d  a0=%.2f" % [
		path, image.get_width(), image.get_height(), err, image.get_pixel(0, 0).a])
	return err == OK


func _key_plate(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var stack: Array[Vector2i] = []
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
		if c.a < 0.08 or _is_checker_matte(c):
			c.a = 0.0
			image.set_pixel(p.x, p.y, c)
			stack.append(Vector2i(p.x + 1, p.y))
			stack.append(Vector2i(p.x - 1, p.y))
			stack.append(Vector2i(p.x, p.y + 1))
			stack.append(Vector2i(p.x, p.y - 1))
	_defringe(image)


func _is_checker_matte(c: Color) -> bool:
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	# Only the gray/white checker (or studio white). Never punch black cloth.
	return chroma < 0.06 and luma > 0.62


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
			if luma > 0.82 and chroma < 0.10:
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


func _fit(src: Image) -> Image:
	var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var cropped := _crop(src)
	if cropped.get_width() < 1 or cropped.get_height() < 1:
		return canvas
	var scale := float(FRAME_H) / float(cropped.get_height())
	if int(round(cropped.get_width() * scale)) > FRAME_W:
		scale = float(FRAME_W) / float(cropped.get_width())
	var tw := maxi(1, int(round(cropped.get_width() * scale)))
	var th := maxi(1, int(round(cropped.get_height() * scale)))
	var scaled := Image.new()
	scaled.copy_from(cropped)
	scaled.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	var ox := int((FRAME_W - tw) / 2.0)
	canvas.blit_rect(scaled, Rect2i(0, 0, tw, th), Vector2i(ox, FRAME_H - th))
	return canvas


func _crop(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a < 0.18:
				continue
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
