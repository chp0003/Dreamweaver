class_name SampleWeave
extends Control
## Main-menu trial of a pixel-drafted T'nalak-inspired cloth. The player ties
## the resist spots, dyes the open warp, then packs each pick into the cloth.

const SCENE := "res://scenes/minigames/SampleWeave.tscn"
const THREADS := 12
const PICKS := 12

const FONT_TITLE := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FONT_BODY := preload("res://assets/fonts/CrimsonPro-Regular.ttf")
const FONT_ITALIC := preload("res://assets/fonts/CrimsonPro-Italic.ttf")

enum Dye { CREAM, RED, BLACK }
enum Phase { TIE_CREAM, TIE_RED, BEAT, FINISHED }

var phase: Phase = Phase.TIE_CREAM
var dream: Array = []
var warp: Array = []
var ties: Array = []

var _busy := false
var _dip_dye := Dye.RED
var _vat := 0.0
var _soaked: Array = []
var _woven := 0
var _slam := 0.0
var _pulse := 0.0
var _match := 0.0
var _painting := false
var _intro_open := true

var _loom: LoomBoard
var _dream_card: DreamCard
var _hint: Label
var _status: Label
var _action: Button
var _intro: Control
var _steps: Array[Label] = []


static func ink(dye: int) -> Color:
	match dye:
		Dye.RED:
			return Palette.RED_SACRED
		Dye.BLACK:
			return Color(0.075, 0.05, 0.042)
		_:
			return Palette.CREAM_WARP


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://assets/themes/dreamweaver.tres") as Theme
	_build()
	_reset_cloth(true)


func _process(delta: float) -> void:
	_pulse += delta
	_slam = move_toward(_slam, 0.0, delta * 2.8)
	if _busy:
		_vat = minf(1.0, _vat + delta / 1.2)
		_loom.vat_level = _vat
		_soak_to(int(floor(_vat * PICKS)))
		if _vat >= 1.0:
			_soak_to(PICKS)
			_finish_dip()
	_loom.slam = _slam
	_loom.pulse = _pulse
	_loom.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		_on_back()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_SPACE and phase == Phase.BEAT and not _busy:
		_try_beat()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and _loom != null:
		_loom.stop_drag()


func _reset_cloth(show_intro := false) -> void:
	dream = _build_dream()
	warp = _filled(Dye.CREAM)
	ties = _blank_bool()
	phase = Phase.TIE_CREAM
	_busy = false
	_vat = 0.0
	_woven = 0
	_slam = 0.0
	_match = 0.0
	_intro_open = show_intro
	if _intro != null:
		_intro.visible = show_intro
	_dream_card.pattern = dream
	_loom.vat_level = 0.0
	_sync_loom()
	_refresh()


func _build_dream() -> Array:
	# Build a real t'nalak motif instead of a placeholder zigzag that looks like
	# random paint. The loom recipe keeps the heritage pattern coherent across rows,
	# so the tie/dye steps actually reflect a woven cloth rather than a flat mockup.
	var loom := ResistDyeLoom.new()
	var raw_pattern := loom.generate_target(Vector2i(THREADS, PICKS), ResistDyeLoom.DYE_BLACK, "kleng")
	var rows: Array = []
	for y in range(raw_pattern.size()):
		var src_row: Array = raw_pattern[y]
		var row: Array = []
		for x in range(src_row.size()):
			var value := int(src_row[x])
			if value == ResistDyeLoom.ThreadState.UNDYED:
				row.append(Dye.CREAM)
			elif value == ResistDyeLoom.DYE_RED:
				row.append(Dye.RED)
			else:
				row.append(Dye.BLACK)
		rows.append(row)
	return rows


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Palette.DREAM_ABYSS
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var floor := ColorRect.new()
	floor.color = Palette.alpha(Palette.EARTH_LOAM, 0.65)
	floor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	floor.offset_top = -150.0
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_steps())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	body.add_child(_build_dream_column())

	_loom = LoomBoard.new()
	_loom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loom.custom_minimum_size = Vector2(560, 420)
	_loom.tie_began.connect(_on_tie_began)
	_loom.tie_dragged.connect(_on_tie_dragged)
	_loom.beat_asked.connect(_try_beat)
	body.add_child(_loom)

	column.add_child(_build_footer())
	_build_intro()


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)

	var eyebrow := Label.new()
	eyebrow.text = "PIXEL-DRAFTED CLOTH"
	eyebrow.add_theme_font_override("font", FONT_BODY)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	titles.add_child(eyebrow)

	var title := Label.new()
	title.text = "Weave a T'nalak-inspired pattern"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Palette.CREAM_WARP)
	titles.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tie the resist pattern, pass the warp through natural dyes, then pack the weft row by row."
	subtitle.add_theme_font_override("font", FONT_ITALIC)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Palette.CREAM_STONE)
	titles.add_child(subtitle)

	var back := Button.new()
	back.text = "Menu"
	back.theme_type_variation = &"GhostButton"
	back.custom_minimum_size = Vector2(120, 40)
	back.pressed.connect(_on_back)
	header.add_child(back)
	return header


