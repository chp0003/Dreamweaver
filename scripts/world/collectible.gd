class_name Collectible
extends Area2D
## A pickup S'lang takes with [R]: faded abaca strands, hulo roots, lore scrolls.
##
## Chapters spawn these with `Collectible.spawn()` and count the `collected`
## signal against their quest total. [E] stays on Interactable for NPCs.

const PromptScene := preload("res://scripts/ui/interaction_prompt.gd")

signal collected(collectible: Collectible)

@export var item_label := "Faded Abaca Strand"
@export var texture_path := ""
@export var tint := Color(0.66, 0.62, 0.55)
@export var score_value := 40
@export var pickup_radius := 30.0
## Lore entry unlocked on pickup, if any.
@export var lore_id := ""
## Quest pickups pulse gold so they read in a gray hall.
@export var highlight := false
## Zero keeps the usual small footprint. The tutorial strand passes a larger one.
@export var art_size := Vector2.ZERO

var _taken := false
var _player_inside := false
var _art: PlaceholderProp
var _prompt: Label


func _ready() -> void:
	add_to_group("collectible")
	collision_layer = 0
	collision_mask = 1
	z_index = 6
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ensure_shape()
	_build_art()
	_build_prompt()
	set_process(false)
	if highlight:
		_start_shimmer()


func _process(_delta: float) -> void:
	_set_prompt_visible(_can_pickup() and _nearest_collectible() == self)


func _unhandled_input(event: InputEvent) -> void:
	if _taken or event.is_echo() or not event.is_action_pressed("pickup"):
		return
	if not _can_pickup() or _nearest_collectible() != self:
		return
	get_viewport().set_input_as_handled()
	_take()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_player_inside = true
	set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_set_prompt_visible(false)
	set_process(false)


func _can_pickup() -> bool:
	return not _taken and _player_inside and not _dialogue_open()


func _dialogue_open() -> bool:
	if not is_inside_tree():
		return false
	var view := get_tree().get_first_node_in_group("dialogue_view")
	return view != null and view.has_method("is_busy") and bool(view.call("is_busy"))


## One [R] takes the closest item when several radii overlap.
func _nearest_collectible() -> Collectible:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var best: Collectible = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("collectible"):
		var item := node as Collectible
		if item == null or not item._can_pickup():
			continue
		var distance := item.global_position.distance_to(player.global_position)
		if distance < best_d:
			best_d = distance
			best = item
	return best


func _take() -> void:
	if _taken:
		return
	_taken = true
	_player_inside = false
	_set_prompt_visible(false)
	set_process(false)
	set_deferred("monitoring", false)
	Audio.play_sfx(Audio.Sfx.PICKUP)
	GameState.add_score(score_value)
	if not lore_id.is_empty():
		GameState.unlock_lore(lore_id)
	collected.emit(self)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(0.0, -34.0), 0.32)
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.chain().tween_callback(queue_free)


func _build_prompt() -> void:
	_prompt = _make_mark("R   ·   pick up", 26)
	_prompt.visible = false
	_prompt.position = Vector2(-90.0, -118.0)
	add_child(_prompt)
	_prompt.remove_from_group("world_chrome")


func _make_mark(text: String, font_size: int) -> Label:
	var mark := PromptScene.new()
	mark.text = text
	mark.z_index = 80
	mark.z_as_relative = true
	mark.top_level = false
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", font_size)
	mark.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	mark.custom_minimum_size = Vector2(48.0 if text.length() < 3 else 190.0, font_size + 12)
	return mark


func _set_prompt_visible(value: bool) -> void:
	if _prompt != null:
		_prompt.visible = value


func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			return
	var circle := CircleShape2D.new()
	circle.radius = pickup_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)


func _build_art() -> void:
	_art = PlaceholderProp.new()
	_art.name = "Art"
	_art.prop_label = item_label
	_art.texture_path = texture_path
	if art_size != Vector2.ZERO:
		_art.prop_size = art_size
	else:
		_art.prop_size = Vector2(34.0, 38.0) if highlight else Vector2(28.0, 28.0)
	_art.body_color = tint
	_art.accent_color = tint.lightened(0.3)
	_art.show_label = false
	_art.cast_shadow = false
	_art.float_amplitude = 3.2 if highlight else 0.0
	add_child(_art)
	if highlight:
		modulate = Color(1.15, 1.08, 0.88)


## Gentle pulse so pickups stay findable in a fully gray room.
func _start_shimmer() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_art, "scale", Vector2(1.12, 0.92), 0.7)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_art, "scale", Vector2(1.0, 1.0), 0.7)\
		.set_trans(Tween.TRANS_SINE)
