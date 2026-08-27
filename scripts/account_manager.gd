extends Node
## Accounts for Dreamweaver.
##
## When supabase_config.gd URL + ANON_KEY are set → Auth + cloud saves.
## When empty → local user://accounts.json (same as before), so the game
## still runs before you create a project.

const Config := preload("res://scripts/systems/supabase_config.gd")
const SAVE_PATH := "user://accounts.json"
const MIN_PASSWORD_LENGTH := 6

const LOGIN_SCENE := "res://scenes/Login.tscn"
const REGISTER_SCENE := "res://scenes/Register.tscn"
const STORY_INTRO_SCENE := "res://scenes/StoryIntro.tscn"
const MAIN_GAME_SCENE := "res://scenes/MainGame.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"
const HUB_SCENE := "res://scenes/HubWorld.tscn"
const ENDING_SCENE := "res://scenes/Ending.tscn"
const GAME_OVER_SCENE := "res://scenes/GameOver.tscn"
const CODEX_SCENE := "res://scenes/LoreCodex.tscn"

var _accounts: Dictionary = {}
var _current_key: String = ""
## Cached progress for the signed-in weaver (GameState reads this sync).
var _progress_cache: Dictionary = {}
var _has_seen_intro_cache: bool = false


func _ready() -> void:
	_load_from_disk()
	if is_cloud_mode() and Supabase.has_session():
		_current_key = _normalize_key(Supabase.username)
		if _current_key.is_empty():
			_current_key = _normalize_key(str(Supabase.user_email).get_slice("@", 0))
		await _pull_progress_from_cloud()


func is_cloud_mode() -> bool:
	return Config.is_configured()


func has_session() -> bool:
	if is_cloud_mode():
		return not _current_key.is_empty() and Supabase.has_session()
	return not _current_key.is_empty() and _accounts.has(_current_key)


func current_username() -> String:
	if not has_session():
		return ""
	if is_cloud_mode():
		if not Supabase.username.is_empty():
			return Supabase.username
		return _current_key
	return str(_accounts[_current_key].get("username", _current_key))


## Login and register both land on the Gateway; New Game / Load Game is chosen there.
func scene_after_login() -> String:
	return MAIN_MENU_SCENE


func has_seen_intro() -> bool:
	if not has_session():
		return false
	if is_cloud_mode():
		return _has_seen_intro_cache
	return bool(_accounts[_current_key].get("has_seen_intro", false))


func mark_intro_seen() -> void:
	if not has_session():
		return
	if is_cloud_mode():
		_has_seen_intro_cache = true
		_push_progress_to_cloud()
		return
	_accounts[_current_key]["has_seen_intro"] = true
	_save_to_disk()


func logout() -> void:
	if is_cloud_mode():
		await Supabase.sign_out()
	_current_key = ""
	_progress_cache.clear()
	_has_seen_intro_cache = false


## Returns "" on success, or a player-facing error.
func change_password(current_password: String, new_password: String, confirm: String) -> String:
	if not has_session():
		return "Sign in before changing your password."
	if current_password.is_empty() or new_password.is_empty() or confirm.is_empty():
		return "Every field must be filled."
	if new_password.length() < MIN_PASSWORD_LENGTH:
		return "A password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if new_password != confirm:
		return "The two new passwords do not match."
	if new_password == current_password:
		return "Pick a password different from the current one."

	if is_cloud_mode():
		var check: Dictionary = await Supabase.sign_in(current_username(), current_password)
		if not bool(check.get("ok", false)):
			return "Current password is wrong."
		var upd: Dictionary = await Supabase.update_password(new_password)
		if not bool(upd.get("ok", false)):
			return str(upd.get("error", "Could not update password."))
		return ""

	var stored := str(_accounts[_current_key].get("password_hash", ""))
	if stored != _hash_password(current_password):
		return "Current password is wrong."
	_accounts[_current_key]["password_hash"] = _hash_password(new_password)
	_save_to_disk()
	return ""


## Soft-deletes the signed-in account and its save. Returns "" on success.
func delete_account(password: String) -> String:
	if not has_session():
		return "No weaver is signed in."
	if password.is_empty():
		return "Enter your password to confirm."

	if is_cloud_mode():
		var check: Dictionary = await Supabase.sign_in(current_username(), password)
		if not bool(check.get("ok", false)):
			return "Password does not match."
		var wiped: Dictionary = await Supabase.soft_delete_account()
		if not bool(wiped.get("ok", false)):
			return str(wiped.get("error", "Could not delete account data."))
		_current_key = ""
		_progress_cache.clear()
		_has_seen_intro_cache = false
		return ""

	var stored := str(_accounts[_current_key].get("password_hash", ""))
	if stored != _hash_password(password):
		return "Password does not match."
	var key := _current_key
	_accounts.erase(key)
	_current_key = ""
	_progress_cache.clear()
	_save_to_disk()
	return ""


