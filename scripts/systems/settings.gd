extends Node
## Persistent player preferences: audio levels, display options, and mute flags.
##
## Stored in `user://settings.cfg` so choices survive restarts. Audio applies
## through the Audio autoload; display options poke the window mode directly.

const SAVE_PATH := "user://settings.cfg"

signal changed

var master_volume := 1.0
var music_volume := 0.85
var sfx_volume := 1.0
var muted := false
var fullscreen := false
var vsync := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_from_disk()
	apply_all()


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", muted))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("display", "vsync", vsync))


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.save(SAVE_PATH)


func apply_all() -> void:
	if Audio != null and Audio.has_method("apply_volumes"):
		Audio.apply_volumes(master_volume, music_volume, sfx_volume, muted)
	_apply_display()
	changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_commit_audio()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_commit_audio()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_commit_audio()


func set_muted(value: bool) -> void:
	muted = value
	_commit_audio()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display()
	save_to_disk()
	changed.emit()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_display()
	save_to_disk()
	changed.emit()


func _commit_audio() -> void:
	if Audio != null and Audio.has_method("apply_volumes"):
		Audio.apply_volumes(master_volume, music_volume, sfx_volume, muted)
	save_to_disk()
	changed.emit()


func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
