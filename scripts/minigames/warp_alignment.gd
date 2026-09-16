extends MiniGameBase
## Chapter 4 - Warp Alignment. A textile swap puzzle with three cloths.
##
## Easy: 2x2 T'boli woven cloth (4 pieces).
## Medium: 3x2 Fu Kudong pattern (6 pieces).
## Hard: 4x3 slices of the photographed T'nalak hanging
## (`assets/images/props/tnalak_cloth.png`).
##
## Click one section, then another, to swap. Match the dream pattern in
## 8 moves and 90 seconds.

enum Difficulty { Easy, Medium, Hard }

const MOVE_BUDGET := 8
const EASY_PATH := "res://assets/images/minigames/warp_pattern_easy.png"
const MEDIUM_PATH := "res://assets/images/minigames/warp_pattern_medium.png"
const HARD_PATH := "res://assets/images/props/tnalak_cloth.png"
## Inner cloth of the hanging photograph, excluding the wooden wall and fringe.
const HARD_CROP_UV := Rect2(0.08, 0.03, 0.84, 0.74)

@export var difficulty := Difficulty.Easy

var _moves_label: Label
var _time_label: Label
var _target_view: TextureRect
var _board: Control
var _tiles: Array[TextureButton] = []
var _target: Array[int] = []
var _current: Array[int] = []
var _selected := -1
var _moves := 0
var _swapping := false
var _cols := 2
var _rows := 2
var _scramble := 3
var _cloth: Texture2D
var _regions: Array[Rect2] = []
var _board_size := Vector2(520.0, 360.0)


func _configure() -> void:
	_apply_difficulty()
	mini_game_title = "Warp Alignment"
	mini_game_subtitle = _difficulty_title()
	instructions = "Click two woven sections to swap them. Rebuild the dream pattern."
	time_limit = 90.0
	max_attempts = 1
	reward_score = 280 + _cols * _rows * 20


func _apply_difficulty() -> void:
	match difficulty:
		Difficulty.Medium:
			_cols = 3
			_rows = 2
			_scramble = 4
			_board_size = Vector2(560.0, 340.0)
		Difficulty.Hard:
			_cols = 4
			_rows = 3
			_scramble = 6
			_board_size = Vector2(620.0, 400.0)
		_:
			_cols = 2
			_rows = 2
			_scramble = 3
			_board_size = Vector2(420.0, 360.0)


func _difficulty_title() -> String:
	match difficulty:
		Difficulty.Medium:
			return "Fu Kudong"
		Difficulty.Hard:
			return "Master Cloth"
		_:
			return "T'boli Woven Cloth"


func _build_content(parent: Control) -> void:
	if _timer_bar != null:
		_timer_bar.visible = false

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 36)
	parent.add_child(hud)

	_moves_label = Label.new()
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_font_size_override("font_size", 20)
	_moves_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.62))
	hud.add_child(_moves_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.62))
	hud.add_child(_time_label)

	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 28)
	parent.add_child(stage)

	var dream_col := VBoxContainer.new()
	dream_col.add_theme_constant_override("separation", 8)
	dream_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(dream_col)

	var dream_tag := Label.new()
	dream_tag.text = "DREAM PATTERN"
	dream_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dream_tag.theme_type_variation = &"FieldLabel"
	dream_col.add_child(dream_tag)

	_target_view = TextureRect.new()
	_target_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_view.custom_minimum_size = Vector2(220.0, 300.0)
	_target_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dream_col.add_child(_target_view)

	var loom_col := VBoxContainer.new()
	loom_col.add_theme_constant_override("separation", 8)
	loom_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loom_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(loom_col)

	var loom_tag := Label.new()
	loom_tag.text = "THE ABLUN LOOM"
	loom_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loom_tag.theme_type_variation = &"FieldLabel"
	loom_col.add_child(loom_tag)

	var board_frame := PanelContainer.new()
	board_frame.custom_minimum_size = _board_size + Vector2(16.0, 16.0)
	board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.10, 0.08, 0.92)
	frame_style.border_color = Color(0.84, 0.74, 0.46, 0.85)
	frame_style.set_border_width_all(2)
	frame_style.set_content_margin_all(8)
	board_frame.add_theme_stylebox_override("panel", frame_style)
	loom_col.add_child(board_frame)

	_board = Control.new()
	_board.custom_minimum_size = _board_size
	_board.size = _board_size
	board_frame.add_child(_board)


func _reset_round() -> void:
	_moves = 0
	_selected = -1
	_swapping = false
	_load_cloth()
	_deal()
	_rebuild_tiles()
	_refresh_hud()
	set_status("Click a woven section, then the section it should trade places with.")


func _process(delta: float) -> void:
	super._process(delta)
	if _time_label != null and time_limit > 0.0:
		_time_label.text = "Time: %ds" % ceili(time_left())


func _load_cloth() -> void:
	var path := EASY_PATH
	match difficulty:
		Difficulty.Medium:
			path = MEDIUM_PATH
		Difficulty.Hard:
			path = HARD_PATH
	_cloth = _load_texture(path)
	_target_view.texture = _cloth_preview()
	_regions = _slice_regions()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var disk := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(disk):
		var image := Image.new()
		if image.load(disk) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _cloth_source_rect() -> Rect2:
	if _cloth == null:
		return Rect2()
	var size := _cloth.get_size()
	if difficulty == Difficulty.Hard:
		return Rect2(
			HARD_CROP_UV.position * size,
			HARD_CROP_UV.size * size
		)
	return Rect2(Vector2.ZERO, size)


