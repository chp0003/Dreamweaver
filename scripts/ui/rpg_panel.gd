class_name RPGPanel
extends PanelContainer
## Standard glass pane used by HUD plates, tooltips and inventory slots.


func _ready() -> void:
	if get_theme_stylebox("panel") == null or not has_theme_stylebox_override("panel"):
		add_theme_stylebox_override("panel", UiStyle.glass())
