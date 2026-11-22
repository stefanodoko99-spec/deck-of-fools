extends "res://tests/suite.gd"
## The Playbill (PlaybillSheet) and the inbox (InboxSheet): items and letters from the server
## are checked and kept, banners and dots count the right things, What's new shows once and
## only to returning players, a letter pays its coins once per profile whatever the server
## answers, and the full views of a card and a letter fit the stage at every text size.
## Game.profile is swapped for a test profile, the copies are kept in memory (cache_path ""),
## and nothing here saves: adopt(..., false) and settle() never do, and the sheets are opened
## with nothing left to mark.

const DAY := 86400
const PRODUCTION_API := "https://deck-of-fools-api.stefanodoko-radari.workers.dev"


## Runs `body` with a fresh test profile, memory-only copies, a release build's money (unless
## `money` says otherwise), the guide finished, dates in UTC and nothing fetched yet, then
## puts everything back.
func isolated(body: Callable, runs_played := 3, money := "off") -> void:
	var saved_profile: Profile = Game.profile
	var saved_money := Game.money_mode
	var saved_settings := [Settings.tutorial_step, Settings.reduce_motion, Settings.size]
	var saved_paths := [PlaybillSheet.cache_path, InboxSheet.cache_path, PlaybillSheet.zone_offset]
	var saved_copies := [PlaybillSheet._copy, PlaybillSheet._copy_loaded, InboxSheet._copy, InboxSheet._copy_loaded]
	var saved_tries := [PlaybillSheet._fetching, PlaybillSheet._tried_at, PlaybillSheet._try_ok,
		InboxSheet._fetching, InboxSheet._tried_at, InboxSheet._try_ok, InboxSheet._tried_for, InboxSheet._claiming]
	var saved_online := [Online.user, Online.token, Online.api_url]
	Game.profile = Profile.new()
	Game.profile.runs_played = runs_played
	Game.money_mode = money
	Settings.tutorial_step = -1
	Settings.reduce_motion = true
	PlaybillSheet.cache_path = ""
	InboxSheet.cache_path = ""
	PlaybillSheet.zone_offset = 0
	PlaybillSheet._copy = {}
	InboxSheet._copy = {}
	PlaybillSheet._copy_loaded = true
	InboxSheet._copy_loaded = true
	PlaybillSheet._fetching = false
	PlaybillSheet._tried_at = -1.0
	PlaybillSheet._try_ok = false
	InboxSheet._fetching = false
	InboxSheet._tried_at = -1.0
	InboxSheet._try_ok = false
	InboxSheet._tried_for = ""
	InboxSheet._claiming = {}
	Online.user = {}
	Online.token = ""
	body.call()
	Game.profile = saved_profile
	Game.money_mode = saved_money
	Settings.tutorial_step = saved_settings[0]
	Settings.reduce_motion = saved_settings[1]
	Settings.size = saved_settings[2]
	PlaybillSheet.cache_path = saved_paths[0]
	InboxSheet.cache_path = saved_paths[1]
	PlaybillSheet.zone_offset = saved_paths[2]
	PlaybillSheet._copy = saved_copies[0]
	PlaybillSheet._copy_loaded = saved_copies[1]
	InboxSheet._copy = saved_copies[2]
	InboxSheet._copy_loaded = saved_copies[3]
	PlaybillSheet._fetching = saved_tries[0]
	PlaybillSheet._tried_at = saved_tries[1]
	PlaybillSheet._try_ok = saved_tries[2]
	InboxSheet._fetching = saved_tries[3]
	InboxSheet._tried_at = saved_tries[4]
	InboxSheet._try_ok = saved_tries[5]
	InboxSheet._tried_for = saved_tries[6]
	InboxSheet._claiming = saved_tries[7]
	Online.user = saved_online[0]
	Online.token = saved_online[1]
	Online.api_url = saved_online[2]


func now() -> int:
	return int(Time.get_unix_time_from_system())


func item(id: int, kind: String, starts: int, ends: Variant = null, action := "", colour := "", version := "") -> Dictionary:
	return { "id": float(id), "kind": kind, "title": "Item %d" % id, "body": "Words for item %d." % id, "colour": colour,
		"action": action, "version": version, "starts_at": float(starts), "ends_at": ends }


func letter(id: int, coins: int, created: int, expires: Variant = null, claimed := false) -> Dictionary:
	return { "id": float(id), "title": "Letter %d" % id, "body": "A letter.", "coins": float(coins), "created_at": float(created),
		"expires_at": expires, "claimed": claimed, "personal": false }


