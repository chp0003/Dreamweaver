class_name BreadcrumbTrail
extends Node2D
## Glowing stepping-stones from S'lang's feet to her next goal.
##
## The route is planned on a coarse grid of the world's static solids, so it
## bends around huts, the totem and the river instead of cutting through them.
## Markers are anchored to the goal end of the route: they stay put while she
## walks, and a bright pulse keeps running along them toward the goal.

const CELL := 20.0
const MAX_CELLS := 12000
const CLEARANCE := 12.0
const GRID_MARGIN := 420.0
const SPACING := 38.0
const START_GAP := 46.0
const END_GAP := 30.0
const ARRIVE_RADIUS := 96.0
const REPATH_INTERVAL := 0.35
const REPATH_MOVE := 20.0
const CORNER_RADIUS := 46.0
const PULSE_SPEED := 300.0
const PULSE_GAP := 560.0
const PULSE_WIDTH := 48.0
const FOLLOW_RATE := 9.0
const FADE_RATE := 2.6

@export var color := Color(1.0, 0.84, 0.42)
@export var core_color := Color(1.0, 0.97, 0.82)
@export var arrive_radius := ARRIVE_RADIUS
## Multiplies stone size and spacing, e.g. for the far-off hub camera.
@export var size := 1.0

var _target_node: Node2D
var _target_offset := Vector2.ZERO
var _target_pos := Vector2.INF
var _route := PackedVector2Array()
var _route_len := 0.0
## Global positions; index 0 sits next to the goal.
var _markers: Array[Vector2] = []
var _grid: AStarGrid2D
var _grid_rect := Rect2()
var _grid_cell := CELL
var _grid_dirty := true
var _repath_left := 0.0
var _planned_from := Vector2.INF
var _planned_goal := Vector2.INF
var _time := 0.0
var _strength := 0.0
var _scale := 1.0
var _glow: Texture2D
var _cast_shape := CircleShape2D.new()
var _cores := Node2D.new()
var _lit: Array = []


func _ready() -> void:
	z_as_relative = false
	z_index = -10
	light_mask = 0
	add_to_group("world_chrome")
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	_glow = _make_glow()
	_cores.name = "Cores"
	_cores.light_mask = 0
	_cores.draw.connect(_draw_cores)
	add_child(_cores)
	set_physics_process(true)
	set_process(true)


func follow(target: Node2D, offset := Vector2.ZERO) -> void:
	if target == _target_node and offset == _target_offset:
		return
	_target_node = target
	_target_offset = offset
	_target_pos = Vector2.INF
	_retarget()


func point_at(world_pos: Vector2) -> void:
	if _target_node == null and _target_pos.distance_squared_to(world_pos) < 1.0:
		return
	_target_node = null
	_target_pos = world_pos
	_retarget()


func clear() -> void:
	_target_node = null
	_target_pos = Vector2.INF
	_route = PackedVector2Array()
	_route_len = 0.0
	_markers.clear()
	_strength = 0.0
	_lit.clear()
	queue_redraw()
	if is_instance_valid(_cores):
		_cores.queue_redraw()


func is_active() -> bool:
	return _goal() != Vector2.INF


## Solids changed (a door opened, a room was swapped in). Replan from scratch.
func invalidate() -> void:
	_grid_dirty = true
	_repath_left = 0.0


func _retarget() -> void:
	_grid_dirty = true
	_repath_left = 0.0
	_markers.clear()


func _goal() -> Vector2:
	if _target_node != null:
		if not is_instance_valid(_target_node) or not _target_node.is_visible_in_tree():
			_target_node = null
			return Vector2.INF
		return _target_node.global_position + _target_offset
	return _target_pos


func _player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node2D


# --------------------------------------------------------------------------
# Planning
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var goal := _goal()
	var player := _player()
	if goal == Vector2.INF or player == null or not is_visible_in_tree():
		return
	_scale = _view_scale(player)
	var from := player.global_position
	_repath_left -= delta
	var moved := from.distance_to(_planned_from) > REPATH_MOVE * _scale \
		or goal.distance_to(_planned_goal) > REPATH_MOVE * _scale
	if _repath_left > 0.0 and not moved:
		return
	_repath_left = REPATH_INTERVAL
	_plan(from, goal)


## Painted interiors scale S'lang up and the hub camera pulls far back; the
## stones keep roughly the same size on screen and beside her either way.
func _view_scale(player: Node2D) -> float:
	var s := 1.0
	if player.has_method("depth_scale"):
		s = float(player.call("depth_scale"))
	var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null and cam.zoom.x > 0.01:
		s = maxf(s, 1.0 / cam.zoom.x)
	return clampf(s, 1.0, 3.2) * size


