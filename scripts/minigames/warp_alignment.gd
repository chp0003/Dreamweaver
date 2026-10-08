extends MiniGameBase

## Chapter 4 - Warp Alignment. Slide neighboring cloth sections
## until the complete woven pattern is restored.
##
## Easy: 3x3 of a complete T'boli cloth (9 pieces), light scramble.
## Medium: 3x4 of Fun Kdungon on a plain wood board. Only her pieces must match.
## Hard: 5x4 slices of the Golden Era village (prologue panel).
##
## Drag a piece, or click it and then a neighbor, to slide them.

enum Difficulty { Easy, Medium, Hard }

const EASY_PATH := "res://assets/images/minigames/warp_pattern_easy.png"
const MEDIUM_PATH := "res://assets/images/characters/fun_kdungon.png"
const HARD_PATH := "res://assets/images/minigames/warp_pattern_hard.png"
const HARD_FALLBACK_PATH := "res://assets/images/story/intro_01_golden_era.png"
const PORTRAIT_PLATE := Vector2i(540, 810)

@export var difficulty := Difficulty.Easy
## Optional override. Chapter 4 passes the Golden Era panel for Hard.
@export var cloth_path := ""

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
## Medium only: slots that show Fun Kdungon. Plain wood slots are not part of the solve.
var _figure_slots: Array[bool] = []
var _portrait_on_plate := Rect2i()
var _plate_image: Image
var _celebrating := false
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
			return "The Golden Era"
		_:
			return "T'boli Woven Cloth"


