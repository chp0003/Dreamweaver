class_name PlaceholderProp
extends Node2D
## A stand-in for every piece of art this build does not have yet.
##
## If `texture_path` points at a real file the prop draws that sprite. If it does
## not, the prop draws a labelled block plus an isometric base shadow, so the
## scene still reads clearly and every missing asset announces itself on screen.
## Dropping the generated PNG into the named path is the whole hand-off - no
## code changes anywhere.

@export var prop_label := "PROP"
## Where the final pixel art belongs, e.g. res://assets/images/props/vat.png
@export var texture_path := ""
@export var prop_size := Vector2(56.0, 84.0)
@export var body_color := Color(0.3, 0.28, 0.27)
@export var accent_color := Color(0.55, 0.46, 0.3)
@export var show_label := true
@export var cast_shadow := true
## Slow vertical bob, for spirits, ghosts and floating items.
@export var float_amplitude := 0.0
@export var float_speed := 1.6
## When true, adds a StaticBody2D feet-collider on the world physics layer so
## S'lang cannot walk through this prop. Flat floor dressing (mats, grass,
## doorways) should set this false — or rely on `is_soft_label()`.
@export var blocks_movement := true
## Override the auto-sized feet ellipse. Zero = derive from prop_size.
@export var collision_feet := Vector2.ZERO
## Slow rotation for plants, banners and hanging fiber. Degrees peak-to-peak / 2.
@export var sway_degrees := 0.0
## Keep pixel art sharp (hub houses, props that should not soften under zoom).
@export var nearest_filter := false

var _label: Label
var _sprite: Sprite2D
var _base_y := 0.0
var _time := 0.0
var _tint := Color.WHITE
var _blocker: StaticBody2D


func _ready() -> void:
	_base_y = position.y
	_load_texture()
	if show_label and _sprite == null:
		_build_label()
	if blocks_movement:
		_add_world_blocker()
	set_process(float_amplitude > 0.0 or sway_degrees > 0.0)


## Labels / paths that should never block the player (rugs, tufts, open doors…).
static func is_soft_label(label: String, path := "") -> bool:
	var key := (label + " " + path).to_lower()
	const SOFT := [
		"mat", "grass", "strand", "doorway", "door frame", "path marker",
		"flower", "darkness pool", "light shaft", "unfinished", "lewet staff",
		"ancestor banner", "pigment stain", "woven motif", "gray figure",
		"near fiber", "near plant", "highland grass", "runner", "aisle",
		"threshold", "work cloth", "hedge", "boardwalk", "plaza weave",
		"grass tuft", "brass lantern", "bamboo fence",
	]
	for token in SOFT:
		if token in key:
			return true
	return false


## Feet-only StaticBody2D on PhysicsLayers.LAYER_WORLD. Replicate this pattern
## for any custom solid (fence, rock, house) — see scenes/world/SolidPropExample.tscn.
##
## The blocker is reparented onto the same World node as the player so it is a
## sibling physics body (avoids rare nested-transform misses with y-sort trees).
func _add_world_blocker() -> void:
	if _blocker != null or has_node("WorldBlocker"):
		_blocker = get_node_or_null("WorldBlocker") as StaticBody2D
		if _blocker != null:
			return
	_blocker = StaticBody2D.new()
	_blocker.name = "WorldBlocker_%s" % str(get_instance_id())
	_blocker.collision_layer = PhysicsLayers.LAYER_WORLD
	_blocker.collision_mask = PhysicsLayers.MASK_WORLD_STATIC

	var shape := CollisionShape2D.new()
	shape.name = "Feet"
	var radius := 0.0
	if collision_feet != Vector2.ZERO:
		radius = maxf(collision_feet.x, collision_feet.y) * 0.5
	else:
		var kind := _silhouette_kind()
		match kind:
			"house":
				radius = maxf(40.0, prop_size.x * 0.40)
			"plant":
				radius = maxf(16.0, prop_size.x * 0.30)
			"person":
				radius = maxf(18.0, prop_size.x * 0.34)
			_:
				radius = maxf(22.0, prop_size.x * 0.38)
	shape.shape = PhysicsLayers.feet_circle(radius)
	shape.disabled = false
	_blocker.add_child(shape)
	# Enter the tree on this prop first, then move beside the player on World.
	add_child(_blocker)
	call_deferred("_reparent_blocker_to_world")


