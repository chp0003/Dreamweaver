class_name SlangFrames
extends RefCounted

## SpriteFrames builder for S'lang — 8-direction idle / walk / attack.
##
## CANVAS (every frame, every animation):
##   Frame size:  256 x 192 px (wide enough for staff swings)
##   Anchor:      feet at bottom-centre of the canvas
##   Node offset: AnimatedSprite2D.offset = (0, -46)
##   Node scale:  (56/128, 92/192)
##
## Unique sheets: down, down_right, right, up_right, up.
## West facings (left, up_left, down_left) use the east sheet + flip_h.
## Packed strips are 8 frames (2048x192). Art lives in slang_8dir/.

const BASE_PATH := "res://assets/images/characters/slang.png"
const WALK_CYCLE_PATH := "res://assets/images/characters/slang_walk_cycle.png"
const ATTACK_CYCLE_PATH := "res://assets/images/characters/slang_attack_swing.png"
const DIR8_PATH := "res://assets/images/characters/slang_8dir/"

const FRAME_W := 256
const FRAME_H := 192
## Two full stride cycles per second at the default 190 px/s move speed.
## FPS is `frame_count *` this, so 8-frame and 12-frame sheets keep the same gait.
const WALK_CYCLES_PER_SEC := 2.0
const ATTACK_FPS := 13.0

const UNIQUE_DIRS := ["down", "down_right", "right", "up_right", "up"]

static var _armed: SpriteFrames
static var _bare: SpriteFrames


static func load_or_build() -> SpriteFrames:
	if _armed != null:
		return _armed
	_armed = _build_armed()
	return _armed


static func load_bare() -> SpriteFrames:
	if _bare != null:
		return _bare
	var armed := load_or_build()
	var frames := SpriteFrames.new()
	for anim in armed.get_animation_names():
		var drop_staff := str(anim).ends_with("_down_right")
		var texs: Array = []
		for i in armed.get_frame_count(anim):
			var tex := armed.get_frame_texture(anim, i)
			texs.append(_cut_staff(tex) if drop_staff else tex)
		_add_anim(
			frames,
			anim,
			texs,
			armed.get_animation_loop(anim),
			armed.get_animation_speed(anim)
		)
	_bare = frames
	return frames


## The staff is painted into the down-right sheets. A straight cut at the staff
## column also deletes the fist, which overlaps that x range. Follow the staff
## as its own thin run and leave the hand on the arm.
static func _cut_staff(tex: Texture2D) -> Texture2D:
	var img := _texture_to_image(tex)
	if img == null:
		return tex
	var copy := Image.new()
	copy.copy_from(img)
	_erase_staff(copy)
	return ImageTexture.create_from_image(copy)


static func _erase_staff(img: Image) -> void:
	var h := img.get_height()
	var staff := Vector2i(-1, -1)
	var started := false
	for y in h:
		var runs := _row_runs(img, y)
		if runs.is_empty():
			continue
		if staff.x < 0 and not started:
			var tip: Vector2i = runs[runs.size() - 1]
			var gap := 99
			if runs.size() > 1:
				var prev: Vector2i = runs[runs.size() - 2]
				gap = tip.x - prev.y - 1
			if tip.y >= 150 and (tip.y - tip.x) <= 24 and gap >= 4:
				_clear_span(img, y, tip.x, tip.y)
				staff = tip
				started = true
			continue
		if staff.x < 0:
			break
		var best := Vector2i(-1, -1)
		var best_d := 999.0
		var mid := (float(staff.x) + float(staff.y)) * 0.5
		for run_v in runs:
			var run: Vector2i = run_v
			if (run.y - run.x) > 24:
				continue
			if run.y < staff.x - 5 or run.x > staff.y + 8:
				continue
			var d := absf((float(run.x) + float(run.y)) * 0.5 - mid)
			if d < best_d:
				best_d = d
				best = run
		if best.x < 0 or best.x < staff.x - 10:
			break
		_clear_span(img, y, best.x, best.y)
		staff = best
	for y in h:
		for run_v in _row_runs(img, y):
			var run: Vector2i = run_v
			if run.x >= 148 and (run.y - run.x) <= 26:
				_clear_span(img, y, run.x, run.y)
	for y in h:
		var runs := _row_runs(img, y)
		if runs.size() < 2:
			continue
		var tip: Vector2i = runs[runs.size() - 1]
		var prev: Vector2i = runs[runs.size() - 2]
		var width := tip.y - tip.x + 1
		var gap := tip.x - prev.y - 1
		if width <= 8 and gap >= 2 and tip.x >= 128:
			_clear_span(img, y, tip.x, tip.y)
	_drop_detached_specks(img)


