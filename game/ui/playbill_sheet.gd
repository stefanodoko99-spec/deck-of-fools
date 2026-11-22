class_name PlaybillSheet
extends Sheet
## The Playbill: news cards from the server (GET /v1/news), newest first, three to a page.
## Each card has a title, two lines and at most one button: open the Shop, the Jester
## collection, today's daily run or a web page. Tapping a card shows all of its words.
## Kinds: "news" (only here), "banner" (also on the home screen, see banners()) and
## "whats_new" (also shown once after an update, see should_show_whats_new()). Nothing here
## opens by itself: the home decides when, and never right after a loss.
##
## refresh() asks the server at most every 10 minutes and keeps the last copy on the device,
## so the cards, the banners and the unread dot work offline. The getters the home polls
## (banners(), unread_count(), should_show_whats_new()) start that refresh in the background
## whenever it is due, so the home stays current just by asking. What the player has read
## lives in the profile (Game.profile.state("playbill")), so it follows them to their other
## devices.

## A card's button needs the screen behind this sheet: "daily" (start or show today's daily
## run), which only the home can do. The Shop, the collection and web links open from here.
signal action_chosen(action: String)

const KIND_NAMES := { "news": "News", "whats_new": "What's new", "banner": "Event" }
const ACTION_WORDS := { "shop": "Open the Shop", "collection": "See the Jesters", "daily": "Play the daily" }
const REFRESH_SECONDS := 600
## After a failed try (offline), the next one may come after a minute rather than ten.
const RETRY_SECONDS := 60
const MAX_BANNERS := 3
const PER_PAGE := 3
const CARD := Vector2(172, 220)
const CACHE_FILE := "user://playbill.json"
## Colour blocks, top-left to bottom-right, from the Shop's palette.
const PALETTE := {
	"gold": [Color("ffd66b"), Color("f0a020")],
	"orange": [Color("f7a93b"), Color("c25a12")],
	"red": [Color("ff5a6e"), Color("a3152f")],
	"pink": [Color("ff5a8a"), Color("e0562a")],
	"purple": [Color("a26bff"), Color("5a2fc1")],
	"blue": [Color("5b9dff"), Color("2f3fb8")],
	"teal": [Color("2fc6b4"), Color("10708a")],
	"green": [Color("5fd08a"), Color("1d7a4f")],
}
const KIND_COLOURS := { "news": "blue", "whats_new": "purple", "banner": "pink" }
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const DAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

## Where the last copy is kept ("" keeps it in memory only, as the tests do).
static var cache_path := CACHE_FILE
## Seconds this device's local time is ahead of UTC, or null to ask the system (the tests
## fix it). Dates are always shown in the player's own time zone.
static var zone_offset: Variant = null
## The last copy: { items, fetched_at (this device's clock), offset (server minus device seconds) }.
static var _copy: Dictionary = {}
static var _copy_loaded := false
## Bumped whenever the items change, so every refresh() waiting on a fetch can tell.
static var _version := 0
static var _fetching := false
static var _tried_at := -1.0
static var _try_ok := false

var page := 0
## The id of the one card shown in full, or 0 for the pages of cards.
var _focus := 0
## Cards that were unread when the sheet opened: they keep their "New" tag while it's open.
var _fresh: Dictionary = {}
var _status_text := ""
var _cards: Control
var _card_down := Vector2.ZERO
var _press_at := Vector2.ZERO
var _pressing := false
var _last_turn := 0


## `start`: "" for the cards, "whats_new" for the newest What's new note in full (what the
## home opens when should_show_whats_new() is true), or an item's id for that card in full.
func _init(start := "") -> void:
	title_text = "Playbill"
	panel_size = Vector2(564, 322)
	if start == "whats_new":
		var note := whats_new_item()
		if note.is_empty():
			note = _newest_note()
		_focus = int(note.get("id", 0))
	elif start.is_valid_int():
		_focus = int(start)


func _ready() -> void:
	_fresh = _unread_ids()
	super._ready()
	_mark_seen()
	_fetch()


func _fetch() -> void:
	var empty := items().is_empty()
	var changed: bool = await PlaybillSheet.refresh()
	if not _alive():
		return
	if changed:
		_fresh.merge(_unread_ids())
		_mark_seen()
	if changed or empty:
		rebuild()


# --- What the home screen asks -----------------------------------------------------


