extends Control
## Credits and final score, after the Color Burst.
##
## The living-world cutscene happens inside Chapter 5, in the restored world
## itself. This screen is the quiet part afterwards: the ranking, the lore tally,
## and the way back into the Codex for anything still unremembered.

const CREDIT_LINES := [
	"DREAMWEAVER",
	"The Legend of Fun Kdungon",
	"",
	"S'LANG, of the loom",
	"FUN KDUNGON, Goddess of Weaving",
	"THE SPIRIT OF THE FIBER",
	"THE MASTER WEAVER",
	"THE SHADOW WEAVER",
	"",
	"In memory of Lang Dulay,",
	"National Living Treasure,",
	"who held a hundred dreams",
	"and gave them all away.",
	"",
	"T'nalak is woven by the T'boli people",
	"of Lake Sebu, South Cotabato.",
	"It is still woven today.",
]

@onready var rank_label: Label = %RankLabel
@onready var score_label: Label = %ScoreLabel
@onready var summary_label: Label = %SummaryLabel
@onready var credits_column: VBoxContainer = %CreditsColumn
@onready var codex_button: Button = %CodexButton
@onready var gateway_button: Button = %GatewayButton


func _ready() -> void:
	# The veil is gone for good; nothing here should be gray.
	ColorRestoration.set_global_gray(0.0)
	Audio.set_ambience(0.3, 13.0)
	Audio.play_sfx(Audio.Sfx.SUCCESS)

	GameState.complete_game()

	rank_label.text = GameState.rank()
	score_label.text = "Final score  %d" % GameState.score
	summary_label.text = "Houses restored %d / %d      Lore remembered %d / %d      Lives remaining %d / %d" % [
		GameState.completed_houses.size(), Houses.count(),
		GameState.lore.size(), CultureData.total_lore(),
		GameState.lives, GameState.MAX_LIVES,
	]

	codex_button.pressed.connect(_on_codex_pressed)
	gateway_button.pressed.connect(_on_gateway_pressed)
	gateway_button.grab_focus()

	_roll_credits()


## Credits fade in one line at a time rather than scrolling, which keeps the
## final screen readable at any window size.
func _roll_credits() -> void:
	for i in range(CREDIT_LINES.size()):
		var text := str(CREDIT_LINES[i])
		var line := Label.new()
		line.text = text
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.modulate.a = 0.0
		if text.is_empty():
			line.custom_minimum_size = Vector2(0.0, 12.0)
		elif i == 0:
			line.theme_type_variation = &"HeaderLabel"
			line.add_theme_font_size_override("font_size", 30)
		elif i == 1:
			line.theme_type_variation = &"TaglineLabel"
		else:
			line.add_theme_font_size_override("font_size", 15)
			line.add_theme_color_override("font_color", Color(0.9, 0.85, 0.72))
		credits_column.add_child(line)

		var tween := create_tween()
		tween.tween_interval(0.35 + float(i) * 0.22)
		tween.tween_property(line, "modulate:a", 1.0, 0.6)


func _on_codex_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.CODEX_SCENE)


func _on_gateway_pressed() -> void:
	if SceneFader.is_busy():
		return
	SceneFader.fade_to_scene(AccountManager.MAIN_MENU_SCENE)
