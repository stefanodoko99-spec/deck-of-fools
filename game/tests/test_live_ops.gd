extends "res://tests/suite.gd"
## The Playbill (PlaybillSheet) and the inbox (InboxSheet): items and letters from the server
## are checked and kept, banners and dots count the right things, What's new shows once and
## only to returning players, and a letter pays its coins once per profile whatever the
## server answers. Game.profile is swapped for a test profile, the copies are kept in memory
## (cache_path ""), and nothing here saves: adopt(..., false) and settle() never do.

const DAY := 86400


## Runs `body` with a fresh test profile, memory-only copies and the guide finished, then
## puts everything back.
func isolated(body: Callable, runs_played := 3) -> void:
	var saved_profile: Profile = Game.profile
	var saved_step := Settings.tutorial_step
	var saved_motion := Settings.reduce_motion
	var saved_paths := [PlaybillSheet.cache_path, InboxSheet.cache_path]
	var saved_copies := [PlaybillSheet._copy, PlaybillSheet._copy_loaded, InboxSheet._copy, InboxSheet._copy_loaded]
	var saved_user: Dictionary = Online.user
	Game.profile = Profile.new()
	Game.profile.runs_played = runs_played
	Settings.tutorial_step = -1
	Settings.reduce_motion = true
	PlaybillSheet.cache_path = ""
	InboxSheet.cache_path = ""
	PlaybillSheet._copy = {}
	InboxSheet._copy = {}
	Online.user = {}
	body.call()
	Game.profile = saved_profile
	Settings.tutorial_step = saved_step
	Settings.reduce_motion = saved_motion
	PlaybillSheet.cache_path = saved_paths[0]
	InboxSheet.cache_path = saved_paths[1]
	PlaybillSheet._copy = saved_copies[0]
	PlaybillSheet._copy_loaded = saved_copies[1]
	InboxSheet._copy = saved_copies[2]
	InboxSheet._copy_loaded = saved_copies[3]
	Online.user = saved_user


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
			{ "id": 3, "kind": "advert", "title": "Not a kind", "starts_at": t - 10 },
			{ "id": 4, "kind": "news", "title": "   ", "starts_at": t - 10 },
			{ "id": -1, "kind": "news", "title": "Bad id", "starts_at": t - 10 },
			"not even an item",
		]
		check(PlaybillSheet.adopt(list, float(t), false), "a new list changes the copy")
		check(not PlaybillSheet.adopt(list, float(t), false), "the same list again doesn't")
		var shown := PlaybillSheet.items()
		eq(ids(shown), [9, 8, 6, 7, 5, 2], "newest first by start time, then id; unusable items dropped")
		var by_id := {}
		for i: Dictionary in shown:
			by_id[int(i["id"])] = i
		eq(by_id[9]["action"], "", "a javascript: action is dropped")
		eq(by_id[9]["colour"], "", "an unknown colour is dropped")
		eq(by_id[8]["action"], "", "a link with a space is dropped")
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
		], float(server), false)
		eq(ids(PlaybillSheet.items()), [4, 1], "started and not ended by the server's clock (same start: higher id first)")
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


func test_whats_new_shows_once_and_only_to_returning_players() -> void:
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.adopt([item(4, "whats_new", t - DAY), item(2, "whats_new", t - 3 * DAY)], float(t), false)
		var st := Game.profile.state("playbill")
		check(not st.has("whats_new_seen"), "a returning player gets no mark from the list")
		check(PlaybillSheet.should_show_whats_new(), "a returning player sees What's new")
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 4, "the newest note")
		Settings.tutorial_step = 2
		check(not PlaybillSheet.should_show_whats_new(), "never during the guided first run")
		Settings.tutorial_step = -1
		st["whats_new_seen"] = 4
		check(not PlaybillSheet.should_show_whats_new(), "once shown, not again")
		PlaybillSheet.adopt([item(6, "whats_new", t - 60), item(4, "whats_new", t - DAY)], float(t), false)
		eq(int(PlaybillSheet.whats_new_item().get("id", 0)), 6, "the next update's note shows once more"))
	var new_player := func() -> void:
		var t := now()
		check(not PlaybillSheet.should_show_whats_new(), "a new player before any list: no")
		PlaybillSheet.adopt([item(4, "whats_new", t - DAY), item(1, "news", t)], float(t), false)
		eq(Game.profile.state("playbill").get("whats_new_seen"), 4, "a new player's first list sets their mark to its newest note")
		Game.profile.runs_played = 1
		check(not PlaybillSheet.should_show_whats_new(), "so the game they started with is never 'new'")
		PlaybillSheet.adopt([item(7, "whats_new", t - 10), item(4, "whats_new", t - DAY)], float(t), false)
		check(PlaybillSheet.should_show_whats_new(), "but a later update's note is")
	isolated(new_player, 0)


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


