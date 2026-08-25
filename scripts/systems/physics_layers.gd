class_name PhysicsLayers
extends RefCounted
## Shared 2D physics layer bits for Dreamweaver.
##
## Project Settings → Layer Names → 2D Physics should list:
##   1 player · 2 enemies · 3 world · 4 sensors
##
## Numeric values already used across the project (kept for compatibility):
##   Player CharacterBody2D   collision_layer = 1,  mask = 4  (hits world)
##   World StaticBody2D       collision_layer = 4,  mask = 0
##   Enemies CharacterBody2D  collision_layer = 2,  mask = 0
##
## Godot stores layers as bits: layer N → value 1 << (N - 1).
## So value 4 means **editor layer 3** ("world" below).

const LAYER_PLAYER := 1
const LAYER_ENEMIES := 2
const LAYER_WORLD := 4

const MASK_PLAYER_MOVES := LAYER_WORLD
const MASK_WORLD_STATIC := 0


## Round feet footprint — circles are the most reliable CharacterBody2D blockers.
static func feet_circle(radius: float) -> CircleShape2D:
	var circle := CircleShape2D.new()
	circle.radius = maxf(8.0, radius)
	return circle


## Flat isometric diamond (optional / TileSet-style footprints).
static func feet_shape(rx: float, ry: float) -> ConvexPolygonShape2D:
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([
		Vector2(0.0, -ry),
		Vector2(rx, 0.0),
		Vector2(0.0, ry),
		Vector2(-rx, 0.0),
	])
	return poly
