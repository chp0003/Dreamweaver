extends Node2D
## The Brass Mirror Puzzle of the House of the Golden Sun.
##
## A light beam leaves the window and travels the floor one cell at a time.
## Each brass mirror deflects it 90 degrees depending on which way the plate
## faces; S'lang turns a mirror by pressing [E] on it. When the beam reaches
## the Golden Spindle cell, `solved` fires.

signal solved
signal mirror_rotated
signal path_changed(lit_mirrors: int, mirror_count: int, spindle_hit: bool)

const MAX_BOUNCES := 24

enum Facing { SLASH, BACKSLASH }

@export var emitter_cell := Vector2i(-5, -5)
@export var emitter_direction := Vector2i(1, 0)
@export var spindle_cell := Vector2i(5, 5)
@export var beam_color := Color(1.0, 0.84, 0.42, 0.95)
@export var max_extent := 12
var cell_to_world: Callable

var _mirrors: Dictionary = {}
var _beam_points := PackedVector2Array()
var _bounce_points := PackedVector2Array()
var _is_solved := false
var _settled := false
var _spindle_prop: Node2D
var _pulse := 0.0
var _hit_spindle := false
var _lit_cells: Dictionary = {}
var _ghost_points := PackedVector2Array()
var _near_cell := Vector2i(9999, 9999)


func _ready() -> void:
	z_as_relative = false
	z_index = -8
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	_refresh_near_mirror()
	_refresh_ghost()
	queue_redraw()


func _draw() -> void:
	_draw_floor_marks()
	if _ghost_points.size() >= 2:
		_draw_dashed(_ghost_points, Color(0.86, 0.82, 0.74, 0.28), 2.0)
	if _beam_points.size() < 2:
		return
	var glow := 0.28 if _settled else 0.42
	var core_w := 3.2 if _settled else 4.2
	if _is_solved and not _settled:
		glow = 0.5 + 0.1 * sin(_pulse * 2.4)
		core_w = 5.2
	# Soft lantern bloom, then a warm core. Diamonds along the path so the
	# beam is not only a colour.
	var bloom := Color(1.0, 0.72, 0.28, glow * 0.35)
	var gold := Color(1.0, 0.78, 0.38, glow)
	var core := Color(1.0, 0.95, 0.78, 0.62 if _settled else 0.9)
	draw_polyline(_beam_points, bloom, 36.0, true)
	draw_polyline(_beam_points, gold, 14.0, true)
	draw_polyline(_beam_points, core, core_w, true)
	_draw_beam_diamonds(_beam_points, core)

	var origin: Vector2 = _beam_points[0]
	draw_circle(origin, 14.0, Color(1.0, 0.78, 0.36, 0.16))
	_draw_diamond(origin, 5.0, Color(1.0, 0.95, 0.8, 0.7))
	for bounce in _bounce_points:
		draw_circle(bounce, 10.0, Color(1.0, 0.8, 0.4, 0.2))
		_draw_diamond(bounce, 4.0, Color(1.0, 0.92, 0.62, 0.85))
	if _hit_spindle:
		var tip: Vector2 = _beam_points[_beam_points.size() - 1]
		var flare := 0.32 + 0.14 * sin(_pulse * 3.0)
		draw_circle(tip, 22.0, Color(1.0, 0.82, 0.4, flare * 0.4))
		_draw_diamond(tip, 7.0, Color(1.0, 0.95, 0.75, flare))


func add_mirror(cell: Vector2i, facing: Facing, prop: Node2D,
		trigger: Interactable) -> void:
	_mirrors[cell] = {"facing": facing, "prop": prop, "trigger": trigger}
	if trigger != null:
		trigger.interacted.connect(_on_mirror_interacted.bind(cell))
	_apply_mirror_visual(cell)


func set_spindle_prop(prop: Node2D) -> void:
	_spindle_prop = prop


func is_solved() -> bool:
	return _is_solved


func set_settled(on: bool) -> void:
	_settled = on
	queue_redraw()


func set_triggers_enabled(on: bool) -> void:
	for data in _mirrors.values():
		var trigger := data["trigger"] as Interactable
		if trigger != null:
			trigger.set_enabled(on)


func _point_of(cell: Vector2i) -> Vector2:
	if cell_to_world.is_valid():
		var world: Vector2 = cell_to_world.call(cell)
		return to_local(world) if is_inside_tree() else world
	return Iso.cell_to_world(Vector2(cell))


func trace_beam() -> bool:
	var cell := emitter_cell
	var direction := emitter_direction
	_beam_points = PackedVector2Array([_point_of(cell)])
	_bounce_points = PackedVector2Array()
	var lit: Dictionary = {}

	_hit_spindle = false
	for _bounce in range(MAX_BOUNCES):
		cell += direction
		_beam_points.append(_point_of(cell))

		if cell == spindle_cell:
			_hit_spindle = true
			break
		if _mirrors.has(cell):
			lit[cell] = true
			_bounce_points.append(_point_of(cell))
			direction = _deflect(direction, _mirrors[cell]["facing"])
			continue
		if absi(cell.x) > max_extent or absi(cell.y) > max_extent:
			break

	_lit_cells = lit
	queue_redraw()
	_update_spindle(_hit_spindle)
	for key in _mirrors.keys():
		_set_mirror_lit(key, lit.has(key))
	path_changed.emit(lit.size(), _mirrors.size(), _hit_spindle)

	if _hit_spindle and not _is_solved:
		_is_solved = true
		Audio.play_sfx(Audio.Sfx.SUCCESS)
		solved.emit()
	return _hit_spindle