func _plan(from: Vector2, goal: Vector2) -> void:
	_planned_from = from
	_planned_goal = goal
	var space := get_world_2d().direct_space_state if get_world_2d() != null else null
	if space == null:
		_set_route(PackedVector2Array([from, goal]))
		return
	var need := Rect2(from, Vector2.ZERO).expand(goal).grow(48.0 * _scale)
	if _grid_dirty or _grid == null or not _grid_rect.encloses(need):
		_build_grid(space, Rect2(from, Vector2.ZERO).expand(goal).grow(GRID_MARGIN * _scale))
	var a := _free_cell(_cell_of(from))
	var b := _free_cell(_cell_of(goal))
	var cells := PackedVector2Array()
	if a != Vector2i(-1, -1) and b != Vector2i(-1, -1):
		cells = _grid.get_point_path(a, b, true)
	if cells.size() < 2:
		_set_route(PackedVector2Array([from, goal]))
		return
	cells[0] = from
	cells.append(goal)
	_set_route(_round_corners(_pull_string(space, cells)))


func _build_grid(space: PhysicsDirectSpaceState2D, rect: Rect2) -> void:
	_grid_dirty = false
	_grid_cell = CELL * _scale
	if (rect.size.x / _grid_cell) * (rect.size.y / _grid_cell) > MAX_CELLS:
		_grid_cell = sqrt(rect.size.x * rect.size.y / MAX_CELLS)
	var cols := maxi(1, ceili(rect.size.x / _grid_cell))
	var rows := maxi(1, ceili(rect.size.y / _grid_cell))
	_grid_rect = Rect2(rect.position, Vector2(cols, rows) * _grid_cell)
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, cols, rows)
	_grid.cell_size = Vector2(_grid_cell, _grid_cell)
	_grid.offset = rect.position + Vector2(_grid_cell, _grid_cell) * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()

	var probe := CircleShape2D.new()
	probe.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = PhysicsLayers.LAYER_WORLD
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0.0, _grid.get_point_position(cell))
			if not space.intersect_shape(query, 1).is_empty():
				_grid.set_point_solid(cell, true)


func _cell_of(world_pos: Vector2) -> Vector2i:
	var local := (world_pos - _grid_rect.position) / _grid_cell
	return Vector2i(
		clampi(int(floor(local.x)), 0, _grid.region.size.x - 1),
		clampi(int(floor(local.y)), 0, _grid.region.size.y - 1)
	)