func ids(list: Array) -> Array:
	return list.map(func(d: Dictionary) -> int: return int(d["id"]))


## The runner's scene: the tests run inside its _ready, while the root is still busy adding
## it, so the root can't take children yet.
func host() -> Node:
	UiTheme.build()
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene != null else tree.root


## Labels whose words can grow without a cap (they wrap and show every line) and sit outside
## a scroll area. In a view with a fixed panel each one could push what follows it off the
## stage. (The runner can't step frames, so a test can't measure the laid-out panel; this
## checks what keeps it inside the stage instead.)
func unbounded_labels(node: Node, in_scroll: bool, out: Array) -> Array:
	if node is Label:
		var l := node as Label
		if not in_scroll and l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.max_lines_visible < 0:
			out.append(l.text.left(30))
	for child in node.get_children():
		unbounded_labels(child, in_scroll or node is ScrollContainer, out)
	return out


## The words `size` long, as plain words.
func words(size: int) -> String:
	var text := ""
	while text.length() < size:
		text += "Il Capitano boasts louder than anyone in the troupe and trips on his own sword. "
	return text.left(size).strip_edges()


func find_buttons(node: Node, out: Array) -> Array:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		find_buttons(child, out)
	return out


func test_online_calls_fail_softly_offline() -> void:
	# Headless runs keep Online inert: every call answers at once, without a request.
	var res: Dictionary = await Online.news()
	check(not res["ok"] and int(res["status"]) == 0, "news() offline: %s" % res)
	res = await Online.letters()
	check(not res["ok"] and int(res["status"]) == 0 and res.get("data") is Dictionary, "letters() offline: %s" % res)
	res = await Online.claim_letter(3, "abcdef0123456789")
	check(not res["ok"] and int(res["status"]) == 0, "claim_letter() offline: %s" % res)
	res = await Online.claim_letter(0)
	check(not res["ok"], "claim_letter(0) is refused")


func test_playbill_items_are_cleaned_and_sorted() -> void:
	isolated(func() -> void:
		var t := now()
		var list := [
			item(2, "news", t - 5 * DAY),
			item(7, "banner", t - 60, float(t + 2 * DAY), "daily", "#FF5A8A"),
			item(5, "whats_new", t - DAY, null, "shop", "purple"),
			item(9, "news", t - 30, null, "javascript:alert(1)", "chartreuse"),
			item(8, "news", t - 30, null, "https://example.com/a b"),
			item(6, "news", t - 30, null, "https://example.com/blog", "teal"),
			item(10, "news", t - 40, null, "https://example.com/a\rb"),
			{ "id": 3, "kind": "advert", "title": "Not a kind", "starts_at": t - 10 },
			{ "id": 4, "kind": "news", "title": "   ", "starts_at": t - 10 },
			{ "id": -1, "kind": "news", "title": "Bad id", "starts_at": t - 10 },
			"not even an item",
		]
		check(PlaybillSheet.adopt(list, float(t), false), "a new list changes the copy")
		check(not PlaybillSheet.adopt(list, float(t), false), "the same list again doesn't")
		var shown := PlaybillSheet.items()
		eq(ids(shown), [9, 8, 6, 10, 7, 5, 2], "newest first by start time, then id; unusable items dropped")
		var by_id := {}
		for i: Dictionary in shown:
			by_id[int(i["id"])] = i
		eq(by_id[9]["action"], "", "a javascript: action is dropped")
		eq(by_id[9]["colour"], "", "an unknown colour is dropped")
		eq(by_id[8]["action"], "", "a link with a space is dropped")
		eq(by_id[10]["action"], "", "a link with a carriage return is dropped (as the API and the table do)")
		eq(by_id[6]["action"], "https://example.com/blog", "an https link is kept")
		eq(by_id[7]["colour"], "#FF5A8A", "a hex colour is kept")
		eq(by_id[2]["ends_at"], 0, "no end time becomes 0")
		check(by_id[6]["id"] is int and by_id[6]["starts_at"] is int, "numbers from JSON become ints"))


func test_items_start_and_end_by_the_server_clock() -> void:
	isolated(func() -> void:
		var t := now()
		# This device's clock is an hour behind the server's.
		var server := t + 3600
		PlaybillSheet.adopt([
			item(1, "news", server - 60),
			item(2, "news", server + 600),
			item(3, "banner", server - 7200, float(server - 60)),
			item(4, "banner", server - 60, float(server + DAY)),
			item(5, "news", server - 60, 0.0),
		], float(server), false)
		eq(ids(PlaybillSheet.items()), [5, 4, 1], "started and not ended by the server's clock (same start: higher id first; 0 = no end)")
		var banner: Dictionary = PlaybillSheet.banners()[0]
		check(absi(int(banner["ends_at"]) - (t + DAY)) <= 2, "a banner's end is told in this device's time: %d vs %d" % [banner["ends_at"], t + DAY]))


