extends Node3D

enum State { EXPLORE, DIALOGUE, CHOOSING, TRANSFORMING, COMPLETE }

var _state: State = State.EXPLORE

@onready var player: CharacterBody3D = $Player
@onready var npc: Node3D = $NPC
@onready var npc_interaction: Node3D = $NPC/Interaction
@onready var world_builder: Node3D = $WorldBuilder
@onready var dream_transform: Node = $DreamTransformation
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var dialogue: Control = $UI/DialogueBox
@onready var choices: Control = $UI/ChoicesPanel
@onready var prompt: Label = $UI/InteractionPrompt
@onready var complete_panel: PanelContainer = $UI/DreamCompletePanel
@onready var complete_label: Label = $UI/DreamCompletePanel/Margin/VBox/MessageLabel


func _ready() -> void:
	GameManager.reset()
	_setup_environment()
	prompt.hide()
	complete_panel.hide()
	choices.hide()

	var particles: GPUParticles3D = world_builder.get_node("DreamParticles")
	dream_transform.setup(
		world_environment,
		sun,
		particles,
		world_builder.flower_root,
		npc,
		world_builder.water_mesh
	)

	npc_interaction.player_nearby.connect(_on_player_nearby)
	npc_interaction.interaction_requested.connect(_on_interaction_requested)
	choices.choice_made.connect(_on_choice_made)
	dream_transform.transformation_complete.connect(_on_transformation_complete)
	complete_panel.get_node("Margin/VBox/ReturnButton").pressed.connect(_on_return_to_menu)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.16, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.55)
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.88, 1.0)
	env.fog_density = 0.035
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = env

	sun.light_energy = 1.2
	sun.light_color = Color(0.85, 0.9, 1.0)
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)


func _on_player_nearby(is_near: bool) -> void:
	if _state != State.EXPLORE:
		return
	prompt.visible = is_near


func _on_interaction_requested() -> void:
	if _state != State.EXPLORE:
		return
	_state = State.DIALOGUE
	prompt.hide()
	player.set_movement_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialogue.show_dialogue(
		"Wisp",
		"I've been wandering this dream alone for so long...\nWill you stay with me?",
		"neutral"
	)
	await get_tree().create_timer(2.5).timeout
	if _state == State.DIALOGUE:
		_state = State.CHOOSING
		choices.show_choices("What will you do?")


func _on_choice_made(choice_id: String) -> void:
	if _state != State.CHOOSING:
		return
	_state = State.TRANSFORMING
	choices.hide_choices()

	if choice_id == "comfort":
		GameManager.choice = GameManager.DreamChoice.COMFORT
		dialogue.show_dialogue("Wisp", "Thank you... the dream feels warm again.", "happy")
	else:
		GameManager.choice = GameManager.DreamChoice.IGNORE
		dialogue.show_dialogue("Wisp", "I knew it... dreams always fade.", "sad")

	dream_transform.apply_choice(choice_id)


func _on_transformation_complete(is_positive: bool) -> void:
	_state = State.COMPLETE
	GameManager.dream_complete = true
	dialogue.hide_dialogue()

	if is_positive:
		complete_label.text = "Dream Complete\n\nYou comforted Wisp.\nThe dream is peaceful and bright."
	else:
		complete_label.text = "Dream Complete\n\nYou ignored Wisp.\nThe dream grows dark and lonely."

	complete_panel.show()
	player.set_movement_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
