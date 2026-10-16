extends ChapterBase
## The village green — one painted 16:9 plate (houses and terrain together).
## Invisible blockers + nameplates sit on the painted houses. Entering a House
## hides the plate and frames that interior.

## Extra zoom on the painted ridge. House interiors keep their own framing.
const HUB_ZOOM_IN := 1.15

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

## Stand on the painted porch in front of the door. World pixels on the 1536 plate.
const HOUSE_DOOR_RADIUS := 108.0

## Residents stroll their porch, then the hall, only after that house is restored.
## They step aside if the chapter is replayed.
const VILLAGERS: Array[Dictionary] = [
	{
		"house": 1,
		"label": "THE CHIEF",
		"sheet": "chief",
		"talk": "Chief",
		"speak": "Speak with the Chief",
		"needs_complete": true,
		"lines": [
			{"speaker": "The Chief", "text": "I walk this green so the path does not forget us."},
			{"speaker": "The Chief", "text": "Come closer. The houses can wait a moment."},
		],
		"door": Vector2(0.32, 0.66),
		"exit": Vector2(0.50, 0.86),
		"outside": [Vector2(0.36, 0.72), Vector2(0.28, 0.76), Vector2(0.44, 0.70)],
		"inside": [Vector2(0.30, 0.62), Vector2(0.48, 0.70), Vector2(0.58, 0.76), Vector2(0.40, 0.52)],
	},
	{
		"house": 2,
		"label": "HARVEST QUEEN",
		"sheet": "queen",
		"talk": "Harvest Queen",
		"speak": "Speak with the Harvest Queen",
		"needs_complete": true,
		"lines": [
			{"speaker": "The Harvest Queen", "text": "The hill and the cloth want the same thing. Someone tending them."},
			{"speaker": "The Harvest Queen", "text": "Speak. The harvest does not run off."},
		],
		"door": Vector2(0.685, 0.66),
		"exit": Vector2(0.50, 0.86),
		"outside": [Vector2(0.62, 0.72), Vector2(0.74, 0.76), Vector2(0.56, 0.68)],
		"inside": [Vector2(0.34, 0.70), Vector2(0.50, 0.62), Vector2(0.64, 0.55), Vector2(0.42, 0.48)],
	},
	{
		"house": 5,
		"label": "FUN KDUNGON",
		"sheet": "fun",
		"talk": "",
		"speak": "Speak with Fun Kdungon",
		"needs_complete": true,
		"lines": [
			{"speaker": "Fun Kdungon", "text": "The Sacred Loom is quiet. I am not."},
			{"speaker": "Fun Kdungon", "text": "Walk with me a little. The great house can spare me."},
		],
		"door": Vector2(0.50, 0.32),
		"exit": Vector2(0.50, 0.82),
		"outside": [Vector2(0.44, 0.38), Vector2(0.56, 0.40), Vector2(0.50, 0.44)],
		"inside": [Vector2(0.62, 0.52), Vector2(0.48, 0.60), Vector2(0.55, 0.70)],
	},
]

var _doors: Dictionary = {}
var _quests: Dictionary = {}
var _house_floors: Dictionary = {}
var _house_nodes: Dictionary = {}
var _exit_triggers: Dictionary = {}
var _house_exits: Dictionary = {}
var _ridge_floor: Node2D
var _terrain: HubTerrain
var _plate: HubPlate
var _scenery_house: PlaceholderProp
var _active_house_id := 0
var _plaza_cell := Vector2.ZERO
var _leaving_house := false
var _trail: BreadcrumbTrail
var _villagers: Dictionary = {}
var _villager_chat := false
var _object_chat := false
## She stays for the chapter 1 farewell, then leaves for chapter 4 on the way out.
var _fun_holding_farewell := false
var _house_sparks: Dictionary = {}


func _build_world() -> void:
	GameState.sync_house_unlocks()
	_ridge_floor = floor_node
	if _ridge_floor != null:
		_ridge_floor.visible = false
	Audio.set_ambience(0.22, 16.0)

	_mount_plate()
	_hide_map_reference()
	if _plate != null and world != null:
		_plate.reparent_solids_to(world)
		NpcNav.bake_world(world, _plate.global_world_rect())
	if player != null:
		player.set_light_enabled(false)
		if GameState.current_chapter < 1:
			var spawn := _plate.spawn_world() if _plate != null \
				else Iso.cell_to_world(player_spawn_cell)
			player.global_position = spawn
			_spawn_position = spawn
	_trail = BreadcrumbTrail.new()
	_trail.name = "HouseTrail"
	_trail.size = 1.35
	(world if world != null else self).add_child(_trail)
	for house in Houses.LIST:
		_build_door(house)
		_mount_house(house)
	_place_scenery_house()

	_restore_completed_colors()
	_show_ridge()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_view_resized):
		get_viewport().size_changed.connect(_on_view_resized)
	ColorRestoration.remove_zone("lewet_staff")
	_refresh_villagers()
	_sync_fun_guide()


func _mount_plate() -> void:
	_plate = HubPlate.new()
	_plate.name = "HubPlate"
	add_child(_plate)
	move_child(_plate, 0)
	_plaza_cell = Iso.world_to_cell(_plate.plaza_world())


func _hide_map_reference() -> void:
	if world == null:
		return
	var map_ref := world.get_node_or_null("MapReference") as CanvasItem
	if map_ref != null:
		map_ref.visible = false


func _mount_terrain() -> void:
	pass


func _mount_house(house: Dictionary) -> void:
	var house_id := int(house["id"])
	var origin: Vector2 = HOUSE_ORIGINS[house_id]
	var tracked: Array[Node] = []
	_add_house_floor(house_id, origin)
	var floor: Node = _house_floors.get(house_id) as Node
	if floor != null:
		tracked.append(floor)

	var world_from := world.get_child_count() if world != null else 0
	var script := load(str(HOUSE_QUESTS[house_id])) as Script
	var quest: HouseQuest = script.new() as HouseQuest
	quest.name = "House%d" % house_id
	quest.host = self
	quest.house_id = house_id
	quest.region_origin = origin
	quest.region_spawn = HOUSE_SPAWNS[house_id]
	add_child(quest)
	quest.build()
	tracked.append(quest)
	_quests[house_id] = quest
	_hide_house_darkness(quest)
	_place_house_exit(house_id, origin, house.get("accent", Palette.GOLD_BRASS) as Color)
	if world != null:
		for i in range(world_from, world.get_child_count()):
			tracked.append(world.get_child(i))
	_house_nodes[house_id] = tracked
	if quest.uses_painted_plate():
		var hall := quest.plate_world_rect()
		if hall.size.x >= 32.0:
			NpcNav.bake_region(world, "NpcNav_house%d" % house_id, hall)
	_set_house_nodes_visible(house_id, false)


