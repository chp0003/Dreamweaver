class_name NpcFrames
extends RefCounted
## SpriteFrames for village NPCs.
## Idle is the original painted plant. Walk is 8 poses from those same
## pixels: left foot and right foot step as two pieces, like S'lang.
##
## Every cell (idle and walk) must be 256 x 192 with the character's feet
## near the bottom. Strips are 256 px per frame (8 frames = 2048 x 192).
##
## v2 changes:
##  - ONE crop and ONE scale per direction, shared by idle and every walk frame.
##    (v1 rescaled each frame to the same height, so frames pulsed and the
##    nearest-neighbour resize shimmered.)
##  - Mipmapped textures so the 0.479 on-screen downscale stays smooth.
##  - A loud warning when a walk strip is missing. Before, a missing strip
##    silently became ONE still frame, which is exactly the "NPC slides" look.

const WALK_DIR := "res://assets/images/characters/npc_stride/"
const IDLE_DIR := "res://assets/images/characters/npc_walk/"
const FRAME_W := 256
const FRAME_H := 192
const UNIQUE_DIRS := ["down", "down_right", "right", "up_right", "up"]
const WALK_CYCLES_PER_SEC := 2.0
const FOOT_PAD := 12
const MIN_WALK_FRAMES := 4
## Painted art: LANCZOS. Pixel art: Image.INTERPOLATE_NEAREST.
const RESIZE_MODE := Image.INTERPOLATE_LANCZOS
## Stopgap used only when a direction has no real walk strip: the idle pose
## bobs twice per cycle. It still glides, but it reads as walking, not sliding.
const FALLBACK_BOB_PX := 3.0
const FALLBACK_FRAMES := 8


static var _cache: Dictionary = {}


static func load_or_build(sheet_id: String, walk_cycles := WALK_CYCLES_PER_SEC) -> SpriteFrames:
	if walk_cycles > 4.0:
		walk_cycles = WALK_CYCLES_PER_SEC
	var key := "fit-v2:%s:%.2f" % [sheet_id, walk_cycles]
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	var frames := _build(sheet_id, walk_cycles)
	if not frames.get_animation_names().is_empty():
		_cache[key] = frames
	return frames


