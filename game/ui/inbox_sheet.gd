class_name InboxSheet
extends Sheet
## The inbox: letters from the troupe (GET /v1/letters), each a short message, some with
## coins inside, four to a page. Claiming asks the server first and pays only on its word:
## the coins go to Game.wallet() and the letter's id is recorded in the profile
## (Game.profile.state("inbox")). The server pays a letter once per account and the record
## pays it once per profile, so a letter never pays twice: not on a second tap, not offline,
## not after a cloud-save conflict, and not when this device's progress moves to a new guest
## account (which the server sees as a new player). Each claim carries a key that stays in
## the record until its answer arrives, so a claim whose answer was lost is asked again with
## that key and its coins aren't lost either (Online.claim_letter). A letter without coins
## is claimed as read. Like the gift, the inbox never opens by itself.

const REFRESH_SECONDS := 600
## Opening the inbox asks again when the copy is older than this: the player is looking.
const OPEN_REFRESH_SECONDS := 60
## After a failed try (offline), the next one may come after a minute.
const RETRY_SECONDS := 60
const PER_PAGE := 4
const ROW_HEIGHT := 52.0
const CACHE_FILE := "user://inbox.json"
## The most coins one letter pays (the server's own limit), in case a reply is garbled.
const MAX_COINS := 5000
## Claims whose answer never came, asked again per refresh.
const SETTLE_AT_ONCE := 5
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

## Where the last copy is kept ("" keeps it in memory only, as the tests do).
static var cache_path := CACHE_FILE
## The last copy: { user, letters, fetched_at (this device's clock), offset (server minus device) }.
static var _copy: Dictionary = {}
static var _copy_loaded := false
## Bumped whenever the letters change, so every refresh() waiting on a fetch can tell.
static var _version := 0
static var _fetching := false
static var _tried_at := -1.0
static var _try_ok := false
## Letters with a claim on its way (id -> true), so a double tap sends one claim.
static var _claiming: Dictionary = {}

var page := 0
var _status_text := ""
var _status_colour := UiTheme.MUTED
## Letters claimed while this sheet is open: id -> coins paid, for the row's "+200".
var _paid_here: Dictionary = {}
var _rows: Control
## The Claim buttons on this page by letter id, to show "Claiming…" and burst from.
var _buttons: Dictionary = {}
var _coins: Label
var _shown_coins := -1
var _press_at := Vector2.ZERO
var _pressing := false
var _last_turn := 0


func _init() -> void:
	title_text = "Inbox"
	panel_size = Vector2(564, 322)


func _ready() -> void:
	super._ready()
	_add_wallet()
	_fetch()


func _fetch() -> void:
	var changed: bool = await InboxSheet.refresh(OPEN_REFRESH_SECONDS)
	if _alive():
		_refresh_wallet()
		if changed or letters().is_empty():
			rebuild()


# --- What the home screen asks -----------------------------------------------------


## Letters still waiting for the player, for the badge on the home screen: coins to claim or
## a message not read yet. Counted from the last copy of this account's letters, less those
## this profile has claimed (also under another account).
static func unclaimed_count() -> int:
	var count := 0
	for letter: Dictionary in letters():
		if not is_claimed(letter):
			count += 1
	return count


## This account's letters from the last copy, newest first: delivered and not expired by the
## server's clock. Empty when the copy belongs to another account (after a sign-in).
static func letters() -> Array:
	_load_copy()
	if str(_copy.get("user", "")) != _user_id():
		return []
	var now := server_now()
	var out: Array = []
	var list: Array = _copy.get("letters", [])
	for letter: Dictionary in list:
		var expires := int(letter["expires_at"])
		if int(letter["created_at"]) <= now and (expires == 0 or expires > now):
			out.append(letter)
	return out


## Whether a letter needs nothing more: the server says this account claimed it, or this
## profile's record has it.
static func is_claimed(letter: Dictionary) -> bool:
	return bool(letter.get("claimed", false)) or claimed_record().has(str(letter.get("id", 0)))


