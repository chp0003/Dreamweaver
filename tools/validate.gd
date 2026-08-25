extends Node
## Temporary build check. Run headless:
##   Godot_v4.x_console.exe --headless --path . res://tools/Validate.tscn
## Loads every script, shader and scene in the project and reports failures.

const SCAN_DIRS := ["res://scripts", "res://scenes", "res://shaders", "res://assets/themes"]
const EXTENSIONS := ["gd", "tscn", "tres", "gdshader"]
const SKIP := ["res://tools"]

var _failures: Array[String] = []
var _checked := 0


func _ready() -> void:
	for dir in SCAN_DIRS:
		_scan(dir)

	print("\n===== VALIDATION =====")
	print("Resources checked: %d" % _checked)
	if _failures.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: %d FAILURE(S)" % _failures.size())
		for failure in _failures:
			print("  - " + failure)
	print("======================\n")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _scan(path: String) -> void:
	for skip in SKIP:
		if path.begins_with(skip):
			return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan(full)
		elif EXTENSIONS.has(entry.get_extension().to_lower()):
			_check(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _check(path: String) -> void:
	_checked += 1
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		_failures.append("failed to load: " + path)
		return
	if res is GDScript and not (res as GDScript).can_instantiate():
		# Abstract-by-design helpers (pure static catalogues) are fine.
		var script := res as GDScript
		if script.get_instance_base_type() == "":
			_failures.append("script did not compile: " + path)
	if res is PackedScene:
		var instance := (res as PackedScene).instantiate()
		if instance == null:
			_failures.append("scene did not instantiate: " + path)
		else:
			instance.free()