func _place_house_exit(house_id: int, origin: Vector2, accent: Color) -> void:
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	var painted := quest != null and quest.uses_painted_plate()
	var exit_pos := Vector2.ZERO
	if painted:
		exit_pos = quest.threshold_world()
	else:
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
		exit_pos = Iso.cell_to_world(exit_cell)
	var gate := HouseExit.new()
	gate.name = "RidgeExit_%d" % house_id
	gate.accent = accent
	gate.painted_path = painted
	gate.position = exit_pos
	world.add_child(gate)
	gate.used.connect(_leave_house.bind(house_id))
	_house_exits[house_id] = gate
	_exit_triggers[house_id] = gate.get_node_or_null("ExitTrigger")
	if GameState.is_house_completed(house_id):
		gate.set_open(true, true)


func _add_house_floor(house_id: int, origin: Vector2) -> void:
	if house_id == 1 or house_id == 2 or house_id == 3 or house_id == 4 or house_id == 5:
		return
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
	# Outer rim trees only — frame the diamond; leave mid-zone for village POIs.
	var trees: Array[Vector2] = [
		Vector2(-14.0, -6.0), Vector2(-14.0, 0.0), Vector2(-14.0, 5.0), Vector2(-13.0, 9.0),
		Vector2(-9.0, -13.0), Vector2(-4.0, -14.0), Vector2(2.0, -14.0), Vector2(7.0, -13.0),
		Vector2(13.0, -8.0), Vector2(14.0, -2.0), Vector2(14.0, 4.0), Vector2(13.0, 8.0),
		Vector2(9.0, 13.0), Vector2(3.0, 14.0), Vector2(-3.0, 14.0), Vector2(-8.0, 13.0),
		Vector2(-12.0, -10.0), Vector2(11.0, -11.0), Vector2(-11.0, 12.0),
	]
	for i in range(trees.size()):
		var cell: Vector2 = trees[i]
		if not _park_slot_free(cell, 4.5, 2):
			continue
		spawn_prop("HIGHLAND TREE", cell, {
			"texture_path": "res://assets/images/environments/highland/highland_tree.png",
			"prop_size": Vector2(80.0 + float(i % 3) * 10.0, 120.0 + float(i % 2) * 16.0),
			"body_color": Palette.EARTH_WOOD,
			"accent_color": Palette.LIVING_LEAF,
			"show_label": false,
			"nearest_filter": true,
			"sway_degrees": 1.2,
			"blocks_movement": true,
			"collision_feet": Vector2(24.0, 16.0),
		})

	# Mid-zone POIs between plaza and houses — gardens, benches, fences, crates.
	_dress_mid_zone()