func test_unread_count_and_banners() -> void:
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.adopt([
			item(1, "news", t - 100), item(2, "whats_new", t - 200), item(3, "banner", t - 10, float(t + DAY), "daily", "pink"),
			item(4, "banner", t - 20, null), item(5, "banner", t - 30, null), item(6, "banner", t - 40, null),
		], float(t), false)
		eq(PlaybillSheet.unread_count(), 2, "news and What's new count, banners don't")
		var st := Game.profile.state("playbill")
		st["read"] = { "1": true, "99": true }
		eq(PlaybillSheet.unread_count(), 1, "read marks are kept by id")
		var banners := PlaybillSheet.banners()
		eq(banners.map(func(b: Dictionary) -> int: return int(b["id"])), [3, 4, 5], "at most three banners, newest first")
		eq((banners[0] as Dictionary).keys(), ["id", "title", "text", "colour", "ends_at", "action"], "the banner shape the home expects")
		eq([banners[0]["action"], banners[0]["colour"], banners[1]["ends_at"]], ["daily", "pink", 0], "action, colour, no end")
		PlaybillSheet.adopt([item(1, "news", t - 100)], float(t), false)
		eq(st["read"], { "1": true }, "marks of items that are gone are dropped"))


func test_the_home_getters_keep_the_copy_fresh() -> void:
	isolated(func() -> void:
		# Nothing fetched yet: the home's first look asks the server (offline here, so it fails
		# at once), and the next looks wait a minute instead of asking again.
		check(PlaybillSheet._tried_at < 0.0, "nothing asked before the home looks")
		PlaybillSheet.banners()
		var first := PlaybillSheet._tried_at
		check(first >= 0.0 and not PlaybillSheet._try_ok, "banners() asks in the background when the copy is due")
		PlaybillSheet.unread_count()
		PlaybillSheet.should_show_whats_new()
		eq(PlaybillSheet._tried_at, first, "a failed try waits a minute before the next")
		# A fresh copy isn't asked for again for ten minutes.
		PlaybillSheet._tried_at = -1.0
		PlaybillSheet.adopt([item(1, "news", now() - 60)], float(now()), false)
		PlaybillSheet.unread_count()
		eq(PlaybillSheet._tried_at, -1.0, "a fresh copy isn't fetched again")
		# The inbox badge does the same for this account's letters.
		Online.token = "test-token"
		Online.user = { "id": "user-a" }
		InboxSheet.unclaimed_count()
		var tried := InboxSheet._tried_at
		check(tried >= 0.0 and InboxSheet._tried_for == "user-a", "unclaimed_count() asks for this account's letters")
		InboxSheet.unclaimed_count()
		eq(InboxSheet._tried_at, tried, "and waits a minute after a failed try"))


func test_whats_new_shows_once_and_only_to_returning_players() -> void:
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.adopt([item(4, "whats_new", t - DAY), item(2, "whats_new", t - 3 * DAY)], float(t), false)
		var st := Game.profile.state("playbill")
		check(not st.has("whats_new_since"), "a returning player gets no start mark from the list")
		check(PlaybillSheet.should_show_whats_new(), "a returning player sees What's new")
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 4, "the newest note")
		Settings.tutorial_step = 2
		check(not PlaybillSheet.should_show_whats_new(), "never during the guided first run")
		Settings.tutorial_step = -1
		check(PlaybillSheet._mark_notes_shown(PlaybillSheet.items()), "showing it marks the notes up now")
		check(not PlaybillSheet.should_show_whats_new(), "once shown, not again, nor the older note")
		PlaybillSheet.adopt([item(6, "whats_new", t - 60), item(4, "whats_new", t - DAY)], float(t), false)
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 6, "the next update's note shows once more")
		PlaybillSheet.adopt([item(4, "whats_new", t - DAY)], float(t), false)
		PlaybillSheet._mark_notes_shown(PlaybillSheet.items())
		PlaybillSheet.adopt([item(6, "whats_new", t - 60), item(4, "whats_new", t - DAY)], float(t), false)
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 6, "a note that left the list and came back isn't marked by the others"))
	var new_player := func() -> void:
		var t := now()
		check(not PlaybillSheet.should_show_whats_new(), "a new player before any list: no")
		PlaybillSheet.adopt([item(4, "whats_new", t - DAY), item(1, "news", t)], float(t), false)
		check(int(Game.profile.state("playbill").get("whats_new_since", 0)) >= t, "a new player's first list marks when they started")
		Game.profile.runs_played = 1
		check(not PlaybillSheet.should_show_whats_new(), "so the game they started with is never 'new'")
		PlaybillSheet.adopt([item(7, "whats_new", t + 10), item(4, "whats_new", t - DAY)], float(t + 20), false)
		check(PlaybillSheet.should_show_whats_new(), "but a later update's note is")
	isolated(new_player, 0)


