extends "res://scripts/chapters/house_quest.gd"
## Chapter 4 - House of the Dream Ancestors.
##
## Beats: the Master Weaver's ghost materialises and speaks in riddles -> four
## stone statues each open a T'boli culture quiz -> pass Warp Alignment on the
## great Ablun loom -> receive the Sacred Master Pattern, which unlocks the
## final House.

const CULTURE_QUIZ := "res://scenes/minigames/CultureQuiz.tscn"
const WARP_ALIGNMENT := "res://scenes/minigames/WarpAlignment.tscn"

const STATUE_CELLS: Array[Vector2] = [
	Vector2(-6.0, -5.0),
	Vector2(6.0, -5.0),
	Vector2(-6.0, 3.0),
	Vector2(6.0, 3.0),
]

var _ghost: PlaceholderProp
var _ghost_trigger: Interactable
var _loom: PlaceholderProp
var _loom_trigger: Interactable
var _statues: Array[PlaceholderProp] = []
var _statue_triggers: Array[Interactable] = []
var _answered := 0
var _busy := false


func _build_world() -> void:
	add_room_bounds(Vector2i(-8, -8), 17, 17)

	_loom = spawn_prop("THE GREAT ABLUN LOOM", Vector2(0.0, -1.0), {
		"texture_path": "res://assets/images/props/ablun_loom.png",
		"prop_size": Vector2(190.0, 130.0),
		"body_color": Color(0.3, 0.26, 0.21),
		"accent_color": Color(0.66, 0.56, 0.34),
	})
	_loom_trigger = add_interactable("Sit at the Ablun loom", Vector2(0.0, 0.6),
		{"enabled": false, "radius": 96.0})

	_ghost = spawn_prop("MASTER WEAVER (ghost)", Vector2(0.0, -3.4), {
		"texture_path": "res://assets/images/characters/master_weaver_ghost.png",
		"prop_size": Vector2(56.0, 96.0),
		"body_color": Color(0.62, 0.66, 0.7),
		"accent_color": Color(0.85, 0.88, 0.9),
		"float_amplitude": 5.0,
		"float_speed": 0.9,
	})
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_ghost_trigger = add_interactable("Listen to the Master Weaver", Vector2(0.0, -2.6),
		{"enabled": false, "radius": 80.0})

	for i in range(STATUE_CELLS.size()):
		var statue_data := CultureData.statue(i)
		var statue := spawn_prop(str(statue_data.get("statue", "STATUE")).to_upper(),
			STATUE_CELLS[i], {
				"texture_path": "res://assets/images/props/ancestor_statue_%d.png" % (i + 1),
				"prop_size": Vector2(52.0, 112.0),
				"body_color": Color(0.33, 0.32, 0.31),
				"accent_color": Color(0.48, 0.47, 0.45),
			})
		_statues.append(statue)

		var trigger := add_interactable("Question the statue", STATUE_CELLS[i] + Vector2(0.0, 0.7),
			{"enabled": false, "radius": 72.0})
		trigger.interacted.connect(_on_statue_interacted.bind(i))
		_statue_triggers.append(trigger)

	_build_hall_dressing()


func _build_hall_dressing() -> void:
	for i in range(6):
		spawn_prop("STONE PILLAR", Vector2(-7.0 + float(i) * 2.8, -7.5), {
			"prop_size": Vector2(50.0, 128.0),
			"body_color": Color(0.24, 0.235, 0.23),
			"accent_color": Color(0.36, 0.35, 0.34),
			"show_label": i == 0,
			"cast_shadow": false,
		})

	spawn_prop("OFFERING BOWL", Vector2(-2.0, 4.0), {
		"prop_size": Vector2(40.0, 30.0),
		"body_color": Color(0.35, 0.3, 0.22),
		"accent_color": Color(0.6, 0.5, 0.3),
	})
	for i in range(5):
		spawn_prop("WOVEN MOTIF", Vector2(-5.0 + float(i) * 2.5, 6.2), {
			"prop_size": Vector2(28.0, 28.0),
			"body_color": Color(0.7, 0.62, 0.42),
			"accent_color": Color(0.9, 0.8, 0.5),
			"show_label": false,
			"cast_shadow": false,
			"float_amplitude": 6.0 + float(i),
			"float_speed": 0.8 + float(i) * 0.12,
		})

	var scroll := spawn_collectible("Lore Scroll: Taboos of the Loom", Vector2(3.0, 5.0), {
		"tint": Color(0.72, 0.68, 0.56),
		"score_value": 80,
		"lore_id": "taboo",
	})
	scroll.collected.connect(func(_pickup: Collectible) -> void:
		banner("Lore recovered: Taboos of the Loom", 1.6))