func _build_steps() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for word in ["Bind cream", "Dye red", "Bind red", "Dye black", "Pack picks"]:
		var label := Label.new()
		label.text = word
		label.add_theme_font_override("font", FONT_BODY)
		label.add_theme_font_size_override("font_size", 15)
		row.add_child(label)
		_steps.append(label)
	return row


func _build_dream_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(230, 0)
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var eyebrow := Label.new()
	eyebrow.text = "THE FINISHED CLOTH"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", FONT_BODY)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	column.add_child(eyebrow)

	var frame := WovenFrame.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(210, 280)
	frame.lit = true
	frame.draw_kleng = true
	frame.pad = 12
	frame.fill = Palette.alpha(Palette.DREAM_NIGHT, 0.92)
	column.add_child(frame)

	_dream_card = DreamCard.new()
	_dream_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dream_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(_dream_card)

	column.add_child(_swatch(ink(Dye.CREAM), "White — tie first, skip both dyes"))
	column.add_child(_swatch(ink(Dye.RED), "Red — dye once, then tie"))
	column.add_child(_swatch(ink(Dye.BLACK), "Black — leave bare both times"))

	var note := Label.new()
	note.text = "Glowing spots on the loom are the ones you tie right now."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_override("font", FONT_ITALIC)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Palette.CREAM_STONE)
	column.add_child(note)
	return column


func _swatch(color: Color, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(16, 16)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Palette.alpha(Palette.CREAM_STONE, 0.7)
	box.set_border_width_all(1)
	chip.add_theme_stylebox_override("panel", box)
	row.add_child(chip)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_BODY)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Palette.CREAM_PAPER)
	row.add_child(label)
	return row


func _build_footer() -> HBoxContainer:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	footer.add_child(words)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_override("font", FONT_BODY)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Palette.CREAM_WARP)
	words.add_child(_hint)

	_status = Label.new()
	_status.add_theme_font_override("font", FONT_ITALIC)
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	words.add_child(_status)

	_action = Button.new()
	_action.custom_minimum_size = Vector2(220, 52)
	_action.add_theme_font_override("font", FONT_TITLE)
	_action.add_theme_font_size_override("font_size", 15)
	_action.pressed.connect(_on_action)
	footer.add_child(_action)
	return footer


func _on_action() -> void:
	if _busy:
		return
	match phase:
		Phase.TIE_CREAM:
			_begin_dip(Dye.RED)
		Phase.TIE_RED:
			_begin_dip(Dye.BLACK)
		Phase.BEAT:
			_try_beat()
		Phase.FINISHED:
			_reset_cloth(false)


func _on_tie_began(cell: Vector2i) -> void:
	if not _loom.tying or not _spot_wanted(cell):
		_loom.stop_drag()
		return
	_painting = not bool(ties[cell.y][cell.x])
	_apply_tie(cell)


func _spot_wanted(cell: Vector2i) -> bool:
	var wants := _wants()
	if wants.is_empty():
		return false
	return bool(wants[cell.y][cell.x])


func _on_tie_dragged(cell: Vector2i) -> void:
	if not _loom.tying:
		return
	_apply_tie(cell)


func _apply_tie(cell: Vector2i) -> void:
	if _painting and not _spot_wanted(cell):
		return
	if bool(ties[cell.y][cell.x]) == _painting:
		return
	ties[cell.y][cell.x] = _painting
	_sync_loom()
	_status.text = _tie_line()


func _begin_dip(dye: int) -> void:
	if not _ties_complete():
		return
	_busy = true
	_dip_dye = dye
	_vat = 0.0
	_soaked = _blank_bool()
	var wash := 0.4 if dye == Dye.RED else 0.55
	_loom.vat_color = Palette.alpha(ink(dye), wash)
	_loom.vat_level = 0.0
	Audio.play_sfx(Audio.Sfx.BELL)
	_sync_loom()
	_refresh()