func _reparent_blocker_to_world() -> void:
	if _blocker == null or not is_instance_valid(_blocker):
		return
	var host := _world_host()
	if host == null or _blocker.get_parent() == host:
		return
	var gp := _blocker.global_position
	var parent := _blocker.get_parent()
	if parent != null:
		parent.remove_child(_blocker)
	host.add_child(_blocker)
	_blocker.global_position = gp


func _world_host() -> Node2D:
	var n: Node = get_parent()
	while n != null:
		if n.name == "World" and n is Node2D:
			return n as Node2D
		n = n.get_parent()
	return get_parent() as Node2D


func _exit_tree() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		_blocker.queue_free()
		_blocker = null



func _process(delta: float) -> void:
	_time += delta * float_speed
	if float_amplitude > 0.0:
		position.y = _base_y + sin(_time) * float_amplitude
	if sway_degrees > 0.0:
		rotation_degrees = sin(_time * 0.85) * sway_degrees


func _draw() -> void:
	if _sprite != null:
		return

	var kind := _silhouette_kind()
	match kind:
		"house":
			_draw_house()
		"person":
			_draw_person()
		"plant":
			_draw_plant()
		_:
			_draw_box()


func _silhouette_kind() -> String:
	var key := (texture_path + " " + prop_label).to_lower()
	if "guno" in key or "house" in key:
		return "house"
	if "slang" in key or "spirit" in key or "weaver" in key or "villager" in key \
			or "minion" in key or "statue" in key or "kdungon" in key:
		return "person"
	if "plant" in key or "grass" in key or "flower" in key or "abaca" in key:
		return "plant"
	return "box"


func _draw_box() -> void:
	var half_w := prop_size.x * 0.5
	if cast_shadow:
		draw_colored_polygon(
			Iso.diamond(Vector2.ZERO, prop_size.x / Iso.HALF.x),
			Color(0, 0, 0, 0.35)
		)
	var body := Rect2(Vector2(-half_w, -prop_size.y), Vector2(prop_size.x, prop_size.y))
	draw_rect(body, body_color * _tint)
	draw_rect(body, (accent_color * _tint), false, 2.0)
	var band_h := maxf(3.0, prop_size.y * 0.06)
	for i in range(2):
		var y := -prop_size.y * (0.62 - 0.24 * float(i))
		draw_rect(
			Rect2(Vector2(-half_w + 4.0, y), Vector2(prop_size.x - 8.0, band_h)),
			(accent_color * _tint) * Color(1, 1, 1, 0.75)
		)


## Stilted Guno Bong: roof, wall band, ladder door. Reads as a house even at HUD scale.
func _draw_house() -> void:
	var w := prop_size.x
	var h := prop_size.y
	var half := w * 0.5
	var ink := body_color * _tint
	var trim := accent_color * _tint
	if cast_shadow:
		draw_colored_polygon(Iso.diamond(Vector2.ZERO, w / Iso.HALF.x), Color(0, 0, 0, 0.4))

	var stilt_w := maxf(3.0, w * 0.06)
	for offset in [-0.55, -0.18, 0.18, 0.55]:
		draw_rect(Rect2(half * offset - stilt_w * 0.5, -h * 0.18, stilt_w, h * 0.22), ink)

	var wall_top := -h * 0.52
	draw_rect(Rect2(-half * 0.82, wall_top, w * 0.82, h * 0.38), ink)
	draw_rect(Rect2(-half * 0.82, wall_top, w * 0.82, h * 0.38), trim, false, 1.5)

	var roof := PackedVector2Array([
		Vector2(-half * 1.05, wall_top + 4.0),
		Vector2(-half * 0.72, wall_top - 6.0),
		Vector2(0.0, -h),
		Vector2(half * 0.72, wall_top - 6.0),
		Vector2(half * 1.05, wall_top + 4.0),
	])
	draw_colored_polygon(roof, ink.darkened(0.15))
	draw_polyline(roof, trim, 1.6)

	var door := Vector2(w * 0.16, h * 0.22)
	draw_rect(Rect2(-door.x * 0.5, wall_top + h * 0.12, door.x, door.y), trim)


