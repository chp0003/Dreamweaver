class_name FiberBin
extends PanelContainer
## A sorting basket in the Fiber Sorting mini-game. Accepts dropped FiberCards.

signal card_dropped(card: FiberCard, bin: FiberBin)

@export var bin_title := "Basket"
@export var bin_hint := ""
## True for the discard basket; the mini-game compares this to the card.
@export var accepts_brittle := false
@export var accent := Color(0.72, 0.6, 0.36)

var _count_label: Label
var _count := 0


func _ready() -> void:
	custom_minimum_size = Vector2(300.0, 120.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _bin_style(false))

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var title := Label.new()
	title.text = bin_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", accent)
	column.add_child(title)

	if not bin_hint.is_empty():
		var hint := Label.new()
		hint.text = bin_hint
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
		column.add_child(hint)

	_count_label = Label.new()
	_count_label.text = "0 strands"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.theme_type_variation = &"FieldLabel"
	column.add_child(_count_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepted := typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("card")
	add_theme_stylebox_override("panel", _bin_style(accepted))
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	add_theme_stylebox_override("panel", _bin_style(false))
	var card := (data as Dictionary)["card"] as FiberCard
	if card != null:
		card_dropped.emit(card, self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_inside_tree():
		add_theme_stylebox_override("panel", _bin_style(false))


func add_count() -> void:
	_count += 1
	_count_label.text = "%d strand%s" % [_count, "" if _count == 1 else "s"]


func reset_count() -> void:
	_count = 0
	_count_label.text = "0 strands"


func _bin_style(highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.09, 0.9) if not highlight \
		else Color(0.2, 0.16, 0.1, 0.95)
	style.border_color = accent if highlight else Color(accent, 0.55)
	style.set_border_width_all(3 if highlight else 2)
	style.set_content_margin_all(10)
	return style