func test_whats_new_for_a_new_player_whose_first_list_comes_after_a_run() -> void:
	# Play first: a new install plays the guided run before anything asks for the news, so the
	# first list arrives with runs_played 1. mark_new_player() at the start keeps it new.
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.mark_new_player()
		Game.profile.runs_played = 1
		check(not PlaybillSheet.should_show_whats_new(), "nothing before the first list")
		PlaybillSheet.adopt([item(1, "whats_new", t - 3 * DAY)], float(t), false)
		check(not PlaybillSheet.should_show_whats_new(), "the note up when they started is not 'new' to them")
		check(not Game.profile.state("playbill").has("new_player"), "the first list settles the mark")
		PlaybillSheet.adopt([item(2, "whats_new", t + 30), item(1, "whats_new", t - 3 * DAY)], float(t + 60), false)
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 2, "the next update's note is")
		# A profile that has been shown notes (one from the cloud) isn't made new again.
		PlaybillSheet._mark_notes_shown(PlaybillSheet.items())
		Game.profile.state("playbill").erase("whats_new_since")
		PlaybillSheet.mark_new_player()
		check(not Game.profile.state("playbill").has("new_player"), "mark_new_player() leaves a profile with marks alone"), 0)


func test_whats_new_scheduled_or_for_a_later_version() -> void:
	var key := "application/config/version"
	var had: Variant = ProjectSettings.get_setting(key, "")
	isolated(func() -> void:
		var t := now()
		# Note 10 was posted first but starts in two days; note 11 is up now.
		PlaybillSheet.adopt([item(10, "whats_new", t + 2 * DAY), item(11, "whats_new", t - 60)], float(t), false)
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 11, "the note that is up")
		PlaybillSheet._mark_notes_shown(PlaybillSheet.items())
		PlaybillSheet.adopt([item(10, "whats_new", t + 2 * DAY), item(11, "whats_new", t - 60)], float(t + 2 * DAY + 60), false)
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 10, "a scheduled note shows when it starts, though its id is lower")
		PlaybillSheet._mark_notes_shown(PlaybillSheet.items())
		# A 1.1 build is shown note 13; note 12 is about 1.2 and waits for the update.
		PlaybillSheet.adopt([item(13, "whats_new", t - 60), item(12, "whats_new", t - DAY, null, "", "", "1.2")], float(t), false)
		ProjectSettings.set_setting(key, "1.1")
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 13, "a 1.1 build: the note for everyone")
		PlaybillSheet._mark_notes_shown(PlaybillSheet.items())
		check(PlaybillSheet.whats_new_item().is_empty(), "and nothing more")
		ProjectSettings.set_setting(key, "1.2")
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 12, "after updating to 1.2, the note about 1.2"))
	ProjectSettings.set_setting(key, had)


func test_whats_new_waits_for_the_build_it_describes() -> void:
	eq([PlaybillSheet.compare_versions("1.10", "1.9"), PlaybillSheet.compare_versions("1.2", "1.2.0"), PlaybillSheet.compare_versions("1.1", "1.2")], [1, 0, -1], "dotted versions compare by number")
	var key := "application/config/version"
	var had: Variant = ProjectSettings.get_setting(key, "")
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.adopt([item(5, "whats_new", t - 60, null, "", "", "1.2"), item(3, "whats_new", t - DAY, null, "", "", "1.1")], float(t), false)
		ProjectSettings.set_setting(key, "1.1")
		eq(ids(PlaybillSheet.items()), [3], "a 1.1 build hides the note about 1.2")
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 3, "and shows its own")
		ProjectSettings.set_setting(key, "1.2.1")
		eq(ids(PlaybillSheet.items()), [5, 3], "a newer build shows both")
		ProjectSettings.set_setting(key, "")
		eq(ids(PlaybillSheet.items()), [5, 3], "a build without a version shows every note"))
	ProjectSettings.set_setting(key, had)