## Goals are often props that block movement themselves; walk out to the
## nearest open cell around them.
func _free_cell(cell: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(cell):
		return cell
	for ring in range(1, 9):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var probe := cell + Vector2i(dx, dy)
				if _grid.is_in_boundsv(probe) and not _grid.is_point_solid(probe):
					return probe
	return Vector2i(-1, -1)


## Drop grid stair-steps: keep only the corners a body could not walk past.
func _pull_string(space: PhysicsDirectSpaceState2D, pts: PackedVector2Array) -> PackedVector2Array:
	_cast_shape.radius = CLEARANCE * 0.7
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _cast_shape
	query.collision_mask = PhysicsLayers.LAYER_WORLD
	query.collide_with_areas = false
	var out := PackedVector2Array([pts[0]])
	var i := 0
	var last := pts.size() - 1
	while i < last:
		var j := i + 1
		while j + 1 <= last and _clear(space, query, pts[i], pts[j + 1]):
			j += 1
		out.append(pts[j])
		i = j
	return out


func _clear(space: PhysicsDirectSpaceState2D, query: PhysicsShapeQueryParameters2D,
		a: Vector2, b: Vector2) -> bool:
	query.transform = Transform2D(0.0, a)
	query.motion = b - a
	var hit := space.cast_motion(query)
	return hit.is_empty() or float(hit[0]) >= 1.0


## Quadratic fillets at each bend so the trail reads as a path, not a polyline.
func _round_corners(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var prev := pts[i - 1]
		var corner := pts[i]
		var next := pts[i + 1]
		var r := minf(CORNER_RADIUS * _scale, minf(corner.distance_to(prev), corner.distance_to(next)) * 0.45)
		var a := corner + (prev - corner).normalized() * r
		var b := corner + (next - corner).normalized() * r
		for k in range(7):
			var t := float(k) / 6.0
			out.append(a.lerp(corner, t).lerp(corner.lerp(b, t), t))
	out.append(pts[pts.size() - 1])
	return out


func _set_route(pts: PackedVector2Array) -> void:
	_route = pts
	_route_len = 0.0
	for i in range(1, pts.size()):
		_route_len += pts[i - 1].distance_to(pts[i])


## Point `dist` pixels back from the goal end of the route.
func _point_from_goal(dist: float) -> Vector2:
	var remaining := dist
	for i in range(_route.size() - 1, 0, -1):
		var seg := _route[i].distance_to(_route[i - 1])
		if remaining <= seg:
			return _route[i].lerp(_route[i - 1], remaining / maxf(seg, 0.001))
		remaining -= seg
	return _route[0]


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var goal := _goal()
	var player := _player()
	var want := 0.0
	if goal != Vector2.INF and player != null and _route.size() >= 2:
		var near := player.global_position.distance_to(goal) < arrive_radius * sqrt(_scale)
		want = 0.0 if near else 1.0
	_strength = move_toward(_strength, want, delta * FADE_RATE)
	if goal == Vector2.INF and _strength <= 0.0:
		_markers.clear()
	_update_markers(delta)
	if _strength > 0.0 or not _lit.is_empty():
		_lit = _lit_stones()
		queue_redraw()
		_cores.queue_redraw()


func _update_markers(delta: float) -> void:
	if _route.size() < 2:
		return
	var spacing := SPACING * _scale
	var wanted: Array[Vector2] = []
	var s := END_GAP * _scale
	while s < _route_len - START_GAP * _scale * 0.5:
		wanted.append(_point_from_goal(s))
		s += spacing
	var blend := 1.0 - exp(-FOLLOW_RATE * delta)
	for k in range(wanted.size()):
		if k < _markers.size():
			_markers[k] = _markers[k].lerp(wanted[k], blend)
		else:
			_markers.append(wanted[k])
	if _markers.size() > wanted.size():
		_markers.resize(wanted.size())


## [local position, index, alpha, pulse] for every stone lit this frame.
func _lit_stones() -> Array:
	var lit: Array = []
	if _strength <= 0.001 or _markers.is_empty():
		return lit
	var sc := _scale
	var spacing := SPACING * sc
	var ease_in := _strength * _strength * (3.0 - 2.0 * _strength)
	for k in range(_markers.size()):
		var from_goal := END_GAP * sc + float(k) * spacing
		var from_player := _route_len - from_goal
		var fade := smoothstep(START_GAP * sc * 0.5, START_GAP * sc + 80.0 * sc, from_player)
		fade *= lerpf(0.55, 1.0, smoothstep(0.0, 70.0 * sc, from_goal))
		# Markers light up from her feet outward as the trail appears.
		fade *= smoothstep(0.0, 0.25, ease_in * 1.25 - from_player / maxf(_route_len, 1.0))
		if fade <= 0.01:
			continue
		var pulse_phase := fposmod(from_player - _time * PULSE_SPEED * sc, PULSE_GAP * sc)
		var band := minf(pulse_phase, PULSE_GAP * sc - pulse_phase) / (PULSE_WIDTH * sc)
		var pulse := exp(-band * band)
		var twinkle := 0.82 + 0.18 * sin(_time * 3.1 + float(k) * 1.7)
		var toward := Vector2(0.0, -1.0)
		if k > 0:
			toward = _markers[k - 1] - _markers[k]
		elif _markers.size() > 1:
			toward = _markers[0] - _markers[1]
		if toward.length_squared() < 0.01:
			toward = Vector2(0.0, -1.0)
		lit.append([to_local(_markers[k]), k, fade * twinkle, pulse, toward.normalized()])
	return lit


func _orb_position(at: Vector2, k: int, pulse: float) -> Vector2:
	var bob := sin(_time * 2.3 + float(k) * 0.65) * 2.6 * _scale
	return at + Vector2(0.0, (-9.0 - pulse * 5.0) * _scale + bob)


## Additive layer: a flat pool under each step, on the floor.
func _draw() -> void:
	var sc := _scale
	for stone in _lit:
		var at: Vector2 = stone[0]
		var alpha: float = stone[2]
		var pulse: float = stone[3]
		var pool := Vector2(28.0, 12.0) * sc * (1.0 + pulse * 0.2)
		var glow := color
		glow.a = (0.28 + pulse * 0.22) * alpha
		draw_texture_rect(_glow, Rect2(at - pool * 0.5, pool), false, glow)


## Solid layer: a small chevron on the floor, pointing at the goal.
func _draw_cores() -> void:
	var sc := _scale
	var rim := Color(0.09, 0.06, 0.04)
	for stone in _lit:
		var at: Vector2 = stone[0]
		var alpha: float = stone[2]
		var pulse: float = stone[3]
		var toward: Vector2 = stone[4]
		var core := core_color
		core.a = (0.9 + pulse * 0.1) * alpha
		rim.a = 0.7 * alpha
		var side := Vector2(-toward.y, toward.x)
		var reach := (7.0 + pulse * 1.4) * sc
		var wide := 5.2 * sc
		var tip := at + toward * reach
		var left := at - toward * reach * 0.35 + side * wide
		var right := at - toward * reach * 0.35 - side * wide
		_cores.draw_colored_polygon(PackedVector2Array([tip, left, right]), core)
		_cores.draw_polyline(PackedVector2Array([left, tip, right]), rim, 1.4 * sc, true)


func _make_glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.62),
		Color(1, 1, 1, 0.16),
		Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
