class_name TutorialManager
extends Node
## Gated awakening: walk, pick up a strand, take the staff, land one hit,
## then roll and raise a ward. Colour sleeps until the beater is in hand.
##
## One lesson on screen at a time. HUD quest steps track progress; the bottom
## card teaches the input. Advance only on real signals.
## Q and the light beam stay out of this room. Their houses teach them.

enum Step {
	Movement,
	Gather,
	Staff,
	Combat,
	Guard,
	Done,
}

signal step_changed(step: Step)
signal finished

const STEPS: Array[String] = [
	"Walk the house",
	"Pick up the strand",
	"Take the Lewet Staff",
	"Strike a Shadow Creep",
	"Roll and ward",
]

const MOVE_HOLD_SECONDS := 0.9
const MOVE_MIN_DISTANCE := 72.0
const CREEP_COUNT := 2

var step := Step.Movement

var _host: ChapterBase
var _player: Slang
var _prompt: TutorialPrompt
var _staff: Node2D
var _staff_trigger: Interactable
var _beacon: QuestBeacon
var _move_hold := 0.0
var _move_distance := 0.0
var _creeps: Array[ShadowMinion] = []
var _strand: Collectible
var _completing := false
var _keys_seen: Dictionary = {}
var _guard_seen: Dictionary = {}


func setup(host: ChapterBase, staff: Node2D, staff_trigger: Interactable) -> void:
	_host = host
	_player = host.player
	_staff = staff
	_staff_trigger = staff_trigger
	_build_prompt()
	_ensure_beacon()
	if _player != null:
		_player.has_staff = false
		_player.set_light_enabled(false)
		if not _player.staff_acquired.is_connected(_on_staff_acquired):
			_player.staff_acquired.connect(_on_staff_acquired)
		if not _player.attack_hit.is_connected(_on_attack_hit):
			_player.attack_hit.connect(_on_attack_hit)
		if not _player.dodged.is_connected(_on_dodged):
			_player.dodged.connect(_on_dodged)
		if not _player.ward_raised.is_connected(_on_ward_raised):
			_player.ward_raised.connect(_on_ward_raised)
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
		if not _staff_trigger.interacted.is_connected(_on_staff_interacted):
			_staff_trigger.interacted.connect(_on_staff_interacted)
	set_process(false)


func begin() -> void:
	goto_step(Step.Movement)


func goto_step(next: Step) -> void:
	step = next
	_completing = false
	step_changed.emit(step)
	_sync_hud_steps()
	match step:
		Step.Movement:
			_enter_movement()
		Step.Gather:
			_enter_gather()
		Step.Staff:
			_enter_staff()
		Step.Combat:
			_enter_combat()
		Step.Guard:
			_enter_guard()
		Step.Done:
			_enter_done()


func advance() -> void:
	if step == Step.Done or _completing:
		return
	goto_step((step + 1) as Step)


func _build_prompt() -> void:
	_prompt = TutorialPrompt.new()
	_prompt.name = "TutorialPrompt"
	var layer: Node = _host.ui_layer if _host != null and _host.ui_layer != null else _host
	layer.add_child(_prompt)


func _ensure_beacon() -> void:
	if _beacon != null or _host == null:
		return
	_beacon = QuestBeacon.new()
	_beacon.name = "TutorialBeacon"
	var parent: Node = _host.world if _host.world != null else _host
	parent.add_child(_beacon)
	_beacon.clear()


func _sync_hud_steps() -> void:
	if _host == null or _host.hud == null or not _host.hud.has_method("set_quest_steps"):
		return
	if step == Step.Done:
		_host.hud.call("set_quest_steps", [], 0)
		return
	_host.hud.call("set_quest_steps", STEPS, int(step))


func _enter_movement() -> void:
	_move_hold = 0.0
	_move_distance = 0.0
	_keys_seen.clear()
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
	if _beacon != null:
		_beacon.clear()
	if _host != null:
		_host.set_player_input(true)
		_host.objective("Walk the house.")
	_prompt.show_hint(
		"Your feet",
		"The floor still knows you. Walk it.",
		["W", "A", "S", "D"],
		1,
		5,
		"wasd"
	)
	set_process(true)


func _enter_gather() -> void:
	set_process(false)
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
	_strand = _spawn_strand()
	if _beacon != null and _strand != null:
		_beacon.pin(_strand)
	if _host != null:
		_host.objective("Pick up the abaca strand. Press [R].")
	_prompt.show_hint(
		"Loose fibre",
		"Strands, roots, and scrolls stay on the ground until you take them.",
		["R"],
		2,
		5
	)


func _enter_staff() -> void:
	set_process(false)
	if _staff_trigger != null:
		_staff_trigger.set_enabled(true)
	if _beacon != null:
		_beacon.pin(_staff)
	if _host != null:
		_host.objective("Take the Lewet Staff. Press [E].")
	_prompt.show_hint(
		"The beater",
		"E speaks to people, and uses what they leave you.",
		["E"],
		3,
		5
	)


func _enter_combat() -> void:
	if _beacon != null:
		_beacon.clear()
	if _host != null:
		_host.objective("Strike a Shadow Creep.")
	_prompt.show_hint(
		"A thread of shadow",
		"Click a Shadow Creep, or press Space.",
		["CLICK", "SPACE"],
		4,
		5
	)
	_spawn_creeps()