func _deflect(direction: Vector2i, facing: int) -> Vector2i:
	if facing == Facing.SLASH:
		return Vector2i(-direction.y, -direction.x)
	return Vector2i(direction.y, direction.x)


func _on_mirror_interacted(cell: Vector2i) -> void:
	if _is_solved or not _mirrors.has(cell):
		return
	var data: Dictionary = _mirrors[cell]
	data["facing"] = Facing.BACKSLASH if int(data["facing"]) == Facing.SLASH else Facing.SLASH
	Audio.play_sfx(Audio.Sfx.THUD)
	_apply_mirror_visual(cell)
	mirror_rotated.emit()
	trace_beam()


func _apply_mirror_visual(cell: Vector2i) -> void:
	var data: Dictionary = _mirrors[cell]
	var prop := data["prop"] as Node2D
	if prop != null and prop.has_method("set_facing"):
		prop.call("set_facing", int(data["facing"]))
	var trigger := data["trigger"] as Interactable
	if trigger != null:
		trigger.set_prompt("Turn the brass mirror")


func _set_mirror_lit(cell: Vector2i, on: bool) -> void:
	if not _mirrors.has(cell):
		return
	var prop := _mirrors[cell]["prop"] as Node2D
	if prop != null and prop.has_method("set_beam_hit"):
		prop.call("set_beam_hit", on)
	elif prop is PlaceholderProp:
		(prop as PlaceholderProp).set_tint(Color(1.35, 1.18, 0.8) if on else Color.WHITE)


func _update_spindle(lit: bool) -> void:
	if _spindle_prop == null:
		return
	if _spindle_prop.has_method("set_tint"):
		_spindle_prop.call("set_tint", Color(1.6, 1.35, 0.8) if lit else Color.WHITE)


func _draw_floor_marks() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for cell in _mirrors.keys():
		var pos := _point_of(cell)
		var near := 1.0
		if player != null:
			var d := player.global_position.distance_to(to_global(pos))
			near = clampf(1.0 - (d - 160.0) / 260.0, 0.0, 1.0)
		if near <= 0.02:
			continue
		var facing := int(_mirrors[cell]["facing"])
		var carrying: bool = _lit_cells.has(cell)
		var ink := Color(1.0, 0.82, 0.42, 0.55 * near) if carrying \
			else Color(0.78, 0.72, 0.6, 0.28 * near)
		var slash := Vector2(16.0, -10.0) if facing == Facing.SLASH else Vector2(16.0, 10.0)
		draw_line(pos - slash, pos + slash, ink, 2.4 if carrying else 1.6)
		_draw_diamond(pos, 3.2, Color(ink.r, ink.g, ink.b, ink.a * 0.8))
		if cell == _near_cell and not _is_solved:
			var bob := sin(_pulse * 3.0) * 3.0
			var tip := pos + Vector2(0.0, -132.0 + bob)
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(0.0, 8.0),
				tip + Vector2(-7.0, -6.0),
				tip + Vector2(7.0, -6.0),
			]), Color(0.96, 0.9, 0.72, 0.9))


func _refresh_near_mirror() -> void:
	_near_cell = Vector2i(9999, 9999)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _is_solved:
		return
	var best := 96.0
	for cell in _mirrors.keys():
		var d := player.global_position.distance_to(to_global(_point_of(cell)))
		if d < best:
			best = d
			_near_cell = cell


func _refresh_ghost() -> void:
	_ghost_points = PackedVector2Array()
	if _is_solved or _near_cell == Vector2i(9999, 9999):
		return
	if not Settings.show_beam_ghost:
		return
	_ghost_points = _trace_points(_near_cell, true)


func _trace_points(flip_cell: Vector2i, flipped: bool) -> PackedVector2Array:
	var cell := emitter_cell
	var direction := emitter_direction
	var points := PackedVector2Array([_point_of(cell)])
	for _bounce in range(MAX_BOUNCES):
		cell += direction
		points.append(_point_of(cell))
		if cell == spindle_cell:
			break
		if _mirrors.has(cell):
			var facing := int(_mirrors[cell]["facing"])
			if flipped and cell == flip_cell:
				facing = Facing.BACKSLASH if facing == Facing.SLASH else Facing.SLASH
			direction = _deflect(direction, facing)
			continue
		if absi(cell.x) > max_extent or absi(cell.y) > max_extent:
			break
	return points


func _draw_beam_diamonds(points: PackedVector2Array, color: Color) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var span := a.distance_to(b)
		var steps := maxi(1, int(span / 42.0))
		for s in range(1, steps):
			_draw_diamond(a.lerp(b, float(s) / float(steps)), 3.0, color)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.72, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.72, 0.0),
	])
	draw_colored_polygon(pts, color)


func _draw_dashed(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var span := a.distance_to(b)
		var steps := maxi(1, int(span / 16.0))
		for s in range(steps):
			if s % 2 == 1:
				continue
			var t0 := float(s) / float(steps)
			var t1 := float(s + 1) / float(steps)
			draw_line(a.lerp(b, t0), a.lerp(b, t1), color, width)
