extends Node
## Autoload holding the live playthrough: lives, essences, unlocked Houses,
## score and lore. Every mutation writes through to the signed-in account via
## AccountManager, so progress survives a quit at any point.

signal lives_changed(lives: int)
signal objective_changed(text: String)
signal inventory_changed
signal score_changed(score: int)
signal progress_changed
signal lore_unlocked(entry_id: String)

const MAX_LIVES := 3
## Wrong quiz answers allowed inside one chapter before a retake is forced.
const MAX_QUIZ_MISTAKES := 3

var lives := MAX_LIVES
## 0 = tutorial not finished. 1..5 = the House the player is currently on.
var current_chapter := 0
var unlocked_houses: Array = [1]
var completed_houses: Array = []
var essences: Array = []
var items: Array = []
var lore: Array = []
var score := 0
var quiz_mistakes := 0
var game_completed := false
var objective := ""


func _ready() -> void:
	load_from_account()


# --------------------------------------------------------------------------
# Save plumbing
# --------------------------------------------------------------------------

func new_game() -> void:
	lives = MAX_LIVES
	current_chapter = 0
	unlocked_houses = [1]
	completed_houses = []
	essences = []
	items = []
	lore = []
	score = 0
	quiz_mistakes = 0
	game_completed = false
	objective = ""
	ColorRestoration.reset()
	save()
	_announce_all()


func load_from_account() -> void:
	var data := AccountManager.get_progress()
	lives = int(data.get("lives", MAX_LIVES))
	current_chapter = int(data.get("current_chapter", 0))
	# JSON round-trips ints as floats; coerce so Array.has(1) works again.
	unlocked_houses = _as_int_array(data.get("unlocked_houses", [1]))
	completed_houses = _as_int_array(data.get("completed_houses", []))
	essences = _as_string_array(data.get("essences", []))
	items = _as_string_array(data.get("items", []))
	lore = _as_string_array(data.get("lore", []))
	score = int(data.get("score", 0))
	game_completed = bool(data.get("game_completed", false))
	quiz_mistakes = 0
	objective = ""
	if unlocked_houses.is_empty():
		unlocked_houses = [1]
	_announce_all()


## JSON.parse turns every number into a float — keep house ids as ints.
func _as_int_array(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for entry in value:
			out.append(int(entry))
	return out


func _as_string_array(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for entry in value:
			out.append(str(entry))
	return out


func save() -> void:
	AccountManager.save_progress({
		"lives": lives,
		"current_chapter": current_chapter,
		"unlocked_houses": unlocked_houses,
		"completed_houses": completed_houses,
		"essences": essences,
		"items": items,
		"lore": lore,
		"score": score,
		"game_completed": game_completed,
	})


func has_save() -> bool:
	return AccountManager.has_progress()


# --------------------------------------------------------------------------
# Lives
# --------------------------------------------------------------------------

## Spends one life. Returns false when the player is out and the run is over.
func lose_life() -> bool:
	lives = maxi(0, lives - 1)
	lives_changed.emit(lives)
	save()
	return lives > 0


func refill_lives() -> void:
	lives = MAX_LIVES
	lives_changed.emit(lives)
	save()


func grant_life() -> void:
	if lives < MAX_LIVES:
		lives += 1
		lives_changed.emit(lives)
		save()


# --------------------------------------------------------------------------
# Houses and inventory
# --------------------------------------------------------------------------

func is_house_unlocked(house_id: int) -> bool:
	return _int_array_has(unlocked_houses, house_id)


func is_house_completed(house_id: int) -> bool:
	return _int_array_has(completed_houses, house_id)


func _int_array_has(values: Array, house_id: int) -> bool:
	for entry in values:
		if int(entry) == house_id:
			return true
	return false


func unlock_house(house_id: int) -> void:
	if house_id > Houses.count() or is_house_unlocked(house_id):
		return
	unlocked_houses.append(house_id)
	progress_changed.emit()
	save()


## Marks a House restored, banks its essence, and opens the next one.
func complete_house(house_id: int) -> void:
	if not is_house_completed(house_id):
		completed_houses.append(house_id)
		add_score(Houses.COMPLETION_SCORE)
	var house := Houses.get_house(house_id)
	var essence := str(house.get("essence", ""))
	if not essence.is_empty():
		add_essence(essence)
	var reward_item := str(house.get("reward_item", ""))
	if not reward_item.is_empty():
		add_item(reward_item)
	unlock_house(house_id + 1)
	quiz_mistakes = 0
	progress_changed.emit()
	save()


func add_essence(essence_id: String) -> void:
	if essence_id.is_empty() or essences.has(essence_id):
		return
	essences.append(essence_id)
	inventory_changed.emit()
	ColorRestoration.sync_essences()
	save()


func has_essence(essence_id: String) -> bool:
	return essences.has(essence_id)


func add_item(item_id: String) -> void:
	if item_id.is_empty() or items.has(item_id):
		return
	items.append(item_id)
	inventory_changed.emit()
	save()


func has_item(item_id: String) -> bool:
	return items.has(item_id)


## True once Black + Red + Gold essences and the Master Pattern are secured.
func can_face_the_shadow_weaver() -> bool:
	return has_essence("black") and has_essence("red") and has_essence("gold") \
		and has_item("master_pattern")


func set_current_chapter(house_id: int) -> void:
	current_chapter = house_id
	quiz_mistakes = 0
	ColorRestoration.sync_essences()
	save()


## Where a retry should drop the player back in.
func current_chapter_scene() -> String:
	if not has_item("lewet_staff"):
		return AccountManager.TUTORIAL_SCENE
	# Live play is one 2.5D ridge; isolated Chapter scenes stay for tools.
	return AccountManager.HUB_SCENE


# --------------------------------------------------------------------------
# Objectives, score, lore
# --------------------------------------------------------------------------

func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func add_score(points: int) -> void:
	score = maxi(0, score + points)
	score_changed.emit(score)


## Fraction of the world's cloth rewoven, used by the HUD weaving meter.
func weaving_percent() -> float:
	return float(completed_houses.size()) / float(Houses.count())


func unlock_lore(entry_id: String) -> void:
	if entry_id.is_empty() or lore.has(entry_id):
		return
	lore.append(entry_id)
	add_score(CultureData.LORE_SCORE)
	lore_unlocked.emit(entry_id)
	save()


## Final ranking shown on the completion screen.
func rank() -> String:
	if score >= 6000:
		return "Master Dreamweaver"
	if score >= 4500:
		return "Keeper of the Loom"
	if score >= 3000:
		return "Dye Mistress"
	if score >= 1500:
		return "Apprentice Weaver"
	return "Thread Gatherer"


# --------------------------------------------------------------------------
# Quizzes
# --------------------------------------------------------------------------

## Records a wrong quiz answer. Returns false once a retake is required.
func register_quiz_mistake() -> bool:
	quiz_mistakes += 1
	add_score(-50)
	return quiz_mistakes < MAX_QUIZ_MISTAKES


func quiz_attempts_left() -> int:
	return maxi(0, MAX_QUIZ_MISTAKES - quiz_mistakes)


func reset_quiz_mistakes() -> void:
	quiz_mistakes = 0


## Banks the victory once. Safe to call again - the ending screen calls it too,
## and a replayed ending must not pay the victory bonus twice.
func complete_game() -> void:
	if game_completed:
		return
	game_completed = true
	add_score(Houses.VICTORY_SCORE)
	save()


func _announce_all() -> void:
	lives_changed.emit(lives)
	score_changed.emit(score)
	inventory_changed.emit()
	progress_changed.emit()
	objective_changed.emit(objective)