# --------------------------------------------------------------------------

func _run_chapter() -> void:
	banner("Chapter IV\nHouse of the Dream Ancestors", 2.6)
	objective("Enter the hall of the ancestors.")
	await wait(1.2)

	await say([
		"Gray stone faces stand around a loom the size of a doorway. None of them were carved. They were people, and then they were remembered, and then they were forgotten into stone.",
	])

	# The ghost fades in rather than popping into existence.
	var appear := create_tween()
	appear.tween_property(_ghost, "modulate:a", 0.75, 1.8)
	Audio.set_ambience(0.35, 11.0)
	await wait(1.9)

	await say([
		{"speaker": "Master Weaver", "text": "You carry three colours and no pattern. That is a bag of dye and a bare loom, child, and a bare loom weaves nothing."},
		{"speaker": "S'lang", "text": "Then teach me the pattern."},
		{"speaker": "Master Weaver", "text": "It is not mine to hand you. It is held in four stones, and the stones do not answer strangers. They answer those who know what they are looking at."},
	])

	_ghost_trigger.set_enabled(true)
	objective("Hear the Master Weaver's riddle. [E]")
	await _ghost_trigger.interacted

	await say([
		{"speaker": "Master Weaver", "text": "Hear them, then. One dreams and does not invent. One is torn from a trunk and made worthy. One is beaten so it may give its colour away. One wove until her hands were maps."},
		{"speaker": "Master Weaver", "text": "Four stones. Four questionings. Answer wrongly three times in this House and you will begin it again - the ancestors do not repeat themselves kindly."},
	])
	GameState.unlock_lore("fun_kdungon")

	for trigger in _statue_triggers:
		trigger.set_enabled(true)
	counter("Statues answered  0 / %d" % STATUE_CELLS.size())
	objective("Question all four ancestor statues. [E]")

	await until(func() -> bool:
		return _answered >= STATUE_CELLS.size() or is_finished())
	if is_finished():
		return

	counter("")
	await say([
		{"speaker": "Master Weaver", "text": "Four stones, four true answers. Now the loom. The dream is already on it - you only have to stop arguing with it."},
	])

	_loom_trigger.set_enabled(true)
	objective("Align the warp threads at the Ablun loom. [E]")
	await _loom_trigger.interacted

	var aligned: bool = await run_mini_game(WARP_ALIGNMENT)
	if not aligned:
		await say([
			{"speaker": "Master Weaver", "text": "You forced it. A warp forced is a warp broken. Rest, and come back to it."},
		])
		await fail_chapter()
		return

	set_player_input(false)
	banner("The Sacred Master Pattern", 2.2)
	Audio.play_sfx(Audio.Sfx.CHIME)
	for statue in _statues:
		statue.set_tint(Color(1.05, 1.0, 0.94))
	restore_local_color(_loom)
	GameState.unlock_lore("lang_dulay")
	await wait(1.6)

	await complete_chapter([
		"The pattern comes off the loom as light rather than cloth, and folds itself small enough to carry.",
		{"speaker": "Master Weaver", "text": "Lang Dulay held a hundred of these in her head and gave them away to anyone who would sit still and learn. That is the whole of it. Memory is a craft."},
		{"speaker": "Master Weaver", "text": "Black, red, gold, and a pattern to put them in. The great house at the centre is open to you now. Something is already at the Sacred Loom, and it is unweaving."},
	])


func _on_statue_interacted(index: int) -> void:
	if _busy or is_finished():
		return
	var statue_data := CultureData.statue(index)
	if statue_data.is_empty():
		return

	_busy = true
	var trigger := _statue_triggers[index]
	trigger.set_enabled(false)

	await say([
		{"speaker": str(statue_data.get("statue", "Statue")),
		 "text": str(statue_data.get("riddle", ""))},
	])

	var passed: bool = await run_mini_game(CULTURE_QUIZ, {
		"questions": statue_data.get("questions", []),
		"quiz_speaker": str(statue_data.get("statue", "The Ancestors")),
	})

	if not passed:
		# The quiz already spent the House's allowance of wrong answers.
		await say([
			{"speaker": "Master Weaver", "text": "Enough. You are guessing, and the stones will not be guessed at. Begin this House again."},
		])
		await fail_chapter()
		return

	_answered += 1
	_statues[index].set_tint(Color(1.0, 0.96, 0.84))
	_statues[index].prop_label = str(statue_data.get("statue", "STATUE")).to_upper() + "\n(answered)"
	counter("Statues answered  %d / %d" % [_answered, STATUE_CELLS.size()])
	GameState.add_score(150)
	Audio.play_sfx(Audio.Sfx.SUCCESS)
	_busy = false
