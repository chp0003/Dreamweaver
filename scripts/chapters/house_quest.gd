class_name HouseQuest
extends Node2D
## A House of Weaving that can live inside the open 2.5D world *or* a
## standalone chapter scene. All cell coordinates are local to the House;
## `region_origin` shifts them onto the shared map.

var host: ChapterBase
var region_origin := Vector2.ZERO
var house_id := 1
var region_spawn := Vector2(0.0, 6.0)

var _quest_finished := false
var _quest_started := false
var _quest_running := false
var _color_anchor: Node2D

var player: Slang:
	get:
		return host.player if host != null else null
var world: Node2D:
	get:
		return host.world if host != null else self
var camera: Camera2D:
	get:
		return host.camera if host != null else null
var hud: CanvasLayer:
	get:
		return host.hud if host != null else null
var dialogue: DialogueView:
	get:
		return host.dialogue if host != null else null
var ui_layer: CanvasLayer:
	get:
		return host.ui_layer if host != null else null
var chapter_id: int:
	get:
		return house_id


func map_cell(cell: Vector2) -> Vector2:
	return cell + region_origin


func build() -> void:
	_ensure_color_anchor()
	_build_world()


## Painted-plate Houses (Chapter 1) skip the iso diamond and walk a 16:9 picture.
func uses_painted_plate() -> bool:
	return false


func player_spawn_world() -> Vector2:
	return Iso.cell_to_world(map_cell(region_spawn))


func threshold_world() -> Vector2:
	return Vector2.ZERO


func plate_world_rect() -> Rect2:
	return Rect2()


func plate_camera_zoom() -> float:
	var rect := plate_world_rect()
	if host != null and host.has_method("cover_zoom_for"):
		return host.cover_zoom_for(rect)
	var view := get_viewport_rect().size
	if rect.size.x < 8.0 or rect.size.y < 8.0 or view.x < 8.0 or view.y < 8.0:
		return 0.86
	return maxf(view.x / rect.size.x, view.y / rect.size.y) * 1.02


func painted_player_scale() -> float:
	return 1.0


func place_prop(label: String, world_pos: Vector2, config := {}) -> PlaceholderProp:
	if host == null:
		return null
	var cfg := config.duplicate()
	cfg["position"] = world_pos
	return host.spawn_prop(label, Vector2.ZERO, cfg)


func place_interactable(prompt: String, world_pos: Vector2, config := {}) -> Interactable:
	if host == null:
		return null
	var cfg := config.duplicate()
	cfg["position"] = world_pos
	return host.add_interactable(prompt, Vector2.ZERO, cfg)


func place_collectible(label: String, world_pos: Vector2, config := {}) -> Collectible:
	if host == null:
		return null
	var cfg := config.duplicate()
	cfg["position"] = world_pos
	return host.spawn_collectible(label, Vector2.ZERO, cfg)


func is_busy() -> bool:
	return _quest_running


func start_quest() -> void:
	if _quest_started or _quest_finished:
		return
	var replay := GameState.wants_replay(house_id)
	if GameState.is_house_completed(house_id) and not replay:
		return
	if replay:
		GameState.clear_replay()
	_quest_started = true
	_quest_running = true
	_run_and_clear()


func _run_and_clear() -> void:
	await _run_chapter()
	_quest_running = false


func _build_world() -> void:
	pass


func _run_chapter() -> void:
	pass


func say(lines: Array) -> void:
	if host != null:
		await host.say(lines)


func ask(prompt: String, options: Array, speaker := "") -> int:
	if host == null:
		return 0
	return await host.ask(prompt, options, speaker)


func objective(text: String) -> void:
	if host != null:
		host.objective(text)


func banner(text: String, hold := 1.9) -> void:
	if host != null:
		host.banner(text, hold)


func counter(text: String) -> void:
	if host != null:
		host.counter(text)


func set_player_input(enabled: bool) -> void:
	if host != null:
		host.set_player_input(enabled)


func is_complete() -> bool:
	return _quest_finished


