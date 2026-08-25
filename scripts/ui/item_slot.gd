class_name ItemSlot
extends PanelContainer
## Inventory well. Empty slots stay dark; occupied slots pick up a gold hairline.

@export var occupied := false


func _ready() -> void:
	custom_minimum_size = Vector2(48.0, 48.0)
	_refresh()


func set_occupied(value: bool) -> void:
	occupied = value
	_refresh()


func _refresh() -> void:
	add_theme_stylebox_override("panel",
		UiStyle.glass_lit() if occupied else UiStyle.glass(Palette.DREAM_NIGHT, 0.7, 8))
