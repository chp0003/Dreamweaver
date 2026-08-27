extends ChapterBase
## The village green — one continuous map, not a per-screen chapter.
##
## S'lang walks a wooden X between the five Guno Bong. Entering a House
## steps her into that interior on the same map (camera follows). Story still
## waits at each door until the previous House is restored.

const DOOR_LABELS := {
	1: "GUNO BONG I",
	2: "GUNO BONG II",
	3: "GUNO BONG III",
	4: "GUNO BONG IV",
	5: "THE GREAT GUNO BONG",
}

const HOUSE_QUESTS := {
	1: "res://scripts/chapters/chapter_1_black.gd",
	2: "res://scripts/chapters/chapter_2_red.gd",
	3: "res://scripts/chapters/chapter_3_gold.gd",
	4: "res://scripts/chapters/chapter_4_ancestors.gd",
	5: "res://scripts/chapters/chapter_5_final.gd",
}

const HOUSE_ORIGINS := {
	1: Vector2(-50.0, 8.0),
	2: Vector2(-50.0, -32.0),
	3: Vector2(-8.0, -52.0),
	4: Vector2(38.0, -32.0),
	5: Vector2(38.0, 10.0),
}

const HOUSE_SPAWNS := {
	1: Vector2(0.0, -1.2),
	2: Vector2(0.0, 7.0),
	3: Vector2(0.0, 6.0),
	4: Vector2(0.0, 6.0),
	5: Vector2(0.0, 7.0),
}

## Front of each hall (toward the camera) — the ridge threshold.
const HOUSE_EXITS := {
	1: Vector2(0.0, 11.2),
	2: Vector2(0.0, 7.1),
	3: Vector2(0.0, 7.1),
	4: Vector2(0.0, 7.1),
	5: Vector2(0.0, 7.1),
}

const FLOOR_ORIGIN := Vector2i(-16, -16)
const FLOOR_COLS := 32
const FLOOR_ROWS := 32

var _doors: Dictionary = {}
var _quests: Dictionary = {}
var _house_floors: Dictionary = {}
var _exit_triggers: Dictionary = {}
var _house_exits: Dictionary = {}
var _ridge_floor: Node2D
var _terrain: HubTerrain
var _active_house_id := 0
var _plaza_cell := Vector2.ZERO
var _leaving_house := false


func _build_world() -> void:
	_ridge_floor = floor_node
	if _ridge_floor != null:
		_ridge_floor.visible = false
	add_room_bounds(FLOOR_ORIGIN, FLOOR_COLS, FLOOR_ROWS)
	Audio.set_ambience(0.55, 16.0)

	_mount_terrain()
	for house in Houses.LIST:
		_build_door(house)
		_mount_house(house)

	_dress_park()
	_dress_living_ridge()
	_restore_completed_colors()
	_set_camera_floor(_ridge_floor)


func _mount_terrain() -> void:
	var houses: Array[Vector2] = []
	for house in Houses.LIST:
		houses.append(house["hub_cell"] as Vector2)
	_terrain = HubTerrain.new()
	_terrain.name = "HubTerrain"
	add_child(_terrain)
	move_child(_terrain, mini(2, get_child_count() - 1))
	_terrain.setup(_plaza_cell, houses, FLOOR_ORIGIN, FLOOR_COLS, FLOOR_ROWS)


func _mount_house(house: Dictionary) -> void:
	var house_id := int(house["id"])
	var origin: Vector2 = HOUSE_ORIGINS[house_id]
	_add_house_floor(house_id, origin)

	var script := load(str(HOUSE_QUESTS[house_id])) as Script
	var quest: HouseQuest = script.new() as HouseQuest
	quest.name = "House%d" % house_id
	quest.host = self
	quest.house_id = house_id
	quest.region_origin = origin
	quest.region_spawn = HOUSE_SPAWNS[house_id]
	add_child(quest)
	quest.build()
	_quests[house_id] = quest
	_hide_house_darkness(quest)
	_place_house_exit(house_id, origin, house.get("accent", Palette.GOLD_BRASS) as Color)


