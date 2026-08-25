extends Node2D
## The Brass Mirror Puzzle of the House of the Golden Sun.
##
## A light beam leaves the emitter in a fixed direction and travels the grid one
## cell at a time. Each brass mirror deflects it 90 degrees depending on which
## way the mirror faces; S'lang rotates a mirror by pressing [E] on it. When the
## beam reaches the Golden Spindle cell, `solved` fires.
##
## Grid coordinates are isometric cells (see Iso), so "east" is down-right on
## screen. Directions are unit cell steps.

signal solved
signal mirror_rotated

const MAX_BOUNCES := 24

## Mirror facings, in rotation order. Each maps an incoming step to an outgoing
## step; "/" style mirrors swap the axes, "\" style negate the swap.
enum Facing { SLASH, BACKSLASH }

@export var emitter_cell := Vector2i(-5, -5)
@export var emitter_direction := Vector2i(1, 0)
@export var spindle_cell := Vector2i(5, 5)
@export var beam_color := Color(1.0, 0.87, 0.45, 0.9)

var _mirrors: Dictionary = {}       # Vector2i -> { facing, prop, interactable }
var _beam_points := PackedVector2Array()
var _is_solved := false
var _spindle_prop: PlaceholderProp


func _ready() -> void:
	z_index = 5


func _draw() -> void:
	if _beam_points.size() < 2:
		return
	# Drawn twice for a soft glow without needing a shader.
	draw_polyline(_beam_points, Color(beam_color, 0.25), 9.0)
	draw_polyline(_beam_points, beam_color, 3.0)
	for i in range(1, _beam_points.size()):
		draw_circle(_beam_points[i], 3.0, beam_color)


## Adds a rotatable mirror. Chapter 3 supplies the visual prop and the [E] hook.
func add_mirror(cell: Vector2i, facing: Facing, prop: PlaceholderProp,
		trigger: Interactable) -> void:
	_mirrors[cell] = {"facing": facing, "prop": prop, "trigger": trigger}
	if trigger != null:
		trigger.interacted.connect(_on_mirror_interacted.bind(cell))
	_apply_mirror_visual(cell)


func set_spindle_prop(prop: PlaceholderProp) -> void:
	_spindle_prop = prop


func is_solved() -> bool:
	return _is_solved


## Recomputes the beam path and reports whether it now hits the spindle.
func trace_beam() -> bool:
	var cell := emitter_cell
	var direction := emitter_direction
	_beam_points = PackedVector2Array([Iso.cell_to_world(Vector2(cell))])

	var hit_spindle := false
	for _bounce in range(MAX_BOUNCES):
		cell += direction
		_beam_points.append(Iso.cell_to_world(Vector2(cell)))

		if cell == spindle_cell:
			hit_spindle = true
			break
		if _mirrors.has(cell):
			direction = _deflect(direction, _mirrors[cell]["facing"])
			continue
		# Leaving the puzzle area: stop so the beam does not run forever.
		if absi(cell.x) > 12 or absi(cell.y) > 12:
			break

	queue_redraw()
	_update_spindle(hit_spindle)

	if hit_spindle and not _is_solved:
		_is_solved = true
		Audio.play_sfx(Audio.Sfx.SUCCESS)
		solved.emit()
	return hit_spindle


func _deflect(direction: Vector2i, facing: int) -> Vector2i:
	# SLASH ("/"): east <-> north. BACKSLASH ("\"): east <-> south.
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
	var prop := data["prop"] as PlaceholderProp
	if prop == null:
		return
	# Lean the placeholder the way the mirror faces, so the puzzle is readable.
	var lean := -0.35 if int(data["facing"]) == Facing.SLASH else 0.35
	var tween := create_tween()
	tween.tween_property(prop, "rotation", lean, 0.16)
	var trigger := data["trigger"] as Interactable
	if trigger != null:
		trigger.set_prompt("Rotate mirror (%s)" %
			("/" if int(data["facing"]) == Facing.SLASH else "\\"))


func _update_spindle(lit: bool) -> void:
	if _spindle_prop == null:
		return
	_spindle_prop.set_tint(Color(1.6, 1.35, 0.8) if lit else Color.WHITE)
