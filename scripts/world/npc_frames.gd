class_name NpcFrames
extends RefCounted
## SpriteFrames for village NPCs.
## Idle is the original painted plant. Walk is 8 poses from those same
## pixels: left foot and right foot step as two pieces, like S'lang.

const WALK_DIR := "res://assets/images/characters/npc_stride/"
const IDLE_DIR := "res://assets/images/characters/npc_walk/"
const FRAME_W := 256
const FRAME_H := 192
const UNIQUE_DIRS := ["down", "down_right", "right", "up_right", "up"]
const WALK_CYCLES_PER_SEC := 2.0
const FOOT_PAD := 12


static var _cache: Dictionary = {}


static func load_or_build(sheet_id: String, walk_cycles := WALK_CYCLES_PER_SEC) -> SpriteFrames:
	if walk_cycles > 4.0:
		walk_cycles = WALK_CYCLES_PER_SEC
	var key := "fit-lock:%s:%.2f" % [sheet_id, walk_cycles]
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
		if walk_imgs.is_empty() or walk_imgs.size() < 4:
			walk_imgs = idle_imgs
		dir_idles[dir] = idle_imgs
		dir_walks[dir] = walk_imgs
		if dir == "down_right":
			stature = _opaque_height(idle_imgs[0] as Image)
		elif stature < 32:
			stature = maxi(stature, _opaque_height(idle_imgs[0] as Image))
	if stature < 32:
		stature = 161
	for dir in UNIQUE_DIRS:
		if not dir_idles.has(dir):
			continue
		var idle_cells := _lock_list(dir_idles[dir] as Array, stature)
		var walk_cells := _lock_list(dir_walks[dir] as Array, stature)
		var fps := float(walk_cells.size()) * maxf(walk_cycles, 0.5)
		_add_anim(frames, "walk_" + dir, walk_cells, true, fps)
		_add_anim(frames, "idle_" + dir, [idle_cells[0]], true, 1.0)
		if dir == "right":
			_add_anim(frames, "walk_side", walk_cells, true, fps)
			_add_anim(frames, "idle_side", [idle_cells[0]], true, 1.0)
	return frames


static func _slice_images(path: String) -> Array:
	var image := Palette.read_image(path)
	if image == null or image.get_width() < FRAME_W:
		return []
	var count := 1
	if image.get_width() % FRAME_W == 0:
		count = int(image.get_width() / FRAME_W)
	elif image.get_width() > image.get_height():
		count = clampi(int(round(float(image.get_width()) / float(FRAME_W))), 2, 8)
	var cell_w := int(image.get_width() / float(count))
	if cell_w < 8:
		return []
	var cells: Array = []
	for i in count:
		cells.append(image.get_region(Rect2i(i * cell_w, 0, cell_w, image.get_height())))
	return cells


static func _lock_list(imgs: Array, stature: int) -> Array:
	var out: Array = []
	for img in imgs:
		out.append(ImageTexture.create_from_image(_lock_stature(img as Image, stature)))
	return out


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


## Same painted pixels. Walk cells only get a nearest-neighbor height lock
## so a shorter stride pose cannot shrink the character on screen.
static func _lock_stature(cell: Image, stature: int) -> Image:
	var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	if cell == null or stature < 8:
		return canvas
	var bounds := _opaque_bounds(cell)
	if bounds.size.y < 8:
		return canvas
	var cropped := cell.get_region(bounds)
	var tw := cropped.get_width()
	var th := cropped.get_height()
	var max_h := FRAME_H - FOOT_PAD
	if th != stature:
		var scale := float(stature) / float(th)
		if float(cropped.get_height()) * scale > float(max_h):
			scale = float(max_h) / float(cropped.get_height())
		if float(cropped.get_width()) * scale > float(FRAME_W):
			scale = float(FRAME_W) / float(cropped.get_width())
		tw = maxi(1, int(round(float(cropped.get_width()) * scale)))
		th = maxi(1, int(round(float(cropped.get_height()) * scale)))
		cropped.resize(tw, th, Image.INTERPOLATE_NEAREST)
	var orig_cx := float(bounds.position.x) + float(bounds.size.x) * 0.5
	var ox := int(round(orig_cx - float(tw) * 0.5))
	ox = clampi(ox, 0, maxi(FRAME_W - tw, 0))
	var oy := max_h - th
	canvas.blit_rect(cropped, Rect2i(0, 0, tw, th), Vector2i(ox, oy))
	return canvas


static func _add_anim(frames: SpriteFrames, name: String, texs: Array, loop: bool, fps: float) -> void:
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for tex in texs:
		frames.add_frame(name, tex as Texture2D)