func _place_house_exit(house_id: int, origin: Vector2, accent: Color) -> void:
	var exit_cell: Vector2 = origin + HOUSE_EXITS[house_id]
	# Woven runner leading to the porch so the way out is readable from mid-room.
	var mat_start := origin + Vector2(0.0, HOUSE_EXITS[house_id].y - 5.0)
	for i in range(3):
		var t := 0.38 + float(i) * 0.18
		var cell := mat_start.lerp(exit_cell, t)
		spawn_prop("RIDGE MAT", cell, {
			"texture_path": "res://assets/images/props/sleeping_mat.png",
			"prop_size": Vector2(52.0 - float(i) * 4.0, 16.0),
			"body_color": Palette.EARTH_WOOD,
			"accent_color": accent,
			"show_label": false,
			"cast_shadow": false,
			"blocks_movement": false,
		})
	var gate := HouseExit.new()
	gate.name = "RidgeExit_%d" % house_id
	gate.accent = accent
	gate.position = Iso.cell_to_world(exit_cell)
	world.add_child(gate)
	gate.used.connect(_leave_house.bind(house_id))
	_house_exits[house_id] = gate
	_exit_triggers[house_id] = gate.get_node_or_null("ExitTrigger")
	if GameState.is_house_completed(house_id):
		gate.set_open(true, true)


func _add_house_floor(house_id: int, origin: Vector2) -> void:
	var floor := Node2D.new()
	floor.name = "FloorHouse%d" % house_id
	floor.set_script(load("res://scripts/world/iso_floor.gd"))
	var cols := 25 if house_id == 1 else 17
	var rows := 25 if house_id == 1 else 17
	var floor_origin := Vector2i(-12, -11) if house_id == 1 else Vector2i(-8, -8)
	floor.set("cols", cols)
	floor.set("rows", rows)
	floor.set("origin_cell", floor_origin + Vector2i(int(origin.x), int(origin.y)))
	floor.set("draw_border", true)
	match house_id:
		1:
			floor.set("base_color", Color(0.38, 0.32, 0.24))
			floor.set("alt_color", Color(0.44, 0.36, 0.28))
			floor.set("terrain_texture_path", "res://assets/images/environments/house_black/tileset.png")
			floor.set("scatter_detail", true)
		2:
			floor.set("base_color", Color(0.2, 0.175, 0.17))
			floor.set("alt_color", Color(0.235, 0.2, 0.195))
			floor.set("terrain_texture_path", "res://assets/images/environments/house_red/tileset.png")
			floor.set("weave_accent", Color(0.36, 0.24, 0.22, 0.35))
		3:
			floor.set("base_color", Color(0.21, 0.195, 0.16))
			floor.set("alt_color", Color(0.245, 0.225, 0.185))
		4:
			floor.set("base_color", Color(0.225, 0.22, 0.215))
			floor.set("alt_color", Color(0.26, 0.255, 0.245))
			floor.set("weave_accent", Color(0.42, 0.4, 0.36, 0.3))
		_:
			floor.set("base_color", Color(0.155, 0.15, 0.155))
			floor.set("alt_color", Color(0.185, 0.18, 0.185))
			floor.set("weave_accent", Color(0.3, 0.26, 0.3, 0.4))
	add_child(floor)
	move_child(floor, 1)
	_house_floors[house_id] = floor


func _dress_park() -> void:
	# Terrain tiles already carry grass / ponds / flowers. Keep a light layer of
	# canopy + lanterns so the park still reads at camera distance.
	var trees: Array[Vector2] = [
		Vector2(-10.0, -4.0), Vector2(10.0, -4.0), Vector2(-10.0, 4.0), Vector2(10.0, 4.0),
		Vector2(-4.0, -10.0), Vector2(4.0, -10.0), Vector2(-4.0, 10.0), Vector2(4.0, 10.0),
		Vector2(-12.0, 2.0), Vector2(12.0, -2.0), Vector2(2.0, 12.5), Vector2(-2.0, -12.5),
		Vector2(-11.0, -8.0), Vector2(11.0, 8.0), Vector2(-8.0, 11.0), Vector2(8.0, -11.0),
	]
	for i in range(trees.size()):
		var cell: Vector2 = trees[i]
		if _terrain != null and _terrain.is_path_cell(cell):
			continue
		spawn_prop("HIGHLAND TREE", cell, {
			"texture_path": "res://assets/images/environments/highland/highland_tree.png",
			"prop_size": Vector2(88.0 + float(i % 3) * 14.0, 132.0 + float(i % 2) * 20.0),
			"body_color": Palette.EARTH_WOOD,
			"accent_color": Palette.LIVING_LEAF,
			"show_label": false,
			"sway_degrees": 1.6,
			"blocks_movement": true,
			"collision_feet": Vector2(28.0, 18.0),
		})

	var lanterns: Array[Vector2] = [
		Vector2(-2.4, -2.4), Vector2(2.4, -2.4), Vector2(-2.4, 2.4), Vector2(2.4, 2.4),
		Vector2(0.0, 5.2), Vector2(5.2, 0.0), Vector2(0.0, -5.2), Vector2(-5.2, 0.0),
		Vector2(4.6, 4.6), Vector2(-4.6, -4.6),
	]
	for cell in lanterns:
		spawn_prop("BRASS LANTERN", cell, {
			"texture_path": "res://assets/images/environments/highland/brass_lantern.png",
			"prop_size": Vector2(36.0, 68.0),
			"body_color": Palette.GOLD_DEEP,
			"accent_color": Palette.GOLD_SUN,
			"show_label": false,
			"cast_shadow": false,
			"blocks_movement": false,
		})

	var fences: Array[Vector2] = [
		Vector2(-4.8, -4.8), Vector2(4.8, -4.8), Vector2(-4.8, 4.8), Vector2(4.8, 4.8),
	]
	for cell in fences:
		spawn_prop("BAMBOO FENCE", cell, {
			"texture_path": "res://assets/images/environments/highland/bamboo_fence.png",
			"prop_size": Vector2(78.0, 52.0),
			"body_color": Palette.EARTH_BAMBOO,
			"accent_color": Palette.EARTH_WOOD,
			"show_label": false,
			"blocks_movement": false,
		})


