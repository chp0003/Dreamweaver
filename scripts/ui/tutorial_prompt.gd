class_name TutorialPrompt
extends Control
## Bottom hint card: glass pane, keycaps, one action at a time.

const FONT_TITLE := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FONT_BODY := preload("res://assets/fonts/CrimsonPro-Regular.ttf")
const KEY_SIZE := Vector2(36.0, 36.0)

var _frame: WovenFrame
var _eyebrow: Label
var _title: Label
var _body: Label
var _keys_host: VBoxContainer
var _check: Label
var _key_nodes: Dictionary = {}
var _tween: Tween
var _shimmers: Array[Tween] = []


func _ready() -> void:
	add_to_group("tutorial_hint")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://assets/themes/dreamweaver.tres")
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -230.0
	offset_right = 230.0
	offset_top = -228.0
	offset_bottom = -22.0
	modulate.a = 0.0
	visible = true

	_frame = WovenFrame.new()
	_frame.lit = true
	_frame.pad = 16
	_frame.header_band = true
	_frame.draw_kleng = true
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(col)

	_eyebrow = Label.new()
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.add_theme_font_override("font", FONT_TITLE)
	_eyebrow.add_theme_font_size_override("font_size", 12)
	_eyebrow.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	_eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.outline_label(_eyebrow, 4)
	col.add_child(_eyebrow)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", FONT_TITLE)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Palette.GOLD_SUN)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.glow_label(_title, Palette.DREAM_LANTERN, 8)
	col.add_child(_title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(400.0, 0.0)
	_body.add_theme_font_override("font", FONT_BODY)
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", Palette.CREAM_WARP)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.outline_label(_body, 5)
	col.add_child(_body)

	_keys_host = VBoxContainer.new()
	_keys_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_keys_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys_host.add_theme_constant_override("separation", 6)
	_keys_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_keys_host)

	_check = Label.new()
	_check.text = "✓"
	_check.visible = false
	_check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check.add_theme_font_override("font", FONT_TITLE)
	_check.add_theme_font_size_override("font_size", 28)
	_check.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.glow_label(_check, Palette.GOLD_SUN, 12)
	col.add_child(_check)


func show_hint(title: String, body: String, keys: Array = [],
		step := 1, total := 3, layout := "row") -> void:
	_eyebrow.text = "LESSON  %d  /  %d" % [step, total]
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	_check.visible = false
	_rebuild_keys(keys, layout)
	_kill_tween()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, UiMotion.BASE)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func show_text(text: String) -> void:
	show_hint("", text)


func light_key(glyph: String) -> void:
	var key: PanelContainer = _key_nodes.get(glyph.to_upper()) as PanelContainer
	if key == null:
		return
	key.add_theme_stylebox_override("panel", _key_style(true))
	var label := key.get_node_or_null("Glyph") as Label
	if label != null:
		label.add_theme_color_override("font_color", Palette.GOLD_SUN)


func celebrate(done_title := "Got it") -> void:
	_stop_shimmers()
	_eyebrow.text = "COMPLETE"
	_title.text = done_title
	_body.visible = false
	_keys_host.visible = false
	_check.visible = true
	UiMotion.bloom(_check, 0.0, UiMotion.BASE)
	await get_tree().create_timer(0.85).timeout
	hide_prompt()
	await get_tree().create_timer(UiMotion.FAST).timeout


func hide_prompt() -> void:
	_stop_shimmers()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, UiMotion.FAST)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


func _rebuild_keys(keys: Array, layout: String) -> void:
	_stop_shimmers()
	for child in _keys_host.get_children():
		child.queue_free()
	_key_nodes.clear()
	_keys_host.visible = not keys.is_empty()
	if keys.is_empty():
		return
	if layout == "wasd" and keys.size() >= 4:
		_build_wasd()
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keys_host.add_child(row)
		for glyph in keys:
			row.add_child(_make_key(str(glyph)))
	for key in _key_nodes.values():
		if key is CanvasItem:
			var tw := UiMotion.shimmer(key as CanvasItem, 0.72, 1.0, 1.6)
			if tw != null:
				_shimmers.append(tw)


func _build_wasd() -> void:
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_host.add_child(top)
	top.add_child(_make_key("W"))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 6)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_host.add_child(bottom)
	bottom.add_child(_make_key("A"))
	bottom.add_child(_make_key("S"))
	bottom.add_child(_make_key("D"))


func _make_key(glyph: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var wide := glyph.length() > 1
	cap.custom_minimum_size = Vector2(72.0 if wide else KEY_SIZE.x, KEY_SIZE.y)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", _key_style(false))
	var label := Label.new()
	label.name = "Glyph"
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_TITLE)
	label.add_theme_font_size_override("font_size", 13 if wide else 16)
	label.add_theme_color_override("font_color", Palette.CREAM_WARP)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(label)
	_key_nodes[glyph.to_upper()] = cap
	return cap


func _key_style(lit: bool) -> StyleBoxFlat:
	var fill := Palette.GOLD_DEEP if lit else Palette.DREAM_INDIGO
	var border := Palette.GOLD_SACRED if lit else Palette.GOLD_BRASS
	var box := UiStyle.glass(fill, 0.9 if lit else 0.78, 6, border, 0.7 if lit else 0.4)
	box.set_corner_radius_all(UiStyle.RADIUS_SMALL)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	if lit:
		box.shadow_color = Palette.alpha(Palette.DREAM_LANTERN, 0.28)
		box.shadow_size = 12
	return box


func _stop_shimmers() -> void:
	for tw in _shimmers:
		if tw != null and tw.is_valid():
			tw.kill()
	_shimmers.clear()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
