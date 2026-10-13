class_name InventoryOverlay
extends CanvasLayer
## S'lang's satchel. Press I.
## Gear, dye essences, and the notes the ancestor statues ask about.

const FONT_TITLE := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FONT_BODY := preload("res://assets/fonts/CrimsonPro-Regular.ttf")
const GEAR_ICONS := {
	"lewet_staff": preload("res://assets/images/props/lewet_staff.png"),
	"tnalak_cloth": preload("res://assets/images/props/tnalak_cloth.png"),
	"master_pattern": preload("res://assets/images/props/master_pattern_cloth.png"),
}
const DYE_ICONS := {
	"black": preload("res://assets/images/hub_crossroads/icon_dot_black.png"),
	"red": preload("res://assets/images/hub_crossroads/icon_dot_red.png"),
	"gold": preload("res://assets/images/hub_crossroads/icon_dot_gold.png"),
}
const COLS := 6
const MIN_SLOTS := 24

var _open := false
var _dim: ColorRect
var _grid: GridContainer
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _kind: Label
var _title: Label
var _body: Label
var _score_label: Label
var _houses_label: Label
var _notes_label: Label
var _tabs: Dictionary = {}
var _entries: Array[Dictionary] = []
var _filter := "all"
var _selected_id := ""
var _note_icon: Texture2D


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_overlay")
	set_process_input(true)
	_note_icon = _make_note_icon()
	_build()
	_dim.visible = false
	set_process(false)


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	if _open and _blocked():
		close()


func _input(event: InputEvent) -> void:
	if not _is_bag_key(event):
		return
	if _open:
		close()
		get_viewport().set_input_as_handled()
		return
	if _blocked():
		return
	open()
	get_viewport().set_input_as_handled()


func _is_bag_key(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed():
		return false
	if event.is_action_pressed("inventory"):
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.keycode == KEY_I or key.physical_keycode == KEY_I
	return false


func open() -> void:
	if _blocked():
		return
	_open = true
	_dim.visible = true
	_dim.modulate.a = 1.0
	get_tree().paused = true
	set_process(true)
	_fill()


func close() -> void:
	if not _open:
		return
	_open = false
	_dim.visible = false
	set_process(false)
	if not _pause_menu_open():
		get_tree().paused = false


func _blocked() -> bool:
	if _pause_menu_open():
		return true
	return get_tree().get_first_node_in_group("player") == null


func _pause_menu_open() -> bool:
	for node in get_tree().get_nodes_in_group("pause_menu"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.05, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var frame := WovenFrame.new()
	frame.lit = true
	frame.pad = 22
	frame.header_band = false
	frame.fill = Color(0.045, 0.05, 0.09, 0.96)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -548.0
	frame.offset_right = 548.0
	frame.offset_top = -308.0
	frame.offset_bottom = 308.0
	_dim.add_child(frame)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	frame.add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	body.add_child(_build_filters())
	body.add_child(_build_grid())
	body.add_child(_build_detail())

	var hint := Label.new()
	hint.text = "I closes the bag. The notes are what the statues will ask."
	hint.add_theme_font_override("font", FONT_BODY)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Palette.CREAM_STONE)
	root.add_child(hint)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	row.add_child(titles)

	var eyebrow := Label.new()
	eyebrow.text = "SATCHEL"
	eyebrow.add_theme_font_override("font", FONT_TITLE)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	eyebrow.add_theme_constant_override("letter_spacing", 3)
	titles.add_child(eyebrow)

	var heading := Label.new()
	heading.text = "Inventory"
	heading.add_theme_font_override("font", FONT_TITLE)
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	titles.add_child(heading)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 22)
	stats.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(stats)

	_score_label = _stat_label()
	_houses_label = _stat_label()
	_notes_label = _stat_label()
	stats.add_child(_score_label)
	stats.add_child(_houses_label)
	stats.add_child(_notes_label)
	return row


func _stat_label() -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_override("font", FONT_BODY)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Palette.CREAM_WARP)
	return label


func _build_filters() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(176.0, 0.0)
	column.add_theme_constant_override("separation", 8)
	for pair in [["all", "All items"], ["gear", "Gear"], ["dye", "Dye"], ["note", "Notes"]]:
		var tab := Button.new()
		tab.text = pair[1]
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(168.0, 46.0)
		tab.add_theme_font_override("font", FONT_BODY)
		tab.add_theme_font_size_override("font_size", 20)
		tab.add_theme_color_override("font_color", Palette.CREAM_WARP)
		tab.add_theme_color_override("font_hover_color", Palette.GOLD_SUN)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_set_filter.bind(pair[0]))
		column.add_child(tab)
		_tabs[pair[0]] = tab
	_paint_tabs()
	return column


