class_name ChapterBase
extends Node2D
## Shared spine for every House of Weaving.
##
## A chapter scene provides the nodes below and a script extending this class.
## The base wires up the player, camera, HUD, dialogue and pause menu, owns the
## life/retry rules, and exposes small helpers so a chapter script reads as its
## own story beats rather than as engine plumbing.
##
## Expected child nodes (all optional except World):
##     Floor      Node2D with iso_floor.gd
##     World      Node2D, y_sort_enabled - props, actors and the player
##     Camera     Camera2D
##     Hud        instance of scenes/ui/Hud.tscn
##     Dialogue   instance of scenes/ui/DialogueView.tscn
##     Pause      instance of scenes/ui/PauseMenu.tscn
##     UiLayer    CanvasLayer for mini-games
##
## Subclasses implement `_build_world()` then `_run_chapter()`.

const PLAYER_SCENE := "res://scenes/world/Player.tscn"

@export var chapter_id := 1
## Overrides the HUD's chapter name. Used by the Tutorial and the Hub, which are
## not Houses and so have no entry in the Houses catalogue.
@export var chapter_title := ""
## The Tutorial and the Hub are walkable but are not a House in progress, so
## they leave GameState.current_chapter (and therefore the retry target) alone.
@export var register_as_current_chapter := true
@export var player_spawn_cell := Vector2(0.0, 4.0)
@export var camera_zoom := Vector2(1.15, 1.15)
## The Hub fits on one screen, so it pins the camera and lets S'lang walk around
## inside a stable frame instead of dragging the whole ridge with her.
@export var camera_follows_player := true
@export var camera_anchor_cell := Vector2.ZERO
## Grayscale level the House starts at. 1.0 is fully bleached.
@export var starting_gray := 1.0
## Tutorial-only: hide essence/score chrome so the room stays the focus.
@export var simplify_hud := false
## When false (the open ridge), finishing a House does not freeze S'lang forever.
@export var lock_input_when_finished := true

var player: Slang
var floor_node: Node2D
var world: Node2D
var camera: Camera2D
var hud: CanvasLayer
var dialogue: DialogueView
var pause_menu: CanvasLayer
var ui_layer: CanvasLayer

var _spawn_position := Vector2.ZERO
var _chapter_finished := false
var _handling_death := false
var stage: IsoStage
var _shake := 0.0


func _ready() -> void:
	_collect_nodes()
	_mount_atmosphere()

	if register_as_current_chapter:
		GameState.set_current_chapter(chapter_id)
	GameState.reset_quiz_mistakes()

	# A finished game stays in colour on replays; otherwise the House is bleached.
	if GameState.game_completed:
		ColorRestoration.set_global_gray(0.0)
	else:
		ColorRestoration.clear_zones()
		ColorRestoration.set_global_gray(starting_gray)

	_spawn_position = Iso.cell_to_world(player_spawn_cell)
	_spawn_player()

	if hud != null and hud.has_method("set_chapter"):
		hud.call("set_chapter", chapter_title if not chapter_title.is_empty()
			else Houses.name_for(chapter_id))
		hud.call("bind_player", player)
		# Tutorial: hide inventory chrome. Houses: full HUD with a clearer quest plate.
		if simplify_hud and hud.has_method("set_story_focus"):
			hud.call("set_story_focus", true)
		elif register_as_current_chapter and hud.has_method("set_chapter_focus"):
			hud.call("set_chapter_focus", true)

	_build_world()
	if stage != null and world != null and floor_node != null:
		stage.dress_foreground(world, floor_node.origin_cell, floor_node.cols, floor_node.rows)
	ColorRestoration.sync_essences()
	# One frame so containers and the camera settle before the first line plays.
	await get_tree().process_frame
	_run_chapter()


func _process(delta: float) -> void:
	_update_camera(delta)


