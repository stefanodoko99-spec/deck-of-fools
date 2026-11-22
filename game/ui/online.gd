extends Node










signal account_changed


signal conflict(cloud: Dictionary)

const API_SETTING := "deck_of_fools/api_url"
const DEFAULT_API := "http://localhost:8787"

var api_url := DEFAULT_API

var account_path := "user://account.json"
var token := ""

var user: Dictionary = {}

var save_version := 0
var dirty := false

var online := false

var pending_runs: Array = []
var syncing := false


var inert := false
var _push_timer: Timer


func _ready() -> void:
	api_url = str(ProjectSettings.get_setting(API_SETTING, DEFAULT_API))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--api="):
			api_url = arg.get_slice("=", 1)
		elif arg.begins_with("--account-file="):
			account_path = arg.get_slice("=", 1)
	inert = DisplayServer.get_name() == "headless" and not OS.get_cmdline_user_args().has("--online")
	if inert:
		return
	_load()
	_push_timer = Timer.new()
	_push_timer.one_shot = true
	_push_timer.wait_time = 4.0
	_push_timer.timeout.connect(sync_save)
	add_child(_push_timer)




func start() -> void:
	if token == "":
		await _guest()
	else:
		await refresh_user()
	if token != "":
		await _send_pending_runs()
		await sync_save()


func signed_in() -> bool:
	return token != ""


func is_guest() -> bool:
	return bool(user.get("guest", true))





func native_signin_available(_provider: String) -> bool:
	return false



func native_identity_token(_provider: String) -> String:
	return ""





func call_api(method: int, path: String, body: Variant = null) -> Dictionary:
	# Headless runs (check.sh, tests, exports) never talk to the server: they used to
	# create a guest account on the live API every time.
	if inert:
		return { "ok": false, "error": "offline (headless run)", "status": 0 }
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var sent := http.request(api_url + path, headers, method, "" if body == null else JSON.stringify(body))
	if sent != OK:
		http.queue_free()
		online = false
		return { "ok": false, "status": 0, "data": {}, "error": "Can't reach the server right now." }
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		online = false
		return { "ok": false, "status": 0, "data": {}, "error": "You're offline. Your progress is kept on this device." }
	online = true
	var status := int(response[1])
	var text := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else {}
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if status == 401 and token != "" and not path.begins_with("/v1/auth/"):
		_signed_out()
	return { "ok": status >= 200 and status < 300, "status": status, "data": data, "error": str(data.get("error", "")) if status >= 300 else "" }




func _guest() -> bool:
	var res := await call_api(HTTPClient.METHOD_POST, "/v1/auth/guest")
	if res["ok"]:
		_signed_in(res["data"])
	return res["ok"]


func refresh_user() -> bool:
	var res := await call_api(HTTPClient.METHOD_GET, "/v1/me")
	if res["ok"]:
		user = res["data"]["user"]
		_save()
		account_changed.emit()
	return res["ok"]



func signup(email: String, password: String, name: String) -> Dictionary:
	var res := await call_api(HTTPClient.METHOD_POST, "/v1/auth/signup", { "email": email, "password": password, "name": name })
	if res["ok"]:
		_signed_in(res["data"])
		await sync_save()
	return res


func login(email: String, password: String) -> Dictionary:
	var res := await call_api(HTTPClient.METHOD_POST, "/v1/auth/login", { "email": email, "password": password })
	if res["ok"]:

		save_version = 0
		_signed_in(res["data"])
		await sync_save()
	return res



func signin_with(provider: String, id_token: String, name := "") -> Dictionary:
	var res := await call_api(HTTPClient.METHOD_POST, "/v1/auth/" + provider, { "id_token": id_token, "name": name })
	if res["ok"]:
		if not bool(res["data"].get("linked", false)):
			save_version = 0
		_signed_in(res["data"])
		await sync_save()
	return res


func forgot(email: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, "/v1/auth/forgot", { "email": email })


func resend_verification() -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, "/v1/auth/resend-verification")


func rename(name: String) -> Dictionary:
	var res := await call_api(HTTPClient.METHOD_PATCH, "/v1/me", { "name": name })
	if res["ok"]:
		user = res["data"]["user"]
		_save()
		account_changed.emit()
	return res



func logout() -> void:
	await call_api(HTTPClient.METHOD_POST, "/v1/auth/logout")
	_signed_out()
	await _guest()
	dirty = true
	await sync_save()



func delete_account() -> Dictionary:
	var res := await call_api(HTTPClient.METHOD_DELETE, "/v1/me")
	if res["ok"]:
		_signed_out()
		await _guest()
	return res


func stats() -> Dictionary:
	return await call_api(HTTPClient.METHOD_GET, "/v1/me/stats")


func _signed_in(data: Dictionary) -> void:
	token = str(data["token"])
	user = data["user"]
	_save()
	account_changed.emit()


func _signed_out() -> void:
	token = ""
	user = {}
	save_version = 0
	_save()
	account_changed.emit()






static func decide(cloud_version: int, seen_version: int, changed: bool) -> String:
	if cloud_version == seen_version:
		return "push" if changed else "none"
	if cloud_version == 0:
		return "push"
	return "ask" if changed else "pull"



