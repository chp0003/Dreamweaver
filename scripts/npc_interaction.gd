extends Node3D

signal player_nearby(is_near: bool)
signal interaction_requested

@export var interact_distance := 3.5

var player_in_range := false
var interaction_used := false

@onready var prompt_target: Node3D = $PromptAnchor

func _ready() -> void:
	var area: Area3D = $InteractionArea
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if interaction_used:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	var is_near := distance <= interact_distance
	if is_near != player_in_range:
		player_in_range = is_near
		player_nearby.emit(is_near)

func _unhandled_input(event: InputEvent) -> void:
	if interaction_used:
		return
	if player_in_range and event.is_action_pressed("interact"):
		interaction_used = true
		player_in_range = false
		player_nearby.emit(false)
		interaction_requested.emit()

func get_prompt_position() -> Vector3:
	return prompt_target.global_position if prompt_target else global_position + Vector3(0.0, 2.2, 0.0)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_nearby.emit(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_nearby.emit(false)
