class_name Collectible
extends Area2D
## A pickup S'lang walks over: faded abaca strands, hulo roots, lore scrolls.
##
## Chapters spawn these with `Collectible.spawn()` and count the `collected`
## signal against their quest total.

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

var _taken := false
var _art: PlaceholderProp


func _ready() -> void:
	add_to_group("collectible")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_ensure_shape()
	_build_art()
	if highlight:
		_start_shimmer()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
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
