extends Node
## One-shot: import the modern prologue floor tileset only.

const SRC := "C:/Users/Admin/.cursor/projects/e-dreamweaver/assets"


func _ready() -> void:
	var src_path := SRC.path_join("tileset_interior_wood_v2.png")
	var dest_path := "res://assets/images/environments/prologue/tileset_interior_wood.png"
	var image := Image.new()
	if image.load(src_path) != OK:
		print("LOAD FAIL %s" % src_path)
		get_tree().quit(1)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	# Keep black matte for iso_floor slicer; just resize to expected sheet size.
	image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_path.get_base_dir()))
	var err := image.save_png(ProjectSettings.globalize_path(dest_path))
	print("OK prologue tileset -> %s err=%d" % [dest_path, err])
	get_tree().quit(0 if err == OK else 1)
