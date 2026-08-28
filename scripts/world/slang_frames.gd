class_name SlangFrames
extends RefCounted
## SpriteFrames builder for S'lang — standard 2D idle / walk setup.
##
## CANVAS (every frame, every animation):
##   Frame size:  128 x 192 px
##   Anchor:      feet at bottom-centre of the canvas
##   Node offset: AnimatedSprite2D.offset = (0, -46)  // feet on CharacterBody2D origin
##   Node scale:  (56/128, 92/192)  // one fixed on-screen size for all anims
##
## Animations:
##   idle_down, idle_up, idle_left, idle_right
##   walk_down, walk_up, walk_left, walk_right
##
## Art: all frames are derived from `slang.png` so idle↔walk never change height.
## Optional replacement strips (must also be 128×192 per frame, feet on the bottom edge):
##   res://assets/images/characters/slang_walk_cycle.png     (8 frames)
##   res://assets/images/characters/slang_attack_swing.png   (8 frames, staff swing)
## Left uses the right-facing frames + flip_h.

const BASE_PATH := "res://assets/images/characters/slang.png"
const WALK_CYCLE_PATH := "res://assets/images/characters/slang_walk_cycle.png"
const ATTACK_CYCLE_PATH := "res://assets/images/characters/slang_attack_swing.png"

const FRAME_W := 128
const FRAME_H := 192
const WALK_FPS := 12.0
const ATTACK_FPS := 14.0


static func load_or_build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var base := _load_texture(BASE_PATH)
	if base == null:
		push_warning("SlangFrames: missing %s" % BASE_PATH)
		return frames

	var idle := _to_frame_texture(base)
	var walk := _load_strip(WALK_CYCLE_PATH, 8)
	if walk.is_empty() or not _footprint_matches_idle(idle, walk[0] as Texture2D):
		walk = _walk_cycle_from_idle(base)
	var attack := _load_strip(ATTACK_CYCLE_PATH, 8)
	if attack.is_empty() or not _footprint_matches_idle(idle, attack[0] as Texture2D):
		attack = _attack_cycle_from_idle(base)

	for dir in ["down", "up", "left", "right"]:
		_add_anim(frames, "idle_" + dir, [idle], true, 1.0)
		_add_anim(frames, "walk_" + dir, walk, true, WALK_FPS)
		_add_anim(frames, "attack_" + dir, attack, false, ATTACK_FPS)
	return frames


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
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null