## News and What's new items not read yet, for a dot on the home screen. Banners don't
## count: they are on the home screen already.
static func unread_count() -> int:
	_refresh_in_background()
	var read := _read_marks()
	var count := 0
	for item: Dictionary in items():
		if item["kind"] != "banner" and not read.has(str(item["id"])):
			count += 1
	return count


## Up to three event banners for the home screen, newest first, each { id, title, text,
## colour, ends_at, action }. `colour` is the server's palette name or "#rrggbb" ("" for the
## default; colours_for() turns it into the two colours of a card), `ends_at` is when it ends
## by this device's clock (unix seconds, 0 for no end) and `action` is "", "shop",
## "collection", "daily" or a web link (perform() does all but "daily").
static func banners() -> Array:
	_refresh_in_background()
	var out: Array = []
	var offset := float(_copy.get("offset", 0.0))
	for item: Dictionary in items():
		if item["kind"] != "banner":
			continue
		var ends := int(item["ends_at"])
		out.append({ "id": item["id"], "title": item["title"], "text": item["body"], "colour": item["colour"],
			"ends_at": roundi(ends - offset) if ends > 0 else 0, "action": item["action"] })
		if out.size() >= MAX_BANNERS:
			break
	return out


## True when there is a What's new note this player hasn't been shown: once after an update
## brings one, and once more when a note scheduled for later starts or an update reaches the
## version a note describes. Never during the guided first run, and never about the game a
## new player started with. Opening PlaybillSheet.new("whats_new") makes it false again.
static func should_show_whats_new() -> bool:
	_refresh_in_background()
	return not whats_new_item().is_empty()


## The What's new note to show now, or {} (see should_show_whats_new): the newest note for
## this build that this profile hasn't been shown, and for a new player only one that went
## up after their first list of news.
static func whats_new_item() -> Dictionary:
	if Settings.tutorial_step >= 0 or _new_player_waiting():
		return {}
	var shown := _shown_notes()
	var since := int(_state().get("whats_new_since", 0))
	for item: Dictionary in items():
		if item["kind"] == "whats_new" and not shown.has(str(item["id"])) and int(item["starts_at"]) > since:
			return item
	return {}


## Count the What's new notes up now as shown, for a caller that shows one its own way.
static func mark_whats_new_seen() -> void:
	if _mark_notes_shown(items()):
		Game.save_profile()


## Call once when this device starts a brand-new profile (Game._ready found no saved one, or
## the home's Play first starts a new player's guided run), before their first list of news
## arrives. That list then counts every What's new note already up as seen, however late it
## comes: Play first plays a whole run before the home asks. A profile from the cloud brings
## its own marks instead.
static func mark_new_player() -> void:
	var st := _state()
	if not st.has("whats_new_since") and _shown_notes().is_empty():
		st["new_player"] = true


## Do what a card's button says: open the Shop or the collection over whatever is on screen,
## or a web page in the browser. Returns false for "daily" (it starts a run, which only the
## home can do) and for anything unknown, so the caller handles those.
static func perform(action: String) -> bool:
	match action:
		"shop":
			UiTheme.show_sheet(ShopSheet.new())
			return true
		"collection":
			UiTheme.show_sheet(CollectionSheet.new())
			return true
	if is_web_link(action):
		OS.shell_open(action)
		return true
	return false


## The two colours of a card or banner: its palette name or "#rrggbb", else its kind's own.
static func colours_for(colour: String, kind := "news") -> Array:
	if PALETTE.has(colour):
		return PALETTE[colour]
	if is_colour(colour):
		var c := Color(colour)
		return [c.lightened(0.12), c.darkened(0.38)]
	return PALETTE[KIND_COLOURS.get(kind, "blue")]


## Text colour for a colour block: dark ink on light blocks (gold), white on the rest.
static func ink_for(colours: Array) -> Color:
	var light := ((colours[0] as Color).get_luminance() + (colours[1] as Color).get_luminance()) / 2.0
	return UiTheme.INK if light > 0.62 else UiTheme.TEXT


# --- The copy of the news ----------------------------------------------------------


## The items to show now, newest first: started and not ended by the server's clock, and
## What's new notes only for this build or an older one.
static func items() -> Array:
	_load_copy()
	var now := server_now()
	var out: Array = []
	var list: Array = _copy.get("items", [])
	for item: Dictionary in list:
		var ends := int(item["ends_at"])
		if int(item["starts_at"]) <= now and (ends == 0 or ends > now) and for_this_build(item):
			out.append(item)
	return out


