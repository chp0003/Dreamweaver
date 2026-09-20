extends Node
## Pack generated S'lang sheets into 256x192 feet-bottom frames.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/PackSlang8Dir.tscn

const SRC := "res://assets/images/characters/slang_8dir_src/"
const OUT := "res://assets/images/characters/slang_8dir/"
const FALLBACK := "res://assets/images/characters/"
## Wide enough for planted legs, the full staff, and attack motion arcs.
## The old 128px cells visibly cut artwork at both sides.
const FRAME_W := 256
const FRAME_H := 192
const FRAME_PAD := 12
const UNIQUE_DIRS := ["down", "down_right", "right", "up_right", "up"]
const PLATE_DIST := 0.28

var _plate := Color(0.85, 0.08, 0.45)
var _plates: Array[Color] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := true
	for dir in UNIQUE_DIRS:
		# Use the restrained low-step cycles. The generated "stride" variants
		# raise a knee to waist height and read as repeated kicks.
		var walk_src := "slang_walk_%s_8f.png" % dir
		ok = _pack_sheet(walk_src, "walk_%s.png" % dir, "", 8) and ok
		ok = _pack_sheet(
			"slang_attack_%s_8f.png" % dir,
			"attack_%s.png" % dir,
			"",
			8
		) and ok
		ok = _pack_sheet(
			"slang_idle_%s_8f.png" % dir,
			"idle_%s_loop.png" % dir,
			"idle_%s.png" % dir,
			8
		) and ok
	ok = _heal_folder(OUT) and ok
	ok = _copy_out("walk_right.png", FALLBACK + "slang_walk_cycle.png") and ok
	ok = _copy_out("attack_right.png", FALLBACK + "slang_attack_swing.png") and ok
	print("PackSlang8Dir %s" % ("ok" if ok else "failed"))
	get_tree().quit(0 if ok else 1)


## Proven 8-frame side walk (feet actually swap). Overwrites walk_right.
func _pack_ready_walk_right() -> bool:
	var strip := Image.create(FRAME_W * 8, FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in range(8):
		var path := "res://assets/images/characters/slang_walk/slang_walk_%02d.png" % (i + 1)
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) != OK:
			push_error("missing " + path)
			return false
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		var fitted := image
		if image.get_width() != FRAME_W or image.get_height() != FRAME_H:
			fitted = _fit_rect(image, _opaque_rect(image), float(FRAME_H) / float(maxi(1, image.get_height())))
		_heal_white(fitted)
		strip.blit_rect(fitted, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(i * FRAME_W, 0))
	return _save(strip, OUT + "walk_right.png")


