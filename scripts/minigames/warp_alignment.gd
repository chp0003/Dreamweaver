extends MiniGameBase
## Chapter 4 - Warp Alignment. Slide neighboring cloth sections
## until the complete woven pattern is restored.
##
## Easy: 3x3 of a complete T'boli cloth (9 pieces), light scramble.
## Medium: 3x4 Fun Kdungon (12 pieces).
## Hard: 5x4 slices of the photographed T'nalak hanging
## (`assets/images/props/tnalak_cloth.png`).
##
## Drag a piece, or click it and then a neighbor, to slide them.

enum Difficulty { Easy, Medium, Hard }

const EASY_PATH := "res://assets/images/minigames/warp_pattern_easy.png"
const MEDIUM_PATH := "res://assets/images/characters/fun_kdungon.png"
const HARD_PATH := "res://assets/images/props/tnalak_cloth.png"
## Inner cloth of the hanging photograph, excluding the wooden wall and fringe.
const HARD_CROP_UV := Rect2(0.08, 0.03, 0.84, 0.74)
## Fun Kdungon sprite content, trimming empty transparent padding.
const MEDIUM_CROP_UV := Rect2(0.02, 0.01, 0.96, 0.98)

@export var difficulty := Difficulty.Easy

var _target_view: TextureRect
var _board_frame: PanelContainer
var _board: Control
var _tiles: Array[TextureButton] = []
var _target: Array[int] = []
var _current: Array[int] = []
var _selected := -1
var _moves := 0
var _sliding := false
var _drag_from := -1
var _drag_start := Vector2.ZERO
var _ignore_click := false
var _cols := 3
var _rows := 3
var _scramble := 8
var _cloth: Texture2D
var _regions: Array[Rect2] = []
var _board_size := Vector2(420.0, 420.0)
var _cell := Vector2.ZERO
var _gap := 4.0


func _configure() -> void:
	_apply_difficulty()
	mini_game_title = "Warp Alignment"
	mini_game_subtitle = _difficulty_title()
	instructions = "Slide neighboring boxes — drag a piece, or click it and then the neighbor it should trade with."
	time_limit = 0.0
	max_attempts = 1
	reward_score = 80 + _cols * _rows * 8


func _apply_difficulty() -> void:
	match difficulty:
		Difficulty.Medium:
			_cols = 3
			_rows = 4
			_scramble = 18
		Difficulty.Hard:
			_cols = 5
			_rows = 4
			_scramble = 24
		_:
			_cols = 3
			_rows = 3
			_scramble = 8


func _difficulty_title() -> String:
	match difficulty:
		Difficulty.Medium:
			return "Fun Kdungon"
		Difficulty.Hard:
			return "Master Cloth"
		_:
			return "T'boli Woven Cloth"


func _build_content(parent: Control) -> void:
	if _timer_bar != null:
		_timer_bar.visible = false

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
	_target_view.stretch_mode = TextureRect.STRETCH_SCALE
	_target_view.custom_minimum_size = Vector2(200.0, 260.0)
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

	_board_frame = PanelContainer.new()
	_board_frame.custom_minimum_size = _board_size + Vector2(16.0, 16.0)
	_board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.10, 0.08, 0.92)
	frame_style.border_color = Color(0.84, 0.74, 0.46, 0.85)
	frame_style.set_border_width_all(2)
	frame_style.set_content_margin_all(8)
	_board_frame.add_theme_stylebox_override("panel", frame_style)
	loom_col.add_child(_board_frame)

	_board = Control.new()
	_board.custom_minimum_size = _board_size
	_board.size = _board_size
	_board_frame.add_child(_board)


func _reset_round() -> void:
	_moves = 0
	_selected = -1
	_sliding = false
	_drag_from = -1
	_ignore_click = false
	_load_cloth()
	_fit_layout_to_cloth()
	_deal()
	_rebuild_tiles()
	_refresh_hud()
	set_status("Slide neighboring sections until the complete cloth returns.")


func _process(delta: float) -> void:
	super._process(delta)


func _load_cloth() -> void:
	var path := EASY_PATH
	match difficulty:
		Difficulty.Medium:
			path = MEDIUM_PATH
		Difficulty.Hard:
			path = HARD_PATH
	_cloth = _load_texture(path)
	_regions = _slice_regions()
	if _target_view != null:
		_target_view.texture = _cloth_preview()


func _fit_layout_to_cloth() -> void:
	var source := _cloth_source_rect()
	if source.size.x <= 1.0 or source.size.y <= 1.0:
		return
	var aspect := source.size.x / source.size.y
	var max_w := 520.0
	var max_h := 480.0
	var board_w := max_w
	var board_h := board_w / aspect
	if board_h > max_h:
		board_h = max_h
		board_w = board_h * aspect
	_board_size = Vector2(board_w, board_h)

	var preview_h := mini(340.0, board_h)
	var preview_w := preview_h * aspect
	if _target_view != null:
		_target_view.custom_minimum_size = Vector2(preview_w, preview_h)
		_target_view.size = Vector2(preview_w, preview_h)

	if _board != null:
		_board.custom_minimum_size = _board_size
		_board.size = _board_size
	if _board_frame != null:
		_board_frame.custom_minimum_size = _board_size + Vector2(16.0, 16.0)


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
	if difficulty == Difficulty.Medium:
		return Rect2(
			MEDIUM_CROP_UV.position * size,
			MEDIUM_CROP_UV.size * size
		)
	return Rect2(Vector2.ZERO, size)


