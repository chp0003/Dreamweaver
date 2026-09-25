class_name WallTorch
extends Node2D

## Wall brass for the House of the Golden Sun. Same load path as BrassMirrorStand.

const TEX_PATH := "res://assets/images/props/wall_torch.png"
const FOOTPRINT := Vector2(78.0, 132.0)

var lit := false
var face_right := false

var _sprite: Sprite2D
var _light: PointLight2D
var _pulse := 0.0


func _ready() -> void:
	z_as_relative = true
	z_index = 10
	_add_shadow()
	_load_art()
	_build_light()
	if face_right and _sprite != null:
		_sprite.flip_h = true
	set_lit(false)
	set_process(true)


func get_light() -> PointLight2D:
	return _light


func set_lit(on: bool) -> void:
	lit = on
	if _light != null:
		_light.enabled = on
		if not on:
			_light.energy = 0.0
	if _sprite != null:
		_sprite.modulate = Color(1.18, 1.08, 0.86) if on else Color.WHITE
	if on and is_inside_tree():
		Fx.light_burst(self, Palette.GOLD_SUN)


func _process(delta: float) -> void:
	if not lit or _light == null:
		return
	_pulse += delta * 6.0
	_light.energy = 1.45 + 0.18 * sin(_pulse * 1.3)
	_light.texture_scale = 4.2 + 0.25 * sin(_pulse * 1.7)


func _add_shadow() -> void:
	var shadow := Polygon2D.new()
	shadow.name = "FootShadow"
	shadow.polygon = Iso.diamond(Vector2.ZERO, 0.9)
	shadow.color = Color(0.02, 0.02, 0.04, 0.38)
	shadow.z_index = -1
	shadow.z_as_relative = true
	add_child(shadow)


func _load_art() -> void:
	var texture := _load_texture()
	if texture == null:
		return
	var tex_size := texture.get_size()
	var scale := minf(FOOTPRINT.x / tex_size.x, FOOTPRINT.y / tex_size.y)
	_sprite = Sprite2D.new()
	_sprite.name = "Plate"
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	_sprite.scale = Vector2(scale, scale)
	add_child(_sprite)


func _build_light() -> void:
	_light = PointLight2D.new()
	_light.name = "TorchLight"
	_light.texture = _radial_glow()
	_light.color = Color(1.0, 0.82, 0.48)
	_light.energy = 0.0
	_light.texture_scale = 4.2
	_light.position = Vector2(0.0, -FOOTPRINT.y * 0.62)
	_light.enabled = false
	add_child(_light)


func _radial_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _load_texture() -> Texture2D:
	return Palette.read_texture(TEX_PATH)
