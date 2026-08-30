class_name HouseExit
extends Node2D
## Front threshold of a Guno Bong interior — the way back to the highland ridge.
##
## A modest T'boli house door: cloth-sealed and gray until the House is
## restored, then the woven leaves open.

signal used

const TEX_CLOSED := "res://assets/images/props/guno_door_closed.png"
const TEX_OPEN := "res://assets/images/props/guno_door_open.png"

@export var accent := Palette.GOLD_BRASS
@export var open := false
## Painted interiors already have a porch in the picture. Hide the hut door
## and diamonds; the wooden path itself is the way out.
@export var painted_path := false

var _trigger: Interactable
var _plate: Control
var _tag: Label
var _light: PointLight2D
var _sprite: Sprite2D
var _glow := 0.0
var _time := 0.0


func _ready() -> void:
	z_as_relative = true
	z_index = 8
	_build_trigger()
	if not painted_path:
		_build_art()
		_build_plate()
		_build_light()
	set_open(open, true)
	set_process(not painted_path)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if open:
		_glow = 0.55 + 0.45 * sin(_time * 2.4)
		queue_redraw()
		if _light != null:
			_light.energy = 0.55 + 0.2 * sin(_time * 2.4)


func set_open(value: bool, _instant := false) -> void:
	open = value
	if _trigger != null:
		_trigger.set_enabled(value)
		_trigger.auto_use = value
	if _tag != null:
		_tag.text = "open" if value else "sealed"
		_tag.add_theme_color_override("font_color",
			accent.lightened(0.2) if value else Palette.alpha(Palette.DREAM_MIST, 0.75))
	if _light != null:
		_light.visible = value
	_apply_gate_art()
	queue_redraw()


func set_plate_visible(value: bool) -> void:
	if _plate != null:
		_plate.visible = value


func _build_art() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "GateArt"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.z_as_relative = true
	_sprite.z_index = 2
	add_child(_sprite)
	_apply_gate_art()


func _apply_gate_art() -> void:
	if _sprite == null:
		return
	var path := TEX_OPEN if open else TEX_CLOSED
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			texture = loaded
	elif FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		return
	_sprite.texture = texture
	var tex_size := texture.get_size()
	var target := Vector2(100.0, 140.0)
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var s := minf(target.x / tex_size.x, target.y / tex_size.y)
		_sprite.scale = Vector2(s, s)
	_sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y + 8.0)
	# Standalone 3/4 door, front visible. Do not use a full hut — the room
	# should see a doorway, not a back wall.
	_sprite.flip_h = false
	_sprite.modulate = Color.WHITE if open else Color(0.7, 0.68, 0.64)


func _draw() -> void:
	if painted_path:
		return
	var gold := accent
	var fill := gold if open else Palette.CURSED_ASH
	var a := (0.28 + _glow * 0.22) if open else 0.16
	for i in range(3):
		var y := 10.0 + float(i) * 12.0
		var span := 1.45 - float(i) * 0.1
		draw_colored_polygon(Iso.diamond(Vector2(0.0, y), span), Palette.alpha(fill, a))
	draw_colored_polygon(Iso.diamond(Vector2(0.0, 4.0), 1.5), Color(0.02, 0.02, 0.04, 0.4))


func _build_trigger() -> void:
	_trigger = Interactable.new()
	_trigger.name = "ExitTrigger"
	_trigger.prompt = "Leave" if painted_path else "Leave to the ridge"
	_trigger.radius = 110.0 if painted_path else 78.0
	_trigger.enabled = false
	_trigger.auto_use = false
	_trigger.prompt_offset = Vector2(0.0, -56.0) if painted_path else Vector2(0.0, -168.0)
	_trigger.interacted.connect(func() -> void: used.emit())
	add_child(_trigger)
	if painted_path:
		_stretch_path_trigger()


func _stretch_path_trigger() -> void:
	var box := CollisionShape2D.new()
	box.name = "PathPad"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(240.0, 88.0)
	box.shape = rect
	box.position = Vector2(0.0, 12.0)
	_trigger.add_child(box)


func _build_plate() -> void:
	_plate = VBoxContainer.new()
	_plate.alignment = BoxContainer.ALIGNMENT_CENTER
	_plate.custom_minimum_size = Vector2(220.0, 0.0)
	_plate.size = Vector2(220.0, 48.0)
	_plate.position = Vector2(-110.0, -172.0)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.z_index = 26
	_plate.visible = false
	_plate.add_to_group("world_chrome")
	_plate.add_theme_constant_override("separation", 0)

	var title := Label.new()
	title.text = "TO THE RIDGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Palette.CREAM_WARP)
	title.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.92))
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(title)

	_tag = Label.new()
	_tag.text = "sealed"
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_font_size_override("font_size", 11)
	_tag.add_theme_color_override("font_color", Palette.alpha(Palette.DREAM_MIST, 0.75))
	_tag.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.85))
	_tag.add_theme_constant_override("outline_size", 5)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_tag)
	add_child(_plate)


func _build_light() -> void:
	_light = PointLight2D.new()
	_light.name = "ThresholdLight"
	_light.color = Color(1.0, 0.88, 0.55)
	_light.energy = 0.7
	_light.texture_scale = 1.8
	_light.position = Vector2(0.0, -40.0)
	_light.visible = false
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_light.texture = tex
	add_child(_light)