func _dress_mid_zone() -> void:
	# Sit in the wedges between path arms — only skip exact road cells.
	var fences: Array[Vector2] = [
		Vector2(-5.0, 4.0), Vector2(5.0, -4.0), Vector2(-6.0, -3.0), Vector2(3.0, 6.0),
		Vector2(-4.0, 7.0), Vector2(7.0, -3.0), Vector2(-7.0, 2.0), Vector2(2.0, -7.0),
		Vector2(-8.0, 5.0), Vector2(8.0, -5.0), Vector2(5.0, 8.0), Vector2(-5.0, -8.0),
		Vector2(-6.0, 6.0), Vector2(6.0, -6.0), Vector2(-3.0, 8.0), Vector2(8.0, 3.0),
	]
	for cell in fences:
		if not _park_slot_free(cell, 3.5, 0):
			continue
		spawn_prop("BAMBOO FENCE", cell, {
			"texture_path": "res://assets/images/environments/highland/bamboo_fence.png",
			"prop_size": Vector2(64.0, 48.0),
			"body_color": Palette.EARTH_WOOD,
			"accent_color": Palette.LIVING_MOSS,
			"show_label": false,
			"nearest_filter": true,
			"blocks_movement": true,
			"collision_feet": Vector2(22.0, 12.0),
		})

	var gardens: Array[Vector2] = [
		Vector2(-6.0, 3.0), Vector2(6.0, -3.0), Vector2(-3.0, -6.0), Vector2(3.0, 6.0),
		Vector2(-7.0, -5.0), Vector2(7.0, 5.0), Vector2(5.0, -7.0), Vector2(-5.0, 7.0),
		Vector2(-9.0, 1.0), Vector2(9.0, -1.0), Vector2(1.0, -9.0), Vector2(-1.0, 9.0),
		Vector2(-8.0, -7.0), Vector2(8.0, 7.0), Vector2(-7.0, 8.0), Vector2(7.0, -8.0),
	]
	for i in range(gardens.size()):
		var cell: Vector2 = gardens[i]
		if not _park_slot_free(cell, 3.5, 0):
			continue
		var flower := i % 2 == 0
		var patch := spawn_prop("GARDEN BED" if flower else "ABACA PATCH", cell, {
			"texture_path": "res://assets/images/props/red_flowers.png" if flower \
					else "res://assets/images/props/abaca_plant.png",
			"prop_size": Vector2(56.0, 42.0) if flower else Vector2(40.0, 80.0),
			"body_color": Palette.RED_DEEP if flower else Palette.BLACK_BARK,
			"accent_color": Palette.RED_EMBER if flower else Palette.CREAM_STONE,
			"show_label": false,
			"nearest_filter": true,
			"sway_degrees": 1.6 if not flower else 0.0,
			"cast_shadow": not flower,
		})
		# A few patches answer when S'lang draws near — same [E] popup as a pickup.
		if not flower and i % 4 == 1:
			_attach_object_talk(patch, "Speak with the Abaca", [
				{"speaker": "Abaca", "text": "Strip me. Comb me. Knot me end to end."},
				{"speaker": "S'lang", "text": "Patience. The cloth begins here."},
			], 48.0, Vector2(0.0, -56.0))

	var benches: Array[Vector2] = [
		Vector2(-2.0, 5.0), Vector2(5.0, 2.0), Vector2(2.0, -5.0), Vector2(-5.0, -2.0),
		Vector2(-4.0, 4.0), Vector2(4.0, -4.0), Vector2(-5.0, 5.0), Vector2(5.0, 5.0),
	]
	for cell in benches:
		if not _park_slot_free(cell, 3.0, 0):
			continue
		spawn_prop("STRIPPING BENCH", cell, {
			"texture_path": "res://assets/images/props/stripping_bench.png",
			"prop_size": Vector2(58.0, 38.0),
			"body_color": Palette.EARTH_WOOD,
			"accent_color": Palette.CREAM_STONE,
			"show_label": false,
			"nearest_filter": true,
			"blocks_movement": true,
			"collision_feet": Vector2(20.0, 12.0),
		})

	var mats: Array[Vector2] = [
		Vector2(4.0, 4.0), Vector2(-4.0, -4.0), Vector2(-3.0, 5.0), Vector2(3.0, -5.0),
		Vector2(-5.0, -5.0), Vector2(5.0, -5.0),
	]
	for cell in mats:
		if not _park_slot_free(cell, 3.0, 0):
			continue
		spawn_prop("REST MAT", cell, {
			"texture_path": "res://assets/images/props/sleeping_mat.png",
			"prop_size": Vector2(52.0, 34.0),
			"body_color": Palette.CREAM_STONE,
			"accent_color": Palette.GOLD_BRASS,
			"show_label": false,
			"nearest_filter": true,
			"cast_shadow": false,
		})

	var rocks: Array[Vector2] = [
		Vector2(-8.0, -4.0), Vector2(8.0, 4.0), Vector2(-4.0, 9.0), Vector2(4.0, -9.0),
		Vector2(9.0, -6.0), Vector2(-9.0, 6.0), Vector2(6.0, 9.0), Vector2(-6.0, -9.0),
		Vector2(10.0, 3.0), Vector2(-10.0, -3.0), Vector2(-9.0, -9.0), Vector2(9.0, 9.0),
	]
	for cell in rocks:
		if not _park_slot_free(cell, 3.5, 0):
			continue
		spawn_prop("RIDGE ROCK", cell, {
			"texture_path": "res://assets/images/environments/highland/highland_rock.png",
			"prop_size": Vector2(46.0, 36.0),
			"body_color": Palette.CREAM_STONE,
			"accent_color": Palette.EARTH_WOOD,
			"show_label": false,
			"nearest_filter": true,
			"blocks_movement": true,
			"collision_feet": Vector2(16.0, 10.0),
		})

	var crates: Array[Vector2] = [
		Vector2(-7.0, -2.0), Vector2(7.0, 2.0), Vector2(-2.0, 8.0), Vector2(2.0, -8.0),
		Vector2(8.0, -3.0), Vector2(-8.0, 3.0), Vector2(-6.0, 8.0), Vector2(6.0, -8.0),
	]
	for i in range(crates.size()):
		var cell: Vector2 = crates[i]
		if not _park_slot_free(cell, 3.5, 0):
			continue
		var drying := i % 2 == 0
		spawn_prop("DRYING RACK" if drying else "FIBRE BASKET", cell, {
			"texture_path": "res://assets/images/props/drying_rack.png" if drying \
					else "res://assets/images/props/fibre_basket.png",
			"prop_size": Vector2(48.0, 60.0) if drying else Vector2(38.0, 36.0),
			"body_color": Palette.EARTH_WOOD,
			"accent_color": Palette.CREAM_STONE,
			"show_label": false,
			"nearest_filter": true,
			"blocks_movement": true,
			"collision_feet": Vector2(14.0, 10.0),
		})


func _park_slot_free(cell: Vector2, house_radius: float, path_radius: int) -> bool:
	if _near_house(cell, house_radius):
		return false
	if _terrain != null and (_terrain.is_path_cell(cell) or _terrain.is_near_path(cell, path_radius)):
		return false
	return true


func _near_house(cell: Vector2, radius: float) -> bool:
	for house in Houses.LIST:
		if cell.distance_to(house["hub_cell"] as Vector2) <= radius:
			return true
	return false