func _pack_sheet(src_name: String, out_strip: String, out_idle: String, want: int) -> bool:
	var image := _load_keyed(SRC + src_name)
	if image == null:
		return false
	var grid := _best_grid(image)
	var cells := _even_grid(image, grid.x, grid.y)
	print("%s  grid=%dx%d cells=%d" % [src_name, grid.x, grid.y, cells.size()])
	if cells.size() < 2:
		cells = _even_grid(image, 4, 2)
	if cells.size() > want:
		cells = cells.slice(0, want)
	if cells.is_empty():
		push_error("no cells: " + src_name)
		return false

	var shared_h := 1
	for cell in cells:
		shared_h = maxi(shared_h, cell.size.y)
	# Include the extraction bleed and leave real transparent head/foot room.
	# Scaling content to the full 192px height made staffs touch the top edge.
	var scale := float(FRAME_H - FRAME_PAD * 2) / float(shared_h + 16)
	var strip := Image.create(FRAME_W * cells.size(), FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in range(cells.size()):
		var fitted := _fit_rect(image, cells[i], scale)
		strip.blit_rect(fitted, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(i * FRAME_W, 0))
		if i == 0 and not out_idle.is_empty():
			if not _save(fitted, OUT + out_idle):
				return false
	if out_strip.is_empty():
		return true
	return _save(strip, OUT + out_strip)


func _fit_rect(src: Image, rect: Rect2i, scale: float) -> Image:
	var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	if rect.size.x < 1 or rect.size.y < 1:
		return canvas
	var pad := 8
	var x := maxi(0, rect.position.x - pad)
	var y := maxi(0, rect.position.y - pad)
	var w := mini(src.get_width() - x, rect.size.x + pad * 2)
	var h := mini(src.get_height() - y, rect.size.y + pad * 2)
	var crop := src.get_region(Rect2i(x, y, w, h))
	var tw := maxi(1, int(round(float(crop.get_width()) * scale)))
	var th := maxi(1, int(round(float(crop.get_height()) * scale)))
	var scaled := Image.new()
	scaled.copy_from(crop)
	scaled.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	for seed in _plates:
		_zero_plate(scaled, seed)
	if tw > FRAME_W:
		var left := int((tw - FRAME_W) / 2.0)
		scaled = scaled.get_region(Rect2i(left, 0, FRAME_W, mini(th, FRAME_H)))
		tw = FRAME_W
		th = mini(th, FRAME_H)
	if th > FRAME_H:
		scaled = scaled.get_region(Rect2i(0, th - FRAME_H, tw, FRAME_H))
		th = FRAME_H
	var ox := int((FRAME_W - tw) / 2.0)
	# Keep a transparent safety border below feet/effects as well as above.
	var oy := maxi(0, FRAME_H - FRAME_PAD - th)
	canvas.blit_rect(scaled, Rect2i(0, 0, tw, th), Vector2i(ox, oy))
	for seed in _plates:
		_zero_plate(canvas, seed)
	return canvas


func _best_grid(image: Image) -> Vector2i:
	var best := Vector2i(4, 2)
	var best_score := -1000.0
	for rows in [2, 3]:
		var cols := 4
		var cw := int(image.get_width() / float(cols))
		var ch := int(image.get_height() / float(rows))
		if cw < 16 or ch < 16:
			continue
		var score := 0.0
		for row in range(rows):
			for col in range(cols):
				var cell := image.get_region(Rect2i(col * cw, row * ch, cw, ch))
				var bands := _content_bands(cell)
				if bands == 1:
					score += 3.0
				elif bands == 0:
					score -= 1.0
				else:
					score -= 4.0
		if score > best_score:
			best_score = score
			best = Vector2i(cols, rows)
	return best


func _content_bands(cell: Image) -> int:
	var h := cell.get_height()
	var w := cell.get_width()
	var hit := PackedByteArray()
	hit.resize(h)
	hit.fill(0)
	for y in range(h):
		for x in range(w):
			if cell.get_pixel(x, y).a >= 0.18:
				hit[y] = 1
				break
	return _runs(hit, 8, int(h * 0.08)).size()


func _runs(hit: PackedByteArray, merge_gap: int, min_size: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var i := 0
	var n := hit.size()
	while i < n:
		while i < n and hit[i] == 0:
			i += 1
		if i >= n:
			break
		var start := i
		while i < n and hit[i] == 1:
			i += 1
		while i < n:
			var gap_start := i
			while i < n and hit[i] == 0:
				i += 1
			var gap := i - gap_start
			if i < n and gap <= merge_gap:
				while i < n and hit[i] == 1:
					i += 1
			else:
				i = gap_start
				break
		var length := i - start
		if length >= min_size:
			runs.append(Vector2i(start, length))
	return runs


func _even_grid(image: Image, cols: int, rows: int) -> Array[Rect2i]:
	var cw := int(image.get_width() / float(cols))
	var ch := int(image.get_height() / float(rows))
	var inset_x := maxi(4, int(cw * 0.04))
	var inset_y := maxi(4, int(ch * 0.05))
	var cells: Array[Rect2i] = []
	for row in range(rows):
		for col in range(cols):
			var x := col * cw + inset_x
			var y := row * ch + inset_y
			var w := cw - inset_x * 2
			var h := ch - inset_y * 2
			if w < 8 or h < 8:
				continue
			var cell := image.get_region(Rect2i(x, y, w, h))
			var box := _opaque_rect(cell)
			if box.size.x < 8:
				continue
			cells.append(Rect2i(x + box.position.x, y + box.position.y, box.size.x, box.size.y))
	return cells


func _copy_out(src_name: String, dest_path: String) -> bool:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(OUT + src_name)) != OK:
		push_error("copy load failed: " + src_name)
		return false
	return _save(image, dest_path)


func _load_keyed(path: String) -> Image:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		push_error("load failed: " + path)
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var plates := _collect_plates(image)
	if plates.is_empty():
		plates.append(_sample_plate(image))
	_plate = plates[0]
	_plates = plates
	for plate in plates:
		_zero_plate(image, plate)
	return image


func _collect_plates(image: Image) -> Array[Color]:
	var w := image.get_width()
	var h := image.get_height()
	var pts: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(w - 3, 2),
		Vector2i(2, h - 3),
		Vector2i(w - 3, h - 3),
		Vector2i(int(w * 0.5), 2),
		Vector2i(int(w * 0.5), h - 3),
		Vector2i(2, int(h * 0.33)),
		Vector2i(2, int(h * 0.66)),
		Vector2i(w - 3, int(h * 0.33)),
		Vector2i(w - 3, int(h * 0.66)),
	]
	var plates: Array[Color] = []
	for p in pts:
		var c := image.get_pixel(clampi(p.x, 0, w - 1), clampi(p.y, 0, h - 1))
		if c.a < 0.5:
			continue
		var unique := true
		for other in plates:
			var dist := absf(c.r - other.r) + absf(c.g - other.g) + absf(c.b - other.b)
			if dist < 0.12:
				unique = false
				break
		if unique:
			plates.append(c)
	return plates