func _build_content(parent: Control) -> void:
	if _timer_bar != null:
		_timer_bar.visible = false
	if parent is BoxContainer:
		(parent as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER

	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage.add_theme_constant_override("separation", 28)
	parent.add_child(stage)

	var dream_col := VBoxContainer.new()
	dream_col.add_theme_constant_override("separation", 8)
	dream_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage.add_child(dream_col)

	var dream_tag := Label.new()
	dream_tag.text = "DREAM PATTERN"
	dream_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dream_tag.theme_type_variation = &"FieldLabel"
	dream_col.add_child(dream_tag)

	_target_view = TextureRect.new()
	_target_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_target_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_target_view.custom_minimum_size = Vector2(180.0, 220.0)
	dream_col.add_child(_target_view)

	var loom_col := VBoxContainer.new()
	loom_col.add_theme_constant_override("separation", 8)
	loom_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	loom_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage.add_child(loom_col)

	var loom_tag := Label.new()
	loom_tag.text = "THE ABLUN LOOM"
	loom_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loom_tag.theme_type_variation = &"FieldLabel"
	loom_col.add_child(loom_tag)

	_board_frame = PanelContainer.new()
	_board_frame.custom_minimum_size = _board_size + Vector2(16.0, 16.0)
	_board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_celebrating = false
	_drag_from = -1
	_ignore_click = false
	_load_cloth()
	_fit_layout_to_cloth()
	_deal()
	_rebuild_tiles()
	_refresh_hud()
	if difficulty == Difficulty.Medium:
		set_status("Slide neighboring sections until Fun Kdungon stands whole. The wood does not have to match.")
	else:
		set_status("Slide neighboring sections until the complete cloth returns.")


func _process(delta: float) -> void:
	super._process(delta)
	# A board that is already whole (no further slide) still has to finish.
	if _celebrating or not running or _sliding or _current.is_empty():
		return
	if _is_solved():
		_celebrating = true
		_finish_solved()


func _load_cloth() -> void:
	var path := cloth_path.strip_edges()
	if path.is_empty():
		path = _default_cloth_path()
	_portrait_on_plate = Rect2i()
	_plate_image = null
	_cloth = _load_texture(path)
	if _cloth == null and difficulty == Difficulty.Hard:
		_cloth = _load_texture(HARD_FALLBACK_PATH)
	if difficulty == Difficulty.Medium and _cloth != null:
		_cloth = _compose_portrait_plate(_cloth)
	_regions = _slice_regions()
	if _target_view != null:
		_target_view.texture = _cloth_preview()
	mini_game_subtitle = _difficulty_title()
	if _subtitle_label != null:
		_subtitle_label.text = mini_game_subtitle


func _default_cloth_path() -> String:
	match difficulty:
		Difficulty.Medium:
			return MEDIUM_PATH
		Difficulty.Hard:
			return HARD_PATH
		_:
			return EASY_PATH


func _fit_layout_to_cloth() -> void:
	var source := _cloth_source_rect()
	if source.size.x <= 1.0 or source.size.y <= 1.0:
		return
	var aspect := source.size.x / source.size.y
	var view := get_viewport_rect().size
	# Leave room for the frame title, the two captions, and the window margins
	# so neither the reference nor the loom is clipped.
	var avail_h := maxf(220.0, view.y - 380.0)
	var avail_w := maxf(520.0, view.x - 240.0)
	var gap := 28.0
	var frame_pad := 16.0
	var picture_h := avail_h
	var picture_w := picture_h * aspect
	var total_w := picture_w + gap + picture_w + frame_pad
	if total_w > avail_w:
		picture_w = (avail_w - gap - frame_pad) * 0.5
		picture_h = picture_w / aspect
	_board_size = Vector2(picture_w, picture_h)
	if _target_view != null:
		_target_view.custom_minimum_size = _board_size
		_target_view.size = _board_size
	if _board != null:
		_board.custom_minimum_size = _board_size
		_board.size = _board_size
	if _board_frame != null:
		_board_frame.custom_minimum_size = _board_size + Vector2(frame_pad, frame_pad)


func _load_texture(path: String) -> Texture2D:
	return Palette.read_texture(path)


func _cloth_source_rect() -> Rect2:
	if _cloth == null:
		return Rect2()
	return Rect2(Vector2.ZERO, _cloth.get_size())


func _cloth_preview() -> Texture2D:
	return _cloth


## Tight crop of Fun Kdungon on a wood board, so empty tiles stay brown
## instead of black.
func _compose_portrait_plate(source: Texture2D) -> Texture2D:
	var raw := source.get_image()
	if raw == null:
		return source
	var src: Image = raw.duplicate() as Image
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var bounds := _opaque_bounds(src)
	var cropped := src.get_region(bounds)
	var max_w := int(float(PORTRAIT_PLATE.x) * 0.9)
	var max_h := int(float(PORTRAIT_PLATE.y) * 0.9)
	var scale := minf(float(max_w) / float(cropped.get_width()), float(max_h) / float(cropped.get_height()))
	var dw := maxi(1, int(round(float(cropped.get_width()) * scale)))
	var dh := maxi(1, int(round(float(cropped.get_height()) * scale)))
	cropped.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
	var plate := Image.create(PORTRAIT_PLATE.x, PORTRAIT_PLATE.y, false, Image.FORMAT_RGBA8)
	_paint_wood(plate)
	var origin := Vector2i((PORTRAIT_PLATE.x - dw) / 2, (PORTRAIT_PLATE.y - dh) / 2)
	_portrait_on_plate = Rect2i(origin.x, origin.y, dw, dh)
	plate.blend_rect(cropped, Rect2i(0, 0, dw, dh), origin)
	_plate_image = plate
	return ImageTexture.create_from_image(plate)


func _opaque_bounds(image: Image) -> Rect2i:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var min_x := width
	var min_y := height
	var max_x := 0
	var max_y := 0
	var found := false
	for y in height:
		for x in width:
			var color: Color = image.get_pixel(x, y)
			if color.a < 0.18:
				continue
			found = true
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if not found:
		return Rect2i(0, 0, width, height)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _paint_wood(plate: Image) -> void:
	# One flat board. Plank lines were a second pattern and read as part of the solve.
	plate.fill(Palette.EARTH_WOOD)


func _slice_regions() -> Array[Rect2]:
	var source := _cloth_source_rect()
	var cell := Vector2(source.size.x / float(_cols), source.size.y / float(_rows))
	var out: Array[Rect2] = []
	for row in range(_rows):
		for col in range(_cols):
			out.append(Rect2(source.position + Vector2(col * cell.x, row * cell.y), cell))
	_mark_figure_slots(out)
	return out


func _mark_figure_slots(regions: Array[Rect2]) -> void:
	_figure_slots.clear()
	var figure_only := difficulty == Difficulty.Medium and _plate_image != null
	for region in regions:
		if not figure_only:
			_figure_slots.append(true)
			continue
		# Her bounding box is wider than her body. A wood tile that only
		# clips that box is still wood, and must not block the finish.
		_figure_slots.append(_cell_shows_figure(region))


func _cell_shows_figure(region: Rect2) -> bool:
	var image := _plate_image
	if image == null:
		return true
	var wood := Palette.EARTH_WOOD
	var x0 := clampi(int(region.position.x), 0, image.get_width() - 1)
	var y0 := clampi(int(region.position.y), 0, image.get_height() - 1)
	var x1 := clampi(int(ceil(region.end.x)), x0 + 1, image.get_width())
	var y1 := clampi(int(ceil(region.end.y)), y0 + 1, image.get_height())
	var seen := 0
	var figure := 0
	var y := y0
	while y < y1:
		var x := x0
		while x < x1:
			var color := image.get_pixel(x, y)
			seen += 1
			var diff := absf(color.r - wood.r) + absf(color.g - wood.g) + absf(color.b - wood.b)
			if diff > 0.14:
				figure += 1
			x += 3
		y += 3
	if seen == 0:
		return false
	return float(figure) / float(seen) >= 0.1


func _slot_matters(index: int) -> bool:
	if index < 0 or index >= _figure_slots.size():
		return true
	return _figure_slots[index]


func _solve_total() -> int:
	var total := 0
	for i in range(_current.size()):
		if _slot_matters(i):
			total += 1
	return total


func _matched_count() -> int:
	var matched := 0
	for i in range(_current.size()):
		if _slot_matters(i) and int(_current[i]) == int(_target[i]):
			matched += 1
	return matched


func _is_solved() -> bool:
	var total := _solve_total()
	return total > 0 and _matched_count() == total


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
		if guard >= _scramble and _matched_count() < _solve_total():
			break
	if _is_solved():
		for i in range(count):
			if not _slot_matters(i):
				continue
			var nbs := _neighbors(i)
			if nbs.is_empty():
				continue
			_swap_values(i, nbs[0])
			break


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
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	if _is_solved() and not _celebrating:
		_celebrating = true
		_finish_solved()


func _finish_solved() -> void:
	await _celebrate()
	if not is_inside_tree() or not running:
		return
	if difficulty == Difficulty.Medium:
		succeed("Fun Kdungon stands whole.")
	else:
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
	if difficulty == Difficulty.Medium:
		set_status("Fun Kdungon  %d / %d. The wood can sit anywhere." % [_matched_count(), _solve_total()])
	else:
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
