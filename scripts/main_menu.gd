extends Control


func _ready() -> void:
	$Center/VBox/StartButton.pressed.connect(_on_start_pressed)
	$Center/VBox/QuitButton.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/dream_world.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