func shake_camera(amount := 10.0) -> void:
	_shake = maxf(_shake, amount)


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target := camera.global_position
	if camera_follows_player and player != null and is_instance_valid(player):
		target = player.global_position
		if player.has_method("apply_depth_scale") and floor_node != null:
			var top := Iso.cell_to_world(Vector2(floor_node.origin_cell))
			var bottom := Iso.cell_to_world(Vector2(
				floor_node.origin_cell.x + floor_node.cols,
				floor_node.origin_cell.y + floor_node.rows))
			var span := maxf(80.0, bottom.y - top.y)
			var t := clampf((player.global_position.y - top.y) / span, 0.0, 1.0)
			player.apply_depth_scale(lerpf(0.94, 1.07, t))
	if _shake > 0.4:
		target += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.55)
		_shake = move_toward(_shake, 0.0, delta * 28.0)
	else:
		_shake = 0.0
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 6.0))
	if camera_follows_player:
		_clamp_camera()


func _clamp_camera() -> void:
	if camera == null or floor_node == null:
		return
	var origin := Vector2(floor_node.origin_cell)
	var corners: Array[Vector2] = [
		Iso.cell_to_world(origin),
		Iso.cell_to_world(origin + Vector2(floor_node.cols, 0)),
		Iso.cell_to_world(origin + Vector2(floor_node.cols, floor_node.rows)),
		Iso.cell_to_world(origin + Vector2(0, floor_node.rows)),
	]
	var min_p: Vector2 = corners[0]
	var max_p: Vector2 = corners[0]
	for p in corners:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	var margin := Vector2(80.0, 60.0)
	camera.global_position = Vector2(
		clampf(camera.global_position.x, min_p.x + margin.x, max_p.x - margin.x),
		clampf(camera.global_position.y, min_p.y + margin.y, max_p.y - margin.y)
	)


# --------------------------------------------------------------------------
# Subclass hooks
# --------------------------------------------------------------------------

## Place props, collectibles, enemies and interactables. Called once.
func _build_world() -> void:
	pass


## The chapter's story beats, as a coroutine. Awaits dialogue and mini-games.
func _run_chapter() -> void:
	pass


# --------------------------------------------------------------------------
# Story helpers
# --------------------------------------------------------------------------

## Plays dialogue with the player frozen, then hands control back.
func say(lines: Array) -> void:
	if dialogue == null:
		return
	set_player_input(false)
	await dialogue.play(lines)
	set_player_input(true)


func ask(prompt: String, options: Array, speaker := "") -> int:
	if dialogue == null:
		return 0
	set_player_input(false)
	var picked: int = await dialogue.ask(prompt, options, speaker)
	set_player_input(true)
	return picked


func objective(text: String) -> void:
	GameState.set_objective(text)


func banner(text: String, hold := 1.9) -> void:
	if hud != null and hud.has_method("flash_banner"):
		hud.call("flash_banner", text, hold)


func counter(text: String) -> void:
	if hud != null and hud.has_method("set_counter"):
		hud.call("set_counter", text)


func set_player_input(enabled: bool) -> void:
	if player != null and is_instance_valid(player):
		var locked := lock_input_when_finished and _chapter_finished
		player.set_input_enabled(enabled and not locked)


## True once the chapter has handed off to the Hub or the retry screen. Wait
## loops should check this so they cannot spin forever after a failure.
func is_finished() -> bool:
	return _chapter_finished


## Waits until `condition` returns true. Used for "collect them all" phases.
func until(condition: Callable) -> void:
	while not bool(condition.call()):
		await get_tree().process_frame
		if not is_inside_tree():
			return


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --------------------------------------------------------------------------
# Mini-games
# --------------------------------------------------------------------------

## Runs a mini-game modally and returns whether the player passed.
## `setup` sets properties on the instance before it enters the tree, e.g.
##     await run_mini_game(PATH, {"questions": bank, "time_limit": 60.0})
## `on_instance` receives the instance before it is added, for wiring up extra
## signals (Chapter 5 uses it to turn rhythm hits into boss damage).
func run_mini_game(scene_path: String, setup := {}, on_instance := Callable()) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("ChapterBase: could not load mini-game %s" % scene_path)
		return false

	var game := packed.instantiate()
	for key in setup:
		game.set(str(key), setup[key])
	if on_instance.is_valid():
		on_instance.call(game)

	set_player_input(false)
	var host: Node = ui_layer if ui_layer != null else self
	host.add_child(game)

	var passed: bool = await game.finished
	if is_instance_valid(game):
		game.queue_free()
	set_player_input(true)
	return passed


