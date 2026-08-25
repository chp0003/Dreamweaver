extends CanvasLayer
## Autoload that owns the Grayscale-to-Color mechanic.
##
## A single full-screen ColorRect running `color_restoration.gdshader` sits above
## the world (layer 100) and below the HUD (layer 110+), so gameplay art fades
## but UI stays readable.
##
## Two kinds of restoration:
##   * global  - `set_global_gray()` / `restore_world()`, used by the prologue and
##               by the Color Burst at the end of Chapter 5.
##   * local   - `add_zone()`, a world-space circle that regains colour. Zones
##               follow their anchor node every frame, projected through the
##               active Camera2D, which is how a House lights up in place.
##
## The veil starts OFF and is opt-in per scene. This autoload outlives every
## scene change, so a default of "fully bleached" would drain the login screen,
## the prologue art and the menus as well as the world. Gameplay scenes switch it
## on in `_ready()` (see ChapterBase.starting_gray); SceneFader drops it on every
## transition so a chapter's bleach can never leak into a menu.

const SHADER_PATH := "res://shaders/color_restoration.gdshader"
const MAX_ZONES := 8
const RENDER_LAYER := 100

signal global_gray_changed(amount: float)

var _rect: ColorRect
var _material: ShaderMaterial
var _back: BackBufferCopy
var _global_gray := 0.0
var _zones: Array[Dictionary] = []
var _tween: Tween


func _ready() -> void:
	layer = RENDER_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_material = ShaderMaterial.new()
	var shader := load(SHADER_PATH)
	if shader is Shader:
		_material.shader = shader
	else:
		push_error("ColorRestoration: missing shader at %s" % SHADER_PATH)

	# Copy the finished world frame BEFORE the veil samples it. Without a fresh
	# copy each frame, moving shadows smear into ghost trails on D3D12.
	_back = BackBufferCopy.new()
	_back.name = "BackBuffer"
	_back.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_back)

	_rect = ColorRect.new()
	_rect.name = "Veil"
	_rect.material = _material
	_rect.color = Color(1, 1, 1, 1)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_apply_global_gray()


func _process(_delta: float) -> void:
	if _material == null:
		return
	_update_combat_safe_mode()
	if _rect != null and _rect.visible and _back != null:
		_back.visible = true
		_back.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_prune_zones()
	_push_zones()


## Moving enemies + screen-texture veil = ghost trails on D3D12. While any
## shadow is alive we bleach with CanvasModulate instead so combat stays clean.
func _update_combat_safe_mode() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var combat := not tree.get_nodes_in_group("shadow_minion").is_empty()
	var scene := tree.current_scene as Node
	if scene == null:
		return
	var mod := scene.get_node_or_null("CombatGray") as CanvasModulate
	if combat and _global_gray > 0.001:
		if mod == null:
			mod = CanvasModulate.new()
			mod.name = "CombatGray"
			scene.add_child(mod)
		var g := lerpf(1.0, 0.42, _global_gray)
		mod.color = Color(g * 1.02, g * 0.99, g * 0.94, 1.0)
		if _rect != null:
			_rect.visible = false
	else:
		if mod != null:
			mod.queue_free()
		if _rect != null:
			_rect.visible = _global_gray > 0.001 or not _zones.is_empty()


## 1.0 = fully bleached, 0.0 = fully restored. `duration` tweens the change.
## When moving combat actors are present, the screen veil is swapped for a
## CanvasModulate so D3D12 cannot smear minions into ghost trails.
func set_global_gray(amount: float, duration: float = 0.0) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		_global_gray = amount
		_apply_global_gray()
		return
	_tween = create_tween()
	_tween.tween_method(_set_gray_stepped, _global_gray, amount, duration)


func global_gray() -> float:
	return _global_gray


## Full colour, everywhere, forever - the Color Burst payoff.
func restore_world(duration: float = 2.4) -> void:
	clear_zones()
	set_global_gray(0.0, duration)


## Drops the veil completely: no global gray, no zones. Menus, the auth screens
## and the prologue all run in full colour, and each gameplay scene re-arms the
## veil for itself on entry.
func reset() -> void:
	clear_zones()
	set_global_gray(0.0, 0.0)


