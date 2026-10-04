@tool
extends Node2D
## Editor-only stand-ins for the people who spawn on this hall.
## Hidden when the game runs. Feet sit on the same UV as the chapter plate.

const FUN := "res://assets/images/characters/fun_kdungon.png"
const CHIEF := "res://assets/images/characters/the_chief.png"
const QUEEN := "res://assets/images/characters/harvest_queen.png"
const SLANG := "res://assets/images/characters/slang_8dir/idle_down.png"
const SLANG_FRAME_H := 192.0
const PLAYER_SCALE := 2.6

var _marks: Array[Dictionary] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	else:
		visible = false
		queue_free()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_rebuild")


func _rebuild() -> void:
	if not Engine.is_editor_hint():
		return
	for child in get_children():
		child.free()
	_marks.clear()
	var size := _plate_size()
	if size.x < 8.0 or size.y < 8.0:
		return
	match _hall_id():
		1:
			_npc("FunKdungon", "FUN KDUNGON", FUN, Vector2(0.40, 0.58), Vector2(110, 188), size)
			_npc("TheChief", "THE CHIEF", CHIEF, Vector2(0.26, 0.58), Vector2(118, 196), size)
			_slang(Vector2(0.50, 0.66), size)
		2:
			_npc("HarvestQueen", "HARVEST QUEEN", QUEEN, Vector2(0.28, 0.78), Vector2(118, 200), size)
			_slang(Vector2(0.50, 0.88), size)
		3:
			_slang(Vector2(0.50, 0.72), size)
		4:
			_npc("MasterWeaver", "MASTER WEAVER", FUN, Vector2(0.36, 0.58), Vector2(110, 188), size)
			_slang(Vector2(0.50, 0.78), size)
		5:
			_npc("FunKdungon", "FUN KDUNGON", FUN, Vector2(0.70, 0.48), Vector2(110, 188), size)
			_slang(Vector2(0.50, 0.78), size)
	queue_redraw()


func _hall_id() -> int:
	var parent := get_parent()
	if parent != null:
		var n := parent.name.to_lower()
		if "house1" in n:
			return 1
		if "house2" in n:
			return 2
		if "house3" in n:
			return 3
		if "house4" in n:
			return 4
		if "house5" in n:
			return 5
	var plate := parent.get_node_or_null("PlateRef") as Sprite2D if parent != null else null
	if plate != null and plate.texture != null:
		var path := plate.texture.resource_path
		if "house_black" in path:
			return 1
		if "house_red" in path:
			return 2
		if "house_gold" in path:
			return 3
		if "ancestors" in path:
			return 4
		if "sacred" in path:
			return 5
	return 0


func _plate_size() -> Vector2:
	var parent := get_parent()
	var plate := parent.get_node_or_null("PlateRef") as Sprite2D if parent != null else null
	if plate != null and plate.texture != null:
		return plate.texture.get_size()
	return Vector2(1536, 1024)


func _uv_to_local(uv: Vector2, size: Vector2) -> Vector2:
	return Vector2((uv.x - 0.5) * size.x, (uv.y - 0.5) * size.y)


func _npc(node_name: String, caption: String, path: String, uv: Vector2, prop_size: Vector2, size: Vector2) -> void:
	var feet := _uv_to_local(uv, size)
	var tex := PlaceholderProp.load_cutout_texture(path, caption)
	if tex != null:
		var spr := Sprite2D.new()
		spr.name = node_name
		spr.texture = tex
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var tex_size := tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0 and prop_size != Vector2.ZERO:
			var s := minf(prop_size.x / tex_size.x, prop_size.y / tex_size.y)
			spr.scale = Vector2(s, s)
		spr.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
		spr.position = feet
		spr.modulate = Color(1.0, 1.0, 1.0, 0.92)
		add_child(spr)
	_marks.append({"pos": feet, "caption": caption, "height": prop_size.y})


func _slang(uv: Vector2, size: Vector2) -> void:
	var feet := _uv_to_local(uv, size)
	var tex := load(SLANG) as Texture2D
	if tex != null:
		var spr := Sprite2D.new()
		spr.name = "Slang"
		spr.texture = tex
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var art := 92.0 / SLANG_FRAME_H
		spr.scale = Vector2(art * PLAYER_SCALE, art * PLAYER_SCALE)
		spr.offset = Vector2(0.0, -46.0)
		spr.position = feet
		spr.modulate = Color(1.0, 1.0, 1.0, 0.88)
		add_child(spr)
	_marks.append({"pos": feet, "caption": "S'LANG (spawn)", "height": 120.0})


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var font := ThemeDB.fallback_font
	for mark in _marks:
		var feet: Vector2 = mark.pos
		var caption: String = mark.caption
		var height: float = mark.height
		draw_circle(feet, 11.0, Color(1.0, 0.82, 0.2, 0.5))
		draw_arc(feet, 11.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.35, 0.95), 2.0)
		var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var top := feet + Vector2(-text_size.x * 0.5, -height - 10.0)
		draw_string_outline(font, top, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0.04, 0.03, 0.02, 0.9))
		draw_string(font, top, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.92, 0.55))