func _dress_living_ridge() -> void:
	var restored := GameState.completed_houses.size()
	if GameState.game_completed:
		restored = Houses.count()

	# Progress is readable on the green itself: more colour, more life, more light.
	if restored >= 1:
		for i in range(3):
			var abaca := spawn_prop("ABACA PLANT", Vector2(-3.5, 6.0 + float(i) * 1.4), {
				"texture_path": "res://assets/images/props/abaca_plant.png",
				"prop_size": Vector2(36.0, 78.0),
				"body_color": Palette.BLACK_BARK,
				"accent_color": Palette.CREAM_STONE,
				"show_label": false,
				"sway_degrees": 2.4,
			})
			if i == 1:
				_attach_object_talk(abaca, "Speak with the Abaca", [
					{"speaker": "Abaca", "text": "I am the banana's cousin. My trunk is the warp if you are patient."},
					{"speaker": "S'lang", "text": "I remember. Bend and hold a knot, or you are set aside."},
				], 52.0, Vector2(0.0, -64.0))
	if restored >= 2:
		for i in range(3):
			spawn_prop("RED FLOWERS", Vector2(6.0 + float(i) * 1.4, -3.2), {
				"texture_path": "res://assets/images/props/red_flowers.png",
				"prop_size": Vector2(40.0, 34.0),
				"body_color": Palette.RED_DEEP,
				"accent_color": Palette.RED_EMBER,
				"show_label": false,
				"cast_shadow": false,
			})
		var root := spawn_prop("HULO ROOTS", Vector2(7.2, -2.0), {
			"texture_path": "res://assets/images/props/hulo_root.png",
			"prop_size": Vector2(44.0, 36.0),
			"body_color": Palette.RED_DEEP,
			"accent_color": Palette.RED_EMBER,
			"show_label": false,
			"nearest_filter": true,
			"cast_shadow": false,
		})
		_attach_object_talk(root, "Speak with the Roots", [
			{"speaker": "Hulo Root", "text": "Pound me in the mortar. I keep the red until the pestle asks."},
			{"speaker": "S'lang", "text": "Loko. The colour of courage."},
		], 50.0, Vector2(0.0, -48.0))
	if restored >= 3:
		for i in range(2):
			var shaft := spawn_prop("LIGHT SHAFT", Vector2(-3.2 + float(i) * 6.4, -3.2 + float(i) * 6.4), {
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
			lamp.energy = 0.45
			lamp.texture_scale = 2.0
			lamp.position = Vector2(0.0, -40.0)
			shaft.add_child(lamp)
	if restored >= 5:
		for i in range(5):
			spawn_prop("HIGHLAND GRASS", Vector2(4.0 + float(i) * 1.2, 4.0 + float(i) * 1.2), {
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
	var unlocked: bool = GameState.is_house_unlocked(house_id)
	var completed: bool = GameState.is_house_completed(house_id)
	var accent: Color = house["accent"]
	var house_size: Vector2 = house.get("hub_size", Vector2(236.0, 248.0)) as Vector2
	var sprite_path := str(house.get("hub_sprite", "res://assets/images/houses/House%d.png" % house_id))
	var feet: Vector2 = house.get("hub_feet", Vector2(house_size.x * 0.82, house_size.y * 0.36)) as Vector2
	var world_pos := _hub_world_pos(house)

	var prop := spawn_prop(str(DOOR_LABELS.get(house_id, "GUNO BONG")), _plaza_cell, {
		"texture_path": sprite_path,
		"prop_size": house_size,
		"body_color": Palette.EARTH_LOAM,
		"accent_color": accent.lightened(0.2),
		"show_label": false,
		"nearest_filter": false,
		"cast_shadow": false,
		"blocks_movement": false,
		"collision_feet": feet,
	})
	prop.position = world_pos
	prop.z_index = 2
	_hide_prop_art(prop)

	if not unlocked:
		prop.set_tint(Color(0.88, 0.89, 0.93, 0.98))
	elif completed:
		prop.set_tint(Color(1.02, 1.01, 0.99, 1.0))

	var tag := "restored" if completed else ("open" if unlocked else "")
	var title := _attach_name_label(prop, Houses.short_name_for(house_id), tag, unlocked, accent, house_size)

	# Doorstep: same X as the painted door, a few pixels toward the camera.
	var porch := _porch_world(house)
	var trigger := add_interactable("Enter %s" % Houses.short_name_for(house_id),
		Vector2.ZERO, {
			"position": porch,
			"radius": HOUSE_DOOR_RADIUS * (1.25 if house_id == 4 else 1.0),
			"hub_door_priority": true,
			"prompt_offset": Vector2(0.0, -120.0),
		})
	trigger.add_to_group("hub_door")
	trigger.interacted.connect(_on_door_used.bind(house_id))

	var lock := _attach_lock_mark(prop, world_pos, porch)
	lock.set_shown(not unlocked)
	var next := _attach_next_mark(prop)
	next.set_shown(false)

	_doors[house_id] = {
		"prop": prop,
		"trigger": trigger,
		"lock": lock,
		"next": next,
		"title": title,
	}


func _place_scenery_house() -> void:
	pass


func _hide_prop_art(prop: PlaceholderProp) -> void:
	var sprite := prop.get_sprite()
	if sprite != null:
		sprite.visible = false
	prop.cast_shadow = false


func _hub_world_pos(house: Dictionary) -> Vector2:
	if _plate != null:
		var uv: Vector2 = house.get("hub_door_uv", house.get("hub_uv", Vector2(0.5, 0.5))) as Vector2
		return _plate.uv_to_world(uv)
	return Iso.cell_to_world(house.get("hub_cell", _plaza_cell) as Vector2)


func _plaza_world() -> Vector2:
	if _plate != null:
		return _plate.plaza_world()
	return Iso.cell_to_world(_plaza_cell)


func _porch_world(house: Dictionary) -> Vector2:
	if _plate != null:
		return _plate.uv_to_world(Houses.hub_porch(house))
	return _porch_pos(_hub_world_pos(house))


func _porch_pos(world_pos: Vector2) -> Vector2:
	var delta := _plaza_world() - world_pos
	if delta.length_squared() < 1.0:
		return world_pos
	return world_pos + delta.normalized() * 96.0


func _attach_name_label(prop: PlaceholderProp, title_text: String, tag_text: String,
		unlocked: bool, accent: Color, _house_size: Vector2) -> Label:
	var plate := VBoxContainer.new()
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.custom_minimum_size = Vector2(240.0, 0.0)
	plate.size = Vector2(240.0, 56.0)
	# This prop sits on the painted door. The name stays there for every house.
	plate.position = Vector2(-120.0, -16.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = 30
	plate.add_theme_constant_override("separation", 0)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color",
		Palette.CREAM_WARP if unlocked else Palette.alpha(Palette.DREAM_MIST, 0.85))
	title.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.95))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Palette.alpha(Palette.DREAM_LANTERN, 0.32 if unlocked else 0.1))
	title.add_theme_constant_override("shadow_outline_size", 10 if unlocked else 4)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(title)

	if not tag_text.is_empty():
		var tag := Label.new()
		tag.text = tag_text
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color",
			accent.lightened(0.25) if tag_text == "restored" else Palette.GOLD_SACRED)
		tag.add_theme_color_override("font_outline_color", Palette.alpha(Palette.DREAM_ABYSS, 0.9))
		tag.add_theme_constant_override("outline_size", 6)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(tag)

	prop.add_child(plate)
	return title


## Padlock on the painted door, just above the name.
func _attach_lock_mark(prop: PlaceholderProp, _house_pos: Vector2, _porch: Vector2) -> HouseLockMark:
	var mark := HouseLockMark.new()
	mark.name = "Lock"
	mark.position = Vector2(0.0, -42.0)
	prop.add_child(mark)
	return mark


