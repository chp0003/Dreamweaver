extends Node
## HTTP client for Supabase Auth + PostgREST.
##
## Async methods return:
##   { "ok": bool, "status": int, "data": Variant, "error": String }

const Config := preload("res://scripts/systems/supabase_config.gd")
const SESSION_PATH := "user://supabase_session.json"

var access_token := ""
var refresh_token := ""
var user_id := ""
var user_email := ""
var username := ""


func _ready() -> void:
	_load_session()


func has_session() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	user_email = ""
	username = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)


# --------------------------------------------------------------------------
# Auth
# --------------------------------------------------------------------------

func sign_up(username_value: String, password: String) -> Dictionary:
	var email := Config.email_for_username(username_value)
	var body := {
		"email": email,
		"password": password,
		"data": {"username": username_value.strip_edges()},
	}
	var result := await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", body, false)
	if not result.get("ok", false):
		return result
	_apply_auth_payload(result.get("data", {}), username_value.strip_edges())
	if has_session():
		await upsert_profile(username_value.strip_edges())
	return result


func sign_in(username_value: String, password: String) -> Dictionary:
	var email := Config.email_for_username(username_value)
	var body := {
		"email": email,
		"password": password,
	}
	var result := await _request(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=password",
		body,
		false
	)
	if not result.get("ok", false):
		return result
	_apply_auth_payload(result.get("data", {}), username_value.strip_edges())
	if has_session():
		await upsert_profile(username_value.strip_edges())
	return result


func sign_out() -> void:
	if has_session():
		await _request(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)
	clear_session()


func update_password(new_password: String) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_PUT,
		"/auth/v1/user",
		{"password": new_password},
		true
	)


## Soft-delete: wipe cloud save + profile, then sign out.
## Deleting the Auth user itself needs the service role or an Edge Function.
func soft_delete_account() -> Dictionary:
	if not has_session():
		return _fail("Not signed in.")
	var wipe_save := await delete_save()
	if not wipe_save.get("ok", false):
		return wipe_save
	var wipe_profile := await _request(
		HTTPClient.METHOD_DELETE,
		"/rest/v1/profiles?id=eq.%s" % user_id,
		null,
		true
	)
	if not wipe_profile.get("ok", false):
		return wipe_profile
	await sign_out()
	return {"ok": true, "status": 200, "data": {}, "error": ""}


# --------------------------------------------------------------------------
# Profiles / saves
# --------------------------------------------------------------------------

func upsert_profile(username_value: String) -> Dictionary:
	if not has_session():
		return _fail("Not signed in.")
	var row := {
		"id": user_id,
		"username": username_value.strip_edges(),
	}
	return await _request(
		HTTPClient.METHOD_POST,
		"/rest/v1/profiles?on_conflict=id",
		row,
		true,
		{"Prefer": "resolution=merge-duplicates,return=minimal"}
	)


func fetch_save() -> Dictionary:
	if not has_session():
		return _fail("Not signed in.")
	return await _request(
		HTTPClient.METHOD_GET,
		"/rest/v1/player_saves?user_id=eq.%s&select=progress,has_seen_intro" % user_id,
		null,
		true
	)


func upsert_save(progress: Dictionary, has_seen_intro: bool) -> Dictionary:
	if not has_session():
		return _fail("Not signed in.")
	var row := {
		"user_id": user_id,
		"progress": progress,
		"has_seen_intro": has_seen_intro,
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	return await _request(
		HTTPClient.METHOD_POST,
		"/rest/v1/player_saves?on_conflict=user_id",
		row,
		true,
		{"Prefer": "resolution=merge-duplicates,return=minimal"}
	)


func delete_save() -> Dictionary:
	if not has_session():
		return _fail("Not signed in.")
	return await _request(
		HTTPClient.METHOD_DELETE,
		"/rest/v1/player_saves?user_id=eq.%s" % user_id,
		null,
		true
	)


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------

func _request(
		method: int,
		path: String,
		body: Variant,
		auth: bool,
		extra_headers: Dictionary = {}
	) -> Dictionary:
	if not Config.is_configured():
		return _fail("Supabase is not configured. See docs/SUPABASE_SETUP.md")

	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)

	var bearer := Config.ANON_KEY
	if auth:
		if access_token.is_empty():
			http.queue_free()
			return _fail("Missing auth token.")
		bearer = access_token

	var headers: PackedStringArray = [
		"apikey: %s" % Config.ANON_KEY,
		"Authorization: Bearer %s" % bearer,
		"Content-Type: application/json",
		"Accept: application/json",
	]
	for key in extra_headers.keys():
		headers.append("%s: %s" % [str(key), str(extra_headers[key])])

	var payload := ""
	if body != null:
		payload = JSON.stringify(body)

	var url := "%s%s" % [Config.URL.rstrip("/"), path]
	var err := http.request(url, headers, method, payload)
	if err != OK:
		http.queue_free()
		return _fail("Could not reach Supabase (%s)." % error_string(err))

	var args: Array = await http.request_completed
	http.queue_free()

	var result_code: int = args[0]
	var response_code: int = args[1]
	var response_body: PackedByteArray = args[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _fail("Network error talking to Supabase.", response_code)

	var text := response_body.get_string_from_utf8()
	var parsed: Variant = {}
	if not text.is_empty():
		parsed = JSON.parse_string(text)
		if parsed == null:
			parsed = {"raw": text}

	var ok := response_code >= 200 and response_code < 300
	var error_text := ""
	if not ok:
		error_text = _extract_error(parsed, response_code)
	return {
		"ok": ok,
		"status": response_code,
		"data": parsed,
		"error": error_text,
	}


func _apply_auth_payload(data: Variant, fallback_username: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var dict := data as Dictionary
	access_token = str(dict.get("access_token", access_token))
	refresh_token = str(dict.get("refresh_token", refresh_token))

	var user: Variant = dict.get("user", {})
	# Some signup responses put the user object at the top level.
	if typeof(user) != TYPE_DICTIONARY and dict.has("id"):
		user = dict
	if typeof(user) == TYPE_DICTIONARY:
		var user_dict := user as Dictionary
		user_id = str(user_dict.get("id", ""))
		user_email = str(user_dict.get("email", ""))
		var meta: Variant = user_dict.get("user_metadata", {})
		if typeof(meta) == TYPE_DICTIONARY:
			username = str((meta as Dictionary).get("username", fallback_username))
		else:
			username = fallback_username
	elif not fallback_username.is_empty():
		username = fallback_username
	_save_session()


func _save_session() -> void:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"access_token": access_token,
		"refresh_token": refresh_token,
		"user_id": user_id,
		"user_email": user_email,
		"username": username,
	}, "\t"))


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data := parsed as Dictionary
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	user_id = str(data.get("user_id", ""))
	user_email = str(data.get("user_email", ""))
	username = str(data.get("username", ""))


func _extract_error(parsed: Variant, status: int) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		var dict := parsed as Dictionary
		var msg := str(dict.get("msg", dict.get("error_description", dict.get("message", ""))))
		var err := str(dict.get("error", ""))
		if not msg.is_empty():
			return msg
		if not err.is_empty():
			return err
	return "Supabase request failed (%d)." % status


func _fail(message: String, status: int = 0) -> Dictionary:
	return {"ok": false, "status": status, "data": {}, "error": message}
