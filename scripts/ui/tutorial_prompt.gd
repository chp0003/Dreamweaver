class_name TutorialPrompt
extends Control
## Bottom-of-screen hint. Fades in/out and never eats clicks.

var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -420.0
	offset_right = 420.0
	offset_top = -128.0
	offset_bottom = -72.0
	modulate.a = 0.0
	visible = true

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Palette.CREAM_WARP)
	_label.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.92))
	_label.add_theme_constant_override("outline_size", 10)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func show_text(text: String) -> void:
	if _label != null:
		_label.text = text
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, UiMotion.BASE)\
		.set_ease(Tween.EASE_OUT)


func hide_prompt() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, UiMotion.BASE)\
		.set_ease(Tween.EASE_IN)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
