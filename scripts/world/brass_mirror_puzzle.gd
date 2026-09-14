extends Node2D
## The Brass Mirror Puzzle of the House of the Golden Sun.
##
## A light beam leaves the window and travels the floor one cell at a time.
## Each brass mirror deflects it 90 degrees depending on which way the plate
## faces; S'lang turns a mirror by pressing [E] on it. When the beam reaches
## the Golden Spindle cell, `solved` fires.

signal solved
signal mirror_rotated

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


func _ready() -> void:
	z_as_relative = false
	z_index = -8
	set_process(true)


func _process(delta: float) -> void:
	if not visible or _beam_points.size() < 2:
		return
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if _beam_points.size() < 2:
		return
	var glow := 0.22 if _settled else 0.34
	var core_w := 3.4 if _settled else 4.6
	var wash_a := 0.10 if _settled else 0.16
	if _is_solved and not _settled:
		glow = 0.42 + 0.08 * sin(_pulse * 2.4)
		core_w = 5.4
		wash_a = 0.22
	var gold := Color(beam_color.r, beam_color.g, beam_color.b, glow)
	var wash := Color(beam_color.r, beam_color.g * 0.9, beam_color.b * 0.55, wash_a)
	var core := Color(1.0, 0.96, 0.78, 0.55 if _settled else 0.82)
	draw_polyline(_beam_points, wash, 28.0, true)
	draw_polyline(_beam_points, gold, 12.0, true)
	draw_polyline(_beam_points, core, core_w, true)

	if _beam_points.size() > 0:
		var origin: Vector2 = _beam_points[0]
		draw_circle(origin, 10.0, Color(1.0, 0.9, 0.55, 0.18))
		draw_circle(origin, 4.0, Color(1.0, 0.95, 0.8, 0.55))
	for bounce in _bounce_points:
		draw_circle(bounce, 7.0, Color(1.0, 0.88, 0.5, 0.22))
	if _hit_spindle and _beam_points.size() > 0:
		var tip: Vector2 = _beam_points[_beam_points.size() - 1]
		var flare := 0.28 + 0.12 * sin(_pulse * 3.0)
		draw_circle(tip, 16.0, Color(1.0, 0.86, 0.45, flare * 0.45))
		draw_circle(tip, 6.0, Color(1.0, 0.95, 0.75, flare))


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

	queue_redraw()
	_update_spindle(_hit_spindle)
	for key in _mirrors.keys():
		_set_mirror_lit(key, lit.has(key))

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
	Audio.play_sfx(Audio.Sfx.PICKUP)
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
