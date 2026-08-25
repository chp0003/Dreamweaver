class_name Iso
extends RefCounted
## Isometric grid maths shared by every gameplay scene.
##
## One cell is a 64x32 diamond. Cell (0,0) is the origin of a room; +x runs
## down-right on screen, +y runs down-left, which is the standard 2:1 dimetric
## layout used by the tile art.

const TILE := Vector2(64.0, 32.0)
const HALF := Vector2(32.0, 16.0)


## Grid cell (may be fractional) to world pixels.
static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)


## World pixels back to a fractional grid cell.
static func world_to_cell(world: Vector2) -> Vector2:
	return Vector2(
		(world.x / HALF.x + world.y / HALF.y) * 0.5,
		(world.y / HALF.y - world.x / HALF.x) * 0.5
	)


static func cell_to_world_i(x: int, y: int) -> Vector2:
	return cell_to_world(Vector2(x, y))


## The four screen-space corners of a cell's diamond, for drawing floors.
static func diamond(center: Vector2, scale_factor: float = 1.0) -> PackedVector2Array:
	var w := HALF.x * scale_factor
	var h := HALF.y * scale_factor
	return PackedVector2Array([
		center + Vector2(0.0, -h),
		center + Vector2(w, 0.0),
		center + Vector2(0.0, h),
		center + Vector2(-w, 0.0),
	])


## Converts raw WASD input into a screen-space direction.
##
## The vertical axis is squashed to match the 2:1 tile ratio, so holding W moves
## S'lang "up the room" at the same visual speed as holding D moves her across
## it. This reads more naturally than rotating input onto the grid axes.
static func screen_direction(input: Vector2) -> Vector2:
	if input.is_zero_approx():
		return Vector2.ZERO
	return Vector2(input.x, input.y * (HALF.y / HALF.x)).normalized()


## Speed multiplier so diagonal-looking movement covers ground evenly.
static func direction_to_velocity(direction: Vector2, speed: float) -> Vector2:
	return direction * speed


## Rough screen distance test that ignores the vertical squash, useful for
## "is the player near this prop" checks that should feel circular on screen.
static func iso_distance(a: Vector2, b: Vector2) -> float:
	var delta := b - a
	delta.y *= HALF.x / HALF.y
	return delta.length()