## Ask the server for the items when the copy is older than 10 minutes (a minute after a
## failed try) and keep them. Returns true when the items changed while it ran, so the caller
## can redraw (the home: its banners and dots). Offline it keeps the copy; it never throws.
## `force` skips the wait, for a deliberate pull to refresh only.
static func refresh(force := false) -> bool:
	_load_copy()
	var before := _version
	while _fetching:
		await (Engine.get_main_loop() as SceneTree).process_frame
	if force or _due():
		_fetching = true
		_tried_at = Time.get_ticks_msec() / 1000.0
		var res: Dictionary = await Online.news()
		_fetching = false
		var data: Variant = res.get("data")
		_try_ok = bool(res.get("ok", false)) and data is Dictionary and (data as Dictionary).get("news") is Array
		if _try_ok:
			adopt((data as Dictionary)["news"], _number(data, "time"))
	return _version != before


## Take a fresh list from the server: keep it as the copy (also on disk unless `save` is
## false), note how far this device's clock is from the server's, and drop read marks of
## items that are gone. A new player's first list (see mark_new_player) sets the moment
## from which What's new notes are new to them, so they aren't told about "new" things in a
## game that is all new to them. Returns whether the items changed.
static func adopt(list: Array, server_time: float, save := true) -> bool:
	_copy_loaded = true
	var fresh: Array = []
	for raw: Variant in list:
		var item := clean(raw)
		if not item.is_empty():
			fresh.append(item)
	fresh.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _newer(a, b))
	var now := Time.get_unix_time_from_system()
	var changed := JSON.stringify(fresh) != JSON.stringify(_copy.get("items", []))
	_copy = { "items": fresh, "fetched_at": now, "offset": server_time - now if server_time > 0.0 else 0.0 }
	if changed:
		_version += 1
	if save:
		_write_copy()
	var st := _state()
	var marks_changed := false
	if _new_player_waiting():
		st["whats_new_since"] = roundi(server_time if server_time > 0.0 else now)
		st.erase("new_player")
		marks_changed = true
	var read := _read_marks()
	var keep := {}
	for item: Dictionary in fresh:
		if read.has(str(item["id"])):
			keep[str(item["id"])] = true
	if keep.size() != read.size():
		st["read"] = keep
		marks_changed = true
	if marks_changed and save:
		Game.save_profile()
	return changed


