class_name WeaveBolt
extends Node2D
## Long-range Lewet shot. AQ Worlds style: gold energy burst that flies at a target.

const BURST_PATH := "res://assets/images/vfx/weave_bolt_burst.png"
const SPEED := 620.0
const RANGE := 420.0
const HIT_RADIUS := 36.0

var direction := Vector2.RIGHT
var damage := 34.0
var source: Node2D
## Optional lock-on. When set, the bolt homes gently toward this node.
var target: Node2D

var _travel := 0.0
var _spent := false
var _sprite: Sprite2D
var _spin := 0.0


func _ready() -> void:
	z_index = 22
	_build_visual()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _spent:
		return

	if target != null and is_instance_valid(target) and target.is_inside_tree():
		var desired := (target.global_position + Vector2(0.0, -28.0) - global_position)
		if desired.length() > 4.0:
			direction = direction.lerp(desired.normalized(), minf(1.0, delta * 9.0)).normalized()

	var step := direction * SPEED * delta
	global_position += step
	_travel += step.length()
	_spin += delta * 8.0
	if _sprite != null:
		_sprite.rotation = _spin
		_sprite.scale = Vector2(0.22, 0.22) * (1.0 + 0.08 * sin(_spin * 3.0))
	_try_hit()
	if _travel >= RANGE:
		_burst_and_die()


func _try_hit() -> void:
	if source == null or not source.is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("hittable"):
		var hit := node as Node2D
		if hit == null or not hit.is_inside_tree() or hit == source:
			continue
		var aim_point := hit.global_position + Vector2(0.0, -28.0)
		if global_position.distance_to(aim_point) > HIT_RADIUS \
				and Iso.iso_distance(global_position, hit.global_position) > HIT_RADIUS:
			continue
		_impact(hit)
		return


func _impact(hit: Node2D) -> void:
	_spent = true
	var landed := true
	if hit.has_method("take_damage"):
		var result: Variant = hit.take_damage(damage, source)
		if result is bool:
			landed = result
	if landed and source != null and source.has_signal("attack_hit"):
		source.attack_hit.emit(hit)
	if not landed:
		queue_free()
		return
	Fx.hit_flash(hit, Palette.GOLD_SUN)
	Fx.fiber_burst(hit, Palette.GOLD_BRASS)
	_spawn_impact_burst()
	var host: Node = get_parent()
	if host != null:
		Fx.damage_number(host, hit.global_position, int(damage), Palette.GOLD_SUN)
	Audio.play_sfx(Audio.Sfx.HIT)
	queue_free()


func _burst_and_die() -> void:
	_spent = true
	_spawn_impact_burst()
	queue_free()


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _load_burst()
	_sprite.centered = true
	_sprite.scale = Vector2(0.22, 0.22)
	_sprite.modulate = Color(1.05, 0.95, 0.45, 0.95)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	# Soft gold halo behind the art so it reads at distance.
	var halo := Sprite2D.new()
	halo.texture = _soft_dot()
	halo.modulate = Palette.alpha(Palette.GOLD_SUN, 0.55)
	halo.scale = Vector2(0.55, 0.55)
	halo.z_index = -1
	add_child(halo)
	move_child(halo, 0)


func _spawn_impact_burst() -> void:
	var host: Node = get_parent()
	if host == null or not host.is_inside_tree():
		return
	var flash := Sprite2D.new()
	flash.texture = _load_burst()
	flash.global_position = global_position
	flash.centered = true
	flash.scale = Vector2(0.18, 0.18)
	flash.modulate = Color(1.1, 0.95, 0.4, 0.95)
	flash.z_index = 24
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(flash)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(0.55, 0.55), 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(flash.queue_free)


func _load_burst() -> Texture2D:
	if ResourceLoader.exists(BURST_PATH):
		var loaded := load(BURST_PATH)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(BURST_PATH):
		var image := Image.new()
		if image.load(BURST_PATH) == OK:
			return ImageTexture.create_from_image(image)
	return _soft_dot()


func _soft_dot() -> Texture2D:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var centre := Vector2(23.5, 23.5)
	for y in range(48):
		for x in range(48):
			var d := Vector2(x, y).distance_to(centre) / 24.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.8)))
	return ImageTexture.create_from_image(image)