## Arrow on the door S'lang should enter, pointing down at the name.
func _attach_next_mark(prop: PlaceholderProp) -> HouseNextMark:
	var mark := HouseNextMark.new()
	mark.name = "Next"
	mark.position = Vector2(0.0, -40.0)
	prop.add_child(mark)
	return mark


## Restored Houses keep their colour on the green.
func _restore_completed_colors() -> void:
	if GameState.game_completed:
		ColorRestoration.clear_zones()
		ColorRestoration.set_global_gray(0.0)
		if _plate != null:
			_plate.sync_restoration(player)
		_sync_house_sparkles()
		return
	if _active_house_id != 0:
		ColorRestoration.clear_zones()
		var quest: HouseQuest = _quests.get(_active_house_id) as HouseQuest
		# Painted interiors curse the plate itself, same as the ridge.
		# Iso houses still use the fullscreen veil.
		if quest != null and quest.uses_painted_plate():
			ColorRestoration.set_global_gray(0.0)
		elif GameState.is_house_completed(_active_house_id):
			ColorRestoration.set_global_gray(0.0)
		else:
			ColorRestoration.set_global_gray(1.0)
		return
	# Ridge uses the cursed plate, not the fullscreen gray filter.
	ColorRestoration.clear_zones()
	ColorRestoration.set_global_gray(0.0)
	if _plate != null:
		_plate.sync_restoration(player)
	_sync_house_sparkles()


func _sync_house_sparkles() -> void:
	if _plate == null:
		return
	for house in Houses.LIST:
		var house_id := int(house["id"])
		var want := GameState.is_house_completed(house_id) or GameState.game_completed
		if want:
			if _house_sparks.has(house_id) and is_instance_valid(_house_sparks[house_id]):
				continue
			var motes := Fx.house_glitter()
			motes.position = _plate.uv_to_world(Houses.hub_solid_centre(house) + Vector2(0.0, -0.03))
			_plate.add_child(motes)
			_house_sparks[house_id] = motes
		elif _house_sparks.has(house_id):
			var stored: Variant = _house_sparks[house_id]
			if is_instance_valid(stored):
				(stored as Node).queue_free()
			_house_sparks.erase(house_id)


func _run_chapter() -> void:
	# Menu "Test Chapter" sets replay_house_id (not saved). Prefer that over a
	# stale current_chapter so the jump always lands inside the chosen House.
	var jump_to := GameState.replay_house_id if GameState.replay_house_id >= 1 \
		else GameState.current_chapter
	if jump_to >= 1:
		await _enter_house(jump_to, true)
		return

	if GameState.game_completed:
		banner("The green, in full colour", 2.4)
		objective("The world is whole. Walk any House, or rest at the Gateway.")
		return

	var next_house := _next_open_house()
	objective("Walk the boardwalk. Enter %s. [E]" % Houses.short_name_for(next_house))
	if hud != null and hud.has_method("show_quest_plate"):
		hud.call("show_quest_plate", false)

	if GameState.completed_houses.is_empty() and not GameState.lore.has("guno_bong"):
		banner("Five houses. Start at Black Foundation — [E] at the porch.", 3.2)
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

	GameState.sync_house_unlocks()
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

	set_player_input(false)
	await SceneFader.cover(0.28)
	await _enter_house(house_id, false)
	await SceneFader.reveal(0.32)


func _enter_house(house_id: int, _from_retry: bool) -> void:
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	if quest == null or player == null:
		return
	_active_house_id = house_id
	GameState.set_current_chapter(house_id)
	Audio.set_house(house_id)
	# Seal before the exit Area2D turns on. Completed Houses keep auto_use open,
	# and spawn can sit inside that pad (Ch2 especially) — Test Chapter was
	# bouncing straight back to the plaza totem on the same frame.
	var starting_quest := GameState.wants_replay(house_id) \
		or not GameState.is_house_completed(house_id)
	var gate: HouseExit = _house_exits.get(house_id) as HouseExit
	if gate != null:
		gate.set_open(not starting_quest, true)
	if quest.uses_painted_plate():
		_spawn_position = quest.player_spawn_world()
	else:
		var spawn: Vector2 = HOUSE_ORIGINS[house_id] + HOUSE_SPAWNS[house_id]
		_spawn_position = Iso.cell_to_world(spawn)
	player.global_position = _spawn_position
	player.velocity = Vector2.ZERO
	_show_house(house_id)
	_refresh_villagers()
	_sync_fun_guide()
	_set_house_darkness(quest, true)
	if gate != null:
		gate.set_plate_visible(true)
	if hud != null and hud.has_method("set_chapter"):
		hud.call("set_chapter", Houses.name_for(house_id))
	if hud != null and hud.has_method("show_quest_plate"):
		hud.call("show_quest_plate", true)
	set_player_input(true)
	if not GameState.is_house_completed(house_id):
		GameState.note_house_entered(house_id, GameState.consume_fresh_attempt())
	if starting_quest:
		quest.start_quest()
	else:
		quest.apply_restored_color()
		if not _from_retry:
			objective("Look around, then walk the wooden path at the front of the house.")


func _leave_house(house_id: int) -> void:
	if _leaving_house or _active_house_id != house_id or SceneFader.is_busy():
		return
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	if quest != null and quest.is_busy():
		await say([
			{"speaker": "S'lang", "text": "Not yet. This house still has work in it."},
		])
		return
	_leaving_house = true
	set_player_input(false)
	await SceneFader.cover(0.28)
	_active_house_id = 0
	if house_id == 1:
		_fun_holding_farewell = false
	GameState.set_current_chapter(0)
	GameState.pause_house_clock()
	Audio.clear_house()
	_set_house_darkness(quest, false)
	var gate: HouseExit = _house_exits.get(house_id) as HouseExit
	if gate != null:
		gate.set_plate_visible(false)
	var door: Dictionary = _doors.get(house_id, {}) as Dictionary
	var trigger: Variant = door.get("trigger")
	if is_instance_valid(trigger) and trigger is Node2D:
		player.global_position = (trigger as Node2D).global_position + Vector2(18.0, 28.0)
	else:
		player.global_position = _hub_world_pos(Houses.get_house(house_id)) + Vector2(18.0, 28.0)
	player.velocity = Vector2.ZERO
	_spawn_position = _plaza_world()
	_show_ridge()
	_refresh_villagers()
	_sync_fun_guide()
	_restore_completed_colors()
	if hud != null and hud.has_method("set_chapter"):
		hud.call("set_chapter", chapter_title)
	if hud != null and hud.has_method("show_quest_plate"):
		hud.call("show_quest_plate", false)
	set_player_input(true)
	if GameState.game_completed:
		objective("The world is whole. Walk the green.")
	else:
		objective("Walk the boardwalk. Enter %s. [E]" % Houses.short_name_for(_next_open_house()))
	await SceneFader.reveal(0.32)
	_leaving_house = false


