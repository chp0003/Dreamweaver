class_name IsoStage
extends Node2D
## 2.5D stage dressing for every House: far parallax, ambient motes, near
## occluders, and a house-coloured dusk. Gameplay nodes stay in `World`.
##
## Layer stack (back to front):
##   FarBackdrop  z -180  camera-parallax ridges / hanging fiber / ancestors
##   Floor        z -100  (already on IsoFloor)
##   World        y-sort  props, S'lang, enemies
##   AmbientVFX   z  40   motes that read above the floor, below UI

@export var chapter_id := 1
@export var parallax := 0.18

var _far: _FarBackdrop
var _camera: Camera2D
var _origin := Vector2.ZERO


func configure(id: int, camera: Camera2D) -> void:
	chapter_id = id
	_camera = camera
	if _far != null:
		_far.chapter_id = id
		_far.queue_redraw()


func _ready() -> void:
	z_as_relative = false
	_far = _FarBackdrop.new()
	_far.name = "FarBackdrop"
	_far.chapter_id = chapter_id
	_far.z_index = -180
	_far.z_as_relative = false
	add_child(_far)

	var motes := LightMotes.new()
	motes.name = "StageMotes"
	motes.mote_count = 18 if chapter_id == 3 else 26
	motes.warm = chapter_id != 1
	motes.z_index = 40
	add_child(motes)


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	if _camera == null or _far == null:
		return
	var centre := _camera.get_screen_center_position()
	_far.position = (centre - _origin) * parallax


## Scatter near-edge plants/fibers into the y-sorted World so S'lang walks
## behind them. Call after `_build_world()`.
func dress_foreground(host: Node2D, origin_cell: Vector2i, cols: int, rows: int) -> void:
	if host == null or chapter_id == 0:
		return
	var accent := Palette.house_accent(chapter_id)
	var count := 3 if chapter_id == 0 else (6 if chapter_id == 5 else 5)
	for i in range(count):
		var t := float(i) / float(maxi(1, count - 1))
		var cell := Vector2(
			float(origin_cell.x) + t * float(cols - 1),
			float(origin_cell.y + rows) - 0.4 - float(i % 2) * 0.35
		)
		var prop := PlaceholderProp.new()
		prop.prop_label = "NEAR FIBER" if chapter_id == 1 else "NEAR PLANT"
		prop.texture_path = "res://assets/images/props/highland_grass.png"
		prop.position = Iso.cell_to_world(cell)
		prop.prop_size = Vector2(28.0 + float(i % 3) * 10.0, 48.0 + float(i % 2) * 14.0)
		prop.body_color = Palette.sink(accent, 0.35)
		prop.accent_color = accent
		prop.show_label = false
		prop.cast_shadow = true
		prop.blocks_movement = false
		prop.sway_degrees = 3.5
		prop.modulate = Color(1, 1, 1, 0.92)
		host.add_child(prop)


class _FarBackdrop extends Node2D:
	var chapter_id := 1

	func _ready() -> void:
		set_notify_transform(false)

	func _draw() -> void:
		var accent := Palette.house_accent(chapter_id)
		var w := 2200.0
		var h := 900.0
		var origin := Vector2(-w * 0.5, -h * 0.72)
		match chapter_id:
			0:
				_draw_ridges(origin, w, h, Palette.LIVING_MOSS.darkened(0.35), Palette.LIVING_LEAF.darkened(0.2))
				_draw_hanging_fiber(origin, w, Palette.LIVING_LEAF)
			1:
				_draw_ridges(origin, w, h, Palette.BLACK_PITCH, Palette.BLACK_BARK)
				_draw_hanging_fiber(origin, w, Palette.CREAM_STONE)
			2:
				_draw_ridges(origin, w, h, Palette.RED_DEEP, Palette.BLACK_PITCH)
				_draw_vines(origin, w, Palette.RED_SACRED)
			3:
				_draw_ridges(origin, w, h, Palette.DREAM_ABYSS, Palette.GOLD_DEEP)
				_draw_gold_motes(origin, w, h)
			4:
				_draw_ridges(origin, w, h, Palette.DREAM_INDIGO, Palette.CREAM_STONE)
				_draw_ancestors(origin, w, Palette.CREAM_PAPER)
			_:
				_draw_ridges(origin, w, h, Palette.DREAM_NIGHT, Palette.GOLD_DEEP)
				_draw_loom_glyph(origin, w, Palette.GOLD_SACRED)
		draw_rect(Rect2(origin.x, origin.y + h * 0.78, w, h * 0.22),
			Palette.alpha(accent, 0.06))

	func _draw_ridges(origin: Vector2, w: float, h: float, near_c: Color, far_c: Color) -> void:
		for layer in range(3):
			var y := origin.y + h * (0.42 + float(layer) * 0.10)
			var amp := h * (0.08 - float(layer) * 0.015)
			var points := PackedVector2Array()
			points.append(Vector2(origin.x, origin.y + h))
			var steps := 14 + layer * 3
			for i in range(steps + 1):
				var t := float(i) / float(steps)
				var jag := sin(t * PI * float(4 + layer) + float(layer)) * amp
				points.append(Vector2(origin.x + w * t, y - jag))
			points.append(Vector2(origin.x + w, origin.y + h))
			draw_colored_polygon(points, far_c.lerp(near_c, float(layer) / 2.0))

	func _draw_hanging_fiber(origin: Vector2, w: float, ink: Color) -> void:
		for i in range(11):
			var x := origin.x + w * (0.12 + float(i) * 0.07)
			var len := 70.0 + float(i % 4) * 28.0
			draw_line(Vector2(x, origin.y + 40.0), Vector2(x + float(i % 3) * 6.0, origin.y + len),
				Palette.alpha(ink, 0.22), 1.6)

	func _draw_vines(origin: Vector2, w: float, ink: Color) -> void:
		for i in range(7):
			var x := origin.x + w * (0.2 + float(i) * 0.1)
			var pts := PackedVector2Array()
			for s in range(8):
				pts.append(Vector2(x + sin(float(s) * 0.9) * 18.0, origin.y + 80.0 + float(s) * 22.0))
			draw_polyline(pts, Palette.alpha(ink, 0.28), 2.0, true)

	func _draw_gold_motes(origin: Vector2, w: float, h: float) -> void:
		for i in range(16):
			var p := Vector2(origin.x + w * (0.15 + float(i) * 0.045), origin.y + h * 0.28)
			draw_circle(p, 2.0 + float(i % 3), Palette.alpha(Palette.GOLD_SUN, 0.18))

	func _draw_ancestors(origin: Vector2, w: float, ink: Color) -> void:
		for i in range(5):
			var x := origin.x + w * (0.22 + float(i) * 0.12)
			var base := Vector2(x, origin.y + 420.0)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-14, 0), base + Vector2(14, 0),
				base + Vector2(10, -70), base + Vector2(0, -96), base + Vector2(-10, -70),
			]), Palette.alpha(ink, 0.16))

	func _draw_loom_glyph(origin: Vector2, w: float, ink: Color) -> void:
		var c := Vector2(origin.x + w * 0.5, origin.y + 260.0)
		for i in range(5):
			var s := 28.0 + float(i) * 18.0
			draw_polyline(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s * 0.72, 0),
				c + Vector2(0, s), c + Vector2(-s * 0.72, 0), c + Vector2(0, -s),
			]), Palette.alpha(ink, 0.12), 1.4, true)
