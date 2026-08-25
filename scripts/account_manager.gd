extends Node
## Local account storage for the capstone build.
## Saves to user://accounts.json (no server). Passwords are SHA-256 hashed.

const SAVE_PATH := "user://accounts.json"
const MIN_PASSWORD_LENGTH := 6

const LOGIN_SCENE := "res://scenes/Login.tscn"
const REGISTER_SCENE := "res://scenes/Register.tscn"
const STORY_INTRO_SCENE := "res://scenes/StoryIntro.tscn"
## Router that decides between the tutorial and the hub, reached from the intro.
const MAIN_GAME_SCENE := "res://scenes/MainGame.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"
const HUB_SCENE := "res://scenes/HubWorld.tscn"
const ENDING_SCENE := "res://scenes/Ending.tscn"
const GAME_OVER_SCENE := "res://scenes/GameOver.tscn"
const CODEX_SCENE := "res://scenes/LoreCodex.tscn"

var _accounts: Dictionary = {}
var _current_key: String = ""


func _ready() -> void:
	_load_from_disk()


func has_session() -> bool:
	return not _current_key.is_empty() and _accounts.has(_current_key)


func current_username() -> String:
	if not has_session():
		return ""
	return str(_accounts[_current_key].get("username", _current_key))


## Login and register both land on the Gateway; New Game / Load Game is chosen
## there rather than being decided for the player.
func scene_after_login() -> String:
	return MAIN_MENU_SCENE


func has_seen_intro() -> bool:
	if not has_session():
		return false
	return bool(_accounts[_current_key].get("has_seen_intro", false))


func mark_intro_seen() -> void:
	if not has_session():
		return
	_accounts[_current_key]["has_seen_intro"] = true
	_save_to_disk()


func logout() -> void:
	_current_key = ""


# --------------------------------------------------------------------------
# Gameplay progress, stored per account alongside the credentials.
# GameState owns the shape of this dictionary; AccountManager only persists it.
# --------------------------------------------------------------------------

## Returns the saved progress dictionary, or an empty one for a fresh weaver.
func get_progress() -> Dictionary:
	if not has_session():
		return {}
	var stored: Variant = _accounts[_current_key].get("progress", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func save_progress(progress: Dictionary) -> void:
	if not has_session():
		return
	_accounts[_current_key]["progress"] = progress
	_save_to_disk()


## True when this account has a run worth loading (past the very first step).
func has_progress() -> bool:
	var progress := get_progress()
	if progress.is_empty():
		return false
	if int(progress.get("current_chapter", 0)) > 0:
		return true
	if bool(progress.get("game_completed", false)):
		return true
	var completed: Variant = progress.get("completed_houses", [])
	if typeof(completed) == TYPE_ARRAY and not (completed as Array).is_empty():
		return true
	# Taking the Lewet Staff counts as a run even before the first House, so a
	# weaver who quits on the ridge can still resume from the Gateway.
	var items: Variant = progress.get("items", [])
	return typeof(items) == TYPE_ARRAY and not (items as Array).is_empty()


func clear_progress() -> void:
	if not has_session():
		return
	_accounts[_current_key].erase("progress")
	_save_to_disk()


## Returns an empty string on success, or a player-facing error message.
func try_login(username: String, password: String) -> String:
	var key := _normalize_key(username)
	if key.is_empty() or password.is_empty():
		return "The loom is empty. Enter your username and password."
	if not _accounts.has(key):
		return "Those threads do not match any known weaver."
	var stored := str(_accounts[key].get("password_hash", ""))
	if stored != _hash_password(password):
		return "Those threads do not match any known weaver."
	_current_key = key
	return ""


## Creates an account, starts a session, and returns "" on success.
func try_register(username: String, password: String, confirm: String) -> String:
	var display_name := username.strip_edges()
	var key := _normalize_key(display_name)
	if key.is_empty() or password.is_empty() or confirm.is_empty():
		return "Every field must be woven. Fill them all."
	if _accounts.has(key):
		return "That name is already spoken in the village."
	if password.length() < MIN_PASSWORD_LENGTH:
		return "A password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if password != confirm:
		return "The two passwords do not match."

	_accounts[key] = {
		"username": display_name,
		"password_hash": _hash_password(password),
		"has_seen_intro": false,
	}
	_current_key = key
	_save_to_disk()
	return ""


func _normalize_key(username: String) -> String:
	return username.strip_edges().to_lower()


func _hash_password(password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()


func _load_from_disk() -> void:
	_accounts = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("AccountManager: could not read %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data := parsed as Dictionary
	var stored: Variant = data.get("accounts", {})
	if typeof(stored) == TYPE_DICTIONARY:
		_accounts = stored


func _save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AccountManager: could not write %s (%s)" % [
			SAVE_PATH, error_string(FileAccess.get_open_error())
		])
		return
	file.store_string(JSON.stringify({"accounts": _accounts}, "\t"))