func _dress_living_ridge() -> void:
	var restored := GameState.completed_houses.size()
	if GameState.game_completed:
		restored = Houses.count()

	# Progress is readable on the green itself: more colour, more life, more light.
	if restored >= 1:
		for i in range(3):
			spawn_prop("ABACA PLANT", Vector2(-1.8, 3.2 + float(i) * 1.5), {
				"texture_path": "res://assets/images/props/abaca_plant.png",
				"prop_size": Vector2(36.0, 78.0),
				"body_color": Palette.BLACK_BARK,
				"accent_color": Palette.CREAM_STONE,
				"show_label": false,
				"sway_degrees": 2.4,
			})
	if restored >= 2:
		for i in range(3):
			spawn_prop("RED FLOWERS", Vector2(3.2 + float(i) * 1.5, -1.6), {
				"texture_path": "res://assets/images/props/red_flowers.png",
				"prop_size": Vector2(40.0, 34.0),
				"body_color": Palette.RED_DEEP,
				"accent_color": Palette.RED_EMBER,
				"show_label": false,
				"cast_shadow": false,
			})
	if restored >= 3:
		for i in range(2):
			var shaft := spawn_prop("LIGHT SHAFT", Vector2(-1.6 + float(i) * 3.2, -1.6 + float(i) * 3.2), {
				"prop_size": Vector2(18.0, 160.0),
				"body_color": Palette.alpha(Palette.GOLD_SUN, 0.18),
				"accent_color": Palette.GOLD_SACRED,
				"show_label": false,
				"cast_shadow": false,
			})
			shaft.modulate.a = 0.45
			var lamp := PointLight2D.new()
			lamp.texture = _hub_light_tex()
			lamp.color = Color(1.0, 0.86, 0.55)
			lamp.energy = 0.7
			lamp.texture_scale = 2.2
			lamp.position = Vector2(0.0, -40.0)
			shaft.add_child(lamp)
	if restored >= 4:
		for i in range(3):
			spawn_prop("ANCESTOR BANNER", Vector2(-1.4 + float(i) * 1.4, -4.8 - float(i) * 0.8), {
				"prop_size": Vector2(36.0, 110.0),
				"body_color": Palette.CREAM_STONE,
				"accent_color": Palette.GOLD_BRASS,
				"show_label": false,
				"cast_shadow": false,
				"sway_degrees": 2.0,
			})
	if restored >= 5:
		for i in range(5):
			spawn_prop("HIGHLAND GRASS", Vector2(2.0 + float(i) * 1.2, 2.0 + float(i) * 1.2), {
				"texture_path": "res://assets/images/props/highland_grass.png",
				"prop_size": Vector2(34.0, 42.0),
				"body_color": Palette.LIVING_LEAF,
				"accent_color": Palette.LIVING_MOSS,
				"show_label": false,
				"cast_shadow": false,
				"sway_degrees": 5.0,
			})