static func _row_runs(img: Image, y: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var w := img.get_width()
	var start := -1
	for x in w:
		var on := img.get_pixel(x, y).a > 0.12
		if on and start < 0:
			start = x
		elif not on and start >= 0:
			runs.append(Vector2i(start, x - 1))
			start = -1
	if start >= 0:
		runs.append(Vector2i(start, w - 1))
	return runs


static func _clear_span(img: Image, y: int, x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		var c := img.get_pixel(x, y)
		if c.a <= 0.0:
			continue
		c.a = 0.0
		img.set_pixel(x, y, c)


static func _drop_detached_specks(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			var i := y * w + x
			if seen[i] != 0:
				continue
			if img.get_pixel(x, y).a <= 0.12:
				seen[i] = 1
				continue
			stack.clear()
			stack.append(Vector2i(x, y))
			seen[i] = 1
			var pts: Array[Vector2i] = []
			var min_x := x
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				pts.append(p)
				min_x = mini(min_x, p.x)
				for step in steps:
					var nx: int = p.x + step.x
					var ny: int = p.y + step.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni: int = ny * w + nx
					if seen[ni] != 0:
						continue
					if img.get_pixel(nx, ny).a <= 0.12:
						seen[ni] = 1
						continue
					seen[ni] = 1
					stack.append(Vector2i(nx, ny))
			if min_x >= 128 and pts.size() < 40:
				for p in pts:
					var c := img.get_pixel(p.x, p.y)
					c.a = 0.0
					img.set_pixel(p.x, p.y, c)


static func _build_armed() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var base := _load_texture(BASE_PATH)
	if base == null:
		push_warning("SlangFrames: missing %s" % BASE_PATH)
		return frames

	var idle_fallback := _to_frame_texture(base)
	var walk_fallback := _load_packed_strip_auto(WALK_CYCLE_PATH)
	if walk_fallback.is_empty():
		walk_fallback = _load_strip(WALK_CYCLE_PATH, 8)
	if walk_fallback.is_empty() or not _footprint_matches_idle(idle_fallback, walk_fallback[0] as Texture2D):
		walk_fallback = _walk_cycle_from_idle(base)
	var attack := _load_strip(ATTACK_CYCLE_PATH, 8)
	if attack.is_empty() or not _footprint_matches_idle(idle_fallback, attack[0] as Texture2D):
		attack = _attack_cycle_from_idle(base)

	for dir in UNIQUE_DIRS:
		var idle := _load_idle_dir(dir)
		if idle == null:
			idle = idle_fallback
		var walk := _load_packed_strip_auto(DIR8_PATH + "walk_%s.png" % dir)
		if walk.is_empty() or not _frames_differ(walk):
			walk = _load_packed_strip(DIR8_PATH + "walk_%s.png" % dir, 4)
		if walk.is_empty() or not _frames_differ(walk):
			if dir == "right" and not walk_fallback.is_empty():
				walk = walk_fallback
			else:
				walk = _walk_cycle_from_idle(idle)
		# Idle must remain the dedicated feet-planted standing artwork. Never
		# replace it with a walk frame, or S'lang freezes in a mid-step pose.
		var dir_attack := _load_packed_strip_auto(DIR8_PATH + "attack_%s.png" % dir)
		if dir_attack.is_empty() or not _frames_differ(dir_attack):
			dir_attack = attack
		_add_anim(frames, "idle_" + dir, [idle], true, 1.0)
		_add_anim(frames, "walk_" + dir, walk, true, float(walk.size()) * WALK_CYCLES_PER_SEC)
		_add_anim(frames, "attack_" + dir, dir_attack, false, ATTACK_FPS)
	return frames


static func _load_idle_dir(dir: String) -> Texture2D:
	var tex := _load_texture(DIR8_PATH + "idle_%s.png" % dir)
	if tex == null:
		return null
	# Already fitted and keyed. Do not decontaminate again — that punches holes
	# in black cloth and makes her look like a ghost.
	return tex


static func _load_packed_strip_auto(path: String) -> Array:
	var sheet := _load_texture(path)
	if sheet == null:
		return []
	var img := _texture_to_image(sheet)
	if img == null:
		return []
	var count := 1
	if img.get_width() >= FRAME_W * 2 and img.get_width() % FRAME_W == 0:
		count = int(img.get_width() / FRAME_W)
	elif img.get_width() > img.get_height():
		count = clampi(int(round(float(img.get_width()) / float(FRAME_W))), 2, 8)
	return _slice_strip(img, count)


static func _load_packed_strip(path: String, count: int) -> Array:
	var sheet := _load_texture(path)
	if sheet == null:
		return []
	var img := _texture_to_image(sheet)
	if img == null:
		return []
	return _slice_strip(img, count)


static func _slice_strip(img: Image, count: int) -> Array:
	var fw := int(img.get_width() / float(count))
	if fw < 8 or count < 1:
		return []
	var out: Array = []
	for i in range(count):
		var cell := img.get_region(Rect2i(i * fw, 0, fw, img.get_height()))
		out.append(ImageTexture.create_from_image(cell))
	return out


static func _add_anim(frames: SpriteFrames, name: String, texs: Array, loop: bool, fps: float) -> void:
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for tex in texs:
		frames.add_frame(name, tex as Texture2D)


## Accept an external strip only if it keys clean and differs across frames.
## Size is forced to FRAME_W×FRAME_H with the same feet-bottom fit as idle.
## Slice a horizontal strip into `count` frames. Keys obvious mattes.
static func _load_strip(path: String, count: int) -> Array:
	var sheet := _load_texture(path)
	if sheet == null:
		return []
	var img := _texture_to_image(sheet)
	if img == null:
		return []
	if _sample_has_checker(img):
		return []
	var fw := int(img.get_width() / float(count))
	if fw < 8:
		return []
	var out: Array = []
	for i in range(count):
		var cell := img.get_region(Rect2i(i * fw, 0, fw, img.get_height()))
		out.append(_to_frame_texture_from_image(cell))
	if not _frames_differ(out):
		return []
	return out


## Four-beat staff SWING: coil, cut, follow-through, recover. Same canvas as idle.
static func _attack_cycle_from_idle(base: Texture2D) -> Array:
	var src := _texture_to_image(base)
	if src == null:
		var one := _to_frame_texture(base)
		return [one, one, one, one]
	src = _fit_to_canvas(src)
	# Horizontal cut, not a poke: pull back, sweep across, finish low, settle.
	var beats: Array[Vector2i] = [
		Vector2i(-10, -2),
		Vector2i(4, -6),
		Vector2i(12, 2),
		Vector2i(3, 0),
	]
	var out: Array = []
	for beat in beats:
		out.append(ImageTexture.create_from_image(_shifted_frame(src, beat.x, beat.y)))
	return out


static func _shifted_frame(src: Image, dx: int, dy: int) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(dx, dy))
	return img


## Standard placeholder walk: intact body from slang.png, only the feet shift.
## Split is at ~82% height (ankles), never through the waist.
static func _walk_cycle_from_idle(base: Texture2D) -> Array:
	var src := _texture_to_image(base)
	if src == null:
		var one := _to_frame_texture(base)
		return [one, one, one, one]
	src = _fit_to_canvas(src)

	var out: Array = []
	# Classic 4-beat: plant → left step → plant → right step
	var beats := [
		{"left": 0, "right": 0},
		{"left": -4, "right": 2},
		{"left": 0, "right": 0},
		{"left": 2, "right": -4},
	]
	for beat in beats:
		out.append(ImageTexture.create_from_image(
			_foot_step_frame(src, int(beat["left"]), int(beat["right"]))
		))
	return out


static func _foot_step_frame(src: Image, left_dy: int, right_dy: int) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Full body first — keeps waist/skirt continuous.
	img.blit_rect(src, Rect2i(0, 0, w, h), Vector2i.ZERO)

	var foot_y := int(h * 0.82)
	var mid := int(w * 0.5)
	var foot_h := h - foot_y
	if foot_h < 2:
		return img

	# Re-draw left / right foot bands with vertical step offsets only.
	var left := src.get_region(Rect2i(0, foot_y, mid, foot_h))
	var right := src.get_region(Rect2i(mid, foot_y, w - mid, foot_h))
	# Clear the foot band, then stamp stepped feet.
	for y in range(foot_y, h):
		for x in range(w):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.blit_rect(left, Rect2i(0, 0, left.get_width(), left.get_height()),
		Vector2i(0, foot_y + left_dy))
	img.blit_rect(right, Rect2i(0, 0, right.get_width(), right.get_height()),
		Vector2i(mid, foot_y + right_dy))
	return img


static func _to_frame_texture(tex: Texture2D) -> Texture2D:
	var img := _texture_to_image(tex)
	if img == null:
		return tex
	return _to_frame_texture_from_image(img)


static func _to_frame_texture_from_image(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(_fit_to_canvas(img))


## Fit any art into FRAME_W×FRAME_H with feet on the bottom edge (shared pivot).
static func _fit_to_canvas(src: Image) -> Image:
	var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	if src.get_width() < 1 or src.get_height() < 1:
		return canvas

	var cropped := _crop_alpha(_decontaminate(src))
	var scale := minf(
		float(FRAME_W) / float(cropped.get_width()),
		float(FRAME_H) / float(cropped.get_height())
	)
	# Prefer filling height so idle and walk share the same on-screen stature.
	scale = float(FRAME_H) / float(cropped.get_height())
	if int(round(cropped.get_width() * scale)) > FRAME_W:
		scale = float(FRAME_W) / float(cropped.get_width())

	var tw := maxi(1, int(round(cropped.get_width() * scale)))
	var th := maxi(1, int(round(cropped.get_height() * scale)))
	var scaled := Image.new()
	scaled.copy_from(cropped)
	scaled.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	var ox := int((FRAME_W - tw) / 2.0)
	var oy := FRAME_H - th
	canvas.blit_rect(scaled, Rect2i(0, 0, tw, th), Vector2i(ox, oy))
	return canvas


static func _crop_alpha(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a < 0.22:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return image
	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


## Knock leftover studio-white (armpit holes, outline halo) without eating
## the cream stitches in the t'nalak.
static func _decontaminate(src: Image) -> Image:
	var image := Image.new()
	image.copy_from(src)
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_clear_white_islands(image)
	for _i in range(3):
		_defringe(image)
	return image


static func _is_plate_white(c: Color) -> bool:
	if c.a < 0.06:
		return true
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var chroma := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return luma > 0.86 and chroma < 0.11


static func _clear_white_islands(image: Image) -> void:
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
			# Keep tiny bead highlights; wipe armpit / outline pockets.
			if blob.size() >= 18 and blob.size() <= 6000:
				for p in blob:
					var k := image.get_pixel(p.x, p.y)
					k.a = 0.0
					image.set_pixel(p.x, p.y, k)


static func _defringe(image: Image) -> void:
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
			if luma > 0.58 and chroma < 0.24:
				kill.append(Vector2i(x, y))
			elif c.a < 0.62 and luma > 0.48:
				kill.append(Vector2i(x, y))
	for p in kill:
		var c := image.get_pixel(p.x, p.y)
		c.a = 0.0
		image.set_pixel(p.x, p.y, c)


static func _near_clear(image: Image, x: int, y: int) -> bool:
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


static func _footprint_matches_idle(idle: Texture2D, walk_frame: Texture2D) -> bool:
	var a := _opaque_bounds(_texture_to_image(idle))
	var b := _opaque_bounds(_texture_to_image(walk_frame))
	if a.size.y < 1.0 or b.size.y < 1.0:
		return false
	# Allow ~18% height drift only.
	return absf(a.size.y - b.size.y) / a.size.y <= 0.18


static func _opaque_bounds(img: Image) -> Rect2:
	if img == null:
		return Rect2()
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a < 0.1:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _frames_differ(frames: Array) -> bool:
	if frames.size() < 2:
		return false
	var first := _texture_to_image(frames[0] as Texture2D)
	if first == null:
		return false
	for i in range(1, frames.size()):
		var other := _texture_to_image(frames[i] as Texture2D)
		if other != null and other.get_data() != first.get_data():
			return true
	return false


static func _sample_has_checker(img: Image) -> bool:
	var hits := 0
	for p in [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(img.get_width() - 3, 3)]:
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
			continue
		var c := img.get_pixelv(p)
		if c.a < 0.35:
			continue
		if absf(c.r - c.g) < 0.05 and absf(c.g - c.b) < 0.05 and c.r > 0.45 and c.r < 0.95:
			hits += 1
	return hits >= 2


static func _key_matte(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a < 0.08:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var sum := c.r + c.g + c.b
			var grey := absf(c.r - c.g) < 0.08 and absf(c.g - c.b) < 0.08
			if sum > 2.7 or sum < 0.12 or (grey and c.r > 0.45):
				image.set_pixel(x, y, Color(0, 0, 0, 0))


static func _texture_to_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	var copy := Image.new()
	copy.copy_from(img)
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	return copy


static func _load_texture(path: String) -> Texture2D:
	return Palette.read_texture(path)