func _cloth_preview() -> Texture2D:
	if _cloth == null:
		return null
	if difficulty == Difficulty.Easy:
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


func _matched_count() -> int:
	var matched := 0
	for i in range(_current.size()):
		if int(_current[i]) == int(_target[i]):
			matched += 1
	return matched


func _is_solved() -> bool:
	return not _current.is_empty() and _matched_count() == _current.size()


func _deal() -> void:
	var count := _cols * _rows
	_target.clear()
	for i in range(count):
		_target.append(i)
	_current = _target.duplicate()
	var guard := 0
	while guard < 80:
		guard += 1
		var index := randi() % count
		var nbs := _neighbors(index)
		if nbs.is_empty():
			continue
		_swap_values(index, nbs[randi() % nbs.size()])
		if guard >= _scramble and _matched_count() <= count - 3:
			break
	if _is_solved():
		_swap_values(0, 1)
		if count > 2:
			_swap_values(1, 2)


func _neighbors(index: int) -> Array[int]:
	var col := index % _cols
	var row := int(index / _cols)
	var out: Array[int] = []
	if col > 0:
		out.append(index - 1)
	if col < _cols - 1:
		out.append(index + 1)
	if row > 0:
		out.append(index - _cols)
	if row < _rows - 1:
		out.append(index + _cols)
	return out


func _is_adjacent(a: int, b: int) -> bool:
	return _neighbors(a).has(b)


func _swap_values(a: int, b: int) -> void:
	var held: int = _current[a]
	_current[a] = _current[b]
	_current[b] = held


func _tile_position(index: int) -> Vector2:
	var col := index % _cols
	var row := int(index / _cols)
	return Vector2(col * (_cell.x + _gap), row * (_cell.y + _gap))


func _rebuild_tiles() -> void:
	for child in _board.get_children():
		child.queue_free()
	_tiles.clear()
	_cell = Vector2(
		(_board_size.x - _gap * float(_cols - 1)) / float(_cols),
		(_board_size.y - _gap * float(_rows - 1)) / float(_rows)
	)
	var count := _cols * _rows
	for i in range(count):
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size = _cell
		button.size = _cell
		button.position = _tile_position(i)
		button.gui_input.connect(_on_tile_gui_input.bind(i))
		button.pressed.connect(_on_tile_pressed.bind(i))
		var border := Panel.new()
		border.name = "TileBorder"
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var border_style := StyleBoxFlat.new()
		border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		border_style.border_color = Color(0.92, 0.82, 0.48, 0.95)
		border_style.set_border_width_all(2)
		border.add_theme_stylebox_override("panel", border_style)
		button.add_child(border)
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
		var border := button.get_node_or_null("TileBorder") as Panel
		if border != null:
			var style := border.get_theme_stylebox("panel") as StyleBoxFlat
			if style != null:
				style.border_color = Color(1.0, 0.92, 0.55, 1.0) if chosen else Color(0.92, 0.82, 0.48, 0.95)
				style.set_border_width_all(3 if chosen else 2)


func _neighbor_from_delta(index: int, delta: Vector2) -> int:
	var col := index % _cols
	var row := int(index / _cols)
	if absf(delta.x) >= absf(delta.y):
		if delta.x > 0.0 and col < _cols - 1:
			return index + 1
		if delta.x < 0.0 and col > 0:
			return index - 1
	else:
		if delta.y > 0.0 and row < _rows - 1:
			return index + _cols
		if delta.y < 0.0 and row > 0:
			return index - _cols
	return -1


func _on_tile_gui_input(event: InputEvent, index: int) -> void:
	if not running or _sliding:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		_drag_from = index
		_drag_start = mouse.global_position


func _input(event: InputEvent) -> void:
	if _drag_from < 0 or not running or _sliding:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var from := _drag_from
	var start := _drag_start
	_drag_from = -1
	var delta := mouse.global_position - start
	if delta.length() < 28.0:
		return
	var dest := _neighbor_from_delta(from, delta)
	if dest < 0:
		return
	_ignore_click = true
	_slide_animated(from, dest)
	_clear_click_guard.call_deferred()


func _clear_click_guard() -> void:
	_ignore_click = false


func _on_tile_pressed(index: int) -> void:
	if _ignore_click:
		_ignore_click = false
		return
	if not running or _sliding:
		return
	if _selected < 0:
		_selected = index
		Audio.play_sfx(Audio.Sfx.PICKUP)
		_paint_tiles()
		set_status("Slide it into a neighboring section.")
		return
	if _selected == index:
		_selected = -1
		_paint_tiles()
		set_status("Released.")
		return
	if not _is_adjacent(_selected, index):
		_selected = index
		Audio.play_sfx(Audio.Sfx.PICKUP)
		_paint_tiles()
		set_status("Those warps do not touch. Slide a neighbor instead.")
		return
	await _slide_animated(_selected, index)


func _slide_animated(a: int, b: int) -> void:
	_sliding = true
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
	tween.tween_property(fly_a, "position", pos_b, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly_b, "position", pos_a, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	_sliding = false

	if _is_solved():
		await _celebrate()
		succeed("The warp matches the dream. The cloth remembers itself.")


func _make_fly(source: TextureButton) -> TextureRect:
	var fly := TextureRect.new()
	fly.texture = source.texture_normal
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_SCALE
	fly.size = source.size
	fly.position = source.position
	fly.modulate = Color(1.12, 1.06, 0.9)
	_board.add_child(fly)
	return fly


func _refresh_hud() -> void:
	set_status("Cloth in place  %d / %d. Slide neighboring boxes." % [_matched_count(), _current.size()])


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
