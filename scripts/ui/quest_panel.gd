class_name QuestPanel
extends PanelContainer
## Objective plate. HUD instances can attach this script for the shared glass.


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.veil(0.46, 14))
