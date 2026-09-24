extends Node
## Accounts for Dreamweaver.
##
## When supabase_config.gd URL + ANON_KEY are set → Auth + cloud saves.
## When empty → local user://accounts.json (same as before), so the game
## still runs before you create a project.

const Config := preload("res://scripts/systems/supabase_config.gd")
const SAVE_PATH := "user://accounts.json"
const MIN_PASSWORD_LENGTH := 6

const BOOT_SCENE := "res://scenes/Boot.tscn"
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
const LEADERBOARD_SCENE := "res://scenes/Leaderboard.tscn"

var _accounts: Dictionary = {}
var _current_key: String = ""
## Cached progress for the signed-in weaver (GameState reads this sync).
var _progress_cache: Dictionary = {}
var _has_seen_intro_cache: bool = false
var _startup_sync_done: bool = false


func _ready() -> void:
	_load_from_disk()
	if is_cloud_mode() and Supabase.has_session():
		_current_key = _normalize_key(Supabase.user_email)
		if _current_key.is_empty():
			_current_key = _normalize_key(Supabase.username)


## Called from Boot.tscn so cloud sync shows on the loading screen, not a blank frame.
func startup_sync() -> void:
	if _startup_sync_done:
		return
	if is_cloud_mode() and has_session():
		await _pull_progress_from_cloud()
	_startup_sync_done = true


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
		var email := str(Supabase.user_email).strip_edges()
		if email.is_empty():
			return "Signed-in email missing; log out and sign in again."
		var check: Dictionary = await Supabase.sign_in(email, current_password)
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
		var email := str(Supabase.user_email).strip_edges()
		if email.is_empty():
			return "Signed-in email missing; log out and sign in again."
		var check: Dictionary = await Supabase.sign_in(email, password)
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


## Ranked weavers: username, houses, chapter, score, rank title.
## Cloud uses fetch_leaderboard(); otherwise local accounts on this machine.
func fetch_leaderboard() -> Dictionary:
	var you := current_username().strip_edges().to_lower()
	var raw: Array = []
	var source := "local"
	if is_cloud_mode() and has_session():
		var res: Dictionary = await Supabase.fetch_leaderboard()
		if bool(res.get("ok", false)):
			var data: Variant = res.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				raw = _leaderboard_from_cloud(data as Array)
				source = "cloud"
	if raw.is_empty():
		raw = _leaderboard_from_local()
		source = "local"
		if is_cloud_mode() and has_session():
			_ensure_you_on_leaderboard(raw)

	raw.sort_custom(_leaderboard_before)
	for i in raw.size():
		var row: Dictionary = raw[i]
		row["place_index"] = i + 1
		row["is_you"] = str(row.get("username", "")).strip_edges().to_lower() == you \
			and not you.is_empty()
		raw[i] = row
	return {"ok": true, "rows": raw, "source": source, "error": ""}


# --------------------------------------------------------------------------
# Auth
# --------------------------------------------------------------------------

## Returns an empty string on success, or a player-facing error message.
## Login uses email + password (username is display-only, set at register).
func try_login(email: String, password: String) -> String:
	var mail := email.strip_edges().to_lower()
	if mail.is_empty() or password.is_empty():
		return "The loom is empty. Enter your email and password."
	if not _looks_like_email(mail):
		return "Enter a valid email address."

	if is_cloud_mode():
		var result: Dictionary = await Supabase.sign_in(mail, password)
		if not bool(result.get("ok", false)):
			return _friendly_auth_error(str(result.get("error", "")), "Those threads do not match any known weaver.")
		_current_key = _normalize_key(mail)
		await _pull_progress_from_cloud()
		return ""

	var key := _find_local_key_by_email(mail)
	if key.is_empty():
		return "Those threads do not match any known weaver."
	var stored := str(_accounts[key].get("password_hash", ""))
	if stored != _hash_password(password):
		return "Those threads do not match any known weaver."
	_current_key = key
	return ""