# --------------------------------------------------------------------------
# World building helpers
# --------------------------------------------------------------------------

func spawn_prop(label: String, cell: Vector2, config := {}) -> PlaceholderProp:
	var prop := PlaceholderProp.new()
	prop.prop_label = label
	prop.position = Iso.cell_to_world(cell)
	# Soft floor dressing (mats, grass, open doorways) does not block by default.
	# Pass blocks_movement in `config` to override.
	if not config.has("blocks_movement"):
		prop.blocks_movement = not PlaceholderProp.is_soft_label(
			label, str(config.get("texture_path", ""))
		)
	for key in config:
		prop.set(str(key), config[key])
	_world_parent().add_child(prop)
	return prop


## Attaches an [E] trigger to a prop (or anywhere, if `anchor` is null).
func add_interactable(prompt: String, cell: Vector2, config := {}) -> Interactable:
	var trigger := Interactable.new()
	trigger.prompt = prompt
	trigger.position = Iso.cell_to_world(cell)
	for key in config:
		trigger.set(str(key), config[key])
	_world_parent().add_child(trigger)
	return trigger


func spawn_collectible(label: String, cell: Vector2, config := {}) -> Collectible:
	var pickup := Collectible.new()
	pickup.item_label = label
	pickup.position = Iso.cell_to_world(cell)
	for key in config:
		pickup.set(str(key), config[key])
	_world_parent().add_child(pickup)
	return pickup


func spawn_minion(cell: Vector2, config := {}) -> ShadowMinion:
	# Hard cap so a stuck chapter loop can never flood the floor.
	var alive := get_tree().get_nodes_in_group("shadow_minion").size()
	if alive >= 4:
		push_warning("spawn_minion blocked — already %d shadows alive" % alive)
		return null
	var minion := ShadowMinion.new()
	minion.position = Iso.cell_to_world(cell)
	for key in config:
		minion.set(str(key), config[key])
	_world_parent().add_child(minion)
	return minion


## Invisible walls along the room's diamond edge, so S'lang cannot walk out.
## Uses thick capsule segments (not zero-width BUILD_SEGMENTS) so move_and_slide
## always registers a solid hit.
func add_room_bounds(origin_cell: Vector2i, cols: int, rows: int) -> void:
	var top := Iso.cell_to_world(Vector2(origin_cell.x, origin_cell.y))
	var right := Iso.cell_to_world(Vector2(origin_cell.x + cols, origin_cell.y))
	var bottom := Iso.cell_to_world(Vector2(origin_cell.x + cols, origin_cell.y + rows))
	var left := Iso.cell_to_world(Vector2(origin_cell.x, origin_cell.y + rows))
	var corners := [top, right, bottom, left]

	var body := StaticBody2D.new()
	body.name = "RoomBounds"
	body.collision_layer = PhysicsLayers.LAYER_WORLD
	body.collision_mask = PhysicsLayers.MASK_WORLD_STATIC

	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var shape := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = maxf(4.0, length - capsule.radius * 2.0)
		shape.shape = capsule
		shape.position = mid
		shape.rotation = (b - a).angle() + PI * 0.5
		body.add_child(shape)

	add_child(body)


# --------------------------------------------------------------------------
# Colour restoration
# --------------------------------------------------------------------------

## Blooms a pool of restored colour around `anchor` - the visual payoff of a
## chapter's Restoration Phase.
func restore_local_color(anchor: Node2D, radius := -1.0, strength := 1.0,
		duration := 4.2) -> void:
	if anchor == null:
		return
	if radius < 0.0:
		radius = 820.0
	ColorRestoration.bloom_zone("house_%d" % chapter_id, anchor, radius, strength, duration)