func _build_grid() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	return scroll


func _build_detail() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(292.0, 0.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055, 0.06, 0.11, 0.96)
	box.set_border_width_all(1)
	box.border_color = Palette.alpha(Palette.GOLD_BRASS, 0.7)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	column.add_child(heading)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(64.0, 118.0)
	var portrait_box := StyleBoxFlat.new()
	portrait_box.bg_color = Color(0.04, 0.04, 0.07, 1.0)
	portrait_box.set_border_width_all(1)
	portrait_box.border_color = Palette.alpha(Palette.GOLD_BRASS, 0.8)
	portrait_box.set_corner_radius_all(8)
	portrait_box.content_margin_left = 6
	portrait_box.content_margin_right = 6
	portrait_box.content_margin_top = 6
	portrait_box.content_margin_bottom = 6
	_portrait_frame.add_theme_stylebox_override("panel", portrait_box)
	heading.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(52.0, 106.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_frame.add_child(_portrait)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 4)
	heading.add_child(names)

	_kind = Label.new()
	_kind.add_theme_font_override("font", FONT_TITLE)
	_kind.add_theme_font_size_override("font_size", 13)
	_kind.add_theme_color_override("font_color", Palette.GOLD_BRASS)
	_kind.add_theme_constant_override("letter_spacing", 2)
	names.add_child(_kind)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_override("font", FONT_TITLE)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Palette.GOLD_SACRED)
	names.add_child(_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.color = Palette.alpha(Palette.GOLD_BRASS, 0.45)
	column.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(240.0, 0.0)
	_body.add_theme_font_override("font", FONT_BODY)
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Palette.CREAM_WARP)
	scroll.add_child(_body)
	_show_empty("Choose something she is carrying.")
	return card


func _fill() -> void:
	_entries = _collect()
	_score_label.text = "Score  %s" % _comma(GameState.score)
	_houses_label.text = "Houses  %d / %d" % [GameState.completed_houses.size(), Houses.count()]
	_notes_label.text = "Notes  %d" % GameState.journals.size()
	_paint_grid()


func _collect() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_id in GameState.items:
		var id := str(item_id)
		var text := Houses.item_note(id)
		if text.is_empty():
			text = "S'lang is carrying this."
		entries.append({
			"id": "gear:" + id,
			"kind": "gear",
			"kind_label": "GEAR",
			"title": Houses.item_name(id),
			"text": text,
			"glyph": _glyph_for_item(id),
			"icon": GEAR_ICONS.get(id),
			"tint": Palette.GOLD_BRASS,
		})
	for essence_id in ["black", "red", "gold"]:
		if not GameState.has_essence(essence_id):
			continue
		entries.append({
			"id": "dye:" + essence_id,
			"kind": "dye",
			"kind_label": "DYE",
			"title": Houses.essence_name(essence_id),
			"text": "A colour restored from one of the Houses. It stays with her.",
			"glyph": "dye",
			"icon": DYE_ICONS.get(essence_id),
			"tint": Houses.essence_color(essence_id),
		})
	var house_ids: Array = GameState.journals.duplicate()
	house_ids.sort()
	for house_id in house_ids:
		var note := CultureData.journal_for(int(house_id))
		if note.is_empty():
			continue
		entries.append({
			"id": "note:house:" + str(house_id),
			"kind": "note",
			"kind_label": "NOTE",
			"title": str(note.get("title", "Note")),
			"text": str(note.get("text", "")),
			"glyph": "note",
			"icon": _note_icon,
			"tint": Palette.CREAM_PAPER,
		})
	for lore_id in GameState.lore:
		var entry := CultureData.lore_entry(str(lore_id))
		if entry.is_empty():
			continue
		entries.append({
			"id": "note:lore:" + str(lore_id),
			"kind": "note",
			"kind_label": "NOTE",
			"title": str(entry.get("title", lore_id)),
			"text": str(entry.get("text", "")),
			"glyph": "note",
			"icon": _note_icon,
			"tint": Palette.CREAM_STONE,
		})
	return entries