func _cloth_preview() -> Texture2D:
	if _cloth == null:
		return null
	if difficulty != Difficulty.Hard:
		return _cloth
	var atlas := AtlasTexture.new()
	atlas.atlas = _cloth
	atlas.region = _cloth_source_rect()
	atlas.filter_clip = true
	return atlas


func _slice_regions() -> Array[Rect2]:
	var source := _cloth_source_rect()
	var cell := Vector2(source.size.x / float(_cols), source.size.y / float(_rows))
	var out: Array[Rect2] = []
	for row in range(_rows):
		for col in range(_cols):
			out.append(Rect2(source.position + Vector2(col * cell.x, row * cell.y), cell))
	return out


func _deal() -> void:
	var count := _cols * _rows
	_target.clear()
	for i in range(count):
		_target.append(i)
	_current = _target.duplicate()
	for _swap in range(_scramble):
		var a := randi() % count
		var b := randi() % count
		if a != b:
			_swap_values(a, b)
	if _current == _target:
		_swap_values(0, mini(1, count - 1))


func _swap_values(a: int, b: int) -> void:
	var held: int = _current[a]
	_current[a] = _current[b]
	_current[b] = held


func _rebuild_tiles() -> void:
	for child in _board.get_children():
		child.queue_free()
	_tiles.clear()
	var count := _cols * _rows
	var gap := 3.0
	var cell := Vector2(
		(_board_size.x - gap * float(_cols - 1)) / float(_cols),
		(_board_size.y - gap * float(_rows - 1)) / float(_rows)
	)
	for i in range(count):
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = cell
		button.size = cell
		var col := i % _cols
		var row := int(i / _cols)
		button.position = Vector2(col * (cell.x + gap), row * (cell.y + gap))
		button.pressed.connect(_on_tile_pressed.bind(i))
		_board.add_child(button)
		_tiles.append(button)
	_paint_tiles()


func _tile_texture(piece_id: int) -> Texture2D:
	if _cloth == null or piece_id < 0 or piece_id >= _regions.size():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = _cloth
	atlas.region = _regions[piece_id]
	atlas.filter_clip = true
	return atlas


func _paint_tiles() -> void:
	for i in range(_tiles.size()):
		var button := _tiles[i]
		button.texture_normal = _tile_texture(_current[i])
		var chosen := i == _selected
		button.modulate = Color(1.18, 1.12, 0.88) if chosen else Color.WHITE
		var ring := button.get_node_or_null("SelectRing") as ColorRect
		if ring == null:
			ring = ColorRect.new()
			ring.name = "SelectRing"
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.color = Color(0.96, 0.86, 0.52, 0.0)
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.add_child(ring)
		ring.color = Color(0.98, 0.9, 0.55, 0.22) if chosen else Color(0.96, 0.86, 0.52, 0.0)


func _on_tile_pressed(index: int) -> void:
	if not running or _swapping:
		return
	if _selected < 0:
		_selected = index
		Audio.play_sfx(Audio.Sfx.PICKUP)
		_paint_tiles()
		set_status("Holding a warp section. Click another to swap.")
		return
	if _selected == index:
		_selected = -1
		_paint_tiles()
		set_status("Released.")
		return
	await _swap_animated(_selected, index)


func _swap_animated(a: int, b: int) -> void:
	_swapping = true
	_selected = -1
	var tile_a := _tiles[a]
	var tile_b := _tiles[b]
	var pos_a := tile_a.position
	var pos_b := tile_b.position
	var fly_a := _make_fly(tile_a)
	var fly_b := _make_fly(tile_b)
	tile_a.visible = false
	tile_b.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly_a, "position", pos_b, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly_b, "position", pos_a, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(fly_a):
		fly_a.queue_free()
	if is_instance_valid(fly_b):
		fly_b.queue_free()
	_swap_values(a, b)
	_moves += 1
	Audio.play_sfx(Audio.Sfx.HIT)
	tile_a.visible = true
	tile_b.visible = true
	_paint_tiles()
	_refresh_hud()
	_swapping = false

	if _current == _target:
		await _celebrate()
		succeed("The warp matches the dream. %d move%s — the cloth remembers itself." % [
			_moves, "" if _moves == 1 else "s"])
	elif _moves >= MOVE_BUDGET:
		fail("The move budget is spent and the warp still fights the dream.")


func _make_fly(source: TextureButton) -> TextureRect:
	var fly := TextureRect.new()
	fly.texture = source.texture_normal
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fly.size = source.size
	fly.position = source.position
	fly.modulate = Color(1.12, 1.06, 0.9)
	_board.add_child(fly)
	return fly


func _refresh_hud() -> void:
	var matched := 0
	for i in range(_current.size()):
		if _current[i] == _target[i]:
			matched += 1
	if _moves_label != null:
		_moves_label.text = "Moves: %d / %d" % [_moves, MOVE_BUDGET]
	set_status("Sections in place  %d / %d. Click two pieces to swap." % [matched, _current.size()])


func _celebrate() -> void:
	set_result_texture(_cloth_preview())
	for tile in _tiles:
		var tween := create_tween()
		tween.tween_property(tile, "modulate", Color(1.35, 1.22, 0.9), 0.18)
		tween.tween_property(tile, "modulate", Color.WHITE, 0.35)
	if _target_view != null:
		var glow := create_tween()
		glow.tween_property(_target_view, "modulate", Color(1.25, 1.16, 0.9), 0.2)
		glow.tween_property(_target_view, "modulate", Color.WHITE, 0.4)
	await get_tree().create_timer(0.45).timeout