func test_dates_are_the_players_own_and_never_hurry() -> void:
	isolated(func() -> void:
		# A banner that ends at 02:00 UTC on 21 December 2026: 21:00 on the 20th in New York.
		var ends := Time.get_unix_time_from_datetime_string("2026-12-21T02:00:00")
		var banner := { "kind": "banner", "starts_at": ends - 5 * DAY, "ends_at": ends }
		PlaybillSheet.zone_offset = -5 * 3600
		eq(PlaybillSheet.when_words(banner), "Until 20 Dec", "in New York it runs until the 20th")
		eq(PlaybillSheet.when_words(banner, true), "Until Sun 20 Dec", "with the weekday in the full view")
		PlaybillSheet.zone_offset = 3600
		eq(PlaybillSheet.when_words(banner, true), "Until Mon 21 Dec", "in Tirana until the 21st")
		# One that ends at midnight runs until the day before.
		var midnight := Time.get_unix_time_from_datetime_string("2026-12-22T00:00:00") - 3600
		eq(PlaybillSheet.when_words({ "kind": "banner", "ends_at": midnight }), "Until 21 Dec", "an end at midnight shows the last day it runs")
		# Ending tomorrow is never "today", whatever the hour.
		var t := now()
		PlaybillSheet.adopt([], float(t), false)
		for hours: int in [2, 20, 30]:
			var text := PlaybillSheet.when_words({ "kind": "banner", "ends_at": t + hours * 3600 })
			check(text.begins_with("Until ") and not text.to_lower().contains("today"), "a banner ending in %d h: '%s'" % [hours, text])
		# Calendar days: a minute before this morning's midnight was yesterday.
		PlaybillSheet.zone_offset = 0
		var midnight_today := floori(t / float(DAY)) * DAY
		eq(PlaybillSheet.ago_words(midnight_today - 60, t), "Yesterday", "a minute before midnight is yesterday")
		eq(PlaybillSheet.ago_words(midnight_today, t), "Today", "midnight is today")
		eq(PlaybillSheet.ago_words(midnight_today - 3 * DAY, t), "3 days ago", "three days ago")
		eq(PlaybillSheet.ago_words(midnight_today - 9 * DAY, t), PlaybillSheet.date_words(midnight_today - 9 * DAY), "then the date")
		# A letter that goes tomorrow evening says its date, never "tonight".
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 200, t - DAY, float(t + 20 * 3600))], float(t), "user-a", false)
		var line := InboxSheet.when_words(InboxSheet.letters()[0])
		check(line.ends_with("until " + PlaybillSheet.date_words(t + 20 * 3600 - 1)) and not line.contains("tonight"), "a letter's last day: '%s'" % line))


func test_letters_count_and_expire_by_the_server_clock() -> void:
	isolated(func() -> void:
		var t := now()
		InboxSheet.adopt([
			letter(1, 100, t - 300),
			letter(2, 0, t - 200),
			letter(3, 50, t - 100, null, true),
			letter(4, 40, t - 900, float(t - 5)),
			letter(5, 75, t + 3600),
			letter(6, 10, t - 50, 0.0),
		], float(t), "user-a", false)
		eq(InboxSheet.letters(), [], "another account's copy is never shown")
		Online.user = { "id": "user-a" }
		eq(ids(InboxSheet.letters()), [1, 2, 3, 6], "not expired (0 = never), delivered, in the server's order")
		eq(InboxSheet.unclaimed_count(), 3, "coins to claim and an unread message; not one claimed on the server")
		InboxSheet._state()["claimed"] = { "2": 0 }
		eq(InboxSheet.unclaimed_count(), 2, "nor one in this profile's record")
		InboxSheet.adopt([letter(1, 100, t - 300, float(t + 1800))], float(t + 3600), "user-a", false)
		eq(InboxSheet.letters(), [], "a letter expired by the server's clock is gone, whatever this device's clock says"))