func _glyph_for_item(item_id: String) -> String:
	match item_id:
		"lewet_staff":
			return "staff"
		"tnalak_cloth":
			return "cloth"
		"light_beam":
			return "beam"
		_:
			return "pattern"


func _set_filter(kind: String) -> void:
	_filter = kind
	_paint_tabs()
	if _open:
		_paint_grid()


func _paint_tabs() -> void:
	for kind in _tabs.keys():
		var tab := _tabs[kind] as Button
		var on := str(kind) == _filter
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.1, 0.11, 0.18, 0.95) if on else Color(0.05, 0.055, 0.09, 0.35)
		box.set_border_width_all(2 if on else 1)
		box.border_color = Palette.GOLD_BRASS if on else Palette.alpha(Palette.CREAM_STONE, 0.28)
		box.set_corner_radius_all(8)
		box.content_margin_left = 16
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		for state in ["normal", "hover", "pressed", "focus"]:
			tab.add_theme_stylebox_override(state, box)


func _paint_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.free()
	var shown := _filtered()
	var slot_count := maxi(MIN_SLOTS, shown.size())
	var remainder := slot_count % COLS
	if remainder != 0:
		slot_count += COLS - remainder
	var pick := -1
	for index in shown.size():
		if str(shown[index].get("id", "")) == _selected_id:
			pick = index
			break
	if pick < 0 and not shown.is_empty():
		pick = 0
		_selected_id = str(shown[0].get("id", ""))
	for index in slot_count:
		var slot := BagSlot.new()
		if index < shown.size():
			var entry: Dictionary = shown[index]
			slot.setup(entry)
			slot.pressed.connect(_choose.bind(entry, slot))
			if index == pick:
				slot.chosen = true
				_show_entry(entry)
		else:
			slot.setup({})
		_grid.add_child(slot)
	if shown.is_empty():
		_selected_id = ""
		_show_empty("Nothing in this fold yet.")


func _filtered() -> Array[Dictionary]:
	if _filter == "all":
		return _entries
	var shown: Array[Dictionary] = []
	for entry in _entries:
		if str(entry.get("kind", "")) == _filter:
			shown.append(entry)
	return shown


func _choose(entry: Dictionary, slot: BagSlot) -> void:
	_selected_id = str(entry.get("id", ""))
	for child in _grid.get_children():
		var other := child as BagSlot
		if other == null:
			continue
		other.chosen = other == slot
		other.queue_redraw()
	_show_entry(entry)


func _show_entry(entry: Dictionary) -> void:
	_kind.text = str(entry.get("kind_label", ""))
	_title.text = str(entry.get("title", ""))
	_body.text = str(entry.get("text", ""))
	_set_portrait(entry.get("icon") as Texture2D)


func _show_empty(message: String) -> void:
	_kind.text = "SATCHEL"
	_title.text = "Empty"
	_body.text = message
	_set_portrait(null)


func _set_portrait(texture: Texture2D) -> void:
	_portrait.texture = texture
	_portrait_frame.visible = texture != null


