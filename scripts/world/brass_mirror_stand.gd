class_name BrassMirrorStand
extends Node2D
## Floor brass for the House of the Golden Sun. Same language as the painted
## bells and spindle: a turned wooden foot and an oval plate, not a UI card.

const TEX_PATH := "res://assets/images/props/brass_mirror.png"
const FOOTPRINT := Vector2(92.0, 156.0)

var facing := 0
var beam_hit := false

var _sprite: Sprite2D
var _draw_fallback := false


func _ready() -> void:
	z_as_relative = true
	_add_shadow()
	_load_art()
	set_facing(facing, true)


func set_facing(value: int, instant := false) -> void:
	facing = value
	# Slash leans toward the window; backslash toward the spindle wall.
	var target := -0.22 if value == 0 else 0.22
	if _sprite != null:
		_sprite.flip_h = value != 0
	if instant or not is_inside_tree():
		rotation = target
		return
	var tween := create_tween()
	tween.tween_property(self, "rotation", target, 0.18).set_trans(Tween.TRANS_SINE)


func set_beam_hit(on: bool) -> void:
	beam_hit = on
	if _sprite != null:
		_sprite.modulate = Color(1.22, 1.10, 0.82) if on else Color.WHITE
	queue_redraw()


func _add_shadow() -> void:
	var shadow := Polygon2D.new()
	shadow.name = "FootShadow"
	shadow.polygon = Iso.diamond(Vector2.ZERO, 1.15)
	shadow.color = Color(0.02, 0.02, 0.04, 0.38)
	shadow.z_index = -1
	shadow.z_as_relative = true
	add_child(shadow)


func _load_art() -> void:
	var texture := _load_texture()
	if texture == null:
		_draw_fallback = true
		queue_redraw()
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


func _draw() -> void:
	if not _draw_fallback:
		return
	draw_colored_polygon(Iso.diamond(Vector2.ZERO, 1.05), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-10.0, -28.0, 20.0, 28.0), Palette.EARTH_WOOD)
	draw_circle(Vector2(0.0, -62.0), 26.0, Palette.GOLD_BRASS)
	draw_arc(Vector2(0.0, -62.0), 26.0, 0.0, TAU, 24, Palette.GOLD_SACRED, 2.4)


func _load_texture() -> Texture2D:
	var disk := ProjectSettings.globalize_path(TEX_PATH)
	if FileAccess.file_exists(disk):
		var image := Image.new()
		if image.load(disk) == OK:
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(TEX_PATH):
		var loaded := load(TEX_PATH)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null