func test_a_failed_fetch_waits_and_says_so() -> void:
	var sheets := host()
	isolated(func() -> void:
		Online.token = "test-token"
		Online.user = { "id": "user-a" }
		# Signed in, no letters fetched yet, and offline.
		check(InboxSheet._due(InboxSheet.OPEN_REFRESH_SECONDS), "never asked: due")
		var changed: bool = await InboxSheet.refresh(InboxSheet.OPEN_REFRESH_SECONDS)
		check(not changed and not InboxSheet._try_ok, "the try fails offline")
		check(not InboxSheet._due(InboxSheet.OPEN_REFRESH_SECONDS) and not InboxSheet._due(InboxSheet.REFRESH_SECONDS), "and the next waits a minute")
		var tried := InboxSheet._tried_at
		for i in 3:
			await InboxSheet.refresh()
		eq(InboxSheet._tried_at, tried, "however often it is asked")
		var inbox := InboxSheet.new()
		sheets.add_child(inbox)
		eq(inbox.body.get_child(0).get_child(1).text, "Letters arrive when you're online", "the empty inbox says so instead of 'Fetching'")
		inbox.free()
		# Another account is asked for at once, and then waits too.
		Online.user = { "id": "user-b" }
		check(InboxSheet._due(InboxSheet.OPEN_REFRESH_SECONDS), "another account: due")
		await InboxSheet.refresh()
		check(InboxSheet._tried_for == "user-b" and not InboxSheet._due(InboxSheet.OPEN_REFRESH_SECONDS), "and it waits after its own failed try"))


func test_a_letter_pays_once() -> void:
	isolated(func() -> void:
		var t := now()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300), letter(2, 250, t - 200), letter(3, 0, t - 100)], float(t), "user-a", false)
		var w := Game.wallet()
		var start := w.coins
		var st := InboxSheet._state()
		st["pending"] = { "1": "key-one-000000", "2": "key-two-000000" }
		var out := InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 100.0 } })
		eq([out["ok"], out["coins"], w.coins - start], [true, 100, 100], "the first answer pays")
		check(InboxSheet.claimed_record().has("1") and not (st["pending"] as Dictionary).has("1"), "recorded, and its key forgotten")
		check(InboxSheet.is_claimed(InboxSheet.letters()[0]), "and the copy shows it claimed")
		out = InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 100.0, "repeat": true } })
		eq([out["coins"], w.coins - start], [0, 100], "a repeated answer never pays twice")
		out = InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 0.0, "already": true } })
		eq(w.coins - start, 100, "nor does 'already'")
		out = InboxSheet.settle(2, { "ok": false, "status": 0, "error": "offline" })
		check(not out["ok"] and (st["pending"] as Dictionary).has("2") and not InboxSheet.claimed_record().has("2"), "offline: nothing paid, the key is kept for the retry")
		out = InboxSheet.settle(2, { "ok": false, "status": 429, "data": { "error": "slow down" } })
		check((st["pending"] as Dictionary).has("2"), "rate-limited: the key is kept")
		out = InboxSheet.settle(2, { "ok": true, "status": 200, "data": { "coins": 250.0, "repeat": true } })
		eq(w.coins - start, 350, "the repeat of a claim whose answer was lost pays, once")
		out = InboxSheet.settle(3, { "ok": true, "status": 200, "data": { "coins": 0.0 } })
		eq([out["ok"], InboxSheet.claimed_record().get("3")], [true, 0], "a message is claimed as read")
		out = InboxSheet.settle(9, { "ok": true, "status": 200, "data": { "coins": 99999.0 } })
		eq(w.coins - start, 350 + InboxSheet.MAX_COINS, "a garbled amount is capped at the server's limit")
		out = InboxSheet.settle(10, { "ok": true, "status": 200, "data": { "coins": "100" } })
		eq(w.coins - start, 350 + InboxSheet.MAX_COINS, "an amount that isn't a number pays nothing"))


func test_a_claim_record_survives_cloud_saves_and_new_accounts() -> void:
	isolated(func() -> void:
		var t := now()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300)], float(t), "user-a", false)
		InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 100.0 } })
		var paid := Game.wallet().coins
		# The cloud save keeps the profile as JSON; a conflict that keeps this copy brings it back.
		Game.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(Game.profile.to_dict())))
		eq(Game.wallet().coins, paid, "the coins came back with the profile")
		check(InboxSheet.claimed_record().has("1"), "and so did the record")
		# A new guest account (logout, account deletion) keeps the profile but is a new player to
		# the server, which lists the letter for everyone as unclaimed again.
		Online.user = { "id": "user-b" }
		InboxSheet.adopt([letter(1, 100, t - 300)], float(t), "user-b", false)
		eq(InboxSheet.unclaimed_count(), 0, "this profile doesn't see it waiting again")
		InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 100.0 } })
		eq(Game.wallet().coins, paid, "and isn't paid again even if the new account claims it"))