func _draw_person() -> void:
	var h := maxf(prop_size.y, 52.0)
	var w := maxf(prop_size.x, 28.0)
	var skin := (body_color if body_color != Color(0.3, 0.28, 0.27) else Palette.EARTH_CLAY) * _tint
	var cloth := accent_color * _tint
	var hair := Palette.BLACK_PITCH * _tint
	if cast_shadow:
		draw_colored_polygon(Iso.diamond(Vector2.ZERO, 1.15), Color(0, 0, 0, 0.45))

	# Skirt / malong — wide trapezoid so she reads at isometric scale.
	var skirt := PackedVector2Array([
		Vector2(-w * 0.48, -h * 0.08),
		Vector2(w * 0.48, -h * 0.08),
		Vector2(w * 0.28, -h * 0.48),
		Vector2(-w * 0.28, -h * 0.48),
	])
	draw_colored_polygon(skirt, cloth)
	draw_rect(Rect2(-w * 0.28, -h * 0.50, w * 0.56, 4.0), Palette.GOLD_DEEP * _tint)
	# Torso.
	draw_rect(Rect2(-w * 0.18, -h * 0.70, w * 0.36, h * 0.24), skin.lightened(0.08))
	# Head + hair.
	draw_circle(Vector2(0.0, -h * 0.80), w * 0.20, skin)
	draw_circle(Vector2(-2.0, -h * 0.86), w * 0.18, hair)
	draw_rect(Rect2(-w * 0.16, -h * 0.84, w * 0.14, h * 0.26), hair)
	# Staff.
	draw_line(Vector2(w * 0.32, -h * 0.04), Vector2(w * 0.26, -h * 0.92), Palette.GOLD_BRASS * _tint, 3.2)
	draw_circle(Vector2(w * 0.26, -h * 0.95), 4.0, Palette.GOLD_SACRED * _tint)


func _draw_plant() -> void:
	if cast_shadow:
		draw_colored_polygon(Iso.diamond(Vector2.ZERO, 0.7), Color(0, 0, 0, 0.3))
	var stem := accent_color * _tint
	var leaf := body_color * _tint
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, -prop_size.y * 0.85), stem, 2.5)
	for i in range(3):
		var y := -prop_size.y * (0.35 + 0.18 * float(i))
		var dir := 1.0 if i % 2 == 0 else -1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, y),
			Vector2(dir * prop_size.x * 0.45, y - 6.0),
			Vector2(0.0, y - 14.0),
		]), leaf)


## Multiplies the placeholder colours (or the sprite) - used when a House is
## still bleached, or when a statue turns from stone into a living NPC.
func set_tint(tint: Color) -> void:
	_tint = tint
	if _sprite != null:
		_sprite.modulate = tint
	queue_redraw()


func get_sprite() -> Sprite2D:
	return _sprite