func _hub_light_tex() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _build_door(house: Dictionary) -> void:
	var house_id := int(house["id"])
	var cell: Vector2 = house["hub_cell"]
	var unlocked: bool = GameState.is_house_unlocked(house_id)
	var completed: bool = GameState.is_house_completed(house_id)
	var accent: Color = house["accent"]
	var is_great := house_id == Houses.count()

	var prop := spawn_prop(str(DOOR_LABELS.get(house_id, "GUNO BONG")), cell, {
		"texture_path": "res://assets/images/props/guno_bong_%d.png" % house_id,
		"prop_size": Vector2(210.0, 256.0) if is_great else Vector2(168.0, 204.0),
		"body_color": Palette.EARTH_LOAM,
		"accent_color": accent.lightened(0.15),
		"show_label": false,
		"collision_feet": Vector2(72.0, 40.0) if is_great else Vector2(58.0, 34.0),
	})

	if not unlocked:
		prop.set_tint(Color(0.62, 0.64, 0.72, 0.88))

	_attach_nameplate(prop, house_id, unlocked, completed, accent)

	var approach: Vector2 = cell.lerp(_plaza_cell, 0.16)
	var trigger := add_interactable("Enter %s" % Houses.short_name_for(house_id),
		approach, {"radius": 100.0})
	trigger.interacted.connect(_on_door_used.bind(house_id))

	_doors[house_id] = {"prop": prop, "trigger": trigger}


func _attach_nameplate(prop: PlaceholderProp, house_id: int, unlocked: bool,
		completed: bool, accent: Color) -> void:
	var plate := VBoxContainer.new()
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.custom_minimum_size = Vector2(200.0, 0.0)
	plate.size = Vector2(200.0, 48.0)
	plate.position = Vector2(-100.0, 4.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = 24
	plate.add_to_group("world_chrome")
	plate.add_theme_constant_override("separation", 0)

	var title := Label.new()
	title.text = Houses.short_name_for(house_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color",
		Palette.CREAM_WARP if unlocked else Palette.alpha(Palette.DREAM_MIST, 0.7))
	title.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.92))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_shadow_color", Palette.alpha(Palette.DREAM_LANTERN, 0.28 if unlocked else 0.0))
	title.add_theme_constant_override("shadow_outline_size", 8 if unlocked else 0)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(title)

	if completed or unlocked:
		var tag := Label.new()
		tag.text = "restored" if completed else "open"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color",
			accent.lightened(0.25) if completed else Palette.GOLD_SACRED)
		tag.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.85))
		tag.add_theme_constant_override("outline_size", 5)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(tag)

	prop.add_child(plate)


## Restored Houses keep their colour on the green.
func _restore_completed_colors() -> void:
	if GameState.game_completed:
		ColorRestoration.set_global_gray(0.0)
		return
	for house_id in GameState.completed_houses:
		var door: Variant = _doors.get(int(house_id))
		if door == null:
			continue
		ColorRestoration.add_zone("hub_house_%d" % int(house_id),
			(door as Dictionary)["prop"] as Node2D, 340.0, 0.94)
	if player != null:
		ColorRestoration.add_zone("staff_carried", player, 130.0, 0.85)


func _run_chapter() -> void:
	if GameState.current_chapter >= 1:
		await _enter_house(GameState.current_chapter, true)
		return

	if GameState.game_completed:
		banner("The green, in full colour", 2.4)
		objective("The world is whole. Walk any House, or rest at the Gateway.")
		return

	var next_house := _next_open_house()
	objective("Walk the boardwalk. Enter %s. [E]" % Houses.short_name_for(next_house))

	if GameState.completed_houses.is_empty():
		await say([
			"Five houses around one crossing, all of them the same gray. The boardwalk between them is worn deep, which means it was walked once, often, by people who are not here now.",
			{"speaker": "S'lang", "text": "The first one, then. Whatever a cloth is built on, that is where you start."},
		])
		GameState.unlock_lore("guno_bong")


func _next_open_house() -> int:
	for house in Houses.LIST:
		var house_id := int(house["id"])
		if GameState.is_house_unlocked(house_id) and not GameState.is_house_completed(house_id):
			return house_id
	return Houses.count()


func _on_door_used(house_id: int) -> void:
	if SceneFader.is_busy() or _active_house_id != 0:
		return

	if not GameState.is_house_unlocked(house_id):
		var house := Houses.get_house(house_id)
		await say([
			{"speaker": "S'lang", "text": "Barred. And the bars are the same stuff as the shadow."},
			str(house.get("locked_hint", "Something must be restored first.")),
		])
		return

	if house_id == Houses.count() and not GameState.can_face_the_shadow_weaver():
		await say([
			{"speaker": "Fun Kdungon", "text": "Not yet. Three colours and a pattern, or the Sacred Loom will not hold what you put on it."},
			"Black, Red, Gold, and the Sacred Master Pattern. Then the great house.",
		])
		return

	await _enter_house(house_id, false)


