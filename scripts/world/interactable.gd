class_name Interactable
extends Area2D
## Anything S'lang can press [E] on: spirits, statues, mirrors, vats, doors.
##
## Shows a floating prompt while the player stands inside, and emits
## `interacted` once per press. Chapters connect to that signal and drive their
## own dialogue or puzzle from there.

const PromptScene := preload("res://scripts/ui/interaction_prompt.gd")

signal interacted

@export var prompt := "Examine"
@export var enabled := true
@export var one_shot := false
@export var prompt_offset := Vector2(0.0, -96.0)
@export var radius := 60.0
## Walk-in doors: stepping onto the trigger uses it without an extra [E].
@export var auto_use := false

var _player_inside := false
var _used := false
var _prompt_label: Label
var _prompt_badge: Control


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ensure_shape()
	_build_prompt()
	set_process(false)


func _process(_delta: float) -> void:
	_follow_prompt()


func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if one_shot:
		_used = true
		set_prompt_visible(false)
	interacted.emit()


func set_enabled(value: bool) -> void:
	enabled = value
	if value:
		_refresh_overlap()
	set_prompt_visible(_player_inside and _can_interact())


func _refresh_overlap() -> void:
	_player_inside = false
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		if body is Node2D and (body as Node2D).is_in_group("player"):
			_player_inside = true
			if auto_use and _can_interact():
				interacted.emit()
			return


func set_prompt(text: String) -> void:
	prompt = text
	if _prompt_label != null:
		_prompt_label.text = "E  ·  %s" % prompt
		_center_badge()


func set_prompt_visible(value: bool) -> void:
	if _prompt_badge != null:
		_prompt_badge.visible = value
		set_process(value)
		if value:
			_follow_prompt()
	elif _prompt_label != null:
		_prompt_label.visible = value


func is_player_inside() -> bool:
	return _player_inside


func _follow_prompt() -> void:
	if _prompt_badge == null or not _prompt_badge.visible:
		return
	# top_level Control: pin in screen space above the interactable so camera
	# zoom never stretches the badge into a UI bug while walking.
	var screen := get_global_transform_with_canvas() * prompt_offset
	_prompt_badge.global_position = screen - Vector2(_prompt_badge.size.x * 0.5, _prompt_badge.size.y)


func _center_badge() -> void:
	if _prompt_badge == null:
		return
	_prompt_badge.reset_size()
	_follow_prompt()


func _can_interact() -> bool:
	return enabled and _player_inside and not (one_shot and _used)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		set_prompt_visible(_can_interact())
		if auto_use and _can_interact():
			interacted.emit()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		set_prompt_visible(false)


func _build_prompt() -> void:
	_prompt_label = PromptScene.new()
	_prompt_label.text = "E  ·  %s" % prompt
	_prompt_label.visible = false
	_prompt_label.top_level = true

	add_child(_prompt_label)
	_prompt_badge = _prompt_label
	_prompt_label.resized.connect(_center_badge)
	_center_badge()