func _soak_to(depth: int) -> void:
	var reached := mini(depth, PICKS)
	for i in reached:
		var y := PICKS - 1 - i
		for x in THREADS:
			if bool(_soaked[y][x]):
				continue
			_soaked[y][x] = true
			if not bool(ties[y][x]):
				warp[y][x] = _dip_dye


func _finish_dip() -> void:
	_busy = false
	_loom.vat_level = 0.0
	if _dip_dye == Dye.BLACK:
		for y in PICKS:
			for x in THREADS:
				ties[y][x] = false
		phase = Phase.BEAT
		_woven = 0
	else:
		phase = Phase.TIE_RED
	Audio.play_sfx(Audio.Sfx.CHIME)
	_sync_loom()
	_refresh()


func _try_beat() -> void:
	if phase != Phase.BEAT or _busy or _woven >= PICKS:
		return
	_slam = 1.0
	_loom.slam = 1.0
	if _woven + 1 >= PICKS:
		Audio.play_sfx(Audio.Sfx.SUCCESS)
	else:
		Audio.play_sfx(Audio.Sfx.THUD)
	_woven += 1
	if _woven >= PICKS:
		phase = Phase.FINISHED
		_match = _score()
	_sync_loom()
	_refresh()


func _score() -> float:
	var hit := 0
	for y in PICKS:
		for x in THREADS:
			if int(warp[y][x]) == int(dream[y][x]):
				hit += 1
	return float(hit) / float(THREADS * PICKS)


func _sync_loom() -> void:
	_loom.warp = warp
	_loom.ties = ties
	_loom.dream = dream
	_loom.woven = _woven
	_loom.show_sword = phase == Phase.BEAT
	_loom.tying = not _intro_open and not _busy and (phase == Phase.TIE_CREAM or phase == Phase.TIE_RED)
	_loom.wants = _wants()
	_loom.queue_redraw()
	_dream_card.guide = _guide_mode()
	_dream_card.queue_redraw()


func _wants() -> Array:
	var rows := _blank_bool()
	if _busy or (phase != Phase.TIE_CREAM and phase != Phase.TIE_RED):
		return rows
	for y in PICKS:
		for x in THREADS:
			var color := int(dream[y][x])
			rows[y][x] = color == Dye.CREAM or (phase == Phase.TIE_RED and color == Dye.RED)
	return rows


func _refresh() -> void:
	_paint_steps()
	_hint.text = _hint_for_phase()
	_status.text = _status_for_phase()
	_action.text = _action_for_phase()
	var tying := phase == Phase.TIE_CREAM or phase == Phase.TIE_RED
	_action.disabled = _busy or _intro_open or (tying and not _ties_complete())


func _paint_steps() -> void:
	var active := _active_step()
	for i in _steps.size():
		var label := _steps[i]
		if i == active:
			label.add_theme_color_override("font_color", Palette.GOLD_SACRED)
		elif i < active:
			label.add_theme_color_override("font_color", Palette.CREAM_PAPER)
		else:
			label.add_theme_color_override("font_color", Palette.alpha(Palette.CREAM_STONE, 0.45))


func _active_step() -> int:
	if phase == Phase.BEAT or phase == Phase.FINISHED:
		return 4
	if phase == Phase.TIE_RED:
		return 3 if _busy else 2
	return 1 if _busy else 0


func _guide_mode() -> int:
	if phase == Phase.TIE_CREAM:
		return 0
	if phase == Phase.TIE_RED and not _busy:
		return 1
	return 2


func _ties_complete() -> bool:
	var wants := _wants()
	for y in PICKS:
		for x in THREADS:
			if bool(wants[y][x]) and not bool(ties[y][x]):
				return false
	return true


func _hint_for_phase() -> String:
	if _busy and _dip_dye == Dye.RED:
		return "Watch the bundle. No string means it turns red. A string means it stays white."
	if _busy:
		return "Watch again. No string means it turns black. A string keeps the color it already has."
	match phase:
		Phase.TIE_CREAM:
			return "Click every glowing white spot. That ties a string around it so the dye cannot touch it."
		Phase.TIE_RED:
			return "White stays tied. Now click every glowing red spot. Leave the dark spots alone — those become black."
		Phase.BEAT:
			return "The colors are already on the threads. Press Pack. Each press locks one row into cloth."
		_:
			return "That is the whole craft. Tie what must keep its color, dip the rest, then pack the cloth."


