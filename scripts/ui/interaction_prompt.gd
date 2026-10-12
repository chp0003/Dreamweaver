class_name InteractionPrompt
extends Label
## World [E] prompt. Interactable builds one of these above a trigger.


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Palette.CREAM_WARP)
	add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.92))
	add_theme_constant_override("outline_size", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	add_to_group("world_chrome")
