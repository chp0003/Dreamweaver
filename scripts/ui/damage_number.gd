class_name DamageNumber
extends Label
## World-space hit numeral. Prefer Fx.damage_number() so chapters stay one-liners.


func present(amount: int, color := Palette.RED_EMBER) -> void:
	text = str(amount)
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Palette.DREAM_ABYSS)
	add_theme_constant_override("outline_size", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 36.0, 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(queue_free)