func _enter_house(house_id: int, _from_retry: bool) -> void:
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	if quest == null or player == null:
		return
	_active_house_id = house_id
	GameState.set_current_chapter(house_id)
	var spawn: Vector2 = HOUSE_ORIGINS[house_id] + HOUSE_SPAWNS[house_id]
	_spawn_position = Iso.cell_to_world(spawn)
	player.global_position = _spawn_position
	player.velocity = Vector2.ZERO
	_set_camera_floor(_house_floors.get(house_id) as Node2D)
	if camera != null:
		camera.global_position = player.global_position
	_set_house_darkness(quest, true)
	if hud != null and hud.has_method("set_chapter"):
		hud.call("set_chapter", Houses.name_for(house_id))
	var exit: Interactable = _exit_triggers.get(house_id) as Interactable
	if exit != null:
		exit.set_enabled(GameState.is_house_completed(house_id))
	set_player_input(true)
	if not GameState.is_house_completed(house_id):
		quest.start_quest()
	else:
		quest.apply_restored_color()
		if not _from_retry:
			objective("Look around, then leave by the porch marked TO THE RIDGE.")


func _leave_house(house_id: int) -> void:
	if _leaving_house or _active_house_id != house_id:
		return
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	if quest != null and quest.is_busy():
		await say([
			{"speaker": "S'lang", "text": "Not yet. This house still has work in it."},
		])
		return
	_leaving_house = true
	_active_house_id = 0
	GameState.set_current_chapter(0)
	_set_house_darkness(quest, false)
	var door: Dictionary = _doors.get(house_id, {}) as Dictionary
	var cell: Vector2 = Houses.get_house(house_id).get("hub_cell", _plaza_cell)
	if door.has("trigger") and door["trigger"] is Node2D:
		player.global_position = (door["trigger"] as Node2D).global_position + Vector2(18.0, 28.0)
	else:
		player.global_position = Iso.cell_to_world(cell + Vector2(0.9, 0.9))
	player.velocity = Vector2.ZERO
	_spawn_position = Iso.cell_to_world(_plaza_cell)
	_set_camera_floor(_ridge_floor)
	if camera != null:
		camera.global_position = player.global_position
	_restore_completed_colors()
	if hud != null and hud.has_method("set_chapter"):
		hud.call("set_chapter", chapter_title)
	set_player_input(true)
	if GameState.game_completed:
		objective("The world is whole. Walk the green.")
	else:
		objective("Walk the boardwalk. Enter %s. [E]" % Houses.short_name_for(_next_open_house()))
	_leaving_house = false


func on_house_completed(house_id: int, _next_scene := "") -> void:
	_restore_completed_colors()
	_refresh_door_locks()
	var gate: HouseExit = _house_exits.get(house_id) as HouseExit
	if gate != null:
		gate.set_open(true)
	set_player_input(true)
	if house_id == Houses.count():
		return
	objective("Walk the glowing porch at the front of the house — TO THE RIDGE.")


func _refresh_door_locks() -> void:
	for house in Houses.LIST:
		var house_id := int(house["id"])
		var data: Variant = _doors.get(house_id)
		if data == null:
			continue
		var prop := (data as Dictionary).get("prop") as PlaceholderProp
		if prop != null and GameState.is_house_unlocked(house_id):
			prop.set_tint(Color.WHITE)


func _on_player_attacked(swing_position: Vector2, facing: Vector2) -> void:
	var quest: HouseQuest = _quests.get(_active_house_id) as HouseQuest
	if quest != null and quest.has_method("_on_player_attacked"):
		quest._on_player_attacked(swing_position, facing)
	else:
		shake_camera(4.5)


func _set_camera_floor(which: Node2D) -> void:
	if which != null:
		floor_node = which


func _hide_house_darkness(quest: HouseQuest) -> void:
	_set_house_darkness(quest, false)


func _set_house_darkness(quest: HouseQuest, on: bool) -> void:
	if quest == null:
		return
	for child in quest.get_children():
		if child is CanvasModulate:
			(child as CanvasModulate).visible = on


func _clamp_camera() -> void:
	if camera == null or floor_node == null:
		return
	if not floor_node.get("origin_cell") is Vector2i:
		super._clamp_camera()
		return
	var origin := Vector2(floor_node.origin_cell)
	var cols := int(floor_node.get("cols"))
	var rows := int(floor_node.get("rows"))
	var corners: Array[Vector2] = [
		Iso.cell_to_world(origin),
		Iso.cell_to_world(origin + Vector2(cols, 0)),
		Iso.cell_to_world(origin + Vector2(cols, rows)),
		Iso.cell_to_world(origin + Vector2(0, rows)),
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