func on_house_completed(house_id: int, _next_scene := "") -> void:
	if house_id == 1:
		_fun_holding_farewell = true
	_restore_completed_colors()
	_refresh_door_locks()
	_refresh_villagers()
	_sync_fun_guide()
	var gate: HouseExit = _house_exits.get(house_id) as HouseExit
	if gate != null:
		gate.set_open(true)
	set_player_input(true)
	if house_id == Houses.count():
		return
	objective("Walk the wooden path at the front of the house to leave.")


func _refresh_villagers() -> void:
	if world == null or _plate == null:
		return
	var wanted: Dictionary = {}
	for spec in VILLAGERS:
		var house_id := int(spec["house"])
		var key := "%d:%s" % [house_id, str(spec["label"])]
		if not _villager_should_walk(spec):
			continue
		wanted[key] = true
		if _villagers.has(key) and is_instance_valid(_villagers[key]):
			continue
		var walker := _spawn_villager(spec)
		if walker != null:
			_villagers[key] = walker
	var gone: Array[String] = []
	for key in _villagers.keys():
		if wanted.has(str(key)):
			continue
		var stored: Variant = _villagers[key]
		if is_instance_valid(stored):
			var walker := stored as VillageWalker
			if walker != null:
				walker.release()
		gone.append(str(key))
	for key in gone:
		_villagers.erase(key)


## One Fun Kdungon. She guides chapter 1, then on the way out she is already
## waiting in chapter 4. A replay of chapter 1 brings her back for that visit.
func _sync_fun_guide() -> void:
	var done := GameState.is_house_completed(1)
	var staying := _active_house_id == 1 and (not done or _fun_holding_farewell or GameState.wants_replay(1))
	var sent := done and not staying
	var first: Node = _quests.get(1) as Node
	var fourth: Node = _quests.get(4) as Node
	if first != null and first.has_method("set_guide_here"):
		first.call("set_guide_here", not sent)
	if fourth != null and fourth.has_method("set_guide_here"):
		fourth.call("set_guide_here", sent)


func _villager_should_walk(spec: Dictionary) -> bool:
	var house_id := int(spec["house"])
	if not GameState.is_house_unlocked(house_id):
		return false
	if bool(spec.get("needs_complete", false)):
		return GameState.is_house_completed(house_id) and not GameState.wants_replay(house_id)
	return true


func _spawn_villager(spec: Dictionary) -> VillageWalker:
	var house_id := int(spec["house"])
	var label := str(spec["label"])
	var stand_in := _find_resident(house_id, label)
	var plate := _interior_plate(house_id)
	if stand_in == null or plate == null:
		return null
	var walker := VillageWalker.new()
	walker.name = "Walker_%d_%s" % [house_id, label.replace(" ", "")]
	walker.house_id = house_id
	walker.resident_name = label
	walker.outside_uvs = _uv_list(spec["outside"])
	walker.inside_uvs = _uv_list(spec["inside"])
	walker.door_uv = spec["door"]
	walker.exit_uv = spec["exit"]
	walker.hub_plate = _plate
	walker.interior_plate = plate
	walker.stand_in = stand_in
	walker.talk_trigger = _find_talk_trigger(house_id, str(spec.get("talk", "")))
	walker.space_of = _player_house_space
	walker.sheet_id = str(spec.get("sheet", ""))
	walker.interior_scale = _interior_scale(house_id)
	walker.speak_prompt = str(spec.get("speak", "Speak"))
	var spoken: Variant = spec.get("lines", [])
	if spoken is Array:
		walker.chat_lines = spoken
	walker.chatted.connect(_on_villager_chatted)
	world.add_child(walker)
	walker.setup(stand_in.texture_path, stand_in.prop_size)
	return walker


func _on_villager_chatted(walker: VillageWalker) -> void:
	if _villager_chat or _object_chat or not is_instance_valid(walker):
		return
	if dialogue != null and dialogue.visible:
		return
	_villager_chat = true
	walker.hold_chat(true)
	await say(walker.pick_lines())
	if is_instance_valid(walker):
		walker.hold_chat(false)
	_villager_chat = false


## Same near-popup as a pickup: walk in, see [E], press it, talk.
func _attach_object_talk(
		host: Node2D,
		prompt: String,
		lines: Array,
		radius := 52.0,
		offset := Vector2(0.0, -56.0)
) -> void:
	if host == null or not is_instance_valid(host) or lines.is_empty():
		return
	var trigger := Interactable.new()
	trigger.name = "ObjectTalk"
	trigger.prompt = prompt
	trigger.radius = radius
	trigger.prompt_offset = Vector2(0.0, -104.0)
	trigger.position = offset
	host.add_child(trigger)
	trigger.interacted.connect(_on_object_talk.bind(lines))


func _on_object_talk(lines: Array) -> void:
	if _object_chat or _villager_chat:
		return
	if dialogue != null and dialogue.visible:
		return
	_object_chat = true
	await say(lines)
	_object_chat = false


func _player_house_space() -> int:
	return _active_house_id


func _interior_scale(house_id: int) -> float:
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	if quest != null:
		return quest.painted_player_scale()
	return 2.6


func _uv_list(points: Array) -> Array[Vector2]:
	var uvs: Array[Vector2] = []
	for point in points:
		uvs.append(point as Vector2)
	return uvs


