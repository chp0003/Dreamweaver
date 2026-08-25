class_name HealthBar
extends ProgressBar
## Themed vitality bar: recessed track, glowing fill.


func _ready() -> void:
	show_percentage = false
	add_theme_stylebox_override("background", UiStyle.bar_track(12))
	add_theme_stylebox_override("fill", UiStyle.bar_fill(Palette.RED_SACRED))
