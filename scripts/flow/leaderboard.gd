extends Control
## Village leaderboard from the Gateway.
##
## Weavers are ranked by how far they have restored the dream: world complete,
## Houses finished, current chapter, then score. Usernames are always shown.

@onready var status_label: Label = %StatusLabel
@onready var row_list: VBoxContainer = %RowList
@onready var you_label: Label = %YouLabel
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %Title

const _COL_GAP := 12
const _RANK_W := 52.0
const _PLACE_W := 200.0
const _HOUSES_W := 88.0
const _SCORE_W := 88.0
const _TITLE_W := 190.0


func _ready() -> void:
	Audio.set_ambience(0.22, 8.0)
	back_button.pressed.connect(_on_back_pressed)
	UiStyle.glow_label(title_label, Palette.DREAM_LANTERN, 12)
	# Shrink, don't fill: a filled list is clamped to the pane and extra
	# weavers get clipped with nothing to scroll.
	row_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var scroll := row_list.get_parent() as ScrollContainer
	if scroll:
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		var frame := scroll.get_parent() as Control
		if frame:
			frame.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.grab_focus()
	await _load_rows()


func _load_rows() -> void:
	status_label.text = "Reading the loom…"
	you_label.text = ""
	_clear_rows()

	var result: Dictionary = await AccountManager.fetch_leaderboard()
	var rows: Array = result.get("rows", [])
	var source := str(result.get("source", "local"))

	if rows.is_empty():
		var err := str(result.get("error", "")).strip_edges()
		if source == "cloud" or not err.is_empty():
			status_label.text = "Signed-in weavers are in Supabase, but this board cannot read them yet. Open the SQL Editor, paste supabase/schema.sql, press Run, then come back."
		else:
			status_label.text = "No weavers on this loom yet. Start a dream to take first place."
		you_label.text = ""
		return

	if source == "cloud":
		status_label.text = "%d weavers, ranked by progress." % rows.size()
	else:
		status_label.text = "%d weavers on this loom, ranked by progress." % rows.size()

	_add_header()
	var you_place := 0
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := entry as Dictionary
		row_list.add_child(_make_row(row, false))
		if bool(row.get("is_you", false)):
			you_place = int(row.get("place_index", 0))

	if you_place > 0:
		you_label.text = "You are #%d — %s" % [you_place, AccountManager.current_username()]
	else:
		you_label.text = ""


func _clear_rows() -> void:
	for child in row_list.get_children():
		child.queue_free()


func _add_header() -> void:
	var header := {
		"place_index": "#",
		"username": "Weaver",
		"place": "Progress",
		"houses": "Houses",
		"score": "Score",
		"rank_title": "Rank",
		"is_you": false,
		"header": true,
	}
	row_list.add_child(_make_row(header, true))


func _make_row(data: Dictionary, header: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 44.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _row_style(data, header))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _COL_GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var rank_text := str(data.get("place_index", ""))
	if not header:
		rank_text = "#%s" % rank_text
	var name_text := str(data.get("username", ""))
	if not header and bool(data.get("is_you", false)):
		name_text = "%s  (you)" % name_text
	var houses_text := str(data.get("houses", ""))
	if not header:
		houses_text = "%d / %d" % [int(data.get("houses", 0)), Houses.count()]
	var score_text := str(data.get("score", ""))
	if not header:
		score_text = str(int(data.get("score", 0)))

	row.add_child(_cell(rank_text, _RANK_W, false, header, data))
	row.add_child(_cell(name_text, 0.0, true, header, data))
	row.add_child(_cell(str(data.get("place", "")), _PLACE_W, false, header, data))
	row.add_child(_cell(houses_text, _HOUSES_W, false, header, data))
	row.add_child(_cell(score_text, _SCORE_W, false, header, data))
	row.add_child(_cell(str(data.get("rank_title", "")), _TITLE_W, false, header, data))
	return panel


func _cell(text: String, width: float, expand: bool, header: bool, data: Dictionary) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.custom_minimum_size = Vector2(width, 0.0)
	label.add_theme_color_override("font_color", _row_color(data, header))
	label.add_theme_font_size_override("font_size", 13 if header else 16)
	return label


func _row_style(data: Dictionary, header: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_right = 8
	box.corner_radius_bottom_left = 8
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if header:
		box.bg_color = Color(0.055, 0.075, 0.149, 0.55)
		box.border_width_bottom = 1
		box.border_color = Color(0.69, 0.541, 0.18, 0.4)
		return box
	if bool(data.get("is_you", false)):
		box.bg_color = Color(0.69, 0.541, 0.18, 0.22)
		box.border_width_left = 1
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 1
		box.border_color = Color(0.929, 0.82, 0.447, 0.65)
		return box
	var place := int(data.get("place_index", 99))
	if place == 1:
		box.bg_color = Color(0.929, 0.82, 0.447, 0.1)
	elif place <= 3:
		box.bg_color = Color(0.086, 0.114, 0.227, 0.72)
	else:
		box.bg_color = Color(0.055, 0.075, 0.149, 0.42)
	return box


func _row_color(data: Dictionary, header: bool) -> Color:
	if header:
		return Color(0.86, 0.72, 0.42, 0.92)
	if bool(data.get("is_you", false)):
		return Palette.GOLD_SUN
	if int(data.get("place_index", 99)) == 1:
		return Palette.DREAM_LANTERN
	return Color(0.94, 0.89, 0.77, 1)


func _on_back_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.MAIN_MENU_SCENE)