func _interior_plate(house_id: int) -> Node:
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	if quest == null:
		return null
	for child in quest.get_children():
		if child.has_method("uv_to_global"):
			return child
	return null


func _find_resident(house_id: int, label: String) -> PlaceholderProp:
	for node in _house_nodes.get(house_id, []):
		if not is_instance_valid(node):
			continue
		if node is PlaceholderProp and (node as PlaceholderProp).prop_label == label:
			return node as PlaceholderProp
	return null

 	
func _find_talk_trigger(house_id: int, needle: String) -> Interactable:
	if needle.is_empty():
		return null
	var want := needle.to_lower()
	for node in _house_nodes.get(house_id, []):
		if not is_instance_valid(node):
			continue
		if node is Interactable and want in (node as Interactable).prompt.to_lower():
			return node as Interactable
	return null


func _refresh_door_locks() -> void:
	for house in Houses.LIST:
		var house_id := int(house["id"])
		var data: Variant = _doors.get(house_id)
		if data == null:
			continue
		var prop := (data as Dictionary).get("prop") as PlaceholderProp
		if prop != null and GameState.is_house_unlocked(house_id):
			prop.set_tint(Color.WHITE)
	_refresh_house_guides()


## Lock badges on barred Houses and a gold arrow on the next porch.
## Hidden inside a House; they return when she steps back onto the green.
func _refresh_house_guides() -> void:
	var next_id := _guide_house_id()
	for house in Houses.LIST:
		var house_id := int(house["id"])
		var data: Dictionary = _doors.get(house_id, {})
		var unlocked := GameState.is_house_unlocked(house_id)
		var is_next := house_id == next_id
		var lock := data.get("lock") as HouseLockMark
		if lock != null:
			lock.set_shown(not unlocked)
		var next := data.get("next") as HouseNextMark
		if next != null:
			next.set_shown(is_next)
		var title := data.get("title") as Label
		if title != null:
			var color := Palette.CREAM_WARP
			if not unlocked:
				color = Palette.alpha(Palette.DREAM_MIST, 0.85)
			elif is_next:
				color = Palette.GOLD_SUN
			title.add_theme_color_override("font_color", color)
	_refresh_house_trail(next_id)


## Glowing breadcrumbs along the boardwalk to the porch of the next House.
func _refresh_house_trail(next_id: int) -> void:
	if _trail == null:
		return
	var data: Dictionary = _doors.get(next_id, {})
	var porch := data.get("trigger") as Node2D
	if porch == null:
		_trail.clear()
		return
	_trail.follow(porch)
	# Ridge solids switch on and off as she walks in and out of Houses.
	_trail.invalidate()
	_trail.call_deferred("invalidate")


func _guide_house_id() -> int:
	if GameState.game_completed or _active_house_id != 0 or GameState.current_chapter >= 1:
		return 0
	var house_id := _next_open_house()
	if GameState.is_house_completed(house_id):
		return 0
	return house_id


func _on_player_attacked(swing_position: Vector2, facing: Vector2) -> void:
	var quest: HouseQuest = _quests.get(_active_house_id) as HouseQuest
	if quest != null and quest.has_method("_on_player_attacked"):
		quest._on_player_attacked(swing_position, facing)
	else:
		shake_camera(4.5)


func _set_house_nodes_visible(house_id: int, on: bool) -> void:
	var nodes: Array = _house_nodes.get(house_id, [])
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node is CanvasItem:
			(node as CanvasItem).visible = on
		_set_area_monitoring(node, on)
		_set_static_collision(node, on)