func test_letters_count_and_expire_by_the_server_clock() -> void:
	isolated(func() -> void:
		var t := now()
		InboxSheet.adopt([
			letter(1, 100, t - 300),
			letter(2, 0, t - 200),
			letter(3, 50, t - 100, null, true),
			letter(4, 40, t - 900, float(t - 5)),
			letter(5, 75, t + 3600),
		], float(t), "user-a", false)
		eq(InboxSheet.letters(), [], "another account's copy is never shown")
		Online.user = { "id": "user-a" }
		eq(ids(InboxSheet.letters()), [1, 2, 3], "not expired, delivered, in the server's order")
		eq(InboxSheet.unclaimed_count(), 2, "coins to claim and an unread message; not one claimed on the server")
		Game.profile.state("inbox")["claimed"] = { "2": 0 }
		eq(InboxSheet.unclaimed_count(), 1, "nor one in this profile's record")
		InboxSheet.adopt([letter(1, 100, t - 300, float(t + 1800))], float(t + 3600), "user-a", false)
		eq(InboxSheet.letters(), [], "a letter expired by the server's clock is gone, whatever this device's clock says"))


func test_a_letter_pays_once() -> void:
	isolated(func() -> void:
		var t := now()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300), letter(2, 250, t - 200), letter(3, 0, t - 100)], float(t), "user-a", false)
		var w := Game.wallet()
		var start := w.coins
		var st := Game.profile.state("inbox")
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


func test_a_gone_or_expired_letter_lets_go() -> void:
	isolated(func() -> void:
		var t := now()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300), letter(2, 50, t - 200)], float(t), "user-a", false)
		var st := Game.profile.state("inbox")
		st["pending"] = { "1": "key-one-000000", "2": "key-two-000000" }
		var out := InboxSheet.settle(1, { "ok": false, "status": 410, "data": { "error": "That letter has expired." } })
		eq([out["ok"], out["error"]], [false, "That letter has expired."], "expired, in plain words")
		out = InboxSheet.settle(2, { "ok": false, "status": 404, "data": {} })
		eq(out["error"], "That letter isn't in your inbox any more.", "gone, in plain words")
		eq(st["pending"], {}, "no keys left behind")
		eq(InboxSheet.letters(), [], "both leave the inbox")
		eq(InboxSheet.claimed_record(), {}, "and nothing is recorded as paid"))


func test_the_sheets_build() -> void:
	UiTheme.build()
	# The runner's scene: the tests run inside its _ready, while the root is still busy
	# adding it, so the root can't take children yet.
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	isolated(func() -> void:
		var t := now()
		PlaybillSheet.adopt([item(1, "whats_new", t - DAY, null, "shop", "purple"), item(2, "news", t - 60, null, "collection"),
			item(3, "banner", t - 30, float(t + DAY), "daily", "gold"), item(4, "news", t - 10, null, "https://example.com/x")], float(t), false)
		# Everything read already, so opening the sheet has nothing to save.
		Game.profile.state("playbill")["read"] = { "1": true, "2": true, "3": true, "4": true }
		Game.profile.state("playbill")["whats_new_seen"] = 1
		var playbill := PlaybillSheet.new()
		host.add_child(playbill)
		check(playbill._cards != null and playbill._cards.get_child_count() == 3, "three cards on the first page")
		playbill._turn(1)
		eq(playbill.page, 1, "a second page")
		playbill.free()
		var note := PlaybillSheet.new("whats_new")
		host.add_child(note)
		eq(note.heading.text, "What's new", "What's new opens the note in full")
		note.free()
		Online.user = { "id": "user-a" }
		InboxSheet.adopt([letter(1, 100, t - 300), letter(2, 0, t - 200), letter(3, 50, t - 100, null, true)], float(t), "user-a", false)
		var inbox := InboxSheet.new()
		host.add_child(inbox)
		check(inbox._rows != null and inbox._rows.get_child_count() == 3, "three letters")
		eq(inbox._buttons.size(), 2, "a button for each letter still waiting")
		inbox.free())
