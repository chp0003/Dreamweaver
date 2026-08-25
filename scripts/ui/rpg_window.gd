class_name RPGWindow
extends PanelContainer
## Framed window for dialogue, pause, and mini-game shells. Same T'nalak chrome.


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.glass_lit())
