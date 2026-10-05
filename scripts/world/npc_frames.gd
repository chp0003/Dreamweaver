class_name NpcFrames
extends RefCounted
## Builds SpriteFrames for village NPCs from `assets/images/characters/npc_walk/`.
##
## Sheet layout (same canvas as S'lang):
##   One horizontal strip per facing: `{sheet}_{dir}.png`
##   Cell size: 256 x 192 px
##   Frame count: width / 256  (usually 8)
##   Unique dirs: down, down_right, right, up_right, up
##   West facings use the east sheet + AnimatedSprite2D.flip_h
##
## Each cell becomes its own ImageTexture. Sharing one AtlasTexture and
## rewriting `region` makes every frame show the last cell — the body then
## slides with no step.

const SHEET_DIR := "res://assets/images/characters/npc_walk/"
const FRAME_W := 256
const FRAME_H := 192
const UNIQUE_DIRS := ["down", "down_right", "right", "up_right", "up"]
const DEFAULT_WALK_FPS := 10.0

static var _cache: Dictionary = {}


static func load_or_build(sheet_id: String, walk_fps := DEFAULT_WALK_FPS) -> SpriteFrames:
	var key := "%s:%.2f" % [sheet_id, walk_fps]
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	var frames := _build(sheet_id, walk_fps)
	if not frames.get_animation_names().is_empty():
		_cache[key] = frames
	return frames


static func _build(sheet_id: String, walk_fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if sheet_id.is_empty():
		return frames
	for dir in UNIQUE_DIRS:
		var cells := _slice_strip(SHEET_DIR + sheet_id + "_" + dir + ".png")
		if cells.is_empty():
			continue
		_add_anim(frames, "walk_" + dir, cells, true, walk_fps)
		_add_anim(frames, "idle_" + dir, [cells[0]], true, 1.0)
		if dir == "right":
			_add_anim(frames, "walk_side", cells, true, walk_fps)
			_add_anim(frames, "idle_side", [cells[0]], true, 1.0)
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
	if cells.size() > 1 and not _frames_differ(cells):
		return []
	return cells


static func _add_anim(frames: SpriteFrames, name: String, texs: Array, loop: bool, fps: float) -> void:
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for tex in texs:
		frames.add_frame(name, tex as Texture2D)


static func _frames_differ(texs: Array) -> bool:
	if texs.size() < 2:
		return false
	var first := (texs[0] as Texture2D).get_image()
	if first == null:
		return false
	for i in range(1, texs.size()):
		var other := (texs[i] as Texture2D).get_image()
		if other != null and other.get_data() != first.get_data():
			return true
	return false