## This profile's claimed letters: id (as text) -> the coins it paid here (0 for a message,
## or when the server said it had been claimed already).
static func claimed_record() -> Dictionary:
	var record: Variant = _state().get("claimed")
	return record if record is Dictionary else {}


## Ask the server for this account's letters when the copy is older than `max_age` seconds
## (a minute after a failed try), then settle claims whose answers never came. Returns true
## when the letters changed while it ran, so the caller can redraw (the home: its badge).
## Offline it keeps the copy; it never throws.
static func refresh(max_age := REFRESH_SECONDS) -> bool:
	_load_copy()
	var before := _version
	while _fetching:
		await (Engine.get_main_loop() as SceneTree).process_frame
	if _due(max_age):
		_fetching = true
		_tried_at = Time.get_ticks_msec() / 1000.0
		var res: Dictionary = await Online.letters()
		_fetching = false
		var data: Variant = res.get("data")
		_try_ok = bool(res.get("ok", false)) and data is Dictionary and (data as Dictionary).get("letters") is Array
		if _try_ok:
			adopt((data as Dictionary)["letters"], _number(data, "time"), _user_id())
			await _settle_pending()
	return _version != before


## Claim a letter: ask the server, then pay its coins once. Returns { ok, coins, error }, where
## coins is what was paid just now: 0 for a message, or when this profile was paid for the
## letter before. A second call while one is on its way returns at once, asking nothing.
static func claim(letter_id: int) -> Dictionary:
	if _claiming.has(letter_id):
		return { "ok": false, "coins": 0, "error": "", "busy": true }
	if claimed_record().has(str(letter_id)):
		_forget_key(letter_id)
		_mark_claimed(letter_id)
		return { "ok": true, "coins": 0, "error": "" }
	_claiming[letter_id] = true
	var key := _key_for(letter_id)
	var res: Dictionary = await Online.claim_letter(letter_id, key)
	_claiming.erase(letter_id)
	var out := settle(letter_id, res)
	if bool(out["ok"]) or int(out.get("status", 0)) in [404, 410]:
		Game.save_profile()
	return out


## Apply the server's answer to a claim. Coins it confirms (a first claim, or the repeat of a
## claim whose answer was lost) are paid unless this profile's record already has the letter;
## then the letter is recorded and its key forgotten. A letter that is gone or expired
## forgets its key too. An offline, refused or rate-limited claim keeps the key for the next
## try. It doesn't save the profile: claim() does (the tests call this alone).
static func settle(letter_id: int, res: Dictionary) -> Dictionary:
	var status := int(res.get("status", 0))
	var data: Variant = res.get("data")
	if not bool(res.get("ok", false)) or not data is Dictionary:
		if status == 404 or status == 410:
			_forget_key(letter_id)
			_drop(letter_id)
		return { "ok": false, "coins": 0, "status": status, "error": _trouble(res) }
	var coins := clampi(roundi(_number(data, "coins")), 0, MAX_COINS)
	var st := _state()
	var record := claimed_record()
	var paid := 0
	if not record.has(str(letter_id)):
		if coins > 0:
			Game.wallet().earn("coins", coins)
			paid = coins
		record[str(letter_id)] = paid
		st["claimed"] = record
	_forget_key(letter_id)
	_mark_claimed(letter_id)
	return { "ok": true, "coins": paid, "status": status, "error": "" }


# --- The copy of the letters --------------------------------------------------------


## Take a fresh list from the server for `user`: keep it as the copy (also on disk unless
## `save` is false) and note how far this device's clock is from the server's. Returns
## whether the letters changed.
static func adopt(list: Array, server_time: float, user: String, save := true) -> bool:
	_copy_loaded = true
	var fresh: Array = []
	for raw: Variant in list:
		var letter := clean(raw)
		if not letter.is_empty():
			fresh.append(letter)
	var now := Time.get_unix_time_from_system()
	var changed := user != str(_copy.get("user", "")) or JSON.stringify(fresh) != JSON.stringify(_copy.get("letters", []))
	_copy = { "user": user, "letters": fresh, "fetched_at": now, "offset": server_time - now if server_time > 0.0 else 0.0 }
	if changed:
		_version += 1
	if save:
		_write_copy()
	return changed


