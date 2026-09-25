class_name BrassMirrorStand
extends Node2D

## The oval brass plate, standing. The wooden vanity, yoke, and side knobs
## are cropped off. The plate stays upright so it reads as a mirror.

const TEX_PATH := "res://assets/images/props/brass_mirror.png"
const PLATE_H := 112.0

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
		_sprite.modulate = Color(1.28, 1.12, 0.78) if on else Color.WHITE
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
	var scale := PLATE_H / maxf(tex_size.y, 1.0)
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
	var centre := Vector2(0.0, -PLATE_H * 0.5)
	draw_circle(centre, 34.0, Palette.GOLD_BRASS)
	draw_arc(centre, 34.0, 0.0, TAU, 32, Palette.GOLD_SACRED, 3.0)


func _load_texture() -> Texture2D:
	var image := _load_image()
	if image == null:
		return null
	var plate := _extract_disc(image)
	if plate == null:
		return ImageTexture.create_from_image(image)
	return ImageTexture.create_from_image(plate)


func _load_image() -> Image:
	return Palette.read_image(TEX_PATH)


## Keeps the standing oval plate. Drops the wooden foot, the yoke, and the
## side knobs, which are thin compared with the brass frame.
func _extract_disc(source: Image) -> Image:
	var src: Image = source.duplicate() as Image
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var width: int = src.get_width()
	var height: int = src.get_height()
	var scan_h: int = int(height * 0.62)
	var col_count := PackedInt32Array()
	col_count.resize(width)
	var max_col := 0
	for y in range(scan_h):
		for x in range(width):
			if not _is_plate(src.get_pixel(x, y)):
				continue
			col_count[x] += 1
			max_col = maxi(max_col, col_count[x])
	if max_col < 8:
		return null
	var min_x := width
	var max_x := 0
	var gate := int(max_col * 0.34)
	for x in range(width):
		if col_count[x] < gate:
			continue
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
	if max_x <= min_x:
		return null
	var min_y := scan_h
	var max_y := 0
	var row_w := PackedInt32Array()
	row_w.resize(scan_h)
	var widest := 0
	for y in range(scan_h):
		var left := -1
		var right := -1
		for x in range(min_x, max_x + 1):
			if not _is_plate(src.get_pixel(x, y)):
				continue
			if left < 0:
				left = x
			right = x
		if left < 0:
			continue
		row_w[y] = right - left
		widest = maxi(widest, row_w[y])
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)
	var body := int(widest * 0.45)
	var bottom := min_y
	for y in range(min_y, max_y + 1):
		if row_w[y] >= body:
			bottom = y
	max_y = bottom
	var centre := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var rx := (max_x - min_x) * 0.5 + 2.0
	var ry := (max_y - min_y) * 0.5 + 2.0
	var crop_x := maxi(0, int(floor(centre.x - rx)))
	var crop_y := maxi(0, int(floor(centre.y - ry)))
	var crop_r := mini(width - 1, int(ceil(centre.x + rx)))
	var crop_b := mini(height - 1, int(ceil(centre.y + ry)))
	var cw := crop_r - crop_x + 1
	var ch := crop_b - crop_y + 1
	if cw < 8 or ch < 8:
		return null
	var plate := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	plate.fill(Color(0, 0, 0, 0))
	for y in range(ch):
		for x in range(cw):
			var sx := crop_x + x
			var sy := crop_y + y
			var nx := (float(sx) - centre.x) / rx
			var ny := (float(sy) - centre.y) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var color: Color = src.get_pixel(sx, sy)
			if color.a < 0.08:
				continue
			plate.set_pixel(x, y, color)
	return plate


func _is_plate(color: Color) -> bool:
	if color.a < 0.12:
		return false
	return color.r > 0.38 and color.g > 0.22 and color.r > color.b + 0.1 and color.g > color.b * 0.85