static func _build(sheet_id: String, walk_cycles: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if sheet_id.is_empty():
		return frames
	var dir_idles: Dictionary = {}
	var dir_walks: Dictionary = {}
	var stature := 0
	for dir in UNIQUE_DIRS:
		var idle_imgs := _slice_images(IDLE_DIR + sheet_id + "_" + dir + ".png")
		var walk_imgs := _slice_images(WALK_DIR + sheet_id + "_" + dir + ".png")
		if idle_imgs.is_empty() and walk_imgs.is_empty():
			continue
		if idle_imgs.is_empty():
			idle_imgs = [walk_imgs[0]]
		if walk_imgs.size() < MIN_WALK_FRAMES or not _images_differ(walk_imgs):
			push_warning("NpcFrames: %s_%s has no usable walk strip (%d frames). Using bob fallback; fix the PNG in %s" \
					% [sheet_id, dir, walk_imgs.size(), WALK_DIR])
			walk_imgs = _bob_walk(idle_imgs[0] as Image)
		dir_idles[dir] = idle_imgs
		dir_walks[dir] = walk_imgs
		var h := _opaque_height(idle_imgs[0] as Image)
		if dir == "down_right":
			stature = h
		elif stature < 32:
			stature = maxi(stature, h)
	if stature < 32:
		stature = 161
	for dir in UNIQUE_DIRS:
		if not dir_idles.has(dir):
			continue
		var locked := _lock_direction(dir_idles[dir] as Array, dir_walks[dir] as Array, stature)
		var idle_cell: Texture2D = locked["idle"]
		var walk_cells: Array = locked["walk"]
		if idle_cell == null or walk_cells.is_empty():
			continue
		var fps := float(walk_cells.size()) * maxf(walk_cycles, 0.5)
		_add_anim(frames, "walk_" + dir, walk_cells, true, fps)
		_add_anim(frames, "idle_" + dir, [idle_cell], true, 1.0)
		if dir == "right":
			_add_anim(frames, "walk_side", walk_cells, true, fps)
			_add_anim(frames, "idle_side", [idle_cell], true, 1.0)
	return frames


static func _slice_images(path: String) -> Array:
	var src := Palette.read_image(path)
	if src == null or src.get_width() < FRAME_W:
		return []
	# Copy so we never modify a cached image, and force one pixel format.
	var image := Image.new()
	image.copy_from(src)
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var count := 1
	if image.get_width() % FRAME_W == 0:
		count = int(image.get_width() / FRAME_W)
	elif image.get_width() > image.get_height():
		count = clampi(int(round(float(image.get_width()) / float(FRAME_W))), 2, 8)
		push_warning("NpcFrames: %s width %d is not a multiple of %d; guessed %d frames" \
				% [path, image.get_width(), FRAME_W, count])
	var cell_w := int(image.get_width() / float(count))
	if cell_w < 8:
		return []
	var cells: Array = []
	for i in count:
		cells.append(image.get_region(Rect2i(i * cell_w, 0, cell_w, image.get_height())))
	return cells


static func _images_differ(imgs: Array) -> bool:
	if imgs.size() < 2:
		return false
	var first := (imgs[0] as Image).get_data()
	for i in range(1, imgs.size()):
		if (imgs[i] as Image).get_data() != first:
			return true
	return false


## Stopgap walk: the idle pose lifted 0..FALLBACK_BOB_PX px, two bobs per cycle.
static func _bob_walk(idle: Image) -> Array:
	var out: Array = []
	var w := idle.get_width()
	var h := idle.get_height()
	for i in FALLBACK_FRAMES:
		var lift := int(round(absf(sin(TAU * float(i) / float(FALLBACK_FRAMES))) * FALLBACK_BOB_PX))
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.blit_rect(idle, Rect2i(0, 0, w, h), Vector2i(0, -lift))
		out.append(img)
	return out


## One crop rectangle and one scale for the idle pose AND every walk frame of
## this direction. Relative positions inside the sheet are untouched, so the
## painted stepping and body bob survive and nothing pulses or wobbles.
static func _lock_direction(idle_imgs: Array, walk_imgs: Array, stature: int) -> Dictionary:
	var all: Array = [idle_imgs[0]]
	all.append_array(walk_imgs)
	var union := Rect2i()
	var have := false
	for img in all:
		var b := _opaque_bounds(img as Image)
		if b.size.y < 1:
			continue
		union = b if not have else union.merge(b)
		have = true
	if not have:
		return {"idle": null, "walk": []}

	var ref_h := _opaque_height(idle_imgs[0] as Image)
	var s := 1.0
	if ref_h >= 8:
		s = float(stature) / float(ref_h)
	var max_h := FRAME_H - FOOT_PAD
	if float(union.size.y) * s > float(max_h):
		s = float(max_h) / float(union.size.y)
	if float(union.size.x) * s > float(FRAME_W):
		s = float(FRAME_W) / float(union.size.x)
	var tw := maxi(1, int(round(float(union.size.x) * s)))
	var th := maxi(1, int(round(float(union.size.y) * s)))
	var orig_cx := float(union.position.x) + float(union.size.x) * 0.5
	var ox := clampi(int(round(orig_cx - float(tw) * 0.5)), 0, maxi(FRAME_W - tw, 0))
	var oy := max_h - th

	var idle_tex := _place(idle_imgs[0] as Image, union, tw, th, ox, oy)
	var walk_tex: Array = []
	for img in walk_imgs:
		walk_tex.append(_place(img as Image, union, tw, th, ox, oy))
	return {"idle": idle_tex, "walk": walk_tex}


static func _place(cell: Image, crop: Rect2i, tw: int, th: int, ox: int, oy: int) -> ImageTexture:
	var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var piece := cell.get_region(crop)
	if piece.get_width() != tw or piece.get_height() != th:
		piece.resize(tw, th, RESIZE_MODE)
	canvas.blit_rect(piece, Rect2i(0, 0, tw, th), Vector2i(ox, oy))
	canvas.generate_mipmaps()
	return ImageTexture.create_from_image(canvas)


static func _opaque_height(img: Image) -> int:
	var bounds := _opaque_bounds(img)
	return int(bounds.size.y)


static func _opaque_bounds(img: Image) -> Rect2i:
	if img == null:
		return Rect2i()
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
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _add_anim(frames: SpriteFrames, name: String, texs: Array, loop: bool, fps: float) -> void:
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for tex in texs:
		frames.add_frame(name, tex as Texture2D)