## One letter from the server, checked and trimmed ({} when it isn't usable).
static func clean(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = raw
	var id := int(_number(d, "id"))
	var title := _text(d, "title").strip_edges()
	if id <= 0 or title == "":
		return {}
	return {
		"id": id, "title": title.left(80), "body": _text(d, "body").strip_edges().left(600),
		"coins": clampi(roundi(_number(d, "coins")), 0, MAX_COINS),
		"created_at": int(_number(d, "created_at")), "expires_at": int(_number(d, "expires_at")),
		"claimed": _flag(d, "claimed"), "personal": _flag(d, "personal"),
	}


## The server's clock as this device knows it, so a wrong device clock doesn't expire
## letters early or keep them late.
static func server_now() -> int:
	return int(Time.get_unix_time_from_system() + float(_copy.get("offset", 0.0)))


## When a letter came, in words, and for an unclaimed letter that goes within three days,
## until when it waits. Dates only: nothing here should hurry anyone.
static func when_words(letter: Dictionary) -> String:
	var now := server_now()
	var days := floori((now - int(letter.get("created_at", now))) / 86400.0)
	var came := "Today" if days <= 0 else ("Yesterday" if days == 1 else ("%d days ago" % days if days < 7 else _date(int(letter["created_at"]))))
	var expires := int(letter.get("expires_at", 0))
	if expires > 0 and expires - now < 3 * 86400 and not is_claimed(letter):
		came += "  ·  " + ("until tonight" if expires - now < 86400 else "until " + _date(expires))
	return came


## Claims whose answer never came (their key is still in the record) are asked again, so
## their coins aren't lost: those the server now lists as claimed, and those it no longer
## lists. One still listed as unclaimed keeps its key for the player's next tap.
static func _settle_pending() -> void:
	var listed := {}
	var list: Array = _copy.get("letters", [])
	for letter: Dictionary in list:
		listed[str(letter["id"])] = bool(letter["claimed"])
	var asked := 0
	for id_text: String in _pending().keys():
		if asked >= SETTLE_AT_ONCE:
			break
		if listed.has(id_text) and not listed[id_text]:
			continue
		asked += 1
		await claim(int(id_text))


## The key of this profile's claim of a letter, made (and saved, before anything is sent)
## the first time, so a retry after a lost answer or a restart sends the same one.
static func _key_for(letter_id: int) -> String:
	var st := _state()
	var pending := _pending()
	var key := str(pending.get(str(letter_id), ""))
	if key == "":
		key = Crypto.new().generate_random_bytes(12).hex_encode()
		pending[str(letter_id)] = key
		st["pending"] = pending
		Game.save_profile()
	return key


static func _forget_key(letter_id: int) -> void:
	var pending := _pending()
	if pending.erase(str(letter_id)):
		_state()["pending"] = pending


static func _pending() -> Dictionary:
	var pending: Variant = _state().get("pending")
	return pending if pending is Dictionary else {}


static func _mark_claimed(letter_id: int) -> void:
	var list: Array = _copy.get("letters", [])
	for letter: Dictionary in list:
		if int(letter["id"]) == letter_id and not bool(letter["claimed"]):
			letter["claimed"] = true
			_version += 1
			_write_copy()
			return


static func _drop(letter_id: int) -> void:
	var list: Array = _copy.get("letters", [])
	for i in list.size():
		if int((list[i] as Dictionary)["id"]) == letter_id:
			list.remove_at(i)
			_version += 1
			_write_copy()
			return


static func _trouble(res: Dictionary) -> String:
	match int(res.get("status", 0)):
		0:
			return "You're offline. The letter waits for you."
		401:
			return "Sign in again to claim it."
		404:
			return "That letter isn't in your inbox any more."
		410:
			return "That letter has expired."
		429:
			return "That's a lot of claims at once. Try again in a little while."
	var said := str(res.get("error", ""))
	return said if said != "" else "That didn't work. Try again."


static func _due(max_age: float) -> bool:
	if str(_copy.get("user", "")) != _user_id():
		return true
	var fetched := float(_copy.get("fetched_at", 0.0))
	var now := Time.get_unix_time_from_system()
	if fetched > 0.0 and now >= fetched and now - fetched < max_age:
		return false
	return _try_ok or _tried_at < 0.0 or Time.get_ticks_msec() / 1000.0 - _tried_at >= RETRY_SECONDS


static func _user_id() -> String:
	return str(Online.user.get("id", ""))


static func _load_copy() -> void:
	if _copy_loaded:
		return
	_copy_loaded = true
	if cache_path == "" or not FileAccess.file_exists(cache_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
	if not data is Dictionary or not (data as Dictionary).get("letters") is Array:
		return
	var kept: Array = []
	for raw: Variant in (data as Dictionary)["letters"]:
		var letter := clean(raw)
		if not letter.is_empty():
			kept.append(letter)
	_copy = { "user": _text(data, "user"), "letters": kept, "fetched_at": _number(data, "fetched_at"), "offset": _number(data, "offset") }
	_version += 1


static func _write_copy() -> void:
	if cache_path == "":
		return
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_copy))