## Dark pixel rim + warm accent edge so the silhouette separates from grass.
func add_silhouette_rim(accent: Color = Color(1.0, 0.9, 0.7)) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	if has_node("SilhouetteRim"):
		return
	var host := Node2D.new()
	host.name = "SilhouetteRim"
	host.z_as_relative = true
	host.z_index = -1
	add_child(host)
	move_child(host, 0)
	var dark := Color(0.04, 0.03, 0.02, 0.92)
	var warm := Color(accent.r, accent.g, accent.b, 0.55).lightened(0.35)
	for dir in [
		Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2),
		Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2),
	]:
		var outline := Sprite2D.new()
		outline.texture = _sprite.texture
		outline.centered = _sprite.centered
		outline.offset = _sprite.offset + dir
		outline.scale = _sprite.scale
		outline.flip_h = _sprite.flip_h
		outline.texture_filter = _sprite.texture_filter
		outline.modulate = dark
		host.add_child(outline)
	# Soft warm rim toward the plaza light (upper-left bias).
	for dir in [Vector2(-1, -1), Vector2(0, -1), Vector2(-1, 0)]:
		var glow := Sprite2D.new()
		glow.texture = _sprite.texture
		glow.centered = _sprite.centered
		glow.offset = _sprite.offset + dir
		glow.scale = _sprite.scale
		glow.flip_h = _sprite.flip_h
		glow.texture_filter = _sprite.texture_filter
		glow.modulate = warm
		host.add_child(glow)


func set_flip_h(value: bool) -> void:
	if _sprite != null:
		_sprite.flip_h = value
	var rim := get_node_or_null("SilhouetteRim")
	if rim != null:
		for child in rim.get_children():
			if child is Sprite2D:
				(child as Sprite2D).flip_h = value


func set_texture_path(path: String) -> void:
	texture_path = path
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	_load_texture()


func label_text() -> String:
	return prop_label


func _load_texture() -> void:
	if texture_path.is_empty():
		return
	var texture: Texture2D = null
	if ResourceLoader.exists(texture_path):
		var loaded := load(texture_path)
		if loaded is Texture2D:
			texture = loaded
	if texture == null:
		# Freshly-written PNGs may not have a .import yet; load the pixels
		# directly so art still shows up the same session it is dropped in.
		var disk := texture_path
		if disk.begins_with("res://"):
			disk = ProjectSettings.globalize_path(disk)
		if FileAccess.file_exists(disk) or FileAccess.file_exists(texture_path):
			var image := Image.new()
			var path := disk if FileAccess.file_exists(disk) else texture_path
			if image.load(path) == OK:
				texture = ImageTexture.create_from_image(image)
	if texture == null:
		push_warning("PlaceholderProp: failed to load %s" % texture_path)
		queue_redraw()
		return

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST if nearest_filter
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var tex_size := texture.get_size()
	# Scale the art to the prop's footprint so AI sheets of any resolution sit
	# correctly on the isometric cell. Anchor by the feet (bottom centre).
	if tex_size.x > 0.0 and tex_size.y > 0.0 and prop_size != Vector2.ZERO:
		var scale := minf(prop_size.x / tex_size.x, prop_size.y / tex_size.y)
		_sprite.scale = Vector2(scale, scale)
	_sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	_sprite.modulate = _tint
	add_child(_sprite)
	if cast_shadow:
		_add_foot_shadow()
	queue_redraw()


func _add_foot_shadow() -> void:
	if has_node("FootShadow"):
		return
	var shadow := Polygon2D.new()
	shadow.name = "FootShadow"
	var span := clampf(prop_size.x / Iso.HALF.x * 0.42, 0.7, 1.6)
	shadow.polygon = Iso.diamond(Vector2.ZERO, span)
	shadow.color = Color(0.02, 0.02, 0.04, 0.36)
	shadow.z_index = -1
	shadow.z_as_relative = true
	add_child(shadow)
	move_child(shadow, 0)


func _build_label() -> void:
	_label = Label.new()
	_label.text = prop_label
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size = Vector2(prop_size.x + 40.0, 40.0)
	_label.position = Vector2(-(prop_size.x + 40.0) * 0.5, -prop_size.y - 42.0)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
