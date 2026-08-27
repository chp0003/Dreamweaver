extends CanvasLayer
## Full-screen fade used when moving between auth, intro, and game scenes.

const DEFAULT_DURATION := 0.55

var _overlay: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	var host := Control.new()
	host.name = "FadeHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Palette.DREAM_ABYSS
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	host.add_child(_overlay)


func is_busy() -> bool:
	return _busy


func fade_to_scene(scene_path: String, duration: float = DEFAULT_DURATION) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_out := create_tween()
	fade_out.tween_property(_overlay, "modulate:a", 1.0, duration)
	await fade_out.finished

	# Every transition in the game funnels through here, which makes this the one
	# safe place to drop the grayscale veil. Without it a chapter's bleach would
	# follow the player out into the menus, since ColorRestoration is an autoload
	# that outlives the scene. Gameplay scenes re-arm it in their own _ready().
	ColorRestoration.reset()

	# Keep the Dreamweaver login track only across auth + Gateway. Leaving that
	# trio fades the song so prologue / chapters own the mix again.
	if not _is_menu_music_scene(scene_path):
		Audio.stop_music()

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneFader: failed to load %s (error %s)" % [scene_path, err])

	await get_tree().process_frame
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "modulate:a", 0.0, duration)
	await fade_in.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _is_menu_music_scene(scene_path: String) -> bool:
	return scene_path == AccountManager.LOGIN_SCENE \
		or scene_path == AccountManager.REGISTER_SCENE \
		or scene_path == AccountManager.MAIN_MENU_SCENE