## Creates an account, starts a session, and returns "" on success.
func try_register(username: String, email: String, password: String, confirm: String) -> String:
	var display_name := username.strip_edges()
	var mail := email.strip_edges().to_lower()
	var key := _normalize_key(mail)
	if display_name.is_empty() or mail.is_empty() or password.is_empty() or confirm.is_empty():
		return "Every field must be woven. Fill them all."
	if not _looks_like_email(mail):
		return "Enter a valid email address."
	if display_name.length() < 3:
		return "Username must be at least 3 characters."
	if password.length() < MIN_PASSWORD_LENGTH:
		return "A password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if password != confirm:
		return "The two passwords do not match."

	if is_cloud_mode():
		var result: Dictionary = await Supabase.sign_up(mail, password, display_name)
		if not bool(result.get("ok", false)):
			return _friendly_auth_error(str(result.get("error", "")), "Could not create that account.")
		if not Supabase.has_session():
			var login_try: Dictionary = await Supabase.sign_in(mail, password)
			if not bool(login_try.get("ok", false)):
				return "Account created. In Supabase → Authentication → Providers → Email, turn OFF “Confirm email”, then sign in."
		_current_key = key
		_progress_cache.clear()
		_has_seen_intro_cache = false
		await _push_progress_to_cloud()
		return ""

	if _accounts.has(key) or not _find_local_key_by_email(mail).is_empty():
		return "That email is already spoken in the village."
	if _find_local_key_by_username(display_name) != "":
		return "That name is already spoken in the village."
	_accounts[key] = {
		"username": display_name,
		"email": mail,
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
	if "already registered" in lower or "user already" in lower or ("email" in lower and "exist" in lower):
		return "That email is already spoken in the village."
	if "duplicate" in lower and "username" in lower:
		return "That name is already spoken in the village."
	if "password" in lower and ("weak" in lower or "least" in lower):
		return "A password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if raw.strip_edges().is_empty():
		return fallback
	return raw


# --------------------------------------------------------------------------
# Local disk
# --------------------------------------------------------------------------

func _normalize_key(value: String) -> String:
	return value.strip_edges().to_lower()


func _looks_like_email(value: String) -> bool:
	return value.find("@") > 0 and value.find(".") > value.find("@")


func _find_local_key_by_email(mail: String) -> String:
	var wanted := _normalize_key(mail)
	if _accounts.has(wanted) and str(_accounts[wanted].get("email", wanted)) == wanted:
		return wanted
	for key in _accounts.keys():
		var row: Dictionary = _accounts[key]
		if _normalize_key(str(row.get("email", ""))) == wanted:
			return str(key)
	return ""


func _find_local_key_by_username(username: String) -> String:
	var wanted := username.strip_edges().to_lower()
	for key in _accounts.keys():
		var row: Dictionary = _accounts[key]
		if str(row.get("username", "")).strip_edges().to_lower() == wanted:
			return str(key)
	return ""


func _leaderboard_from_cloud(data: Array) -> Array:
	var out: Array = []
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var name := str((entry as Dictionary).get("username", "")).strip_edges()
		if name.is_empty():
			continue
		out.append(_leaderboard_row(name, _as_progress_dict((entry as Dictionary).get("progress", {}))))
	return out


func _leaderboard_from_local() -> Array:
	var out: Array = []
	for key in _accounts.keys():
		var stored: Variant = _accounts[key]
		if typeof(stored) != TYPE_DICTIONARY:
			continue
		var row := stored as Dictionary
		var name := str(row.get("username", key)).strip_edges()
		if name.is_empty():
			name = str(key)
		out.append(_leaderboard_row(name, _as_progress_dict(row.get("progress", {}))))
	return out


func _ensure_you_on_leaderboard(rows: Array) -> void:
	var you := current_username().strip_edges()
	if you.is_empty():
		return
	var wanted := you.to_lower()
	for entry in rows:
		if typeof(entry) == TYPE_DICTIONARY \
				and str((entry as Dictionary).get("username", "")).strip_edges().to_lower() == wanted:
			return
	rows.append(_leaderboard_row(you, _progress_cache.duplicate(true)))


func _leaderboard_row(username: String, progress: Dictionary) -> Dictionary:
	var houses := _progress_array_size(progress.get("completed_houses", []))
	var lore := _progress_array_size(progress.get("lore", []))
	var score := int(progress.get("score", 0))
	return {
		"username": username,
		"score": score,
		"houses": houses,
		"chapter": int(progress.get("current_chapter", 0)),
		"completed": bool(progress.get("game_completed", false)),
		"lore": lore,
		"place": GameState.place_from_progress(progress),
		"rank_title": GameState.rank_for_score(score),
	}


func _as_progress_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	if typeof(value) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(str(value))
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed as Dictionary
	return {}


func _progress_array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()


func _leaderboard_before(a: Variant, b: Variant) -> bool:
	var left: Dictionary = {}
	var right: Dictionary = {}
	if typeof(a) == TYPE_DICTIONARY:
		left = a
	if typeof(b) == TYPE_DICTIONARY:
		right = b
	var left_done := 1 if bool(left.get("completed", false)) else 0
	var right_done := 1 if bool(right.get("completed", false)) else 0
	if left_done != right_done:
		return left_done > right_done
	if int(left.get("houses", 0)) != int(right.get("houses", 0)):
		return int(left.get("houses", 0)) > int(right.get("houses", 0))
	if int(left.get("chapter", 0)) != int(right.get("chapter", 0)):
		return int(left.get("chapter", 0)) > int(right.get("chapter", 0))
	if int(left.get("score", 0)) != int(right.get("score", 0)):
		return int(left.get("score", 0)) > int(right.get("score", 0))
	if int(left.get("lore", 0)) != int(right.get("lore", 0)):
		return int(left.get("lore", 0)) > int(right.get("lore", 0))
	return str(left.get("username", "")).nocasecmp_to(str(right.get("username", ""))) < 0


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
