extends SceneTree
## Build walk strips from the idle PNGs so standing and walking share the
## same pixels / sharpness. Generated walk sheets were JPEG-crushed and
## looked muddy the moment she moved.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/build_idle_walk.gd

const OUT := "res://assets/images/characters/slang_8dir/"
const FALLBACK := "res://assets/images/characters/slang_walk_cycle.png"
const FRAME_W := 256
const FRAME_H := 192
const DIRS := ["down", "down_right", "right", "up_right", "up"]


func _init() -> void:
	var ok := true
	for dir in DIRS:
		ok = _build_dir(dir) and ok
	var src := _load_rgba(OUT + "walk_down_right.png")
	if src != null:
		ok = src.save_png(ProjectSettings.globalize_path(FALLBACK)) == OK and ok
	print("BuildIdleWalk %s" % ("ok" if ok else "failed"))
	quit(0 if ok else 1)


func _build_dir(dir: String) -> bool:
	var idle := _load_rgba(OUT + "idle_%s.png" % dir)
	if idle == null:
		push_error("missing idle " + dir)
		return false
	var layout := _layout(idle)
	var frames: Array[Image] = []
	for beat in _beats():
		frames.append(_frame(idle, layout, beat))
	var strip := Image.create(FRAME_W * frames.size(), FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in range(frames.size()):
		strip.blit_rect(frames[i], Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(i * FRAME_W, 0))
		var box := _opaque_rect(frames[i])
		print("  %s f%02d  %dx%d  y=%d..%d" % [
			dir, i + 1, box.size.x, box.size.y,
			box.position.y, box.position.y + box.size.y - 1,
		])
	var dest := OUT + "walk_%s.png" % dir
	var err := strip.save_png(ProjectSettings.globalize_path(dest))
	print("%s  %dx%d  err=%d" % [dest, strip.get_width(), strip.get_height(), err])
	return err == OK


func _beats() -> Array:
	# Screen-left / screen-right lower legs. Small steps so the skirt stays closed.
	var s := 5
	return [
		{"ldx": -s, "ldy": 0, "rdx": s, "rdy": 0},
		{"ldx": -s + 2, "ldy": 2, "rdx": s - 1, "rdy": 0},
		{"ldx": 0, "ldy": 4, "rdx": 0, "rdy": 0},
		{"ldx": s - 1, "ldy": 3, "rdx": -3, "rdy": 1},
		{"ldx": s, "ldy": 0, "rdx": -s, "rdy": 0},
		{"ldx": s - 1, "ldy": 0, "rdx": -s + 2, "rdy": 2},
		{"ldx": 0, "ldy": 0, "rdx": 0, "rdy": 4},
		{"ldx": -3, "ldy": 1, "rdx": s - 1, "rdy": 3},
	]


func _layout(idle: Image) -> Dictionary:
	var box := _opaque_rect(idle)
	# Split at the lower thigh so the wrap skirt never tears.
	var hip_y := box.position.y + int(box.size.y * 0.74)
	var span := _widest_span(idle, hip_y, box)
	var pad := 6
	var x0 := maxi(0, span.x - pad)
	var x1 := mini(idle.get_width(), span.x + span.y + pad)
	var mid := x0 + int((x1 - x0) * 0.48)
	return {
		"box": box,
		"hip_y": hip_y,
		"x0": x0,
		"x1": x1,
		"mid": mid,
	}


func _frame(idle: Image, layout: Dictionary, beat: Dictionary) -> Image:
	var w := idle.get_width()
	var h := idle.get_height()
	var hip: int = layout["hip_y"]
	var x0: int = layout["x0"]
	var x1: int = layout["x1"]
	var mid: int = layout["mid"]

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(idle, Rect2i(0, 0, w, h), Vector2i.ZERO)

	var well_y := hip
	for y in range(well_y, h):
		for x in range(x0, x1):
			img.set_pixel(x, y, Color(0, 0, 0, 0))

	# Keep a few idle pixels at the split so the hem doesn't flash a seam.
	var band := 5
	img.blit_rect(
		idle,
		Rect2i(x0, hip, x1 - x0, band),
		Vector2i(x0, hip)
	)

	var left_w := maxi(1, mid - x0)
	var right_w := maxi(1, x1 - mid)
	var leg_h := h - hip
	var left := idle.get_region(Rect2i(x0, hip, left_w, leg_h))
	var right := idle.get_region(Rect2i(mid, hip, right_w, leg_h))
	img.blit_rect(left, Rect2i(0, 0, left.get_width(), left.get_height()),
		Vector2i(x0 + int(beat["ldx"]), hip - int(beat["ldy"])))
	img.blit_rect(right, Rect2i(0, 0, right.get_width(), right.get_height()),
		Vector2i(mid + int(beat["rdx"]), hip - int(beat["rdy"])))
	return img


func _widest_span(img: Image, y: int, box: Rect2i) -> Vector2i:
	var best_s := box.position.x
	var best_w := 1
	var x := box.position.x
	var x_end := box.position.x + box.size.x
	y = clampi(y, 0, img.get_height() - 1)
	while x < x_end:
		while x < x_end and img.get_pixel(x, y).a < 0.18:
			x += 1
		if x >= x_end:
			break
		var start := x
		while x < x_end and img.get_pixel(x, y).a >= 0.18:
			x += 1
		var w := x - start
		if w > best_w:
			best_w = w
			best_s = start
	return Vector2i(best_s, best_w)


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