func mark_dirty() -> void:
	if inert:
		return
	dirty = true
	_save()
	if token != "" and _push_timer != null and is_inside_tree():
		_push_timer.start()


func sync_save() -> void:
	if token == "" or syncing:
		return
	syncing = true
	var res := await call_api(HTTPClient.METHOD_GET, "/v1/save")
	if res["ok"]:
		var cloud: Dictionary = res["data"]
		match decide(int(cloud["version"]), save_version, dirty):
			"push":
				await _push(false)
			"pull":
				_adopt(cloud)
			"ask":
				conflict.emit(cloud)
	syncing = false



func resolve_conflict(keep: String, cloud: Dictionary) -> void:
	if keep == "cloud":
		_adopt(cloud)
	else:
		save_version = int(cloud["version"])
		await _push(true)


func _push(force: bool) -> void:
	var res := await call_api(HTTPClient.METHOD_PUT, "/v1/save", { "base_version": save_version, "data": Game.cloud_data(), "device": OS.get_name(), "force": force })
	if res["ok"]:
		save_version = int(res["data"]["version"])
		dirty = false
		_save()
	elif res["status"] == 409:
		conflict.emit(res["data"])


func _adopt(cloud: Dictionary) -> void:
	if cloud.get("data") is Dictionary:
		Game.adopt_cloud(cloud["data"])
	save_version = int(cloud["version"])
	dirty = false
	_save()





func submit_run(run: RunState, meta: Dictionary) -> void:
	if inert or bool(meta.get("practice", false)):
		return
	var entry := {
		"seed": run.seed_text, "deck": run.deck_id, "stake": run.stake, "challenge": run.challenge,
		"won": run.won, "town": run.town, "best_hand": float(run.counters.get("best_hand", 0.0)),
		"jesters": run.zanni.map(func(z: ItemCard) -> String: return z.def_id),
		"actions": run.action_log,
	}
	if meta.has("daily_date"):
		entry["daily_date"] = meta["daily_date"]
	pending_runs.append(entry)
	_save()
	await _send_pending_runs()


func _send_pending_runs() -> void:
	while token != "" and not pending_runs.is_empty():
		var res := await call_api(HTTPClient.METHOD_POST, "/v1/runs", pending_runs[0])
		if res["status"] == 0 or res["status"] >= 500 or res["status"] == 429:
			return

		pending_runs.pop_front()
		_save()



static func daily_setup(date := "") -> Dictionary:
	if date == "":
		date = Time.get_date_string_from_system(true)
	var parts := date.split("-")
	var day := int(Time.get_unix_time_from_datetime_dict({ "year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]) }) / 86400)
	var decks: Array = ContentDB.pool("deck").map(func(d: ContentDef) -> String: return d.id)
	return { "date": date, "seed": "DAY" + date.replace("-", ""), "deck": decks[day % decks.size()], "stake": 1 }



func daily() -> Dictionary:
	return await call_api(HTTPClient.METHOD_GET, "/v1/daily")


func start_daily() -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, "/v1/daily/start")



func leaderboard(kind: String, stake := 1) -> Dictionary:
	var path := "/v1/leaderboards/" + kind + ("?stake=%d" % stake if kind == "town" else "")
	return await call_api(HTTPClient.METHOD_GET, path)


## The Playbill's items: news, What's new and banners (GET /v1/news, newest first). Public,
## so it works without an account. Offline and in headless runs it fails like every call
## here (ok false, status 0), and PlaybillSheet keeps showing its last copy.
func news() -> Dictionary:
	return await call_api(HTTPClient.METHOD_GET, "/v1/news")


## The inbox: letters for this player and for everyone, each saying whether this account
## claimed it (GET /v1/letters). Without a session there is nothing to ask for, so it answers
## like a call that couldn't be made instead of spending a request on a refusal.
func letters() -> Dictionary:
	if token == "":
		return { "ok": false, "status": 0, "data": {}, "error": "Your letters arrive when you're online." }
	return await call_api(HTTPClient.METHOD_GET, "/v1/letters")


## Claim a letter (POST /v1/letters/<id>/claim): the first claim answers { coins }, later ones
## { coins: 0, already: true }. `key` names this claim; sending it again after an answer was
## lost gets { coins, repeat: true }, so the coins aren't lost on the way. Only InboxSheet.claim
## should call this: it pays the coins, once per profile.
func claim_letter(id: int, key := "") -> Dictionary:
	if id <= 0:
		return { "ok": false, "status": 0, "data": {}, "error": "That isn't a letter." }
	if token == "":
		return { "ok": false, "status": 0, "data": {}, "error": "Claiming needs a connection." }
	return await call_api(HTTPClient.METHOD_POST, "/v1/letters/%d/claim" % id, { "key": key } if key != "" else {})




func _load() -> void:
	if not FileAccess.file_exists(account_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(account_path))
	if data is Dictionary:
		token = str(data.get("token", ""))
		user = data.get("user", {})
		save_version = int(data.get("save_version", 0))
		dirty = bool(data.get("dirty", false))
		pending_runs = data.get("pending_runs", [])


func _save() -> void:
	if inert:
		return
	var f := FileAccess.open(account_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({ "token": token, "user": user, "save_version": save_version, "dirty": dirty, "pending_runs": pending_runs }))
