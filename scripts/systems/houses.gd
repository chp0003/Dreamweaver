class_name Houses
extends RefCounted
## Static catalogue of the five Houses of Weaving.
##
## Everything that differs between chapters - title, scene, essence, hub
## position, accent colour - lives here so the Hub, HUD, save file and codex all
## read from one source instead of hard-coding chapter numbers.

const COMPLETION_SCORE := 500
const VICTORY_SCORE := 1500

const LIST: Array[Dictionary] = [
	{
		"id": 1,
		"name": "House of the Black Foundation",
		"short": "Black Foundation",
		"scene": "res://scenes/Chapter1.tscn",
		"essence": "black",
		"essence_name": "Black Dye Essence",
		"reward_item": "",
		"accent": Color(0.16, 0.15, 0.15),
		"hub_cell": Vector2(1.0, 11.0),
		"hub_uv": Vector2(0.28, 0.70),
		"hub_sprite": "res://assets/images/hub_crossroads/house_black_foundation.png",
		"hub_size": Vector2(236.0, 248.0),
		"hub_feet": Vector2(194.0, 90.0),
		"blurb": "Black Dye Essence. Abaca stripped, dried and remembered.",
		"locked_hint": "Open from the first step of the journey.",
	},
	{
		"id": 2,
		"name": "House of Red Courage",
		"short": "Red Courage",
		"scene": "res://scenes/Chapter2.tscn",
		"essence": "red",
		"essence_name": "Red Dye Essence",
		"reward_item": "",
		"accent": Color(0.62, 0.14, 0.13),
		"hub_cell": Vector2(11.0, 1.0),
		"hub_uv": Vector2(0.72, 0.70),
		"hub_sprite": "res://assets/images/hub_crossroads/house_red_courage.png",
		"hub_size": Vector2(236.0, 248.0),
		"hub_feet": Vector2(194.0, 90.0),
		"blurb": "Red Dye Essence. Hulo root, mortar and fire — the colour of courage.",
		"locked_hint": "Restore the Black Foundation first.",
	},
	{
		"id": 3,
		"name": "House of the Golden Sun",
		"short": "Golden Sun",
		"scene": "res://scenes/Chapter3.tscn",
		"essence": "gold",
		"essence_name": "Gold Essence",
		"reward_item": "",
		"accent": Color(0.86, 0.68, 0.24),
		"hub_cell": Vector2(-9.0, -9.0),
		"hub_uv": Vector2(0.50, 0.20),
		"hub_sprite": "res://assets/images/hub_crossroads/house_golden_sun.png",
		"hub_size": Vector2(300.0, 320.0),
		"hub_feet": Vector2(230.0, 108.0),
		"blurb": "Gold Essence. Light, illumination and clarity.",
		"locked_hint": "Restore Red Courage first.",
	},
	{
		"id": 4,
		"name": "House of the Dream Ancestors",
		"short": "Dream Ancestors",
		"scene": "res://scenes/Chapter4.tscn",
		"essence": "",
		"essence_name": "",
		"reward_item": "master_pattern",
		"accent": Color(0.84, 0.78, 0.63),
		"hub_cell": Vector2(-10.0, -4.0),
		"hub_uv": Vector2(0.25, 0.32),
		"hub_sprite": "res://assets/images/hub_crossroads/house_dream_ancestors.png",
		"hub_size": Vector2(250.0, 260.0),
		"hub_feet": Vector2(200.0, 92.0),
		"blurb": "The Sacred Master Pattern, kept by the spirit of a Master Weaver.",
		"locked_hint": "Restore the Golden Sun first.",
	},
	{
		"id": 5,
		"name": "The Sacred Loom",
		"short": "Sacred Loom",
		"scene": "res://scenes/Chapter5.tscn",
		"essence": "",
		"essence_name": "",
		"reward_item": "",
		"accent": Color(0.93, 0.86, 0.55),
		"hub_cell": Vector2(0.0, 0.0),
		"hub_uv": Vector2(0.73, 0.34),
		"hub_sprite": "res://assets/images/hub_crossroads/ritual_altar.png",
		"hub_size": Vector2(236.0, 248.0),
		"hub_feet": Vector2(194.0, 90.0),
		"blurb": "Final House. Confront the Shadow Weaver and undo the Great Bleaching.",
		"locked_hint": "Bring Black, Red, Gold and the Sacred Master Pattern.",
	},
]

## Expanded hub: houses sit in the mid-zone of the diamond (~1.7x prior spacing)
## so paths, plaza and farmland fill most of the island; grass/trees only frame.

const ESSENCE_NAMES := {
	"black": "Black Dye Essence",
	"red": "Red Dye Essence",
	"gold": "Gold Essence",
}

const ESSENCE_COLORS := {
	"black": Color(0.22, 0.2, 0.2),
	"red": Color(0.72, 0.16, 0.14),
	"gold": Color(0.92, 0.75, 0.29),
}

const ITEM_NAMES := {
	"lewet_staff": "Lewet Staff",
	"master_pattern": "Sacred Master Pattern",
}


static func count() -> int:
	return LIST.size()


static func get_house(house_id: int) -> Dictionary:
	for house in LIST:
		if int(house["id"]) == house_id:
			return house
	return {}


static func scene_for(house_id: int) -> String:
	var house := get_house(house_id)
	return str(house.get("scene", "res://scenes/HubWorld.tscn"))


static func name_for(house_id: int) -> String:
	var house := get_house(house_id)
	return str(house.get("name", "Unknown House"))


static func short_name_for(house_id: int) -> String:
	var house := get_house(house_id)
	return str(house.get("short", "Unknown"))


static func accent_for(house_id: int) -> Color:
	var house := get_house(house_id)
	return house.get("accent", Color(0.8, 0.7, 0.4)) as Color


static func essence_name(essence_id: String) -> String:
	return str(ESSENCE_NAMES.get(essence_id, essence_id.capitalize()))


static func essence_color(essence_id: String) -> Color:
	return ESSENCE_COLORS.get(essence_id, Color(0.7, 0.7, 0.7)) as Color


static func item_name(item_id: String) -> String:
	return str(ITEM_NAMES.get(item_id, item_id.capitalize()))
