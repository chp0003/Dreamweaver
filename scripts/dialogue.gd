extends Control

signal dialogue_finished

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/Margin/VBox/Header/NameLabel
@onready var text_label: RichTextLabel = $Panel/Margin/VBox/TextLabel
@onready var face_portrait: Control = $Panel/Margin/VBox/Header/FacePortrait
@onready var left_eye: ColorRect = $Panel/Margin/VBox/Header/FacePortrait/LeftEye
@onready var right_eye: ColorRect = $Panel/Margin/VBox/Header/FacePortrait/RightEye
@onready var mouth: ColorRect = $Panel/Margin/VBox/Header/FacePortrait/Mouth
@onready var face_bg: ColorRect = $Panel/Margin/VBox/Header/FacePortrait/FaceBG


func _ready() -> void:
	hide()


func show_dialogue(speaker_name: String, text: String, mood: String = "neutral") -> void:
	name_label.text = speaker_name
	text_label.text = text
	_apply_face_mood(mood)
	show()


func hide_dialogue() -> void:
	hide()
	dialogue_finished.emit()


func _apply_face_mood(mood: String) -> void:
	match mood:
		"happy":
			face_bg.color = Color(1.0, 0.88, 0.72)
			left_eye.size = Vector2(14, 14)
			right_eye.size = Vector2(14, 14)
			mouth.size = Vector2(28, 8)
			mouth.position = Vector2(36, 62)
			mouth.color = Color(0.7, 0.25, 0.25)
		"sad":
			face_bg.color = Color(0.78, 0.72, 0.68)
			left_eye.size = Vector2(12, 16)
			right_eye.size = Vector2(12, 16)
			mouth.size = Vector2(22, 6)
			mouth.position = Vector2(39, 68)
			mouth.color = Color(0.35, 0.3, 0.45)
		_:
			face_bg.color = Color(0.95, 0.82, 0.68)
			left_eye.size = Vector2(12, 12)
			right_eye.size = Vector2(12, 12)
			mouth.size = Vector2(20, 4)
			mouth.position = Vector2(40, 64)
			mouth.color = Color(0.5, 0.25, 0.25)
