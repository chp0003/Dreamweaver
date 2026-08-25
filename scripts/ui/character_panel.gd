class_name CharacterPanel
extends PanelContainer
## Portrait well for dialogue and the combat stage.


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.glass())