## One item from the server, checked and trimmed ({} when it isn't usable): a positive id, a
## known kind, a title, at most 600 characters of words, and an action and a colour the game
## understands (anything else becomes "").
static func clean(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = raw
	var id := int(_number(d, "id"))
	var kind := _text(d, "kind")
	var title := _text(d, "title").strip_edges()
	if id <= 0 or not KIND_NAMES.has(kind) or title == "":
		return {}
	var colour := _text(d, "colour")
	var action := _text(d, "action")
	return {
		"id": id, "kind": kind, "title": title.left(80), "body": _text(d, "body").strip_edges().left(600),
		"colour": colour if is_colour(colour) else "", "action": action if is_action(action) else "",
		"version": _text(d, "version").left(20), "starts_at": int(_number(d, "starts_at")), "ends_at": int(_number(d, "ends_at")),
	}


## Newest first, as the server sends them (by start time, then id), so the order holds
## whatever the list looked like.
static func _newer(a: Dictionary, b: Dictionary) -> bool:
	if int(a["starts_at"]) != int(b["starts_at"]):
		return int(a["starts_at"]) > int(b["starts_at"])
	return int(a["id"]) > int(b["id"])


static func is_action(action: String) -> bool:
	return action in ["shop", "collection", "daily"] or is_web_link(action)


## Only https links open: 12 to 300 characters without spaces, tabs, line breaks, quotes or
## < > (the same rule as the API and the news table's CHECK).
static func is_web_link(action: String) -> bool:
	if not action.begins_with("https://") or action.length() > 300 or action.length() < 12:
		return false
	for bad: String in [" ", "\"", "'", "<", ">", "\n", "\t", "\r", char(11), char(12)]:
		if action.contains(bad):
			return false
	return true


static func is_colour(colour: String) -> bool:
	if PALETTE.has(colour):
		return true
	if colour.length() != 7 or not colour.begins_with("#"):
		return false
	for ch: String in colour.substr(1):
		if not "0123456789abcdefABCDEF".contains(ch):
			return false
	return true


## The server's clock as this device knows it (its own clock plus the difference seen at the
## last fetch), so a device clock that is wrong doesn't end or start items early.
static func server_now() -> int:
	return int(Time.get_unix_time_from_system() + float(_copy.get("offset", 0.0)))


## Whether an item is for this build: What's new notes name the version they describe, and a
## build that knows it is older doesn't show them. A build without a version
## (application/config/version unset, like the web game today) takes every note.
static func for_this_build(item: Dictionary) -> bool:
	if item.get("kind") != "whats_new":
		return true
	var wanted := str(item.get("version", ""))
	var mine := str(ProjectSettings.get_setting("application/config/version", ""))
	return wanted == "" or mine == "" or compare_versions(mine, wanted) >= 0


## Compares dotted versions number by number: -1, 0 or 1 ("1.10" comes after "1.9").
static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


## When an item went up ("Today", "Yesterday", "3 days ago", "21 Nov"), or for a banner the
## last day it runs ("Until 21 Dec", or "Until Sat 21 Dec" with `weekday`). Calendar dates in
## the player's own time zone, never a countdown or "ends today": nothing on the Playbill
## should hurry anyone.
static func when_words(item: Dictionary, weekday := false) -> String:
	var ends := int(item.get("ends_at", 0))
	if item.get("kind") == "banner" and ends > 0:
		# The last second it is up, so a banner that ends at midnight shows the day before.
		return "Until " + date_words(ends - 1, weekday)
	return ago_words(int(item.get("starts_at", 0)), server_now())


## How long before `now` a moment was, in calendar days of the player's time zone: "Today",
## "Yesterday", "3 days ago", then its date.
static func ago_words(unix: int, now: int) -> String:
	var days := days_between(unix, now)
	if days <= 0:
		return "Today"
	if days == 1:
		return "Yesterday"
	return "%d days ago" % days if days < 7 else date_words(unix)


## A moment as the player's calendar date: "21 Dec", or "Sat 21 Dec" with `weekday`.
static func date_words(unix: int, weekday := false) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + local_offset())
	var text := "%d %s" % [int(d["day"]), MONTHS[clampi(int(d["month"]) - 1, 0, 11)]]
	return "%s %s" % [DAYS[clampi(int(d["weekday"]), 0, 6)], text] if weekday else text


## Calendar days from `earlier` to `later` in the player's time zone (0 on the same day).
static func days_between(earlier: int, later: int) -> int:
	var offset := local_offset()
	return floori((later + offset) / 86400.0) - floori((earlier + offset) / 86400.0)


## Seconds this device's local time is ahead of UTC, summer time included: its local clock
## read as if it were UTC, less the real time (this works on every platform, the web too).
static func local_offset() -> int:
	if zone_offset is int:
		return zone_offset
	var local := Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return roundi((local - Time.get_unix_time_from_system()) / 60.0) * 60


static func _due() -> bool:
	var fetched := float(_copy.get("fetched_at", 0.0))
	var now := Time.get_unix_time_from_system()
	if fetched > 0.0 and now >= fetched and now - fetched < REFRESH_SECONDS:
		return false
	return _try_ok or _tried_at < 0.0 or Time.get_ticks_msec() / 1000.0 - _tried_at >= RETRY_SECONDS


## The home polls the getters every few seconds. When the copy is due they ask the server
## in the background (refresh() keeps to its ten minutes, and to a minute after a failed
## try), and the next look sees the answer.
static func _refresh_in_background() -> void:
	_load_copy()
	if not _fetching and _due():
		_refresh_detached()


static func _refresh_detached() -> void:
	var _changed: bool = await refresh()


static func _load_copy() -> void:
	if _copy_loaded:
		return
	_copy_loaded = true
	if cache_path == "" or not FileAccess.file_exists(cache_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
	if not data is Dictionary or not (data as Dictionary).get("items") is Array:
		return
	var kept: Array = []
	for raw: Variant in (data as Dictionary)["items"]:
		var item := clean(raw)
		if not item.is_empty():
			kept.append(item)
	_copy = { "items": kept, "fetched_at": _number(data, "fetched_at"), "offset": _number(data, "offset") }
	_version += 1


static func _write_copy() -> void:
	if cache_path == "":
		return
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_copy))