# --------------------------------------------------------------------------
# Gameplay progress
# --------------------------------------------------------------------------

func get_progress() -> Dictionary:
	if not has_session():
		return {}
	if is_cloud_mode():
		return _progress_cache.duplicate(true)
	var stored: Variant = _accounts[_current_key].get("progress", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return (stored as Dictionary).duplicate(true)


func save_progress(progress: Dictionary) -> void:
	if not has_session():
		return
	if is_cloud_mode():
		_progress_cache = progress.duplicate(true)
		_push_progress_to_cloud()
		return
	_accounts[_current_key]["progress"] = progress.duplicate(true)
	_save_to_disk()


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
	var items: Variant = progress.get("items", [])
	return typeof(items) == TYPE_ARRAY and not (items as Array).is_empty()


func clear_progress() -> void:
	if not has_session():
		return
	if is_cloud_mode():
		_progress_cache.clear()
		_has_seen_intro_cache = false
		_push_progress_to_cloud()
		return
	_accounts[_current_key].erase("progress")
	_accounts[_current_key]["has_seen_intro"] = false
	_save_to_disk()


# --------------------------------------------------------------------------
# Auth
# --------------------------------------------------------------------------

## Returns an empty string on success, or a player-facing error message.
func try_login(username: String, password: String) -> String:
	var display := username.strip_edges()
	var key := _normalize_key(display)
	if key.is_empty() or password.is_empty():
		return "The loom is empty. Enter your username and password."

	if is_cloud_mode():
		var result: Dictionary = await Supabase.sign_in(display, password)
		if not bool(result.get("ok", false)):
			return _friendly_auth_error(str(result.get("error", "")), "Those threads do not match any known weaver.")
		_current_key = key
		await _pull_progress_from_cloud()
		return ""

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
	if password.length() < MIN_PASSWORD_LENGTH:
		return "A password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if password != confirm:
		return "The two passwords do not match."

	if is_cloud_mode():
		var result: Dictionary = await Supabase.sign_up(display_name, password)
		if not bool(result.get("ok", false)):
			return _friendly_auth_error(str(result.get("error", "")), "Could not create that account.")
		if not Supabase.has_session():
			var login_try: Dictionary = await Supabase.sign_in(display_name, password)
			if not bool(login_try.get("ok", false)):
				return "Account created. In Supabase → Authentication → Providers → Email, turn OFF “Confirm email”, then sign in."
		_current_key = key
		_progress_cache.clear()
		_has_seen_intro_cache = false
		await _push_progress_to_cloud()
		return ""

	if _accounts.has(key):
		return "That name is already spoken in the village."
	_accounts[key] = {
		"username": display_name,
		"password_hash": _hash_password(password),
		"has_seen_intro": false,
	}
	_current_key = key
	_save_to_disk()
	return ""


# --------------------------------------------------------------------------
# Cloud sync
# --------------------------------------------------------------------------

func _pull_progress_from_cloud() -> void:
	var res: Dictionary = await Supabase.fetch_save()
	if not bool(res.get("ok", false)):
		_progress_cache.clear()
		_has_seen_intro_cache = false
		return
	var rows: Variant = res.get("data", [])
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		_progress_cache.clear()
		_has_seen_intro_cache = false
		await _push_progress_to_cloud()
		return
	var row: Dictionary = (rows as Array)[0]
	var prog: Variant = row.get("progress", {})
	if typeof(prog) == TYPE_DICTIONARY:
		_progress_cache = (prog as Dictionary).duplicate(true)
	else:
		_progress_cache.clear()
	_has_seen_intro_cache = bool(row.get("has_seen_intro", false))


func _push_progress_to_cloud() -> void:
	if not Supabase.has_session():
		return
	await Supabase.upsert_save(_progress_cache.duplicate(true), _has_seen_intro_cache)


func _friendly_auth_error(raw: String, fallback: String) -> String:
	var lower := raw.to_lower()
	if "invalid login" in lower or "invalid_credentials" in lower:
		return "Those threads do not match any known weaver."
	if "already registered" in lower or "user already" in lower:
		return "That name is already spoken in the village."
	if "password" in lower and ("weak" in lower or "least" in lower):
		return "A password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if raw.strip_edges().is_empty():
		return fallback
	return raw


# --------------------------------------------------------------------------
# Local disk
# --------------------------------------------------------------------------

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
