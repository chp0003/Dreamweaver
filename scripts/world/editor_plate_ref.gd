@tool
extends Sprite2D
## Hall painting for drawing collision in the editor. Hidden when the game runs.


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