static func _state() -> Dictionary:
	return Game.profile.state("playbill")


static func _read_marks() -> Dictionary:
	var read: Variant = _state().get("read")
	return read if read is Dictionary else {}


## The What's new notes this profile has been shown, by id. They are kept even after a note
## leaves the list, so an old note that comes back into the newest 20 isn't "new" again.
static func _shown_notes() -> Dictionary:
	var shown: Variant = _state().get("whats_new")
	return shown if shown is Dictionary else {}


## Adds the What's new notes in `list` to the shown ones; true when that changed anything
## (the caller saves the profile).
static func _mark_notes_shown(list: Array) -> bool:
	var shown := _shown_notes().duplicate()
	var before := shown.size()
	for item: Dictionary in list:
		if item["kind"] == "whats_new":
			shown[str(item["id"])] = true
	if shown.size() == before:
		return false
	_state()["whats_new"] = shown
	return true


## A new player's What's new waits for their first list of news (see adopt): one marked by
## mark_new_player(), or a profile with no finished runs that has never been shown a note.
static func _new_player_waiting() -> bool:
	var st := _state()
	if st.has("whats_new_since"):
		return false
	return bool(st.get("new_player", false)) or (Game.profile.runs_played == 0 and not st.has("whats_new"))


static func _unread_ids() -> Dictionary:
	var read := _read_marks()
	var out := {}
	for item: Dictionary in items():
		if not read.has(str(item["id"])):
			out[int(item["id"])] = true
	return out


## The newest What's new note this build shows, seen or not ({} when there is none).
static func _newest_note() -> Dictionary:
	for item: Dictionary in items():
		if item["kind"] == "whats_new":
			return item
	return {}


static func _number(d: Variant, key: String) -> float:
	var v: Variant = (d as Dictionary).get(key) if d is Dictionary else null
	return float(v) if v is int or v is float else 0.0


static func _text(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key)
	return v if v is String else ""


# --- The sheet -----------------------------------------------------------------------


## Opening the Playbill counts its cards as read (their "New" tags stay until it closes), and
## its What's new notes as shown, so the home doesn't offer them again.
func _mark_seen() -> void:
	var st := _state()
	var read := _read_marks().duplicate()
	var changed := false
	var shown := items()
	for item: Dictionary in shown:
		if not read.has(str(item["id"])):
			read[str(item["id"])] = true
			changed = true
	if changed:
		st["read"] = read
	if _mark_notes_shown(shown):
		changed = true
	if changed:
		Game.save_profile()


func _build() -> void:
	var list := items()
	if _focus > 0:
		var item := _find(list, _focus)
		if not item.is_empty():
			_build_focus(item, list.size() > 1)
			return
		_focus = 0
	title_text = "Playbill"
	if list.is_empty():
		_build_empty()
		return
	page = clampi(page, 0, _pages(list) - 1)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(page * PER_PAGE, mini(list.size(), (page + 1) * PER_PAGE)):
		row.add_child(_card(list[i]))
	# A short last page keeps the row's size, so the footer doesn't jump.
	for i in PER_PAGE - row.get_child_count():
		var gap := Control.new()
		gap.custom_minimum_size = CARD
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	body.add_child(row)
	_cards = row
	if not Settings.reduce_motion:
		row.modulate.a = 0.0
		row.create_tween().tween_property(row, "modulate:a", 1.0, 0.16)
	_build_footer(_pages(list))