func _status_for_phase() -> String:
	if _busy:
		return "Dyeing the bare thread…"
	match phase:
		Phase.TIE_CREAM, Phase.TIE_RED:
			return _tie_line()
		Phase.BEAT:
			return "Row %d of %d" % [_woven, PICKS]
		_:
			return "White skipped both dyes. Red took one. Black took both."


func _tie_line() -> String:
	var need := 0
	var hit := 0
	var wants := _wants()
	for y in PICKS:
		for x in THREADS:
			if bool(wants[y][x]):
				need += 1
				if bool(ties[y][x]):
					hit += 1
	if hit >= need:
		return "All glowing spots are tied. Dye the bare thread."
	var which := "white" if phase == Phase.TIE_CREAM else "red"
	return "Tied %d of %d %s spots" % [hit, need, which]


func _action_for_phase() -> String:
	if _busy:
		return "DYEING…"
	match phase:
		Phase.TIE_CREAM:
			return "DYE THE REST RED" if _ties_complete() else "TIE EVERY WHITE SPOT"
		Phase.TIE_RED:
			return "DYE THE REST BLACK" if _ties_complete() else "TIE EVERY RED SPOT"
		Phase.BEAT:
			return "PACK NEXT ROW"
		_:
			return "WEAVE AGAIN"


func _build_intro() -> void:
	_intro = Control.new()
	_intro.visible = false
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_intro)

	var dim := ColorRect.new()
	dim.color = Palette.alpha(Palette.DREAM_ABYSS, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(center)

	var frame := WovenFrame.new()
	frame.custom_minimum_size = Vector2(580, 0)
	frame.lit = true
	frame.draw_kleng = true
	frame.header_band = true
	frame.pad = 26
	frame.fill = Palette.alpha(Palette.DREAM_NIGHT, 0.96)
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	var title := Label.new()
	title.text = "One rule"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Palette.CREAM_WARP)
	box.add_child(title)

	for line in [
		"You do not paint the cloth.",
		"You tie string around the spots that must keep their color. Then the whole bundle goes in the dye.",
		"Tied spot stays as it is. Bare spot takes the dye.",
		"White is tied first, so it stays white. Red is dyed, then tied. Black is left bare both times, so it turns black.",
	]:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(520, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FONT_BODY)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Palette.CREAM_PAPER)
		box.add_child(label)

	var start := Button.new()
	start.text = "Start — tie the white spots"
	start.custom_minimum_size = Vector2(320, 52)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_override("font", FONT_TITLE)
	start.add_theme_font_size_override("font_size", 16)
	start.pressed.connect(_on_intro_start)
	box.add_child(start)


func _on_intro_start() -> void:
	_intro_open = false
	if _intro != null:
		_intro.visible = false
	_sync_loom()
	_refresh()


func _on_back() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.MAIN_MENU_SCENE)


func _filled(color: int) -> Array:
	var rows: Array = []
	for _y in PICKS:
		var row: Array = []
		for _x in THREADS:
			row.append(color)
		rows.append(row)
	return rows


func _blank_bool() -> Array:
	var rows: Array = []
	for _y in PICKS:
		var row: Array = []
		row.resize(THREADS)
		row.fill(false)
		rows.append(row)
	return rows


class DreamCard extends Control:
	var pattern: Array = []
	## 0 highlights white, 1 highlights red, 2 shows the whole cloth.
	var guide := 2

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if pattern.is_empty() or size.x < 8.0 or size.y < 8.0:
			return
		var area := Rect2(Vector2.ZERO, size).grow(-4.0)
		draw_rect(area, Palette.EARTH_LOAM)
		var inset := area.grow(-7.0)
		var cw := inset.size.x / SampleWeave.THREADS
		var ch := inset.size.y / SampleWeave.PICKS
		for y in SampleWeave.PICKS:
			for x in SampleWeave.THREADS:
				var color := int(pattern[y][x])
				var cell := Rect2(inset.position.x + x * cw + 1.0, inset.position.y + y * ch + 1.0, cw - 2.0, ch - 2.0)
				var ink := SampleWeave.ink(color)
				var lit := guide == 2 or (guide == 0 and color == SampleWeave.Dye.CREAM) or (guide == 1 and color != SampleWeave.Dye.BLACK)
				if not lit:
					ink.a = 0.28
				draw_rect(cell, ink)
				if guide == 0 and color == SampleWeave.Dye.CREAM:
					draw_rect(cell, Palette.GOLD_SACRED, false, 2.0)
				elif guide == 1 and color == SampleWeave.Dye.RED:
					draw_rect(cell, Palette.GOLD_SACRED, false, 2.0)


