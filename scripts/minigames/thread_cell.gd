class_name ThreadCell
extends Button
## One square of warp. Cream, bound (gold tie), or dyed. No rules — the board
## tells it what to paint.

signal cell_pressed(cell: Vector2i)

var cell := Vector2i.ZERO

var _tie: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(22.0, 22.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not pressed.is_connected(_emit_pressed):
		pressed.connect(_emit_pressed)
	if _tie == null:
		_tie = Label.new()
		_tie.text = "+"
		_tie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tie.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tie.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tie.add_theme_font_size_override("font_size", 16)
		_tie.add_theme_color_override("font_color", Palette.GOLD_SUN)
		_tie.visible = false
		add_child(_tie)
	set_thread(TnalakCloth.SegmentState.RAW, false)


func set_interactive(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW


func set_thread(state: int, show_tie: bool) -> void:
	var fill := _fill_for(state)
	_apply_fill(fill)
	if _tie != null:
		_tie.visible = show_tie and state == TnalakCloth.SegmentState.RESISTED


func _emit_pressed() -> void:
	cell_pressed.emit(cell)


func _fill_for(state: int) -> Color:
	if state == TnalakCloth.EMPTY:
		return Palette.BLACK_CHARCOAL
	match state:
		TnalakCloth.SegmentState.RESISTED:
			return Palette.CREAM_PAPER
		TnalakCloth.SegmentState.DYED_BLACK:
			return Palette.BLACK_SOOT
		TnalakCloth.SegmentState.DYED_RED:
			return Palette.RED_SACRED
		TnalakCloth.SegmentState.RAW:
			return Palette.CREAM_WARP
		_:
			if state >= TnalakCloth.DYE_CUSTOM_BASE:
				return Palette.EARTH_CLAY
			return Palette.CREAM_WARP


func _apply_fill(color: Color) -> void:
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.1) if kind == "hover" else color
		box.set_corner_radius_all(2)
		if kind == "hover":
			box.border_color = Palette.GOLD_SACRED
			box.set_border_width_all(1)
		add_theme_stylebox_override(kind, box)