## A card: its kind and when, a picture of where it leads, the title, two lines of words and
## its button. Tapping anywhere else on it shows all of its words.
func _card(item: Dictionary) -> Control:
	var colours := colours_for(str(item["colour"]), str(item["kind"]))
	var ink := ink_for(colours)
	var tile := ShopSheet.Tile.new(colours, 10.0)
	tile.custom_minimum_size = CARD
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.gui_input.connect(_on_card_input.bind(int(item["id"])))
	tile.col.add_theme_constant_override("separation", 5)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.add_child(_tag(str(KIND_NAMES[item["kind"]]), ink))
	if _fresh.has(int(item["id"])):
		top.add_child(_tag("New", UiTheme.INK, Color.WHITE))
	var stamp := UiTheme.label(when_words(item), 8, Color(ink, 0.82))
	stamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The date gives way (ends in "…") rather than widen the card.
	stamp.clip_text = true
	stamp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_plain(stamp, ink)
	top.add_child(stamp)
	tile.col.add_child(top)
	var art := CenterContainer.new()
	art.custom_minimum_size = Vector2(0, 56)
	art.add_child(Emblem.new(emblem_for(item), 52.0, ink))
	tile.col.add_child(art)
	var title := UiTheme.title(str(item["title"]), 13, ink)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size = Vector2(CARD.x - 20.0, 0)
	_plain(title, ink)
	tile.col.add_child(title)
	var blurb := UiTheme.label(str(item["body"]), 9, Color(ink, 0.9))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blurb.custom_minimum_size = Vector2(CARD.x - 20.0, 0)
	_plain(blurb, ink)
	tile.col.add_child(blurb)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.col.add_child(gap)
	if str(item["action"]) != "":
		var b := _action_button(str(item["action"]), 9, 22.0)
		tile.col.add_child(b)
	return tile