static func _state() -> Dictionary:
	return Game.profile.state("inbox")


static func _date(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%d %s" % [int(d["day"]), MONTHS[clampi(int(d["month"]) - 1, 0, 11)]]


static func _number(d: Variant, key: String) -> float:
	var v: Variant = (d as Dictionary).get(key) if d is Dictionary else null
	return float(v) if v is int or v is float else 0.0


static func _flag(d: Dictionary, key: String) -> bool:
	var v: Variant = d.get(key)
	return v is bool and v


static func _text(d: Variant, key: String) -> String:
	var v: Variant = (d as Dictionary).get(key) if d is Dictionary else null
	return v if v is String else ""


# --- The sheet -----------------------------------------------------------------------


func _build() -> void:
	var list := letters()
	if list.is_empty():
		_build_empty()
		_build_footer(1)
		return
	var pages := maxi(1, ceili(list.size() / float(PER_PAGE)))
	page = clampi(page, 0, pages - 1)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(page * PER_PAGE, mini(list.size(), (page + 1) * PER_PAGE)):
		rows.add_child(_row(list[i]))
	body.add_child(rows)
	_rows = rows
	if not Settings.reduce_motion:
		rows.modulate.a = 0.0
		rows.create_tween().tween_property(rows, "modulate:a", 1.0, 0.16)
	_build_footer(pages)


## One letter: an envelope (gold with coins inside, blue for a message, open once claimed),
## its title and two lines, when it came, and its coins with a Claim button, or a tick.
func _row(letter: Dictionary) -> Control:
	var id := int(letter["id"])
	var coins := int(letter["coins"])
	var done := is_claimed(letter)
	var panel := PanelContainer.new()
	var edge := Color(1, 1, 1, 0.1) if done else (Color(UiTheme.GOLD, 0.55) if coins > 0 else UiTheme.TONAL_EDGE)
	var box := UiTheme.box(Color(1, 1, 1, 0.045 if done else 0.1), edge, 14)
	box.content_margin_left = 8
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var badge := CenterContainer.new()
	badge.add_child(Envelope.new("open" if done else ("coins" if coins > 0 else "message"), 36.0))
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var title := UiTheme.label(str(letter["title"]), 11, UiTheme.TEXT)
	title.add_theme_font_override("font", UiTheme.bold)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if bool(letter["personal"]):
		top.add_child(_tag("For you"))
	var stamp := UiTheme.label(when_words(letter), 8, UiTheme.MUTED)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(stamp)
	text.add_child(top)
	var blurb := UiTheme.label(str(letter["body"]), 9, UiTheme.MUTED if done else Color(UiTheme.TEXT, 0.88))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blurb.custom_minimum_size = Vector2(250, 0)
	text.add_child(blurb)
	row.add_child(text)
	var side := HBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if done:
		var paid := int(_paid_here.get(str(id), 0))
		side.add_child(_done_pill(("+%s" % UiTheme.number(paid)) if paid > 0 else ("Claimed" if coins > 0 else "Read")))
	else:
		if coins > 0:
			var amount := UiTheme.currency("coins", coins, 11)
			amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			(amount.get_child(1) as Label).text = "+" + UiTheme.number(coins)
			side.add_child(amount)
		var busy := _claiming.has(id)
		var b := UiTheme.button("Claiming…" if busy else ("Claim" if coins > 0 else "Got it"), _claim.bind(id), 10, UiTheme.GOLD if coins > 0 else UiTheme.PANEL_LIGHT)
		_buttons[id] = b
		b.custom_minimum_size = Vector2(72, 24)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = busy
		side.add_child(b)
	row.add_child(side)
	if done:
		panel.modulate = Color(1, 1, 1, 0.78)
	return panel


func _build_empty() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	var art := CenterContainer.new()
	art.add_child(Envelope.new("open", 64.0))
	col.add_child(art)
	var heading_text := "No letters right now"
	var more := "Now and then the troupe sends a letter, sometimes with coins inside. It waits here until you open it."
	# The sheet asks for the letters as it opens (_fetch), so a due fetch is as good as started.
	if _fetching or (Online.signed_in() and _due(OPEN_REFRESH_SECONDS)):
		heading_text = "Fetching your letters…"
		more = ""
	elif not _try_ok and _tried_at >= 0.0:
		heading_text = "Letters arrive when you're online"
		more = "Your game and your coins are kept on this device in the meantime."
	var title := UiTheme.title(heading_text, 14, UiTheme.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if more != "":
		var l := UiTheme.label(more, 9, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(panel_size.x - 80.0, 0)
		col.add_child(l)
	body.add_child(col)


func _build_footer(pages: int) -> void:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	var status := UiTheme.label(_status_line(), 9, _status_colour if _status_text != "" else UiTheme.MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size = Vector2(0, 22)
	foot.add_child(status)
	if pages > 1:
		var back := UiTheme.icon_button("back", _turn.bind(-1), 22.0)
		back.modulate.a = 1.0 if page > 0 else 0.25
		foot.add_child(back)
		var dots := Control.new()
		dots.custom_minimum_size = Vector2(pages * 12.0 + 8.0, 22)
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.draw.connect(_draw_dots.bind(dots, pages))
		foot.add_child(dots)
		var next := UiTheme.icon_button("forward", _turn.bind(1), 22.0)
		next.modulate.a = 1.0 if page < pages - 1 else 0.25
		foot.add_child(next)
	body.add_child(foot)


## What just happened, or a word about the letters when nothing has.
func _status_line() -> String:
	if _status_text != "":
		return _status_text
	if not _try_ok and _tried_at >= 0.0 and not letters().is_empty():
		return "You're offline: these are the letters from your last visit."
	var waiting := unclaimed_count()
	if letters().is_empty():
		return ""
	return "You're all caught up." if waiting == 0 else "%d letter%s waiting for you." % [waiting, "" if waiting == 1 else "s"]


func _claim(letter_id: int) -> void:
	if _claiming.has(letter_id):
		return
	Feel.play("click")
	var at := Vector2.ZERO
	var button: Variant = _buttons.get(letter_id)
	if button is Button and is_instance_valid(button):
		at = (button as Button).get_global_rect().get_center()
		(button as Button).disabled = true
		(button as Button).text = "Claiming…"
	var result: Dictionary = await InboxSheet.claim(letter_id)
	if not _alive() or bool(result.get("busy", false)):
		return
	if bool(result["ok"]):
		var coins := int(result["coins"])
		_paid_here[str(letter_id)] = coins
		if coins > 0:
			Feel.play("cash")
			Feel.buzz(30)
			if at != Vector2.ZERO:
				Feel.burst(at, UiTheme.GOLD, 24)
			_set_status("Added %s coins." % UiTheme.number(coins), UiTheme.GOOD)
		else:
			Feel.play("select")
			var letter := _find(letter_id)
			_set_status("Claimed already, so nothing more to add." if int(letter.get("coins", 0)) > 0 else "Thanks for reading.", UiTheme.MUTED)
		_refresh_wallet()
	else:
		Feel.play("error")
		Feel.buzz(20)
		_set_status(str(result["error"]), UiTheme.MULT.lightened(0.35))
	rebuild()


func _find(letter_id: int) -> Dictionary:
	var list: Array = _copy.get("letters", [])
	for letter: Dictionary in list:
		if int(letter["id"]) == letter_id:
			return letter
	return {}


func _set_status(text: String, colour: Color) -> void:
	_status_text = text
	_status_colour = colour


func _turn(step: int) -> void:
	var pages := maxi(1, ceili(letters().size() / float(PER_PAGE)))
	var to := clampi(page + step, 0, pages - 1)
	if to == page:
		return
	Feel.play("click")
	Feel.buzz(6)
	page = to
	_last_turn = Time.get_ticks_msec()
	_status_text = ""
	rebuild()


## Swipes (either way) and scrolls turn pages, as in the Jester collection. This looks at
## input before the rows do without taking it, so a tap still reaches a Claim button.
func _input(event: InputEvent) -> void:
	if _rows == null or not is_instance_valid(_rows) or not is_inside_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			if Time.get_ticks_msec() - _last_turn > 380 and _rows.get_global_rect().has_point(get_global_mouse_position()):
				_turn(1 if mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] else -1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var at := get_global_mouse_position()
			if mb.pressed:
				_press_at = at
				_pressing = _rows.get_global_rect().grow(10.0).has_point(at)
			elif _pressing:
				_pressing = false
				var moved := at - _press_at
				if moved.length() > 40.0:
					var sideways := absf(moved.x) > absf(moved.y)
					_turn(1 if (moved.x < 0.0 if sideways else moved.y < 0.0) else -1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP]:
			_turn(1 if event.keycode in [KEY_RIGHT, KEY_DOWN] else -1)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _draw_dots(dots: Control, pages: int) -> void:
	var x := 4.0
	var y := dots.size.y / 2.0
	for i in pages:
		if i == page:
			dots.draw_style_box(UiTheme.box(UiTheme.TEXT, Color(0, 0, 0, 0), 99), Rect2(x - 1.0, y - 3.0, 14.0, 6.0))
			x += 18.0
		else:
			dots.draw_circle(Vector2(x + 3.0, y), 3.0, Color(1, 1, 1, 0.3), true, -1.0, true)
			x += 12.0


## A green pill with a tick: claimed (with the coins it just paid) or read.
func _done_pill(text: String) -> Control:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(UiTheme.GOOD, 0.22), Color(UiTheme.GOOD, 0.6), 99)
	box.content_margin_left = 8
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var tick := ShopSheet.Check.new(12.0)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
	var l := UiTheme.label(text, 9, UiTheme.TEXT)
	l.add_theme_font_override("font", UiTheme.bold)
	row.add_child(l)
	pill.add_child(row)
	return pill


func _tag(text: String) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(UiTheme.POINTS, 0.35), Color(UiTheme.POINTS, 0.7), 99)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiTheme.label(text, 8, UiTheme.TEXT)
	l.add_theme_font_override("font", UiTheme.bold)
	pill.add_child(l)
	return pill


# --- The coins in the header ---------------------------------------------------------


func _add_wallet() -> void:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(0, 0, 0, 0.32), UiTheme.TONAL_EDGE, 99)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coins := UiTheme.currency("coins", 0, 11)
	pill.add_child(coins)
	_coins = coins.get_child(1) as Label
	var top := heading.get_parent()
	top.add_child(pill)
	top.move_child(pill, heading.get_index() + 1)
	var space := Control.new()
	space.custom_minimum_size = Vector2(4, 0)
	top.add_child(space)
	top.move_child(space, pill.get_index() + 1)
	_refresh_wallet()


## Show the coins, counting up to a new balance (at once with Reduce motion).
func _refresh_wallet() -> void:
	if _coins == null or not is_instance_valid(_coins):
		return
	var to := Game.wallet().coins
	if _shown_coins < 0 or _shown_coins == to or Settings.reduce_motion:
		_coins.text = UiTheme.number(to)
	else:
		var label := _coins
		var roll := label.create_tween()
		roll.tween_method(func(v: float) -> void: label.text = UiTheme.number(roundi(v)), float(_shown_coins), float(to), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shown_coins = to


func _alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Like Sheet.rebuild, but the old content leaves the tree at once, so it never counts toward
## the panel's size while the sheet slides in (see ShopSheet.rebuild).
func rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_rows = null
	_buttons.clear()
	_build()
	heading.text = title_text


## A letter's badge: a closed envelope on a gold disc when coins are inside, on a blue one for
## a message, and an open envelope on glass once it has been claimed or read.
class Envelope extends Control:
	var look := "coins"

	func _init(kind: String, diameter: float) -> void:
		look = kind
		custom_minimum_size = Vector2(diameter, diameter)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		var fill := UiTheme.GOLD if look == "coins" else (UiTheme.POINTS if look == "message" else Color(1, 1, 1, 0.12))
		var ink := UiTheme.INK if look == "coins" else UiTheme.TEXT
		draw_circle(c + Vector2(0, r * 0.07), r, Color(0, 0, 0, 0.22), true, -1.0, true)
		draw_circle(c, r, fill, true, -1.0, true)
		if look == "open":
			draw_arc(c, r - 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 1.0, true)
		var w := r * 1.12
		var h := w * 0.7
		var stroke := maxf(1.2, r * 0.085)
		var env := Rect2(c - Vector2(w / 2.0, h / 2.0 - r * 0.08), Vector2(w, h))
		if look == "open":
			# The letter peeks out of the open envelope, its flap folded up behind it.
			var flap := PackedVector2Array([env.position, Vector2(c.x, env.position.y - h * 0.48), Vector2(env.end.x, env.position.y)])
			draw_polyline(flap, Color(ink, 0.6), stroke, true)
			var sheet := Rect2(env.position + Vector2(w * 0.14, -h * 0.3), Vector2(w * 0.72, h * 0.7))
			draw_colored_polygon(Paint.round_rect(sheet, r * 0.06, 3), Color(1, 1, 1, 0.9))
			for k: int in 2:
				var y := sheet.position.y + sheet.size.y * (0.3 + k * 0.25)
				draw_line(Vector2(sheet.position.x + sheet.size.x * 0.18, y), Vector2(sheet.end.x - sheet.size.x * 0.18, y), Color(UiTheme.INK, 0.35), maxf(1.0, stroke * 0.7), true)
		var body_shape := Paint.round_rect(env, r * 0.1, 4)
		if look == "open":
			draw_colored_polygon(body_shape, Color(0.2, 0.14, 0.32, 1.0))
		draw_polyline(Paint.closed(body_shape), ink, stroke, true)
		var fold := env.position.y + (h * 0.02 if look == "open" else 0.0)
		var tip := Vector2(c.x, env.position.y + h * (0.22 if look == "open" else 0.56))
		draw_polyline(PackedVector2Array([Vector2(env.position.x + stroke * 0.4, fold + stroke * 0.4), tip, Vector2(env.end.x - stroke * 0.4, fold + stroke * 0.4)]), ink, stroke, true)
