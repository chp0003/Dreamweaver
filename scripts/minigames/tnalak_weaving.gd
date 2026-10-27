extends MiniGameBase

## Chapter 1 loom — bind, dye, and weave a small pixel-draft.
## The draft uses geometric T'nalak-inspired motifs rather than copying a
## particular community pattern.

signal cloth_completed(cloth: TnalakCloth)

const CLOTH_PATH := "res://assets/images/props/tnalak_cloth.png"

var last_cloth: TnalakCloth

var _hint: Label
var _board: PixelLoomBoard
var _cloth_tex: Texture2D


func _configure() -> void:
	mini_game_title = "T'nalak Weaving"
	mini_game_subtitle = "House of the Black Foundation"
	instructions = "Bind the cream cells to preserve them, dye the open warp, then weave the cloth. Match the pixel draft to reveal the motif."
	time_limit = 0.0
	max_attempts = 3
	reward_score = 320


func _build_content(parent: Control) -> void:
	_cloth_tex = _load_cloth_texture()

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	parent.add_child(_hint)

	_board = PixelLoomBoard.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(420.0, 320.0)
	_board.step_changed.connect(_on_step_changed)
	_board.pattern_completed.connect(_on_all_joined)
	parent.add_child(_board)


func _load_cloth_texture() -> Texture2D:
	var image := Palette.read_image(CLOTH_PATH)
	if image == null:
		return Palette.read_texture(CLOTH_PATH)
	if image.get_width() > 640:
		var h := int(round(640.0 * float(image.get_height()) / float(image.get_width())))
		image.resize(640, maxi(h, 1), Image.INTERPOLATE_LANCZOS)
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


func _reset_round() -> void:
	last_cloth = null
	if _board != null:
		_board.reset()
	_hint.text = "Bind the cream cells, then dye and weave."
	set_status("Bind the resist pattern. 0% complete.")


func _on_step_changed(message: String, progress: int) -> void:
	if not running:
		return
	Audio.play_sfx(Audio.Sfx.CHIME)
	_hint.text = message
	set_status("Pattern progress: %d%%" % progress)


func _on_all_joined() -> void:
	if not running:
		return
	last_cloth = _board.to_cloth()
	cloth_completed.emit(last_cloth)
	_hint.text = "The warp settles into a finished T'nalak-inspired cloth."
	set_status("Cloth complete.")
	set_result_texture(_cloth_tex)
	succeed("The first cloth holds a pixel-drafted bird and diamond motif in cream, red, and black.")


