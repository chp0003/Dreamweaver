extends MiniGameBase
## Simple vat view: click the live row to bind cream, then dip red or black.
## That row weaves in immediately. Four rows make a cloth.

const BOARD_SCENE := preload("res://scenes/minigames/LoomPatternBoard.tscn")

signal cloth_completed(cloth: TnalakCloth)

@export var grid_size := Vector2i(4, 4)

var last_cloth: TnalakCloth

var _cloth: TnalakCloth
var _hint: Label
var _board: LoomPatternBoard
var _dye_row: HBoxContainer


func _configure() -> void:
	mini_game_title = "T'nalak Weaving"
	mini_game_subtitle = "House of the Black Foundation"
	instructions = "Click the highlighted row to bind cream. Then dip red or black. Repeat for each row."


func _build_content(parent: Control) -> void:
	_cloth = TnalakCloth.new()
	_cloth.segment_changed.connect(_on_segment_changed)
	_cloth.strand_woven.connect(_on_strand_woven)
	_cloth.progress_changed.connect(_on_progress)
	_cloth.cloth_completed.connect(_on_cloth_completed)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	parent.add_child(_hint)

	_board = BOARD_SCENE.instantiate() as LoomPatternBoard
	_board.board_title = "THE CLOTH"
	_board.interactive = true
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.cell_pressed.connect(_on_cell_pressed)
	parent.add_child(_board)

	_dye_row = HBoxContainer.new()
	_dye_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dye_row.add_theme_constant_override("separation", 16)
	parent.add_child(_dye_row)
	_dye_row.add_child(_make_dye_button("Dip red", Palette.RED_SACRED, TnalakCloth.DYE_RED))
	_dye_row.add_child(_make_dye_button("Dip black", Palette.BLACK_SOOT, TnalakCloth.DYE_BLACK))


func _make_dye_button(label: String, fill: Color, dye_id: int) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(180.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(4)
	box.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Palette.CREAM_WARP)
	button.pressed.connect(func() -> void: _on_dye_pressed(dye_id))
	return button


func _reset_round() -> void:
	_cloth.start_new_cloth(grid_size, TnalakCloth.Axis.ROWS)
	_board.rebuild(grid_size, true)
	_paint()
	_refresh_chrome()


func _on_cell_pressed(cell: Vector2i) -> void:
	if not running:
		return
	if cell.y != _cloth.active_index:
		return
	if _cloth.toggle_resist(cell.x):
		Audio.play_sfx(Audio.Sfx.PICKUP)
		_refresh_chrome()


func _on_segment_changed(strand_index: int, segment_index: int, state: int) -> void:
	if _cloth.axis == TnalakCloth.Axis.ROWS:
		_board.set_cell(Vector2i(segment_index, strand_index), state)
	else:
		_board.set_cell(Vector2i(strand_index, segment_index), state)


func _on_strand_woven(_strand_index: int) -> void:
	Audio.play_sfx(Audio.Sfx.CHIME)
	_paint()
	_refresh_chrome()


func _on_progress(completion: float) -> void:
	set_status("Cloth  %d%%" % int(round(completion * 100.0)))


func _on_dye_pressed(dye_id: int) -> void:
	if not running:
		return
	if _cloth.dye_and_weave(dye_id):
		_paint()
		_refresh_chrome()


func _on_cloth_completed(cloth: TnalakCloth) -> void:
	last_cloth = cloth
	cloth_completed.emit(cloth)
	if not running:
		return
	_paint()
	_refresh_chrome()
	succeed("The cloth is finished.")


func _paint() -> void:
	_board.paint(_cloth.display_grid())


func _refresh_chrome() -> void:
	if _hint == null or _cloth == null:
		return
	var strand := _cloth.active_strand()
	_board.interactive = strand != null and not _cloth.is_complete
	_dye_row.visible = strand != null and not _cloth.is_complete
	if strand == null or _cloth.is_complete:
		_hint.text = "The cloth is on the loom."
		return
	_hint.text = "Row %d of %d. Click to bind cream, then dip." % [
		strand.id + 1, _cloth.strand_count()]
	set_status("Bound  %d" % _cloth.resist_count())