class LoomBoard extends Control:
	signal tie_began(cell: Vector2i)
	signal tie_dragged(cell: Vector2i)
	signal beat_asked

	var warp: Array = []
	var ties: Array = []
	var wants: Array = []
	var dream: Array = []
	var woven := 0
	var tying := false
	var show_sword := false
	var slam := 0.0
	var pulse := 0.0
	var vat_level := 0.0
	var vat_color := Color(0, 0, 0, 0)

	var _drag := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(queue_redraw)

	func stop_drag() -> void:
		_drag = false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			if _drag and tying:
				var moved := _cell_at(event.position)
				if moved.x >= 0:
					tie_dragged.emit(moved)
				accept_event()
			return
		if not (event is InputEventMouseButton):
			return
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if not mouse.pressed:
			_drag = false
			return
		if show_sword:
			beat_asked.emit()
			accept_event()
			return
		if not tying:
			return
		var cell := _cell_at(mouse.position)
		if cell.x < 0:
			return
		_drag = true
		tie_began.emit(cell)
		accept_event()

	func _field() -> Rect2:
		return Rect2(36.0, 28.0, maxf(size.x - 72.0, 8.0), maxf(size.y - 52.0, 8.0))

	func _cell_at(pos: Vector2) -> Vector2i:
		var field := _field()
		if not field.has_point(pos) or warp.is_empty():
			return Vector2i(-1, -1)
		var local := pos - field.position
		var x := clampi(int(local.x / (field.size.x / SampleWeave.THREADS)), 0, SampleWeave.THREADS - 1)
		var y := clampi(int(local.y / (field.size.y / SampleWeave.PICKS)), 0, SampleWeave.PICKS - 1)
		return Vector2i(x, y)

	func _draw() -> void:
		if warp.is_empty() or size.x < 16.0:
			return
		var field := _field()
		_draw_frame(field)
		_draw_threads(field)
		if vat_level > 0.01:
			var vat_h := field.size.y * vat_level
			draw_rect(Rect2(field.position.x, field.end.y - vat_h, field.size.x, vat_h), vat_color)
		_draw_ties(field)
		_draw_targets(field)
		if show_sword:
			_draw_sword(field)

	func _draw_frame(field: Rect2) -> void:
		var beam := Rect2(field.position.x - 18.0, field.position.y - 20.0, field.size.x + 36.0, 16.0)
		draw_rect(beam, Palette.EARTH_WOOD)
		draw_rect(Rect2(beam.position, Vector2(beam.size.x, 2.0)), Palette.EARTH_BAMBOO)
		draw_rect(Rect2(beam.position.x, beam.position.y - 3.0, 9.0, 22.0), Palette.GOLD_BRASS)
		draw_rect(Rect2(beam.end.x - 9.0, beam.position.y - 3.0, 9.0, 22.0), Palette.GOLD_BRASS)
		draw_rect(Rect2(field.position.x - 18.0, field.position.y, 10.0, field.size.y), Palette.EARTH_LOAM)
		draw_rect(Rect2(field.end.x + 8.0, field.position.y, 10.0, field.size.y), Palette.EARTH_LOAM)
		var breast := Rect2(field.position.x - 18.0, field.end.y + 4.0, field.size.x + 36.0, 14.0)
		draw_rect(breast, Palette.EARTH_WOOD)
		draw_rect(Rect2(breast.position.x, breast.position.y, 9.0, 16.0), Palette.GOLD_BRASS)
		draw_rect(Rect2(breast.end.x - 9.0, breast.position.y, 9.0, 16.0), Palette.GOLD_BRASS)

	func _draw_threads(field: Rect2) -> void:
		draw_rect(field, Palette.EARTH_LOAM)
		var col_w := field.size.x / SampleWeave.THREADS
		var row_h := field.size.y / SampleWeave.PICKS
		for y in SampleWeave.PICKS:
			var y0 := field.position.y + y * row_h
			if y < woven:
				for x in SampleWeave.THREADS:
					var cell := Rect2(field.position.x + x * col_w + 1.0, y0 + 1.0, col_w - 2.0, row_h - 2.0)
					var color := SampleWeave.ink(int(warp[y][x]))
					draw_rect(cell, color)
					draw_line(cell.position + Vector2(3.0, 0), cell.position + Vector2(3.0, cell.size.y), Palette.alpha(Palette.CREAM_WARP, 0.13), 1.0, true)
				draw_line(
					Vector2(field.position.x, y0 + row_h * 0.5),
					Vector2(field.end.x, y0 + row_h * 0.5),
					Color(0.04, 0.03, 0.025, 0.45),
					1.25,
					true
				)
				continue
			for x in SampleWeave.THREADS:
				if _is_target(x, y):
					continue
				var cx := field.position.x + (x + 0.5) * col_w
				var color := SampleWeave.ink(int(warp[y][x]))
				var width := 14.0 if _is_tied(x, y) else 7.0
				draw_line(Vector2(cx, y0 + 2.0), Vector2(cx, y0 + row_h - 2.0), color, width, true)
				if not _is_tied(x, y):
					draw_line(
						Vector2(cx - 1.6, y0 + 2.0),
						Vector2(cx - 1.6, y0 + row_h - 2.0),
						Palette.alpha(Palette.CREAM_WARP, 0.22),
						1.4,
						true
					)
		if show_sword and woven < SampleWeave.PICKS:
			var y0 := field.position.y + woven * row_h
			draw_rect(
				Rect2(field.position.x, y0, field.size.x, row_h),
				Palette.alpha(Palette.GOLD_SACRED, 0.08)
			)

	func _is_target(x: int, y: int) -> bool:
		return tying and not wants.is_empty() and bool(wants[y][x]) and not bool(ties[y][x])


	func _is_tied(x: int, y: int) -> bool:
		return not ties.is_empty() and bool(ties[y][x])


	func _block(field: Rect2, x: int, y: int) -> Rect2:
		var col_w := field.size.x / SampleWeave.THREADS
		var row_h := field.size.y / SampleWeave.PICKS
		var block_w := maxf(8.0, col_w * 0.52)
		var block_h := maxf(8.0, row_h * 0.48)
		var cx := field.position.x + (x + 0.5) * col_w
		var cy := field.position.y + (y + 0.5) * row_h
		return Rect2(cx - block_w * 0.5, cy - block_h * 0.5, block_w, block_h)


	func _draw_ties(field: Rect2) -> void:
		if ties.is_empty():
			return
		for y in SampleWeave.PICKS:
			if y < woven:
				continue
			for x in SampleWeave.THREADS:
				if not bool(ties[y][x]):
					continue
				var block := _block(field, x, y)
				var color := SampleWeave.ink(int(warp[y][x]))
				draw_rect(block, color)
				for i in 3:
					var t := 0.25 + 0.5 * (float(i) / 2.0)
					var yy := block.position.y + block.size.y * t
					draw_line(
						Vector2(block.position.x + 2.0, yy),
						Vector2(block.end.x - 2.0, yy),
						Palette.GOLD_BRASS,
						1.2,
						true
					)
				draw_circle(Vector2(block.end.x - 3.0, block.position.y + block.size.y * 0.5), 1.5, Palette.GOLD_SUN)


	func _draw_targets(field: Rect2) -> void:
		if not tying or wants.is_empty() or dream.is_empty():
			return
		var breathe := 0.55 + 0.45 * (0.5 + 0.5 * sin(pulse * 3.0))
		for y in SampleWeave.PICKS:
			for x in SampleWeave.THREADS:
				if not _is_target(x, y):
					continue
				var block := _block(field, x, y)
				draw_rect(block, SampleWeave.ink(int(dream[y][x])))
				draw_rect(block.grow(3.0), Palette.alpha(Palette.GOLD_SACRED, breathe), false, 3.0)

	func _draw_sword(field: Rect2) -> void:
		if woven >= SampleWeave.PICKS:
			return
		var row_h := field.size.y / SampleWeave.PICKS
		var y := field.position.y + woven * row_h + row_h * 0.15
		var hover := sin(pulse * 4.0) * 2.5 * (1.0 - slam)
		var kick := -row_h * 0.35 * slam
		var blade := Rect2(field.position.x - 6.0, y + hover + kick, field.size.x + 12.0, 7.0)
		draw_rect(blade, Palette.GOLD_BRASS)
		draw_rect(Rect2(blade.position, Vector2(blade.size.x, 1.5)), Palette.GOLD_SUN)
		draw_rect(Rect2(blade.end.x - 4.0, blade.position.y - 3.0, 8.0, 13.0), Palette.EARTH_WOOD)