func _set_area_monitoring(node: Node, on: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is Area2D:
		var area := node as Area2D
		area.monitoring = on
		area.monitorable = on
		if area is Interactable and not on:
			(area as Interactable).set_prompt_visible(false)
	for child in node.get_children():
		if is_instance_valid(child):
			_set_area_monitoring(child, on)


func _set_static_collision(node: Node, on: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is CharacterBody2D or node is Area2D:
		return
	if node is StaticBody2D:
		(node as StaticBody2D).collision_layer = PhysicsLayers.LAYER_WORLD if on else 0
	if node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = not on
	elif node is CollisionShape2D:
		(node as CollisionShape2D).disabled = not on
	for child in node.get_children():
		if is_instance_valid(child):
			_set_static_collision(child, on)


func _disable_non_hub_world_solids() -> void:
	if world == null:
		return
	for child in world.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.name == "HubCollision":
			continue
		if child.name == "HubSolids" or child.name == "HubBounds":
			continue
		if child.name.begins_with("WorldBlocker_"):
			continue
		if child is CharacterBody2D or child is NavigationRegion2D:
			continue
		_set_static_collision(child, false)


func _exit_tree() -> void:
	Audio.set_nature_ambience(false)
	Audio.clear_house()


func _show_house(house_id: int) -> void:
	Audio.set_nature_ambience(false)
	if _terrain != null:
		_terrain.visible = false
	_set_ridge_art_visible(false)
	for id in _house_nodes:
		_set_house_nodes_visible(int(id), int(id) == house_id)
	var quest: HouseQuest = _quests.get(house_id) as HouseQuest
	var painted := quest != null and quest.uses_painted_plate()
	if painted:
		if stage != null:
			stage.visible = false
		if floor_node != null:
			floor_node.visible = false
		camera_limit_rect = quest.plate_world_rect()
		if camera != null:
			var z := quest.plate_camera_zoom()
			camera_zoom = Vector2(z, z)
			camera.zoom = Vector2(z, z)
			var rect := quest.plate_world_rect()
			var view := get_viewport_rect().size / Vector2(z, z)
			camera_follows_player = view.x < rect.size.x or view.y < rect.size.y
			if camera_follows_player and player != null and is_instance_valid(player):
				camera.global_position = player.global_position
			else:
				camera.global_position = rect.get_center()
			if player != null and is_instance_valid(player) and player.has_method("apply_depth_scale"):
				player.apply_depth_scale(quest.painted_player_scale())
		apply_camera_world_limits()
		_clamp_camera()
	else:
		camera_limit_rect = Rect2()
		if stage != null:
			stage.visible = true
			stage.configure(house_id, camera)
		fit_camera_to_floor(_house_floors.get(house_id) as Node2D)
	_restore_completed_colors()
	if _trail != null:
		_trail.clear()
		_trail.visible = false


func _show_ridge() -> void:
	Audio.set_nature_ambience(true)
	if _terrain != null:
		_terrain.visible = false
	_set_ridge_art_visible(true)
	for id in _house_nodes:
		_set_house_nodes_visible(int(id), false)
	floor_node = _ridge_floor
	if _ridge_floor != null:
		# The painted HubPlate is the ridge. The old iso grass diamond
		# must stay hidden or it covers the jungle with neon checkers.
		_ridge_floor.visible = false
	camera_follows_player = true
	var ridge := _ridge_frame_rect()
	if camera != null and ridge.size.x >= 8.0:
		var z := cover_zoom_for(ridge) * HUB_ZOOM_IN
		camera_zoom = Vector2(z, z)
		camera.zoom = camera_zoom
		camera_limit_rect = ridge
	elif camera != null:
		camera.zoom = camera_zoom
		camera_limit_rect = Rect2()
	if camera != null and player != null and is_instance_valid(player):
		camera.global_position = player.global_position
		if player.has_method("apply_depth_scale"):
			player.apply_depth_scale(1.0)
	if camera != null:
		apply_camera_world_limits(_ridge_floor)
		_clamp_camera()
	if hud != null and hud.has_method("show_quest_plate"):
		hud.call("show_quest_plate", false)
	_disable_non_hub_world_solids()
	call_deferred("_disable_non_hub_world_solids")
	if stage != null:
		stage.visible = true
		stage.configure(0, camera)
	if _trail != null:
		_trail.visible = true


func _set_ridge_art_visible(on: bool) -> void:
	if _plate != null:
		_plate.set_ridge_visible(on)
		# Solids stay on while the ridge is the active scene, even if the
		# painting is hidden for a fade. Only house interiors drop them.
		_plate.set_ridge_collision(_active_house_id == 0)
	if _scenery_house != null:
		_scenery_house.visible = on
	for data in _doors.values():
		if data is Dictionary:
			var door_data := data as Dictionary
			var prop: Variant = door_data.get("prop")
			if is_instance_valid(prop) and prop is CanvasItem:
				(prop as CanvasItem).visible = on
			var trigger: Variant = door_data.get("trigger")
			if is_instance_valid(trigger) and trigger is Interactable:
				var door_trigger := trigger as Interactable
				door_trigger.visible = on
				door_trigger.monitoring = on
				door_trigger.monitorable = on
				door_trigger.set_process(on)
				if not on:
					door_trigger.set_prompt_visible(false)
				door_trigger.set_enabled(on)
	_refresh_house_guides()


func apply_camera_world_limits(which: Node2D = null) -> void:
	if _active_house_id == 0 and _plate != null and camera != null:
		_limit_camera_to_rect(_plate.world_rect())
		return
	var quest: HouseQuest = _quests.get(_active_house_id) as HouseQuest
	if quest != null and quest.uses_painted_plate():
		var rect := quest.plate_world_rect()
		if rect.size.x >= 8.0:
			_limit_camera_to_rect(rect)
			return
	super.apply_camera_world_limits(which)


func _clamp_camera() -> void:
	if _active_house_id == 0 and _plate != null and camera != null:
		_clamp_camera_to_rect(_plate.world_rect())
		return
	var quest: HouseQuest = _quests.get(_active_house_id) as HouseQuest
	if quest != null and quest.uses_painted_plate():
		var rect := quest.plate_world_rect()
		if rect.size.x >= 8.0:
			_clamp_camera_to_rect(rect)
			return
	super._clamp_camera()


func _limit_camera_to_rect(rect: Rect2) -> void:
	if camera == null or rect.size.x < 8.0:
		return
	var pad := 8
	camera.limit_left = int(floor(rect.position.x)) - pad
	camera.limit_top = int(floor(rect.position.y)) - pad
	camera.limit_right = int(ceil(rect.end.x)) + pad
	camera.limit_bottom = int(ceil(rect.end.y)) + pad
	camera.limit_smoothed = false


func _clamp_camera_to_rect(rect: Rect2) -> void:
	if camera == null or rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var half := get_viewport_rect().size / (camera.zoom * 2.0)
	var min_x := rect.position.x + half.x
	var max_x := rect.end.x - half.x
	var min_y := rect.position.y + half.y
	var max_y := rect.end.y - half.y
	var pos := camera.global_position
	if min_x > max_x:
		pos.x = rect.get_center().x
	else:
		pos.x = clampf(pos.x, min_x, max_x)
	if min_y > max_y:
		pos.y = rect.get_center().y
	else:
		pos.y = clampf(pos.y, min_y, max_y)
	camera.global_position = pos


func _on_view_resized() -> void:
	if _active_house_id != 0:
		var quest: HouseQuest = _quests.get(_active_house_id) as HouseQuest
		if quest != null and quest.uses_painted_plate():
			var z := quest.plate_camera_zoom()
			camera_zoom = Vector2(z, z)
			if camera != null:
				camera.zoom = camera_zoom
			camera_limit_rect = quest.plate_world_rect()
			apply_camera_world_limits()
			_clamp_camera()
		else:
			fit_camera_to_floor(_house_floors.get(_active_house_id) as Node2D)
	else:
		var ridge := _ridge_frame_rect()
		if ridge.size.x >= 8.0:
			var z := cover_zoom_for(ridge) * HUB_ZOOM_IN
			camera_zoom = Vector2(z, z)
			if camera != null:
				camera.zoom = camera_zoom
			camera_limit_rect = ridge
		apply_camera_world_limits(_ridge_floor)
		_clamp_camera()


func _ridge_frame_rect() -> Rect2:
	if _plate != null and _plate.has_method("global_world_rect"):
		return _plate.global_world_rect()
	return Rect2()


func _hide_house_darkness(quest: HouseQuest) -> void:
	_set_house_darkness(quest, false)


func _set_house_darkness(quest: HouseQuest, on: bool) -> void:
	if quest == null:
		return
	for child in quest.get_children():
		if child is CanvasModulate:
			(child as CanvasModulate).visible = on