func _make_note_icon() -> Texture2D:
	var image := Image.create(96, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var paper := Color(0.965, 0.925, 0.835, 1.0)
	var page := Rect2i(16, 12, 64, 102)
	image.fill_rect(Rect2i(page.position.x + 5, page.position.y + 6, page.size.x, page.size.y), Color(0.04, 0.03, 0.02, 0.4))
	image.fill_rect(page, paper)
	image.fill_rect(Rect2i(page.position.x, page.position.y, 8, page.size.y), Color(0.4, 0.26, 0.15, 1.0))
	image.fill_rect(Rect2i(page.position.x + page.size.x - 4, page.position.y, 4, page.size.y), Color(0.78, 0.7, 0.56, 1.0))
	for stitch in 6:
		image.fill_rect(Rect2i(page.position.x + 2, page.position.y + 12 + stitch * 14, 3, 6), Color(0.93, 0.86, 0.72, 1.0))
	var ink := Color(0.28, 0.18, 0.11, 0.88)
	for line in 5:
		var width := 34 if line == 4 else 40
		image.fill_rect(Rect2i(page.position.x + 16, page.position.y + 24 + line * 14, width, 2), ink)
	image.fill_rect(Rect2i(page.position.x + 28, page.position.y, 5, 24), Color(0.62, 0.16, 0.13, 1.0))
	var fold := 18
	var x0 := page.position.x + page.size.x - fold
	var y0 := page.position.y
	for yy in fold:
		for xx in fold:
			if xx + yy >= fold:
				continue
			var shade := xx + yy >= fold - 7
			var color := Color(0.8, 0.72, 0.58, 1.0) if shade else Color(0, 0, 0, 0)
			image.set_pixel(x0 + xx, y0 + yy, color)
	return ImageTexture.create_from_image(image)


func _comma(value: int) -> String:
	var text := str(absi(value))
	var grouped := ""
	while text.length() > 3:
		grouped = "," + text.substr(text.length() - 3) + grouped
		text = text.substr(0, text.length() - 3)
	grouped = text + grouped
	if value < 0:
		return "-" + grouped
	return grouped


class BagSlot extends Button:
	var glyph := ""
	var tint := Palette.GOLD_BRASS
	var art: Texture2D
	var chosen := false
	var filled := false

	func _init() -> void:
		custom_minimum_size = Vector2(82.0, 82.0)
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)

	func setup(entry: Dictionary) -> void:
		filled = not entry.is_empty()
		glyph = str(entry.get("glyph", ""))
		art = entry.get("icon") as Texture2D
		tint = entry.get("tint", Palette.GOLD_BRASS) as Color
		disabled = not filled
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if filled else Control.CURSOR_ARROW
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
		var fill := Color(0.07, 0.075, 0.12, 1.0)
		if chosen:
			fill = Color(0.12, 0.1, 0.07, 1.0)
		draw_rect(rect, fill, true)
		var border := Palette.alpha(Palette.CREAM_STONE, 0.16)
		var width := 1.5
		if filled:
			border = Palette.alpha(tint, 0.9)
			width = 2.0
		if chosen:
			border = Palette.GOLD_SUN
			width = 2.5
		draw_rect(rect, border, false, width)
		if not filled:
			return
		if art != null:
			_draw_icon(rect)
		else:
			_draw_glyph(rect.get_center())

	func _draw_icon(slot: Rect2) -> void:
		var tex_size := art.get_size()
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			return
		var box := Rect2(slot.position + Vector2(7.0, 6.0), slot.size - Vector2(14.0, 12.0))
		var scale := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
		var draw_size := tex_size * scale
		var pos := box.position + (box.size - draw_size) * 0.5
		draw_texture_rect(art, Rect2(pos, draw_size), false)

	func _draw_glyph(centre: Vector2) -> void:
		match glyph:
			"staff":
				draw_line(centre + Vector2(0.0, -16.0), centre + Vector2(0.0, 16.0), tint, 3.0)
				draw_line(centre + Vector2(-9.0, -6.0), centre + Vector2(9.0, -6.0), tint, 3.0)
			"cloth":
				draw_rect(Rect2(centre + Vector2(-12.0, -14.0), Vector2(24.0, 28.0)), tint, false, 2.0)
				draw_line(centre + Vector2(-8.0, -4.0), centre + Vector2(8.0, 2.0), tint, 2.0)
				draw_line(centre + Vector2(-8.0, 6.0), centre + Vector2(8.0, -2.0), tint, 2.0)
			"beam":
				draw_line(centre + Vector2(0.0, -14.0), centre + Vector2(0.0, 14.0), tint, 2.0)
				draw_line(centre + Vector2(-10.0, 0.0), centre + Vector2(10.0, 0.0), tint, 2.0)
				draw_line(centre + Vector2(-7.0, -7.0), centre + Vector2(7.0, 7.0), tint, 2.0)
				draw_line(centre + Vector2(7.0, -7.0), centre + Vector2(-7.0, 7.0), tint, 2.0)
			"dye":
				draw_circle(centre, 11.0, tint)
			"note":
				draw_rect(Rect2(centre + Vector2(-11.0, -14.0), Vector2(22.0, 28.0)), tint, false, 2.0)
				draw_line(centre + Vector2(-6.0, -4.0), centre + Vector2(6.0, -4.0), tint, 2.0)
				draw_line(centre + Vector2(-6.0, 2.0), centre + Vector2(6.0, 2.0), tint, 2.0)
				draw_line(centre + Vector2(-6.0, 8.0), centre + Vector2(2.0, 8.0), tint, 2.0)
			_:
				draw_colored_polygon(PackedVector2Array([
					centre + Vector2(0.0, -13.0),
					centre + Vector2(12.0, 0.0),
					centre + Vector2(0.0, 13.0),
					centre + Vector2(-12.0, 0.0),
				]), tint)
