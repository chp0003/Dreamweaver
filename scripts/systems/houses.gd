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
		"hub_cell": Vector2(0.0, 9.0),
		"blurb": "Abaca stripped, dried and remembered. Every cloth begins here.",
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
		"hub_cell": Vector2(9.0, 0.0),
		"blurb": "Hulo root, mortar and fire. The colour of blood kept warm.",
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
		"hub_cell": Vector2(-9.0, 0.0),
		"blurb": "Brass, light and the turning spindle. The sun-thread of the sky.",
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
		"hub_cell": Vector2(0.0, -9.0),
		"blurb": "Statues, riddles and the great Ablun loom. Knowledge before craft.",
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
		"hub_cell": Vector2(11.0, 11.0),
		"blurb": "The great Guno Bong at the centre. Where the Shadow Weaver waits.",
		"locked_hint": "Bring Black, Red, Gold and the Sacred Master Pattern.",
	},
]

## `hub_cell` values sit on an X of boardwalk in grid space, which is also an X
## on screen: +x runs down-right, +y runs down-left. Houses 1-4 hold the four
## arms; house 5 sits on a fifth path due south, nearest the camera.

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