func test_test_builds_keep_letters_apart() -> void:
	isolated(func() -> void:
		var t := now()
		Online.token = "test-token"
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 200, t - 300)], float(t), "user-a", false)
		# A test-money build on the real server only shows letters: nothing is sent or kept.
		Online.api_url = PRODUCTION_API
		check(not InboxSheet.can_claim(), "a test build on the real server doesn't claim")
		var out: Dictionary = await InboxSheet.claim(1)
		check(not out["ok"] and bool(out.get("test_build", false)), "claim() says why: %s" % out)
		check(InboxSheet._pending().is_empty() and InboxSheet._claiming.is_empty(), "no key made, nothing on its way")
		eq(Game.profile.test_wallet.coins + Game.profile.wallet.coins, 0, "and nothing paid")
		var sheets := host()
		var inbox := InboxSheet.new()
		sheets.add_child(inbox)
		var button: Button = inbox._buttons.get(1)
		check(button != null and button.disabled, "the Claim button is off")
		var lines: Array = find_labels(inbox.body, []).filter(func(l: Label) -> bool: return l.text == InboxSheet.TEST_BUILD_WORDS)
		check(not lines.is_empty(), "and the footer says letters are claimed in the released game")
		inbox.free()
		# Pointed at another server it claims, into the test wallet and a record of its own.
		Online.api_url = "http://127.0.0.1:9"
		check(InboxSheet.can_claim(), "a test build on another server claims")
		InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 200.0 } })
		eq([Game.profile.test_wallet.coins, Game.profile.wallet.coins], [200, 0], "into the test wallet")
		check(Game.profile.state("inbox_test").get("claimed", {}).has("1") and not Game.profile.state("inbox").has("claimed"), "recorded apart")
		# The released game still owes the real wallet that letter.
		Game.money_mode = "off"
		check(InboxSheet.can_claim() and not InboxSheet.claimed_record().has("1"), "a release build has no record of it")
		InboxSheet._copy["letters"][0]["claimed"] = false
		InboxSheet.settle(1, { "ok": true, "status": 200, "data": { "coins": 200.0 } })
		eq([Game.profile.test_wallet.coins, Game.profile.wallet.coins], [200, 200], "and pays the real wallet"), 3, "test")


func find_labels(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		find_labels(child, out)
	return out


func test_a_gone_or_expired_letter_lets_go() -> void:
	isolated(func() -> void:
		var t := now()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300), letter(2, 50, t - 200)], float(t), "user-a", false)
		var st := InboxSheet._state()
		st["pending"] = { "1": "key-one-000000", "2": "key-two-000000" }
		var out := InboxSheet.settle(1, { "ok": false, "status": 410, "data": { "error": "That letter has expired." } })
		eq([out["ok"], out["error"]], [false, "That letter has expired."], "expired, in plain words")
		out = InboxSheet.settle(2, { "ok": false, "status": 404, "data": {} })
		eq(out["error"], "That letter isn't in your inbox any more.", "gone, in plain words")
		eq(st["pending"], {}, "no keys left behind")
		eq(InboxSheet.letters(), [], "both leave the inbox")
		eq(InboxSheet.claimed_record(), {}, "and nothing is recorded as paid"))


func test_the_sheets_build() -> void:
	var sheets := host()
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.adopt([item(1, "whats_new", t - DAY, null, "shop", "purple"), item(2, "news", t - 60, null, "collection"),
			item(3, "banner", t - 30, float(t + DAY), "daily", "gold"), item(4, "news", t - 10, null, "https://example.com/x")], float(t), false)
		# Everything read already, so opening the sheet has nothing to save.
		Game.profile.state("playbill")["read"] = { "1": true, "2": true, "3": true, "4": true }
		Game.profile.state("playbill")["whats_new"] = { "1": true }
		var playbill := PlaybillSheet.new()
		sheets.add_child(playbill)
		check(playbill._cards != null and playbill._cards.get_child_count() == 3, "three cards on the first page")
		playbill._turn(1)
		eq(playbill.page, 1, "a second page")
		playbill.free()
		var note := PlaybillSheet.new("whats_new")
		sheets.add_child(note)
		eq(note.heading.text, "What's new", "What's new opens the note in full")
		note.free()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300), letter(2, 0, t - 200), letter(3, 50, t - 100, null, true)], float(t), "user-a", false)
		var inbox := InboxSheet.new()
		sheets.add_child(inbox)
		check(inbox._rows != null and inbox._rows.get_child_count() == 3, "three letters")
		eq(inbox._buttons.size(), 2, "a button for each letter still waiting")
		inbox.free())


