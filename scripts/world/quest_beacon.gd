class_name QuestBeacon
extends Node2D
## Gold arrow over the current story beat — sits above the target's head.
## A breadcrumb trail on the floor leads from S'lang to the same target.

var _pulse := 0.0
var _follow: Node2D
var _offset := Vector2(0.0, -64.0)
var _pinned := false
var _trail := BreadcrumbTrail.new()


func _init() -> void:
	_trail.name = "Trail"
	add_child(_trail)


func _ready() -> void:
	z_index = 48
	z_as_relative = false
	add_to_group("world_chrome")
	visible = false
	set_process(true)
	queue_redraw()


func pin(target: Node2D, offset := Vector2.INF) -> void:
	_follow = target
	_pinned = target != null
	visible = _pinned
	_offset = offset if offset != Vector2.INF else _head_offset(target)
	if target != null:
		global_position = target.global_position + _offset
		_trail.follow(target)
	else:
		_trail.clear()
	queue_redraw()


func pin_world(world_pos: Vector2) -> void:
	_follow = null
	_pinned = true
	visible = true
	_offset = Vector2(0.0, -48.0)
	global_position = world_pos + _offset
	_trail.point_at(world_pos)
	queue_redraw()


func clear() -> void:
	_follow = null
	_pinned = false
	visible = false
	_trail.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if not _pinned:
		visible = false
		return
	_pulse += delta * 3.4
	if _follow != null and is_instance_valid(_follow):
		global_position = _follow.global_position + _offset
	queue_redraw()


func _head_offset(target: Node2D) -> Vector2:
	if target is PlaceholderProp:
		return Vector2(0.0, -(target as PlaceholderProp).prop_size.y - 36.0)
	return Vector2(0.0, -86.0)


func _draw() -> void:
	if not _pinned:
		return
	var bob := sin(_pulse) * 5.0
	var tip := Vector2(0.0, 12.0 + bob)
	var left := Vector2(-12.0, -10.0 + bob)
	var right := Vector2(12.0, -10.0 + bob)
	var gold: Color = Palette.GOLD_SUN
	gold.a = 0.82 + 0.18 * sin(_pulse)
	var rim: Color = Palette.GOLD_SACRED
	rim.a = gold.a
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0.0, 2.5),
		left + Vector2(-2.0, -1.5),
		right + Vector2(2.0, -1.5),
	]), Palette.alpha(Palette.DREAM_ABYSS, 0.8))
	draw_colored_polygon(PackedVector2Array([tip, left, right]), gold)
	draw_polyline(PackedVector2Array([left, tip, right]), rim, 1.6)