## Legacy matching board kept below for compatibility with older saved scenes.
class ConnectBoard extends Control:
	signal pair_joined(joined: int, total: int)
	signal mismatch
	signal all_joined

	const PAIR_COUNT := 4

	var is_complete := false
	var cloth_texture: Texture2D

	var _left: Array[Dictionary] = []
	var _right: Array[Dictionary] = []
	var _joined: Dictionary = {}
	var _selected_side := ""
	var _selected_index := -1
	var _pulse := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(queue_redraw)
		set_process(true)
		reset()

	func _process(delta: float) -> void:
		if _selected_index < 0:
			return
		_pulse += delta * 3.2
		queue_redraw()

	func reset() -> void:
		is_complete = false
		_joined.clear()
		_selected_side = ""
		_selected_index = -1
		_pulse = 0.0
		var pairs := _make_pairs()
		_left = pairs.duplicate()
		_left.shuffle()
		_right = _shuffle_without_straights(_left)
		queue_redraw()

	## Random right column, but no colour may sit on the same row as its twin
	## (that would draw a flat horizontal thread).
	func _shuffle_without_straights(left: Array[Dictionary]) -> Array[Dictionary]:
		var right: Array[Dictionary] = left.duplicate()
		for _attempt in range(64):
			right.shuffle()
			if not _has_straight_pair(left, right):
				return right
		# Guaranteed derangement for n >= 2 if shuffle keeps landing fixed points.
		right = left.duplicate()
		var first: Dictionary = right.pop_front()
		right.append(first)
		return right

	func _has_straight_pair(left: Array[Dictionary], right: Array[Dictionary]) -> bool:
		for i in range(mini(left.size(), right.size())):
			if int(left[i]["id"]) == int(right[i]["id"]):
				return true
		return false

	func to_cloth() -> TnalakCloth:
		var cloth := TnalakCloth.new()
		cloth.start_new_cloth(Vector2i(4, 4), TnalakCloth.Axis.ROWS)
		for y in range(4):
			var strand: TnalakCloth.Strand = cloth.strands[y]
			var dye := int(_make_pairs()[y]["dye"])
			for x in range(4):
				strand.segments[x] = dye
			strand.stage = TnalakCloth.StrandStage.WOVEN
			strand.dye_id = TnalakCloth.DYE_BLACK if dye == TnalakCloth.SegmentState.DYED_BLACK \
				else TnalakCloth.DYE_RED
		cloth.is_complete = true
		cloth.completion = 1.0
		cloth.active_index = -1
		return cloth

	func _gui_input(event: InputEvent) -> void:
		if is_complete:
			return
		if not (event is InputEventMouseButton):
			return
		var click := event as InputEventMouseButton
		if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit := _hit_knob(click.position)
		if hit.is_empty():
			_selected_side = ""
			_selected_index = -1
			queue_redraw()
			accept_event()
			return
		_click_knob(str(hit["side"]), int(hit["index"]))
		accept_event()

	func _click_knob(side: String, index: int) -> void:
		var id := _id_at(side, index)
		if _joined.has(id):
			return
		if _selected_index < 0:
			_selected_side = side
			_selected_index = index
			queue_redraw()
			return
		if side == _selected_side and index == _selected_index:
			_selected_side = ""
			_selected_index = -1
			queue_redraw()
			return
		if side == _selected_side:
			_selected_side = side
			_selected_index = index
			queue_redraw()
			return
		var other_id := _id_at(_selected_side, _selected_index)
		if other_id != id:
			mismatch.emit()
			_selected_side = ""
			_selected_index = -1
			queue_redraw()
			return
		_joined[id] = true
		_selected_side = ""
		_selected_index = -1
		queue_redraw()
		pair_joined.emit(_joined.size(), PAIR_COUNT)
		if _joined.size() >= PAIR_COUNT:
			is_complete = true
			all_joined.emit()

	func _draw() -> void:
		var rect := _board_rect()
		draw_rect(rect.grow(18.0), Palette.EARTH_LOAM)
		draw_rect(rect.grow(18.0), Palette.GOLD_BRASS, false, 1.6)
		if is_complete:
			_draw_finished_cloth(rect)
			return
		_draw_threads(rect)
		for i in range(PAIR_COUNT):
			_draw_knob(_knob_pos("left", i), _left[i], _selected_side == "left" and _selected_index == i)
			_draw_knob(_knob_pos("right", i), _right[i], _selected_side == "right" and _selected_index == i)

	func _draw_threads(rect: Rect2) -> void:
		for i in range(PAIR_COUNT):
			var left_i := _index_of(_left, int(_left[i]["id"]))
			var right_i := _index_of(_right, int(_left[i]["id"]))
			if left_i < 0 or right_i < 0:
				continue
			var a := _knob_pos("left", left_i)
			var b := _knob_pos("right", right_i)
			var color: Color = _left[i]["color"]
			if _joined.has(int(_left[i]["id"])):
				draw_line(a, b, color, 10.0, true)
			elif not is_complete:
				draw_line(a, b, Palette.alpha(Palette.GOLD_SACRED, 0.12), 2.0, true)
		draw_rect(rect, Color(0, 0, 0, 0))

	func _draw_finished_cloth(rect: Rect2) -> void:
		if cloth_texture == null:
			return
		var tex_size := cloth_texture.get_size()
		if tex_size.x < 1.0 or tex_size.y < 1.0:
			return
		var scale := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
		var draw_size := tex_size * scale
		var pos := rect.position + (rect.size - draw_size) * 0.5
		draw_texture_rect(cloth_texture, Rect2(pos, draw_size), false)

	func _draw_knob(pos: Vector2, strand: Dictionary, selected: bool) -> void:
		var color: Color = strand["color"]
		var done := _joined.has(int(strand["id"]))
		var radius := 22.0
		draw_circle(pos, radius + 4.0, Palette.EARTH_LOAM)
		draw_circle(pos, radius, color)
		draw_arc(pos, radius, 0.0, TAU, 28, Palette.GOLD_SACRED if not done else Palette.GOLD_SUN, 2.0, true)
		if selected:
			var glow := 3.0 + sin(_pulse) * 2.0
			draw_arc(pos, radius + 6.0 + glow, 0.0, TAU, 28, Palette.GOLD_SUN, 2.4, true)

	func _board_rect() -> Rect2:
		var pad := Vector2(72.0, 36.0)
		var inner := size - pad * 2.0
		if inner.x < 80.0 or inner.y < 80.0:
			return Rect2(Vector2(24, 24), size - Vector2(48, 48))
		return Rect2(pad, inner)

	func _knob_pos(side: String, index: int) -> Vector2:
		var rect := _board_rect()
		var x := rect.position.x if side == "left" else rect.end.x
		var gap := rect.size.y / float(PAIR_COUNT)
		var y := rect.position.y + gap * (float(index) + 0.5)
		return Vector2(x, y)

	func _hit_knob(local: Vector2) -> Dictionary:
		for side in ["left", "right"]:
			for i in range(PAIR_COUNT):
				if local.distance_to(_knob_pos(side, i)) <= 28.0:
					return {"side": side, "index": i}
		return {}

	func _id_at(side: String, index: int) -> int:
		var row: Array[Dictionary] = _left if side == "left" else _right
		return int(row[index]["id"])

	func _index_of(row: Array[Dictionary], id: int) -> int:
		for i in range(row.size()):
			if int(row[i]["id"]) == id:
				return i
		return -1

	func _make_pairs() -> Array[Dictionary]:
		return [
			{"id": 0, "title": "Cream", "color": Palette.CREAM_WARP, "dye": TnalakCloth.SegmentState.RAW},
			{"id": 1, "title": "Black", "color": Color(0.45, 0.34, 0.28), "dye": TnalakCloth.SegmentState.DYED_BLACK},
			{"id": 2, "title": "Red", "color": Palette.RED_SACRED, "dye": TnalakCloth.SegmentState.DYED_RED},
			{"id": 3, "title": "Gold", "color": Palette.GOLD_BRASS, "dye": TnalakCloth.SegmentState.RAW},
		]


	class PixelLoomBoard extends Control:
		signal step_changed(message: String, progress: int)
		signal pattern_completed

		const SIZE := 12
		const RAW := 0
		const RESISTED := 1
		const RED := 2
		const BLACK := 3

		var current: Array = []
		var target: Array = []
		var is_complete := false
		var _motif := 0
		var _pulse := 0.0

		func _ready() -> void:
			mouse_filter = Control.MOUSE_FILTER_STOP
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			resized.connect(queue_redraw)
			_make_pattern()
			set_process(true)

		func _process(delta: float) -> void:
			_pulse += delta
			queue_redraw()

		func reset() -> void:
			is_complete = false
			_make_pattern()
			queue_redraw()

		func _make_pattern() -> void:
			current.clear()
			target.clear()
			_motif = randi_range(0, 2)
			for y in range(SIZE):
				var current_row: Array[int] = []
				var target_row: Array[int] = []
				for x in range(SIZE):
					current_row.append(RAW)
					target_row.append(_pattern_state(x, y))
				current.append(current_row)
				target.append(target_row)

		func _pattern_state(x: int, y: int) -> int:
			var edge := x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1
			var diamond := absi(x - 5) + absi(y - 5) == 4 or absi(x - 6) + absi(y - 6) == 4
			var bird := (y == 4 and x >= 3 and x <= 8) or (y == 5 and (x == 2 or x == 9))
			var wing := (y == 3 and (x == 4 or x == 7)) or (y == 6 and (x == 4 or x == 7))
			if _motif == 1:
				diamond = absi(x - 5) + absi(y - 5) == 3 or absi(x - 6) + absi(y - 6) == 3
				bird = (x == 5 and y >= 3 and y <= 8) or (x == 6 and (y == 2 or y == 9))
				wing = (x == 4 and (y == 4 or y == 7)) or (x == 7 and (y == 4 or y == 7))
			elif _motif == 2:
				diamond = (x == y or x + y == SIZE - 1) and x > 1 and x < SIZE - 2
				bird = (y == 5 and x >= 3 and x <= 8) or (y == 6 and x >= 4 and x <= 7)
				wing = (y == 4 and (x == 3 or x == 8)) or (y == 7 and (x == 3 or x == 8))
			if edge or diamond:
				return BLACK
			if bird or wing:
				return RED
			return RAW

		func to_cloth() -> TnalakCloth:
			var cloth := TnalakCloth.new()
			cloth.start_new_cloth(Vector2i(SIZE, SIZE), TnalakCloth.Axis.ROWS)
			for y in range(SIZE):
				var strand: TnalakCloth.Strand = cloth.strands[y]
				for x in range(SIZE):
					var value := int(target[y][x])
					strand.segments[x] = TnalakCloth.SegmentState.RAW if value == RAW else \
						(TnalakCloth.SegmentState.DYED_RED if value == RED else TnalakCloth.SegmentState.DYED_BLACK)
				strand.stage = TnalakCloth.StrandStage.WOVEN
				strand.dye_id = TnalakCloth.DYE_RED if y % 2 == 0 else TnalakCloth.DYE_BLACK
			cloth.is_complete = true
			cloth.completion = 1.0
			cloth.active_index = -1
			return cloth

		func _gui_input(event: InputEvent) -> void:
			if is_complete or not (event is InputEventMouseButton):
				return
			var click := event as InputEventMouseButton
			if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
				return
			var cell := _cell_at(click.position)
			if cell.x < 0:
				return
			var next := (int(current[cell.y][cell.x]) + 1) % 4
			current[cell.y][cell.x] = next
			var matched := 0
			for y in range(SIZE):
				for x in range(SIZE):
					if int(current[y][x]) == int(target[y][x]):
						matched += 1
			var progress := int(round(float(matched) / float(SIZE * SIZE) * 100.0))
			var message := "Bind the cream highlights, then pass the open warp through the red and black baths."
			if next == RESISTED:
				message = "Resist tied. The dye will stay out of this pixel."
			elif next == RED:
				message = "Red root dye takes. Keep the pixel draft in view."
			elif next == BLACK:
				message = "Black earth dye takes. The motif is emerging."
			step_changed.emit(message, progress)
			if matched == SIZE * SIZE:
				is_complete = true
				pattern_completed.emit()
			accept_event()

		func _draw() -> void:
			var rect := _grid_rect()
			draw_rect(rect.grow(18.0), Palette.EARTH_WOOD)
			draw_rect(rect.grow(18.0), Palette.GOLD_BRASS, false, 2.0)
			for y in range(SIZE):
				for x in range(SIZE):
					var cell := Rect2(rect.position + Vector2(x, y) * rect.size / SIZE, rect.size / SIZE)
					draw_rect(cell, _color_for(int(current[y][x])))
					draw_rect(cell, Palette.alpha(Palette.CREAM_PAPER, 0.22), false, 1.0)
					if int(current[y][x]) == RESISTED:
						draw_line(cell.position + cell.size * 0.25, cell.end - cell.size * 0.25, Palette.GOLD_SUN, 2.0)
						draw_line(Vector2(cell.end.x - cell.size.x * 0.25, cell.position.y + cell.size.y * 0.25), Vector2(cell.position.x + cell.size.x * 0.25, cell.end.y - cell.size.y * 0.25), Palette.GOLD_SUN, 2.0)
			if is_complete:
				draw_rect(rect.grow(7.0 + sin(_pulse * 3.0) * 2.0), Palette.GOLD_SUN, false, 3.0)

		func _color_for(state: int) -> Color:
			match state:
				RESISTED: return Palette.CREAM_PAPER
				RED: return Palette.RED_SACRED
				BLACK: return Palette.BLACK_SOOT
				_: return Palette.CREAM_WARP

		func _grid_rect() -> Rect2:
			var side := minf(size.x - 56.0, size.y - 36.0)
			return Rect2(Vector2((size.x - side) * 0.5, (size.y - side) * 0.5), Vector2(side, side))

		func _cell_at(point: Vector2) -> Vector2i:
			var rect := _grid_rect()
			if not rect.has_point(point):
				return Vector2i(-1, -1)
			var local := point - rect.position
			return Vector2i(clampi(int(local.x / rect.size.x * SIZE), 0, SIZE - 1), clampi(int(local.y / rect.size.y * SIZE), 0, SIZE - 1))