func is_finished() -> bool:
	return _quest_finished or (host != null and host.is_finished())


func until(condition: Callable) -> void:
	if host != null:
		await host.until(condition)


func wait(seconds: float) -> void:
	if host != null:
		await host.wait(seconds)


func run_mini_game(scene_path: String, setup := {}, on_instance := Callable()) -> bool:
	if host == null:
		return false
	return await host.run_mini_game(scene_path, setup, on_instance)


func spawn_prop(label: String, cell: Vector2, config := {}) -> PlaceholderProp:
	return host.spawn_prop(label, map_cell(cell), config)


func add_interactable(prompt: String, cell: Vector2, config := {}) -> Interactable:
	return host.add_interactable(prompt, map_cell(cell), config)


func spawn_collectible(label: String, cell: Vector2, config := {}) -> Collectible:
	return host.spawn_collectible(label, map_cell(cell), config)


func spawn_minion(cell: Vector2, config := {}) -> ShadowMinion:
	return host.spawn_minion(map_cell(cell), config)


func place_minion(world_pos: Vector2, config := {}) -> ShadowMinion:
	if host == null:
		return null
	var minion := host.spawn_minion(Vector2.ZERO, config)
	if minion != null:
		minion.global_position = world_pos
	return minion


func add_room_bounds(origin_cell: Vector2i, cols: int, rows: int) -> void:
	var shifted := Vector2i(
		origin_cell.x + int(region_origin.x),
		origin_cell.y + int(region_origin.y)
	)
	host.add_room_bounds(shifted, cols, rows, self)


func _ensure_color_anchor() -> void:
	if _color_anchor != null:
		return
	_color_anchor = Node2D.new()
	_color_anchor.name = "HouseColor_%d" % house_id
	_color_anchor.position = Iso.cell_to_world(map_cell(Vector2(0.0, 0.0)))
	world.add_child(_color_anchor)


func house_restore_radius() -> float:
	return 1400.0 if uses_painted_plate() else 820.0


func restore_local_color(anchor: Node2D, radius := -1.0, strength := 1.0,
		duration := 4.2) -> void:
	if anchor == null:
		anchor = _color_anchor
	if anchor == null:
		return
	if radius < 0.0:
		radius = house_restore_radius()
	ColorRestoration.bloom_zone("house_%d" % house_id, anchor, radius, strength, duration)


## Instant full colour if this House was already restored (re-entry).
func apply_restored_color() -> void:
	_ensure_color_anchor()
	if _color_anchor == null:
		return
	ColorRestoration.add_zone("house_%d" % house_id, _color_anchor,
		house_restore_radius(), 1.0)


func shake_camera(amount := 10.0) -> void:
	if host != null:
		host.shake_camera(amount)


func focus_camera_on(world_pos: Vector2, zoom := Vector2.ZERO) -> void:
	if host != null:
		host.focus_camera_on(world_pos, zoom)


func clear_camera_focus() -> void:
	if host != null:
		host.clear_camera_focus()


func fail_chapter() -> void:
	_quest_finished = true
	_quest_running = false
	if host != null:
		await host.fail_chapter()


func complete_chapter(closing_lines: Array = [], next_scene := "") -> void:
	if _quest_finished:
		return
	_quest_finished = true
	_quest_running = false
	GameState.complete_house(house_id)
	counter("")
	set_player_input(false)
	if not ColorRestoration.has_zone("house_%d" % house_id):
		restore_local_color(_color_anchor)

	var house := Houses.get_house(house_id)
	var essence := str(house.get("essence", ""))
	if not essence.is_empty():
		banner("%s Restored" % Houses.essence_name(essence), 2.4)
	else:
		banner("%s Restored" % Houses.short_name_for(house_id), 2.4)

	if not closing_lines.is_empty() and dialogue != null:
		await dialogue.play(closing_lines)

	if host != null and host.has_method("on_house_completed"):
		await host.on_house_completed(house_id, next_scene)
	elif host != null:
		await host.complete_chapter([], next_scene)