func _enter_guard() -> void:
	set_process(false)
	_guard_seen.clear()
	if _host != null:
		_host.objective("Roll with [Shift], then press [1] to ward.")
	var living := _living_creep()
	if _beacon != null:
		if living != null:
			_beacon.pin(living)
		else:
			_beacon.clear()
	_prompt.show_hint(
		"Guard yourself",
		"Shift rolls through a blow. Right-click does the same. 1 raises a ward.",
		["SHIFT", "1"],
		5,
		5
	)


func _enter_done() -> void:
	set_process(false)
	_prompt.hide_prompt()
	if _beacon != null:
		_beacon.clear()
	if _host != null:
		_host.set_player_input(false)
		_host.objective("Listen.")
	_clear_creeps()
	finished.emit()


func _process(delta: float) -> void:
	if step != Step.Movement or _player == null or not is_instance_valid(_player):
		return
	if not _player.input_enabled or _completing:
		return
	_light_move_keys()
	var speed := _player.velocity.length()
	if speed > 24.0:
		_move_hold += delta
		_move_distance += speed * delta
	else:
		_move_hold = 0.0
	# Distance alone must not skip the lesson. Every direction has to be pressed.
	if _keys_seen.size() >= 4 and (_move_hold >= MOVE_HOLD_SECONDS or _move_distance >= MOVE_MIN_DISTANCE):
		_finish_step("That's it")


func _light_move_keys() -> void:
	var pairs := {
		"move_up": "W",
		"move_left": "A",
		"move_down": "S",
		"move_right": "D",
	}
	for action in pairs:
		if Input.is_action_pressed(action):
			var glyph: String = pairs[action]
			if not _keys_seen.has(glyph):
				_keys_seen[glyph] = true
				_prompt.light_key(glyph)


func _on_staff_interacted() -> void:
	if step != Step.Staff or _player == null:
		return
	_player.equip_staff()
	if _staff != null and is_instance_valid(_staff):
		_staff.queue_free()
		_staff = null
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
	if _beacon != null:
		_beacon.clear()
	Audio.play_sfx(Audio.Sfx.CHIME)
	if _host != null:
		_host.banner("The Lewet Staff", 1.6)
		ColorRestoration.remove_zone("lewet_staff")
		ColorRestoration.bloom_zone("staff_carried", _player, 620.0, 1.0, 1.15)
		ColorRestoration.set_global_gray(0.0, 1.4)


func _on_strand_collected(_pickup: Collectible) -> void:
	if step != Step.Gather or _completing:
		return
	_prompt.light_key("R")
	if _beacon != null:
		_beacon.clear()
	_strand = null
	_finish_step("Fibre in hand")


func _on_staff_acquired() -> void:
	if step != Step.Staff or _completing:
		return
	GameState.unlock_lore("lewet_staff")
	GameState.add_score(200)
	GameState.unlock_house(1)
	_finish_step("Staff in hand")


func _on_attack_hit(_hit: Node2D) -> void:
	if step != Step.Combat or _completing:
		return
	_prompt.light_key("CLICK")
	_prompt.light_key("SPACE")
	_finish_step("First strike")


func _on_dodged() -> void:
	_note_guard("SHIFT")


func _on_ward_raised() -> void:
	_note_guard("1")


func _note_guard(glyph: String) -> void:
	if step != Step.Guard or _completing or _guard_seen.has(glyph):
		return
	_guard_seen[glyph] = true
	if _prompt != null:
		_prompt.light_key(glyph)
	if _guard_seen.size() >= 2:
		_finish_step("Guarded")


func _finish_step(done_title: String) -> void:
	if _completing or step == Step.Done:
		return
	_completing = true
	set_process(false)
	if _prompt != null:
		await _prompt.celebrate(done_title)
	if step == Step.Done:
		return
	goto_step((step + 1) as Step)


func _spawn_strand() -> Collectible:
	if _host == null or not _host.has_method("spawn_tutorial_strand"):
		return null
	var strand: Collectible = _host.call("spawn_tutorial_strand")
	if strand != null and not strand.collected.is_connected(_on_strand_collected):
		strand.collected.connect(_on_strand_collected)
	return strand


func _living_creep() -> ShadowMinion:
	for creep in _creeps:
		if creep != null and is_instance_valid(creep) and not creep.is_queued_for_deletion():
			return creep
	return null


func _spawn_creeps() -> void:
	if _host == null:
		return
	for i in range(CREEP_COUNT):
		var spawn := {
			"spawn_delay": 0.55,
			"max_health": 48.0,
			"touch_damage": 6.0,
			"speed": 58.0,
		}
		var cell := Vector2(-4.5, 1.2) if i == 0 else Vector2(4.5, 1.6)
		if _host.has_method("creep_world"):
			spawn["position"] = _host.call("creep_world", i)
			cell = Vector2.ZERO
		var minion := _host.spawn_minion(cell, spawn)
		if minion == null:
			continue
		_creeps.append(minion)
		if i == 0 and _beacon != null:
			_beacon.pin(minion)


func _clear_creeps() -> void:
	for creep in _creeps:
		if creep != null and is_instance_valid(creep):
			creep.queue_free()
	_creeps.clear()
