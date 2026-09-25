extends MiniGameBase

## Chapter 1 vat — simple matching. Click a strand, then its twin.
## Completing every pair reveals a finished T'nalak cloth.

signal cloth_completed(cloth: TnalakCloth)

const CLOTH_PATH := "res://assets/images/props/tnalak_cloth.png"

var last_cloth: TnalakCloth

var _hint: Label
var _board: ConnectBoard
var _cloth_tex: Texture2D


func _configure() -> void:
	mini_game_title = "T'nalak Weaving"
	mini_game_subtitle = "House of the Black Foundation"
	instructions = "Click a coloured strand, then click its matching colour. Join all four pairs and the T'nalak appears."
	time_limit = 0.0
	max_attempts = 3
	reward_score = 320


func _build_content(parent: Control) -> void:
	_cloth_tex = _load_cloth_texture()

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	parent.add_child(_hint)

	_board = ConnectBoard.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(420.0, 280.0)
	_board.cloth_texture = _cloth_tex
	_board.pair_joined.connect(_on_pair_joined)
	_board.mismatch.connect(_on_mismatch)
	_board.all_joined.connect(_on_all_joined)
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
	_hint.text = "Click a strand, then its match."
	set_status("Join the sorted abaca. 0 of 4.")


func _on_pair_joined(joined: int, total: int) -> void:
	if not running:
		return
	Audio.play_sfx(Audio.Sfx.CHIME)
	_hint.text = "Strand in. %d of %d." % [joined, total]
	set_status("Joined  %d / %d" % [joined, total])


func _on_mismatch() -> void:
	if not running:
		return
	Audio.play_sfx(Audio.Sfx.FAIL)
	_hint.text = "Those two are not the same fibre. Try another pair."


func _on_all_joined() -> void:
	if not running:
		return
	last_cloth = _board.to_cloth()
	cloth_completed.emit(last_cloth)
	_hint.text = "The T'nalak is finished."
	set_status("Cloth complete.")
	set_result_texture(_cloth_tex)
	succeed("The first T'nalak holds — cream, red, and black, as the dream gave it.")


## Two columns of coloured knobs. Click a colour, then its twin.
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
