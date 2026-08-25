class_name Tooltip
extends PanelContainer
## Floating help chip. Cream type on a dark woven pane.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.glass())


func set_text(value: String) -> void:
	var label := get_node_or_null("Label") as Label
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Palette.CREAM_WARP)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
	label.text = value
