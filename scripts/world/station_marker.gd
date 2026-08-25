class_name StationMarker
extends Node2D
## Lit callout over the current workstation. Unlit stations stay quiet so the
## floor numbers can carry the map.

var title := "STATION"
var hint := "[E]"
var lit := false
var _plate: Label


func _ready() -> void:
	z_index = 24
	_plate = Label.new()
	_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_theme_font_size_override("font_size", 13)
	_plate.add_theme_color_override("font_color", Palette.GOLD_SUN)
	_plate.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.92))
	_plate.add_theme_constant_override("outline_size", 8)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.position = Vector2(-90.0, -118.0)
	_plate.size = Vector2(180.0, 28.0)
	_plate.add_to_group("world_chrome")
	add_child(_plate)
	set_lit(false)


func set_lit(on: bool, action := "[E]") -> void:
	lit = on
	hint = action
	if _plate == null:
		return
	_plate.visible = on
	if on:
		_plate.text = "%s  ·  %s" % [title, action]