## One card in full: all of its words, its picture large, its button, and the way back to
## the other cards. The title and the words scroll inside the card (a card may hold 80 and
## 600 characters), so the button and the way back always stay on the stage.
func _build_focus(item: Dictionary, others: bool) -> void:
	title_text = "What's new" if item["kind"] == "whats_new" else "Playbill"
	var colours := colours_for(str(item["colour"]), str(item["kind"]))
	var ink := ink_for(colours)
	var tile := ShopSheet.Tile.new(colours, 16.0)
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	tile.col.add_child(row)
	tile.col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 7)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var tag := str(KIND_NAMES[item["kind"]])
	if item["kind"] == "whats_new" and str(item["version"]) != "":
		tag += " in " + str(item["version"])
	top.add_child(_tag(tag, ink))
	var stamp := UiTheme.label(when_words(item, true), 9, Color(ink, 0.82))
	stamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamp.clip_text = true
	stamp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_plain(stamp, ink)
	top.add_child(stamp)
	text.add_child(top)
	var words := scroll_area(ink, colours[1])
	words.name = "Words"
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(inner)
	var title := UiTheme.title(str(item["title"]), 20, ink)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plain(title, ink)
	inner.add_child(title)
	var blurb := UiTheme.label(str(item["body"]), 10, Color(ink, 0.94))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plain(blurb, ink)
	inner.add_child(blurb)
	text.add_child(words)
	if str(item["action"]) != "":
		var b := _action_button(str(item["action"]), 11, 28.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size = Vector2(150, 28)
		text.add_child(b)
	var art := CenterContainer.new()
	art.custom_minimum_size = Vector2(120, 0)
	art.add_child(Emblem.new(emblem_for(item), 104.0, ink))
	row.add_child(art)
	body.add_child(tile)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	if others:
		foot.add_child(UiTheme.icon_button("back", _show_all, 22.0))
		foot.add_child(link_button("All news", _show_all))
	var status := _status_label()
	foot.add_child(status)
	body.add_child(foot)
	if not Settings.reduce_motion:
		tile.modulate.a = 0.0
		tile.create_tween().tween_property(tile, "modulate:a", 1.0, 0.16)


## A vertical scroll area for long words on a card or a letter: no sideways scrolling, room
## kept for a slim pill of a scroll bar in the text's colour (so the words never re-wrap when
## it appears), a soft fade at an edge with more words past it, and drag to scroll on touch
## screens. The mouse wheel scrolls it too.
static func scroll_area(ink: Color, fade: Color) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	s.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
	s.add_theme_color_override("scroll_hint_vertical_color", Color(fade.darkened(0.35), 0.55))
	s.add_theme_constant_override("scrollbar_v_separation", 6)
	var bar := s.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(ink, 0.1)
	track.set_corner_radius_all(99)
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grab := track.duplicate() as StyleBoxFlat
	grab.bg_color = Color(ink, 0.5)
	var held := track.duplicate() as StyleBoxFlat
	held.bg_color = Color(ink, 0.75)
	for state: String in ["scroll", "scroll_focus"]:
		bar.add_theme_stylebox_override(state, track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", held)
	bar.add_theme_stylebox_override("grabber_pressed", held)
	return s


func _build_empty() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	var art := CenterContainer.new()
	art.add_child(Emblem.new("spark", 64.0, UiTheme.TEXT, Color(1, 1, 1, 0.1)))
	col.add_child(art)
	var heading_text := "No news right now"
	var more := "The troupe posts news here: new Jesters, festivals and what's new in the game."
	# The sheet asks for the news as it opens (_fetch), so a due fetch is as good as started.
	if _fetching or _due():
		heading_text = "Fetching the Playbill…"
		more = ""
	elif _copy.get("fetched_at", 0.0) == 0.0 and not _try_ok and _tried_at >= 0.0:
		heading_text = "The Playbill needs a connection"
		more = "Its news arrives when you're online. Everything else in the game works offline."
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
	var status := _status_label()
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


## A line of news about the news: what a button couldn't do, or that the cards shown are the
## last copy because the device is offline.
func _status_label() -> Label:
	var text := _status_text
	if text == "" and not _try_ok and _tried_at >= 0.0 and not _fetching and float(_copy.get("fetched_at", 0.0)) > 0.0:
		text = "You're offline: this is the news from your last visit."
	var l := UiTheme.label(text, 8, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## The picture on a card: where its button leads, else what kind of news it is.
static func emblem_for(item: Dictionary) -> String:
	var action := str(item.get("action", ""))
	match action:
		"shop":
			return "shop"
		"collection":
			return "cards"
		"daily":
			return "trophy"
	if is_web_link(action):
		return "forward"
	return "info" if item.get("kind") == "news" else "spark"


func _action_button(action: String, font_size: int, height: float) -> Button:
	var b := UiTheme.button(str(ACTION_WORDS.get(action, "Read more")), _act.bind(action), font_size, Color.WHITE)
	b.custom_minimum_size = Vector2(0, height)
	b.clip_text = true
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var st := b.get_theme_stylebox(state) as StyleBoxFlat
		if st != null:
			st.content_margin_left = 8
			st.content_margin_right = 8
			st.content_margin_top = 1
			st.content_margin_bottom = 1
	return b


func _act(action: String) -> void:
	Feel.play("select")
	if action == "daily":
		if action_chosen.get_connections().is_empty():
			_status_text = "Today's daily run is on the home screen."
			rebuild()
			return
		action_chosen.emit(action)
		close()
		return
	if not perform(action):
		_status_text = "That doesn't work in this version of the game."
		rebuild()


func _show_all() -> void:
	Feel.play("click")
	_focus = 0
	_status_text = ""
	rebuild()


func _on_card_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at := (event as InputEventMouseButton).global_position
		if (event as InputEventMouseButton).pressed:
			_card_down = at
		elif (at - _card_down).length() < 9.0:
			Feel.play("select")
			Feel.buzz(8)
			_focus = id
			_status_text = ""
			rebuild()


func _turn(step: int) -> void:
	var to := clampi(page + step, 0, _pages(items()) - 1)
	if to == page or _focus > 0:
		return
	Feel.play("click")
	Feel.buzz(6)
	page = to
	_last_turn = Time.get_ticks_msec()
	rebuild()


## Swipes and scrolls turn pages, as in the Jester collection. This looks at input before the
## cards do without taking it, so a tap still opens a card and a sideways drag turns the page.
func _input(event: InputEvent) -> void:
	if _focus > 0 or _cards == null or not is_instance_valid(_cards) or not is_inside_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			# Trackpads send a stream of wheel events; turn once per flick.
			if Time.get_ticks_msec() - _last_turn > 380 and _cards.get_global_rect().has_point(get_global_mouse_position()):
				_turn(1 if mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] else -1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var at := get_global_mouse_position()
			if mb.pressed:
				_press_at = at
				_pressing = _cards.get_global_rect().grow(10.0).has_point(at)
			elif _pressing:
				_pressing = false
				var moved := at - _press_at
				if absf(moved.x) > 40.0 and absf(moved.x) > absf(moved.y) * 1.4:
					_card_down = Vector2(INF, INF)
					_turn(1 if moved.x < 0.0 else -1)


func _unhandled_input(event: InputEvent) -> void:
	if _focus == 0 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT or event.keycode == KEY_LEFT:
			_turn(1 if event.keycode == KEY_RIGHT else -1)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _pages(list: Array) -> int:
	return maxi(1, ceili(list.size() / float(PER_PAGE)))


func _find(list: Array, id: int) -> Dictionary:
	for item: Dictionary in list:
		if int(item["id"]) == id:
			return item
	return {}


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


## A small pill label: white glass on a colour block, or `bg` behind `fg`.
func _tag(text: String, ink: Color, bg := Color(0, 0, 0, 0)) -> PanelContainer:
	var pill := PanelContainer.new()
	var fill := bg if bg.a > 0.0 else (Color(1, 1, 1, 0.24) if ink == UiTheme.TEXT else Color(0, 0, 0, 0.12))
	var box := UiTheme.box(fill, Color(1, 1, 1, 0.3) if bg.a == 0.0 else bg, 99)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text_colour := ink if bg.a == 0.0 else UiTheme.INK
	var l := UiTheme.label(text, 8, text_colour)
	l.add_theme_font_override("font", UiTheme.bold)
	_plain(l, text_colour)
	pill.add_child(l)
	return pill


## Dark ink reads best without the soft shadow that white text wears.
static func _plain(l: Label, ink: Color) -> void:
	if ink.get_luminance() < 0.5:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))


## A gold text link, such as "All news" back from a card shown in full.
static func link_button(text: String, on_press: Callable) -> Button:
	var b := UiTheme.button(text, on_press, 9)
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 2
	none.content_margin_right = 4
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, none)
	b.add_theme_color_override("font_color", UiTheme.GOLD)
	b.add_theme_color_override("font_hover_color", UiTheme.GOLD.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD.darkened(0.15))
	return b