## Registers a travelling pool of colour.
##   id       - unique key, re-registering the same id replaces it.
##   anchor   - Node2D the zone follows (usually a prop or the player).
##   radius   - world-space radius in pixels.
##   strength - 0..1, how much colour comes back inside the zone.
func add_zone(id: String, anchor: Node2D, radius: float, strength: float = 1.0) -> void:
	if anchor == null:
		return
	remove_zone(id)
	if _zones.size() >= MAX_ZONES:
		_zones.remove_at(0)
	_zones.append({
		"id": id,
		"anchor": anchor,
		"radius": radius,
		"strength": clampf(strength, 0.0, 1.0),
	})


## Same as add_zone() but fades the colour in, for the moment an essence lands.
func bloom_zone(id: String, anchor: Node2D, radius: float, strength: float = 1.0,
		duration: float = 1.6) -> void:
	add_zone(id, anchor, 1.0, strength)
	var tween := create_tween()
	tween.tween_method(_set_zone_radius.bind(id), 1.0, radius, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func remove_zone(id: String) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		if str(_zones[i]["id"]) == id:
			_zones.remove_at(i)


func clear_zones() -> void:
	_zones.clear()
	if _material != null:
		_material.set_shader_parameter("zone_count", 0)


func has_zone(id: String) -> bool:
	for zone in _zones:
		if str(zone["id"]) == id:
			return true
	return false


## Argument order matches `Callable.bind()`, which appends bound args last.
func _set_zone_radius(radius: float, id: String) -> void:
	for zone in _zones:
		if str(zone["id"]) == id:
			zone["radius"] = radius
			return


func _set_gray_stepped(amount: float) -> void:
	_global_gray = amount
	_apply_global_gray()


func _apply_global_gray() -> void:
	if _material != null:
		_material.set_shader_parameter("global_gray", _global_gray)
	sync_essences()
	# Skip the shader entirely once the world is whole again.
	if _rect != null:
		_rect.visible = _global_gray > 0.001 or not _zones.is_empty()
	global_gray_changed.emit(_global_gray)


## Pushes dye-family restores from the save so a gray world can still show
## Black, then Red, then Gold as those Houses come back - not a flat filter.
func sync_essences() -> void:
	if _material == null:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var black := 1.0 if gs.game_completed or gs.has_essence("black") else 0.0
	var red := 1.0 if gs.game_completed or gs.has_essence("red") else 0.0
	var gold := 1.0 if gs.game_completed or gs.has_essence("gold") else 0.0
	match int(gs.current_chapter):
		1:
			black = maxf(black, 0.35)
		2:
			black = maxf(black, 1.0)
			red = maxf(red, 0.4)
		3:
			black = maxf(black, 1.0)
			red = maxf(red, 1.0)
			gold = maxf(gold, 0.45)
		4, 5:
			black = maxf(black, 1.0)
			red = maxf(red, 1.0)
			gold = maxf(gold, 1.0)
	_material.set_shader_parameter("black_restore", black)
	_material.set_shader_parameter("red_restore", red)
	_material.set_shader_parameter("gold_restore", gold)
	_material.set_shader_parameter("protect_gold", 0.7 if gs.has_item("lewet_staff") else 0.45)


func _prune_zones() -> void:
	for i in range(_zones.size() - 1, -1, -1):
		var anchor: Variant = _zones[i]["anchor"]
		if not is_instance_valid(anchor) or not (anchor as Node2D).is_inside_tree():
			_zones.remove_at(i)


func _push_zones() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var view_size := viewport.get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return

	_material.set_shader_parameter("screen_aspect", view_size.x / view_size.y)

	if _zones.is_empty():
		_material.set_shader_parameter("zone_count", 0)
		_rect.visible = _global_gray > 0.001
		return

	var camera := viewport.get_camera_2d()
	var packed := PackedVector4Array()
	for zone in _zones:
		var anchor := zone["anchor"] as Node2D
		var world_pos := anchor.global_position
		var screen_pos := world_pos
		var zoom := Vector2.ONE
		if camera != null:
			zoom = camera.zoom
			screen_pos = (world_pos - camera.get_screen_center_position()) * zoom \
				+ view_size * 0.5
		var uv := screen_pos / view_size
		var radius_uv := (float(zone["radius"]) * zoom.x) / view_size.x
		packed.append(Vector4(uv.x, uv.y, radius_uv, float(zone["strength"])))

	_material.set_shader_parameter("zones", packed)
	_material.set_shader_parameter("zone_count", packed.size())
	_rect.visible = true
