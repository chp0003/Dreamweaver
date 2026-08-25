extends Node

enum DreamChoice { NONE, COMFORT, IGNORE }

var choice: DreamChoice = DreamChoice.NONE
var dream_complete: bool = false


func reset() -> void:
	choice = DreamChoice.NONE
	dream_complete = false