func _sample_plate(image: Image) -> Color:
	var w := image.get_width()
	var h := image.get_height()
	var samples: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(w - 3, 2),
		Vector2i(2, h - 3),
		Vector2i(w - 3, h - 3),
		Vector2i(int(w * 0.5), 2),
	]
	for p in samples:
		var c := image.get_pixel(p.x, p.y)
		if c.a > 0.5:
			return c
	return Color(0.85, 0.08, 0.45)


func _zero_plate(image: Image, plate: Color) -> void:
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
		if not _is_plate(image.get_pixel(p.x, p.y), plate):
			continue
		image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	# Second pass: leftover jpeg dust matching the plate, even if enclosed.
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a < 0.08:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if _is_plate(c, plate):
				image.set_pixel(x, y, Color(0, 0, 0, 0))


func _is_plate(c: Color, plate: Color) -> bool:
	if c.a < 0.08:
		return true
	var dist := absf(c.r - plate.r) + absf(c.g - plate.g) + absf(c.b - plate.b)
	if dist < PLATE_DIST:
		return true
	var plate_light := plate.r > 0.72 and plate.g > 0.72 and plate.b > 0.72
	var c_light := c.r > 0.72 and c.g > 0.72 and c.b > 0.72
	return plate_light and c_light


func _save(image: Image, path: String) -> bool:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	print("%s  %dx%d  err=%d  a0=%.2f" % [
		path, image.get_width(), image.get_height(), err, image.get_pixel(0, 0).a])
	return err == OK


func _opaque_rect(image: Image) -> Rect2i:
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
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _heal_folder(dir_path: String) -> bool:
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	var listing := DirAccess.get_files_at(abs_dir)
	var ok := true
	for name in listing:
		if not name.ends_with(".png"):
			continue
		ok = _heal_path(dir_path.path_join(name)) and ok
	return ok


func _heal_path(path: String) -> bool:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		push_error("heal load failed: " + path)
		return false
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_heal_white(image)
	return _save(image, path)


func _heal_white(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var outside := PackedByteArray()
	outside.resize(w * h)
	outside.fill(0)
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
		if outside[idx] == 1:
			continue
		var c := image.get_pixel(p.x, p.y)
		if c.a >= 0.18 and not _is_studio_white(c):
			continue
		outside[idx] = 1
		if _is_studio_white(c) or c.a < 0.18:
			image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for y in range(h):
		for x in range(w):
			var idx := y * w + x
			if seen[idx] == 1 or outside[idx] == 1:
				continue
			var c := image.get_pixel(x, y)
			if not _is_studio_white(c):
				continue
			var blob: Array[Vector2i] = []
			var flood: Array[Vector2i] = [Vector2i(x, y)]
			while not flood.is_empty():
				var p: Vector2i = flood.pop_back()
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
					continue
				var i2 := p.y * w + p.x
				if seen[i2] == 1:
					continue
				var pc := image.get_pixel(p.x, p.y)
				if not _is_studio_white(pc):
					continue
				seen[i2] = 1
				blob.append(p)
				flood.append(Vector2i(p.x + 1, p.y))
				flood.append(Vector2i(p.x - 1, p.y))
				flood.append(Vector2i(p.x, p.y + 1))
				flood.append(Vector2i(p.x, p.y - 1))
			if blob.size() < 8:
				continue
			var fill := _blob_fill_color(image, blob)
			for p in blob:
				image.set_pixel(p.x, p.y, fill)


func _blob_fill_color(image: Image, blob: Array[Vector2i]) -> Color:
	var w := image.get_width()
	var h := image.get_height()
	var mark := {}
	for p in blob:
		mark[p] = true
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for p in blob:
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var q := Vector2i(p.x + ox, p.y + oy)
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
					continue
				if mark.has(q):
					continue
				var c := image.get_pixel(q.x, q.y)
				if c.a < 0.35 or _is_studio_white(c):
					continue
				r += c.r
				g += c.g
				b += c.b
				n += 1
	if n < 1:
		return Color(0.12, 0.09, 0.08, 1.0)
	return Color(r / float(n), g / float(n), b / float(n), 1.0)


func _is_studio_white(c: Color) -> bool:
	if c.a < 0.08:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return luma > 0.88 and chroma < 0.10