func _alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Like Sheet.rebuild, but the old content leaves the tree at once, so it never counts toward
## the panel's size while the sheet slides in (see ShopSheet.rebuild).
func rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_cards = null
	_build()
	heading.text = title_text


## A frosted disc with a picture of where a card leads: the Shop's bag, a fan of cards for the
## collection, the daily's trophy, an arrow for a web page, an "i" for news, or a sparkle for
## What's new and events.
class Emblem extends Control:
	var glyph := "info"
	var ink := Color.WHITE
	var disc := Color(1, 1, 1, 0.2)

	func _init(glyph_name: String, diameter: float, colour := Color.WHITE, fill := Color(0, 0, 0, 0)) -> void:
		glyph = glyph_name
		ink = colour
		if fill.a > 0.0:
			disc = fill
		elif colour.get_luminance() < 0.5:
			disc = Color(1, 1, 1, 0.34)
		custom_minimum_size = Vector2(diameter, diameter)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if glyph in ["shop", "trophy", "forward", "info"]:
			var icon := UiIcon.new(glyph, ink)
			icon.position = custom_minimum_size * 0.25
			icon.size = custom_minimum_size * 0.5
			add_child(icon)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_circle(c + Vector2(0, r * 0.06), r, Color(0, 0, 0, 0.12), true, -1.0, true)
		draw_circle(c, r, disc, true, -1.0, true)
		draw_arc(c, r - 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.32), 1.0, true)
		match glyph:
			"spark":
				_sparkle(c + Vector2(-r * 0.08, r * 0.06), r * 0.6, 0.0)
				_sparkle(c + Vector2(r * 0.4, -r * 0.38), r * 0.26, 0.12)
			"cards":
				for k: int in [-1, 1, 0]:
					var w := r * 0.5
					var h := w * 1.4
					draw_set_transform(c + Vector2(k * r * 0.2, r * 0.04 + absf(k) * r * 0.05), k * 0.26, Vector2.ONE)
					var card := Paint.round_rect(Rect2(-w / 2.0, -h / 2.0, w, h), w * 0.14, 4)
					draw_colored_polygon(card, Color(ink, 0.95) if k == 0 else Color(ink, 0.55))
					draw_polyline(Paint.closed(card), Color(0, 0, 0, 0.18), 1.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A four-pointed star: an astroid-like curve (sharp points, curved sides) let out by
	## `waist` toward a circle so a small one isn't too thin. Filled polygons have hard edges,
	## so a thin antialiased outline of the same colour smooths them.
	func _sparkle(at: Vector2, radius: float, waist: float) -> void:
		var points := PackedVector2Array()
		for k: int in 64:
			var a := k * TAU / 64.0
			var star := Vector2(signf(cos(a)) * pow(absf(cos(a)), 4.0), signf(sin(a)) * pow(absf(sin(a)), 4.0))
			points.append(at + (star * (1.0 - waist) + Vector2(cos(a), sin(a)) * waist) * radius)
		draw_colored_polygon(points, ink)
		draw_polyline(Paint.closed(points), ink, 1.0, true)
