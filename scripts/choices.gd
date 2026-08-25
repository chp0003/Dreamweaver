extends Control

signal choice_made(choice_id: String)

@onready var panel: PanelContainer = $Panel
@onready var prompt_label: Label = $Panel/Margin/VBox/PromptLabel
@onready var comfort_button: Button = $Panel/Margin/VBox/Buttons/ComfortButton
@onready var ignore_button: Button = $Panel/Margin/VBox/Buttons/IgnoreButton


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	comfort_button.pressed.connect(_on_comfort_pressed)
	ignore_button.pressed.connect(_on_ignore_pressed)


func show_choices(prompt: String = "What will you do?") -> void:
	prompt_label.text = prompt
	show()
	get_viewport().set_input_as_handled()


func hide_choices() -> void:
	hide()


func _on_comfort_pressed() -> void:
	hide_choices()
	choice_made.emit("comfort")


func _on_ignore_pressed() -> void:
	hide_choices()
	choice_made.emit("ignore")