func test_a_card_in_full_fits_the_stage_at_every_text_size() -> void:
	var sheets := host()
	isolated(func() -> void:
		var t := now()
		var long := item(1, "news", t - 60, null, "collection", "teal")
		long["title"] = words(80)
		long["body"] = words(600)
		PlaybillSheet.adopt([long, item(2, "news", t - 120)], float(t), false)
		Game.profile.state("playbill")["read"] = { "1": true, "2": true }
		for size: int in [0, 1, 2]:
			Settings.size = size
			UiTheme.build()
			var sheet := PlaybillSheet.new("1")
			sheets.add_child(sheet)
			var scroll := sheet.body.find_child("Words", true, false) as ScrollContainer
			check(scroll != null and scroll.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == long["body"]), "text size %d: all 600 characters, in a scroll area" % size)
			eq(unbounded_labels(sheet.body, false, []), [], "text size %d: no words that can grow outside it" % size)
			var buttons: Array = find_buttons(sheet.body, []).filter(func(b: Button) -> bool: return b.text in ["See the Jesters", "All news"])
			check(buttons.size() == 2 and scroll != null and buttons.all(func(b: Button) -> bool: return not scroll.is_ancestor_of(b)), "text size %d: its button and the way back stay outside it" % size)
			sheet.free()
		Settings.size = 1
		UiTheme.build())


func test_a_letter_in_full_fits_the_stage_at_every_text_size() -> void:
	var sheets := host()
	isolated(func() -> void:
		var t := now()
		var long := letter(1, 200, t - 300)
		long["title"] = words(80)
		long["body"] = words(600)
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([long, letter(2, 0, t - 200)], float(t), "user-a", false)
		for size: int in [0, 1, 2]:
			Settings.size = size
			UiTheme.build()
			var inbox := InboxSheet.new()
			sheets.add_child(inbox)
			check(inbox._rows != null, "text size %d: the list first" % size)
			check(unbounded_labels(inbox.body, false, []).is_empty(), "text size %d: the list's rows show two lines each" % size)
			inbox.open_letter(1)
			var scroll := inbox.body.find_child("Words", true, false) as ScrollContainer
			check(scroll != null and scroll.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == long["body"]), "text size %d: all 600 characters, in a scroll area" % size)
			eq(unbounded_labels(inbox.body, false, []), [], "text size %d: no words that can grow outside it" % size)
			var button: Button = inbox._buttons.get(1)
			check(button != null and button.text == "Claim" and not button.disabled and not scroll.is_ancestor_of(button), "text size %d: with its Claim button below the words" % size)
			var back: Array = find_buttons(inbox.body, []).filter(func(b: Button) -> bool: return b.text == "All letters")
			check(back.size() == 1 and not scroll.is_ancestor_of(back[0]), "text size %d: and the way back" % size)
			inbox._show_all()
			check(inbox._rows != null and inbox._focus == 0, "text size %d: back to the list" % size)
			inbox.free()
		Settings.size = 1
		UiTheme.build())


func test_an_inbox_opened_during_a_claim_shows_how_it_ended() -> void:
	var sheets := host()
	isolated(func() -> void:
		var t := now()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 200, t - 300), letter(2, 50, t - 200)], float(t), "user-a", false)
		# A claim sent from an inbox that has since closed is still on its way.
		InboxSheet._claiming[1] = true
		var inbox := InboxSheet.new()
		sheets.add_child(inbox)
		var button: Button = inbox._buttons.get(1)
		check(button != null and button.disabled and button.text == "Claiming…", "the reopened inbox waits for it")
		# It fails (offline): the button comes back.
		InboxSheet._claiming.erase(1)
		InboxSheet._claims.ended.emit(1, { "ok": false, "coins": 0, "status": 0, "error": "offline" })
		button = inbox._buttons.get(1)
		check(button != null and not button.disabled and button.text == "Claim", "and offers Claim again when it fails")
		# Another one pays: the inbox shows it, with the coins.
		InboxSheet._claiming[2] = true
		inbox.rebuild()
		InboxSheet._claiming.erase(2)
		InboxSheet.settle(2, { "ok": true, "status": 200, "data": { "coins": 50.0 } })
		InboxSheet._claims.ended.emit(2, { "ok": true, "coins": 50, "status": 200, "error": "" })
		check(not inbox._buttons.has(2), "a paid letter has no button left")
		var texts: Array = find_labels(inbox.body, []).map(func(l: Label) -> String: return l.text)
		check(texts.has("+50") and texts.has("Added 50 coins."), "it shows what was paid: %s" % [texts])
		inbox.free()
		check(InboxSheet._claims.ended.get_connections().is_empty(), "a closed inbox stops listening"))
