class_name RPGButton
extends Button
## Shared Dreamweaver action button: T'nalak earth fill, gold hairline, cream type.


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 40.0)
	add_theme_stylebox_override("normal", UiStyle.button(Palette.EARTH_LOAM, 0.82, 0.0, 0.4))
	add_theme_stylebox_override("hover", UiStyle.button(Palette.RED_DEEP, 0.88, 0.18, 0.55))
	add_theme_stylebox_override("pressed", UiStyle.button(Palette.BLACK_PITCH, 0.92, 0.0, 0.35))
	add_theme_color_override("font_color", Palette.CREAM_WARP)
	add_theme_color_override("font_hover_color", Palette.GOLD_SUN)
	add_theme_color_override("font_pressed_color", Palette.GOLD_BRASS)
