class_name QuestBeacon
extends Node2D
## A woven gold floor mark for the current story beat.

const TEX_PATH := "res://assets/images/props/quest_mark.png"

var _pulse := 0.0
var _follow: Node2D
var _art: Sprite2D
var _pinned := false


func _ready() -> void:
	z_index = 6
	z_as_relative = true
	add_to_group("world_chrome")
	_art = Sprite2D.new()
	_art.name = "Mark"
	_art.centered = true
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists(TEX_PATH):
		var loaded := load(TEX_PATH)
		if loaded is Texture2D:
			_art.texture = loaded
	add_child(_art)
	visible = false
	set_process(true)


func pin(target: Node2D, offset := Vector2(0.0, 10.0)) -> void:
	_follow = target
	_pinned = target != null
	visible = _pinned
	if target != null:
		global_position = target.global_position + offset


func pin_world(world_pos: Vector2) -> void:
	_follow = null
	_pinned = true
	visible = true
	global_position = world_pos


func clear() -> void:
	_follow = null
	_pinned = false
	visible = false


func _process(delta: float) -> void:
	if not _pinned:
		visible = false
		return
	_pulse += delta * 3.2
	if _follow != null and is_instance_valid(_follow):
		global_position = _follow.global_position + Vector2(0.0, 10.0)
	var t := 0.82 + 0.18 * sin(_pulse)
	if _art != null:
		_art.scale = Vector2(t, t)
		_art.modulate = Color(1.08, 1.02, 0.9, 0.72 + 0.28 * sin(_pulse))