# --------------------------------------------------------------------------
# Completion, death and retry
# --------------------------------------------------------------------------

## Banks the House, shows the outro, and returns to the Hub.
func complete_chapter(closing_lines: Array = [], next_scene := "") -> void:
	if _chapter_finished:
		return
	_chapter_finished = true
	GameState.complete_house(chapter_id)
	counter("")
	set_player_input(false)

	var house := Houses.get_house(chapter_id)
	var essence := str(house.get("essence", ""))
	if not essence.is_empty():
		banner("%s Restored" % Houses.essence_name(essence), 2.4)
	else:
		banner("%s Restored" % Houses.short_name_for(chapter_id), 2.4)

	if not closing_lines.is_empty() and dialogue != null:
		await dialogue.play(closing_lines)

	objective("Return to the Hub and choose the next House.")
	SceneFader.fade_to_scene(next_scene if not next_scene.is_empty()
		else AccountManager.HUB_SCENE)


## S'lang has run out of health. Costs a life, then respawns or ends the run.
func _on_player_died() -> void:
	if _handling_death or _chapter_finished:
		return
	_handling_death = true

	if not GameState.lose_life():
		await wait(0.8)
		SceneFader.fade_to_scene(AccountManager.GAME_OVER_SCENE)
		return

	banner("A life spent", 1.6)
	await wait(1.1)
	if not is_inside_tree():
		return
	_respawn_player()
	_handling_death = false


## Sends the player to the retry screen, e.g. after failing a quiz outright.
func fail_chapter() -> void:
	if _chapter_finished:
		return
	_chapter_finished = true
	set_player_input(false)
	await wait(0.5)
	SceneFader.fade_to_scene(AccountManager.GAME_OVER_SCENE)


func _respawn_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = _spawn_position
	player.velocity = Vector2.ZERO
	player.heal_full()
	set_player_input(true)


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _mount_atmosphere() -> void:
	if get_node_or_null("Atmosphere") == null:
		var sky := WorldAtmosphere.new()
		sky.name = "Atmosphere"
		add_child(sky)
		move_child(sky, 0)
	if get_node_or_null("Stage") == null:
		stage = IsoStage.new()
		stage.name = "Stage"
		add_child(stage)
		move_child(stage, 1)
	else:
		stage = get_node_or_null("Stage") as IsoStage
	if stage != null:
		stage.configure(chapter_id if register_as_current_chapter else 0, camera)


func _collect_nodes() -> void:
	floor_node = get_node_or_null("Floor") as Node2D
	world = get_node_or_null("World") as Node2D
	camera = get_node_or_null("Camera") as Camera2D
	hud = get_node_or_null("Hud") as CanvasLayer
	dialogue = get_node_or_null("Dialogue") as DialogueView
	pause_menu = get_node_or_null("Pause") as CanvasLayer
	ui_layer = get_node_or_null("UiLayer") as CanvasLayer

	if world == null:
		world = Node2D.new()
		world.name = "World"
		world.y_sort_enabled = true
		add_child(world)

	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UiLayer"
		ui_layer.layer = 120
		add_child(ui_layer)

	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera"
		add_child(camera)
	camera.zoom = camera_zoom
	camera.position_smoothing_enabled = false
	camera.make_current()


func _spawn_player() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		push_error("ChapterBase: missing %s" % PLAYER_SCENE)
		return
	player = packed.instantiate() as Slang
	player.global_position = _spawn_position
	# The staff carries over from the tutorial; without it there is no combat.
	player.has_staff = GameState.has_item("lewet_staff")
	world.add_child(player)
	player.died.connect(_on_player_died)
	player.attacked.connect(_on_player_attacked)
	if player.has_staff:
		ColorRestoration.add_zone("lewet_staff", player, 150.0, 0.88)
	if camera != null:
		camera.global_position = Iso.cell_to_world(camera_anchor_cell) \
			if not camera_follows_player else _spawn_position


func _on_player_attacked(_swing_position: Vector2, _facing: Vector2) -> void:
	shake_camera(4.5)


func _world_parent() -> Node2D:
	return world if world != null else self
