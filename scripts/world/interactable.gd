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
## When true, only the closest door in group `hub_door` may show a prompt or
## accept [E] while the player overlaps several at once.
@export var hub_door_priority := false
## Walk-in doors: stepping onto the trigger uses it without an extra [E].
@export var auto_use := false

var _player_inside := false
var _used := false
var _prompt_label: Label
var _prompt_badge: Control


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ensure_shape()
	_build_prompt()
	set_process(true)


func _process(_delta: float) -> void:
	if _prompt_badge == null:
		return
	var show := _can_interact()
	if _prompt_badge.visible != show:
		_prompt_badge.visible = show
	if show:
		_follow_prompt()


func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			var existing := child as CollisionShape2D
			if existing.shape is CircleShape2D:
				(existing.shape as CircleShape2D).radius = radius
			return
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)


func apply_radius(value: float) -> void:
	radius = maxf(value, 8.0)
	_ensure_shape()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _dialogue_open():
		return
	if hub_door_priority:
		if not enabled or (one_shot and _used) or not monitoring:
			return
		if _best_hub_door() != self:
			return
	elif not _can_interact():
		return
	get_viewport().set_input_as_handled()
	if one_shot:
		_used = true
		set_prompt_visible(false)
	Audio.play_house_cue(&"interact")
	interacted.emit()


func set_enabled(value: bool) -> void:
	enabled = value
	if value:
		_refresh_overlap()
	if hub_door_priority:
		_refresh_hub_door_prompts()
	else:
		set_prompt_visible(_player_inside and _can_interact())


func _refresh_overlap() -> void:
	_player_inside = false
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
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
		if value:
			_follow_prompt()
	elif _prompt_label != null:
		_prompt_label.visible = value


func is_player_inside() -> bool:
	return _player_inside


func _follow_prompt() -> void:
	if _prompt_badge == null or not _prompt_badge.visible:
		return
	var player := _player_node()
	if player == null:
		return
	if _prompt_badge.get_parent() != player:
		_prompt_badge.reparent(player)
	var size := _prompt_badge.size
	var stack := _visible_prompt_index()
	# Body origin is her feet. The sprite is 92px tall, so this rests on her hair.
	_prompt_badge.position = Vector2(-size.x * 0.5, -90.0 - size.y - 16.0 * float(stack))


func _player_node() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			return node as Node2D
	return null


func _visible_prompt_index() -> int:
	var index := 0
	for node in get_tree().get_nodes_in_group("interactable"):
		var other := node as Interactable
		if other == null:
			continue
		if other == self:
			return index
		if other._prompt_badge != null and other._prompt_badge.visible:
			index += 1
	return index


func _center_badge() -> void:
	if _prompt_badge == null:
		return
	_prompt_badge.reset_size()
	_follow_prompt()


func _can_interact() -> bool:
	if not enabled or (one_shot and _used) or _dialogue_open():
		return false
	if hub_door_priority:
		return _best_hub_door() == self
	return _player_inside


func _dialogue_open() -> bool:
	if not is_inside_tree():
		return false
	var view := get_tree().get_first_node_in_group("dialogue_view")
	return view != null and view.has_method("is_busy") and bool(view.call("is_busy"))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if hub_door_priority:
			_refresh_hub_door_prompts(body)
		else:
			set_prompt_visible(_can_interact())
		if auto_use and _can_interact() and (not hub_door_priority or _best_hub_door(body) == self):
			interacted.emit()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if hub_door_priority:
			_refresh_hub_door_prompts(body)
		else:
			set_prompt_visible(false)


func _exit_tree() -> void:
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.queue_free()
	_prompt_label = null
	_prompt_badge = null


func _build_prompt() -> void:
	_prompt_label = PromptScene.new()
	_prompt_label.text = "E  ·  %s" % prompt
	_prompt_label.visible = false
	add_child(_prompt_label)
	# Dialogue chrome turns every world_chrome node on when a line ends.
	# That was lighting every mirror and spindle in the room.
	_prompt_label.remove_from_group("world_chrome")
	_prompt_badge = _prompt_label
	_prompt_label.resized.connect(_center_badge)
	_center_badge()


func _best_hub_door(player: Node2D = null) -> Interactable:
	if not hub_door_priority or not is_inside_tree():
		return self
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var best: Interactable = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("hub_door"):
		var door := node as Interactable
		if door == null or not door.enabled or not door.monitoring:
			continue
		var reach := door.radius + 14.0
		var d := door.global_position.distance_to(player.global_position)
		if d > reach:
			continue
		if d < best_d:
			best_d = d
			best = door
	return best


func _refresh_hub_door_prompts(player: Node2D = null) -> void:
	if not is_inside_tree():
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	var best := _best_hub_door(player)
	for node in get_tree().get_nodes_in_group("hub_door"):
		var door := node as Interactable
		if door != null:
			door.set_prompt_visible(door == best)
