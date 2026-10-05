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


static var _cache: Dictionary = {}


static func load_or_build(sheet_id: String, walk_cycles := WALK_CYCLES_PER_SEC) -> SpriteFrames:
	if walk_cycles > 4.0:
		walk_cycles = WALK_CYCLES_PER_SEC
	var key := "hip-leg:%s:%.2f" % [sheet_id, walk_cycles]
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
	for dir in UNIQUE_DIRS:
		var idle_cells := _slice_strip(IDLE_DIR + sheet_id + "_" + dir + ".png")
		var walk_cells := _slice_strip(WALK_DIR + sheet_id + "_" + dir + ".png")
		if idle_cells.is_empty() and walk_cells.is_empty():
			continue
		if idle_cells.is_empty():
			idle_cells = [walk_cells[0]]
		if walk_cells.is_empty() or walk_cells.size() < 4:
			walk_cells = idle_cells
		var fps := float(walk_cells.size()) * maxf(walk_cycles, 0.5)
		_add_anim(frames, "walk_" + dir, walk_cells, true, fps)
		_add_anim(frames, "idle_" + dir, [idle_cells[0]], true, 1.0)
		if dir == "right":
			_add_anim(frames, "walk_side", walk_cells, true, fps)
			_add_anim(frames, "idle_side", [idle_cells[0]], true, 1.0)
	return frames


static func _slice_strip(path: String) -> Array:
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
		var cell := image.get_region(Rect2i(i * cell_w, 0, cell_w, image.get_height()))
		cells.append(ImageTexture.create_from_image(cell))
	return cells


static func _add_anim(frames: SpriteFrames, name: String, texs: Array, loop: bool, fps: float) -> void:
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for tex in texs:
		frames.add_frame(name, tex as Texture2D)
