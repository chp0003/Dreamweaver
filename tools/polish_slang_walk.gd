extends SceneTree
## Clean walk strips: drop specks, key leftover magenta, lock feet + torso.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/polish_slang_walk.gd

const OUT := "res://assets/images/characters/slang_8dir/"
const FALLBACK := "res://assets/images/characters/slang_walk_cycle.png"
const FRAME_W := 256
const FRAME_H := 192
const DIRS := ["down", "down_right", "right", "up_right", "up"]


func _init() -> void:
	var ok := true
	for dir in DIRS:
		ok = _polish_dir(dir) and ok
	ok = _copy_fallback() and ok
	print("PolishSlangWalk %s" % ("ok" if ok else "failed"))
	quit(0 if ok else 1)


func _polish_dir(dir: String) -> bool:
	var walk := _load_rgba(OUT + "walk_%s.png" % dir)
	var idle := _load_rgba(OUT + "idle_%s.png" % dir)
	if walk == null:
		push_error("missing walk " + dir)
		return false
	var count := maxi(1, int(walk.get_width() / float(FRAME_W)))
	var idle_box := Rect2i()
	var idle_torso := float(FRAME_W) * 0.5
	var idle_foot := FRAME_H - 13
	if idle != null:
		idle_box = _opaque_rect(idle)
		if idle_box.size.y > 8:
			idle_foot = idle_box.position.y + idle_box.size.y - 1
			idle_torso = _torso_cx(idle, idle_box)
	var frames: Array[Image] = []
	for i in range(count):
		var cell := walk.get_region(Rect2i(i * FRAME_W, 0, FRAME_W, FRAME_H))
		_key_magenta(cell)
		_drop_specks(cell)
		_drop_maroon_plate(cell)
		_defringe(cell)
		frames.append(cell)
	var strip := Image.create(FRAME_W * count, FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in range(count):
		var aligned := _lock_to_idle(frames[i], idle_foot, idle_torso)
		strip.blit_rect(aligned, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(i * FRAME_W, 0))
		var box := _opaque_rect(aligned)
		print("  %s f%02d  %dx%d  y=%d..%d  torso=%.1f" % [
			dir, i + 1, box.size.x, box.size.y,
			box.position.y, box.position.y + box.size.y - 1,
			_torso_cx(aligned, box),
		])
	var dest := OUT + "walk_%s.png" % dir
	var err := strip.save_png(ProjectSettings.globalize_path(dest))
	print("%s  %dx%d  err=%d" % [dest, strip.get_width(), strip.get_height(), err])
	return err == OK


func _lock_to_idle(src: Image, idle_foot: int, idle_torso: float) -> Image:
	var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var box := _opaque_rect(src)
	if box.size.x < 4:
		return canvas
	var foot := box.position.y + box.size.y - 1
	var torso := _torso_cx(src, box)
	var dx := int(round(idle_torso - torso))
	var dy := idle_foot - foot
	canvas.blit_rect(src, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(dx, dy))
	return canvas


func _torso_cx(img: Image, box: Rect2i) -> float:
	if box.size.x < 2:
		return FRAME_W * 0.5
	var y0 := box.position.y + int(box.size.y * 0.30)
	var y1 := box.position.y + int(box.size.y * 0.58)
	var x0 := box.position.x
	var x1 := box.position.x + int(box.size.x * 0.62)
	var total := 0.0
	var weight := 0.0
	for y in range(y0, maxi(y0 + 1, y1)):
		for x in range(x0, maxi(x0 + 1, x1)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var a := img.get_pixel(x, y).a
			if a < 0.2:
				continue
			total += float(x) * a
			weight += a
	if weight < 1.0:
		return float(box.position.x) + float(box.size.x) * 0.45
	return total / weight


func _key_magenta(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a < 0.08:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if _is_magenta(c):
				image.set_pixel(x, y, Color(0, 0, 0, 0))


func _is_magenta(c: Color) -> bool:
	if c.r > 0.50 and c.b > 0.20 and c.g < 0.40 and (c.r - c.g) > 0.20:
		return true
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return c.r > 0.62 and c.b > 0.28 and chroma > 0.28 and c.g < 0.42


## Flat wine fill left when enclosed magenta was JPEG-shifted (#3C0B15).
func _is_plate_maroon(c: Color) -> bool:
	if c.a < 0.10:
		return false
	var dist := absf(c.r - 0.235) + absf(c.g - 0.043) + absf(c.b - 0.082)
	return dist < 0.14


func _drop_maroon_plate(image: Image) -> void:
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
			if not _is_plate_maroon(image.get_pixel(x, y)):
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
				if not _is_plate_maroon(image.get_pixel(p.x, p.y)):
					continue
				seen[i2] = 1
				blob.append(p)
				stack.append(Vector2i(p.x + 1, p.y))
				stack.append(Vector2i(p.x - 1, p.y))
				stack.append(Vector2i(p.x, p.y + 1))
				stack.append(Vector2i(p.x, p.y - 1))
			# Tiny wine stitches in the t'nalak stay; the healed cape is huge.
			if blob.size() < 22:
				continue
			for p in blob:
				image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))


## Drop dust only. Keeping a single blob ate the staff when it was not touching her.
func _drop_specks(image: Image) -> void:
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
			if image.get_pixel(x, y).a < 0.16:
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
				if image.get_pixel(p.x, p.y).a < 0.16:
					continue
				seen[i2] = 1
				blob.append(p)
				stack.append(Vector2i(p.x + 1, p.y))
				stack.append(Vector2i(p.x - 1, p.y))
				stack.append(Vector2i(p.x, p.y + 1))
				stack.append(Vector2i(p.x, p.y - 1))
			if blob.size() >= 80:
				continue
			for p in blob:
				image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))


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
			if _is_magenta(c):
				kill.append(Vector2i(x, y))
				continue
			var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if luma > 0.62 and chroma < 0.16:
				kill.append(Vector2i(x, y))
			elif c.a < 0.42:
				kill.append(Vector2i(x, y))
	for p in kill:
		image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))


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


func _opaque_rect(image: Image) -> Rect2i:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a < 0.16:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _load_rgba(path: String) -> Image:
	var disk := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(disk):
		return null
	var image := Image.new()
	if image.load(disk) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _copy_fallback() -> bool:
	var src := _load_rgba(OUT + "walk_down_right.png")
	if src == null:
		return false
	var err := src.save_png(ProjectSettings.globalize_path(FALLBACK))
	print("%s  err=%d" % [FALLBACK, err])
	return err == OK
