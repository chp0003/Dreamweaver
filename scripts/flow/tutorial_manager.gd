class_name TutorialManager
extends Node
## Step-gated awakening: move, pick up the staff, land one hit.
##
## Advance only on real signals (held movement, staff_acquired, attack_hit).
## Add a Step case and a `_enter_*` method to extend.

enum Step {
	Movement,
	Pickup,
	Combat,
	Done,
}

signal step_changed(step: Step)
signal finished

const MOVE_HOLD_SECONDS := 1.2
const MOVE_MIN_DISTANCE := 96.0
const CREEP_COUNT := 2
const CREEP_CELLS: Array[Vector2] = [
	Vector2(-4.5, 1.2),
	Vector2(4.5, 1.6),
]

var step := Step.Movement

var _host: ChapterBase
var _player: Slang
var _prompt: TutorialPrompt
var _staff: Node2D
var _staff_trigger: Interactable
var _move_hold := 0.0
var _move_distance := 0.0
var _creeps: Array[ShadowMinion] = []


func setup(host: ChapterBase, staff: Node2D, staff_trigger: Interactable) -> void:
	_host = host
	_player = host.player
	_staff = staff
	_staff_trigger = staff_trigger
	_build_prompt()
	if _player != null:
		_player.has_staff = false
		_player.set_light_enabled(false)
		if not _player.staff_acquired.is_connected(_on_staff_acquired):
			_player.staff_acquired.connect(_on_staff_acquired)
		if not _player.attack_hit.is_connected(_on_attack_hit):
			_player.attack_hit.connect(_on_attack_hit)
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
		if not _staff_trigger.interacted.is_connected(_on_staff_interacted):
			_staff_trigger.interacted.connect(_on_staff_interacted)
	set_process(false)


func begin() -> void:
	goto_step(Step.Movement)


func goto_step(next: Step) -> void:
	step = next
	step_changed.emit(step)
	match step:
		Step.Movement:
			_enter_movement()
		Step.Pickup:
			_enter_pickup()
		Step.Combat:
			_enter_combat()
		Step.Done:
			_enter_done()


func advance() -> void:
	if step == Step.Done:
		return
	goto_step((step + 1) as Step)


func _build_prompt() -> void:
	_prompt = TutorialPrompt.new()
	_prompt.name = "TutorialPrompt"
	var layer: Node = _host.ui_layer if _host != null and _host.ui_layer != null else _host
	layer.add_child(_prompt)


func _enter_movement() -> void:
	_move_hold = 0.0
	_move_distance = 0.0
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
	if _host != null:
		_host.set_player_input(true)
		_host.objective("Walk around the room. WASD")
	_prompt.show_text("WASD to move")
	set_process(true)


func _enter_pickup() -> void:
	set_process(false)
	_prompt.hide_prompt()
	if _staff_trigger != null:
		_staff_trigger.set_enabled(true)
	if _host != null:
		_host.objective("Take the Lewet Staff. [E]")


func _enter_combat() -> void:
	if _host != null:
		_host.objective("Left-click a Shadow Creep to attack.")
	_prompt.show_text("Left Click to attack")
	_spawn_creeps()


func _enter_done() -> void:
	set_process(false)
	_prompt.hide_prompt()
	if _host != null:
		_host.set_player_input(false)
		_host.objective("Listen.")
	_clear_creeps()
	finished.emit()


func _process(delta: float) -> void:
	if step != Step.Movement or _player == null or not is_instance_valid(_player):
		return
	if not _player.input_enabled:
		return
	var speed := _player.velocity.length()
	if speed > 24.0:
		_move_hold += delta
		_move_distance += speed * delta
		if _move_hold >= MOVE_HOLD_SECONDS or _move_distance >= MOVE_MIN_DISTANCE:
			advance()
	else:
		_move_hold = 0.0


func _on_staff_interacted() -> void:
	if step != Step.Pickup or _player == null:
		return
	_player.equip_staff()
	if _staff != null and is_instance_valid(_staff):
		_staff.queue_free()
		_staff = null
	if _staff_trigger != null:
		_staff_trigger.set_enabled(false)
	Audio.play_sfx(Audio.Sfx.CHIME)
	if _host != null:
		_host.banner("The Lewet Staff", 2.0)
		ColorRestoration.add_zone("staff_carried", _player, 150.0, 1.0)


func _on_staff_acquired() -> void:
	if step != Step.Pickup:
		return
	GameState.unlock_lore("lewet_staff")
	GameState.add_score(200)
	GameState.unlock_house(1)
	advance()


func _on_attack_hit(_hit: Node2D) -> void:
	if step != Step.Combat:
		return
	advance()


func _spawn_creeps() -> void:
	if _host == null:
		return
	var count := mini(CREEP_COUNT, CREEP_CELLS.size())
	for i in range(count):
		var minion := _host.spawn_minion(CREEP_CELLS[i], {
			"spawn_delay": 0.75,
			"max_health": 40.0,
			"touch_damage": 8.0,
			"speed": 72.0,
		})
		if minion == null:
			continue
		_creeps.append(minion)


func _clear_creeps() -> void:
	for creep in _creeps:
		if creep != null and is_instance_valid(creep):
			creep.queue_free()
	_creeps.clear()
