extends SceneTree
## Headless tests for the money core: Wallet, Economy, ShopCatalog, AdPolicy and the
## Encore in RunState. Run: <godot> --headless --path game -s tests/money_tests.gd
## (exit code 0 when everything passes). Pure logic only: nothing here touches the
## player's saved profile.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	if ContentDB.pool("deck").is_empty():
		ContentPacks.register_all()
	_wallet()
	_economy()
	_catalog()
	_ad_policy()
	_encore()
	print("money tests: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	quit(1 if failures.size() > 0 else 0)


func ok(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures.append(what)


func eq(got: Variant, want: Variant, what: String) -> void:
	checks += 1
	if got != want:
		failures.append("%s: got %s, want %s" % [what, str(got), str(want)])


func _wallet() -> void:
	var w := Wallet.new()
	w.earn("coins", 100)
	w.earn("diamonds", 7)
	w.earn("coins", -50)
	w.earn("gems", 10)
	eq(w.coins, 100, "earn adds coins, ignores negatives")
	eq(w.diamonds, 7, "earn adds diamonds, ignores unknown currencies")
	ok(not w.spend("coins", 101), "cannot overspend")
	eq(w.coins, 100, "failed spend leaves the balance")
	ok(not w.spend("coins", -5), "negative spend refused")
	ok(w.spend("coins", 40), "spend within balance")
	eq(w.coins, 60, "spend deducts")
	eq(w.coins_spent, 40, "spend is counted")
	w.earn("coins", Wallet.MAX_BALANCE)
	eq(w.coins, Wallet.MAX_BALANCE, "balance is capped")
	w.add_item("encore_ticket", 2)
	ok(w.use_item("encore_ticket"), "use an item")
	eq(w.item_count("encore_ticket"), 1, "item count goes down")
	ok(w.use_item("encore_ticket"), "use the last item")
	ok(not w.use_item("encore_ticket"), "no item left")
	ok(not w.items.has("encore_ticket"), "empty items are removed")
	ok(not w.is_payer(), "nobody paid yet")
	w.log_purchase("dof.diamonds.100", "test", true, "t1")
	ok(w.is_payer(), "a purchase makes a payer")
	(w.purchases[0] as Dictionary)["refunded"] = true
	ok(not w.is_payer(), "a refunded purchase doesn't count")
	w.grant("remove_ads")
	ok(w.is_payer(), "No intermissions counts as a supporter")
	w.roll_ad_day("2026-11-22")
	w.rewarded_today = 4
	w.roll_ad_day("2026-11-22")
	eq(w.rewarded_today, 4, "same day keeps ad counters")
	w.roll_ad_day("2026-11-23")
	eq(w.rewarded_today, 0, "a new day resets ad counters")
	for i in 60:
		w.log_purchase("x%d" % i, "test", true)
	eq(w.purchases.size(), Wallet.MAX_PURCHASE_LOG, "purchase log is capped")
	var round_trip := Wallet.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	eq(round_trip.to_dict(), w.to_dict(), "wallet survives a JSON round trip")
	var hostile := Wallet.from_dict({ "coins": -10, "diamonds": "12", "owned": "nope", "items": { "a": -3, "b": 2 }, "purchases": 5 })
	eq(hostile.coins, 0, "negative balance from a save is clamped")
	eq(hostile.diamonds, 12, "numeric strings are read")
	eq(hostile.items, { "b": 2 }, "bad item counts are dropped")
	ok(hostile.owned.is_empty() and hostile.purchases.is_empty(), "bad lists are ignored")


func _economy() -> void:
	eq(Economy.coins_for_show(0, 1), 5, "Matinee in town 1")
	eq(Economy.coins_for_show(2, 1), 15, "Patron in town 1")
	eq(Economy.coins_for_show(2, 8), 15 + 7 * Economy.TOWN_STEP, "Patron in town 8")
	eq(Economy.show_payout(10, false, 0), 10, "a show pays in full")
	eq(Economy.show_payout(10, true, 0), 5, "daily practice pays half")
	eq(Economy.show_payout(10, false, Economy.DAILY_SOFT_CAP), 3, "after the soft cap a show pays a quarter")
	eq(Economy.show_payout(1, true, Economy.DAILY_SOFT_CAP), 1, "a won show always pays something")
	eq(Economy.coins_for_run_win("quick"), 40, "quick run win")
	eq(Economy.coins_for_run_win("tour", 3), 100 + 2 * Economy.TOUR_STAKE_BONUS, "tour win grows with the stake")
	eq(Economy.coins_for_run_win("unknown"), Economy.RUN_WIN_COINS["tour"], "unknown mode pays like a tour")
	eq(Economy.album_milestones(24, 25), 1, "the 25th Jester is a milestone")
	eq(Economy.album_milestones(25, 49), 0, "no milestone between steps")
	eq(Economy.album_milestones(10, 60), 2, "two milestones at once")
	eq(Economy.gift_for(1), Economy.GIFTS[0], "day 1 gift")
	eq(Economy.gift_for(8), Economy.GIFTS[0], "the gift calendar repeats after day 7")
	eq(Economy.gift_for(0), Economy.GIFTS[0], "day 0 is treated as day 1")
	ok(Economy.is_next_day("2026-11-30", "2026-12-01"), "next day across a month")
	ok(Economy.is_next_day("2026-12-31", "2027-01-01"), "next day across a year")
	ok(not Economy.is_next_day("2026-11-20", "2026-11-22"), "a skipped day breaks the streak")
	ok(not Economy.is_next_day("", "2026-11-22"), "no earlier day")
	eq(Economy.today(), Time.get_date_string_from_system(true), "today is the UTC date, like the daily run")


func _catalog() -> void:
	var ids := {}
	var backs := {}
	for entry: Dictionary in ShopCatalog.ITEMS:
		ok(not ids.has(entry["id"]), "unique item id " + str(entry["id"]))
		ids[entry["id"]] = true
		ok(entry["currency"] in Wallet.CURRENCIES, "item currency " + str(entry["id"]))
		ok(int(entry["price"]) > 0, "item price " + str(entry["id"]))
		if entry["currency"] == "diamonds":
			eq(int(entry["price"]) % 100, 0, "diamond price is a multiple of 100: " + str(entry["id"]))
		ok(entry["kind"] != "coins", "coins are never sold: " + str(entry["id"]))
		if entry["kind"] == "card_back":
			ok(not backs.has(entry["back"]), "unique back index")
			backs[entry["back"]] = true
			ok(ShopCatalog.BACK_NAMES.has(int(entry["back"])), "named back %d" % int(entry["back"]))
	for p: Dictionary in ShopCatalog.PRODUCTS:
		ok(not ids.has(p["id"]), "unique product id " + str(p["id"]))
		ids[p["id"]] = true
		ok(str(p["id"]).begins_with("dof."), "store product id " + str(p["id"]))
		ok(float(p["usd"]) > 0.0, "reference price " + str(p["id"]))
		ok(not p.has("coins"), "no coins in paid products: " + str(p["id"]))
	eq(ShopCatalog.money_value(300), "about $2.97", "diamond prices show their money value at the base rate")
	var w := Wallet.new()
	ok(ShopCatalog.back_unlocked(0, w) and ShopCatalog.back_unlocked(5, w), "classic backs are free")
	ok(not ShopCatalog.back_unlocked(6, w), "premium back starts locked")
	ok(not ShopCatalog.back_unlocked(10, w), "the starter's back starts locked")
	eq(ShopCatalog.buy("back_gilded_sun", w), "Not enough coins.", "can't buy without coins")
	w.earn("coins", 2000)
	eq(ShopCatalog.buy("back_gilded_sun", w), "", "buy a back with coins")
	eq(w.coins, 1400, "the back's price is paid")
	ok(ShopCatalog.back_unlocked(6, w), "bought back is unlocked")
	eq(ShopCatalog.buy("back_gilded_sun", w), "Owned.", "a back can't be bought twice")
	eq(w.coins, 1400, "no charge for an owned back")
	eq(ShopCatalog.buy("nope", w), "Not for sale.", "unknown items")
	eq(ShopCatalog.buy("back_opera_night", w), "Not enough diamonds.", "diamond backs need diamonds")
	eq(ShopCatalog.deliver("dof.starter", w), "", "deliver the starter pack")
	ok(w.owns("back_starter_crest") and ShopCatalog.back_unlocked(10, w), "starter pack unlocks its back")
	eq(w.diamonds, 300, "starter pack diamonds")
	eq(w.coins, 1400, "starter pack holds no coins")
	eq(ShopCatalog.deliver("dof.starter", w), "Already bought.", "starter pack only once")
	eq(ShopCatalog.buy("back_opera_night", w), "", "buy a back with diamonds")
	eq(w.diamonds, 0, "diamonds paid")
	eq(ShopCatalog.deliver("dof.diamonds.500", w), "", "deliver diamonds")
	eq(w.diamonds, 500, "diamond pack credited")
	for pack: Dictionary in ShopCatalog.PRODUCTS:
		eq(int(pack.get("diamonds", 0)) % 100, 0, "pack size leaves no leftovers: " + str(pack["id"]))
	eq(ShopCatalog.deliver("dof.diamonds.500", w), "", "diamond packs can be bought again")
	eq(ShopCatalog.deliver("dof.remove_ads", w), "", "No intermissions")
	ok(w.owns("remove_ads"), "No intermissions owned")
	eq(ShopCatalog.deliver("dof.nothing", w), "Unknown product.", "unknown product")


func _ad_policy() -> void:
	var base := {
		"mode": "test", "now": 10000.0, "session_start": 0.0, "runs_finished": 10, "install_days": 30, "in_tutorial": false,
		"payer": false, "remove_ads": false, "last_intermission": -1.0, "last_rewarded": -1.0, "last_purchase": -1.0,
		"intermissions_session": 0, "intermissions_today": 0, "rewarded_today": 0, "town": 3,
	}
	eq(AdPolicy.check("town_break", base), "", "a town break is allowed when every rule passes")
	eq(AdPolicy.check("run_end", base), "", "a run-end intermission is allowed when every rule passes")
	eq(AdPolicy.check("encore", base), "", "a rewarded Encore is allowed")
	var off := base.duplicate()
	off["mode"] = "off"
	ok(AdPolicy.check("encore", off) != "" and AdPolicy.check("run_end", off) != "", "no ads when the mode is off")
	for case: Array in [
		["runs_finished", AdPolicy.NEW_PLAYER_RUNS - 1, "new players (few runs) get no intermissions"],
		["install_days", AdPolicy.NEW_PLAYER_DAYS - 1, "new players (recent install) get no intermissions"],
		["in_tutorial", true, "no intermissions in the guided run"],
		["payer", true, "no intermissions for payers"],
		["remove_ads", true, "no intermissions after No intermissions"],
		["session_start", 10000.0 - AdPolicy.SESSION_WARMUP + 1.0, "session warm-up"],
		["last_intermission", 10000.0 - AdPolicy.COOLDOWN + 1.0, "cooldown between intermissions"],
		["last_rewarded", 10000.0 - AdPolicy.AFTER_REWARDED + 1.0, "pause after a rewarded ad"],
		["last_purchase", 10000.0 - AdPolicy.AFTER_REWARDED + 1.0, "pause after a purchase"],
		["intermissions_session", AdPolicy.MAX_PER_SESSION, "session cap"],
		["intermissions_today", AdPolicy.MAX_PER_DAY, "daily cap"],
	]:
		var s := base.duplicate()
		s[case[0]] = case[1]
		ok(AdPolicy.check("town_break", s) != "", str(case[2]))
		ok(AdPolicy.check("run_end", s) != "", str(case[2]) + " (run end)")
	for town in [1, 2, 4, 6, 8]:
		var s := base.duplicate()
		s["town"] = town
		ok(AdPolicy.check("town_break", s) != "", "no town break into town %d" % town)
	for town in [3, 5, 7]:
		var s := base.duplicate()
		s["town"] = town
		eq(AdPolicy.check("town_break", s), "", "town break allowed into town %d" % town)
	var daily := base.duplicate()
	daily["ranked_daily"] = true
	ok(AdPolicy.check("town_break", daily) != "", "no town break in the ranked daily")
	ok(AdPolicy.check("encore", daily) != "", "no Encore in the ranked daily run")
	var cooled := base.duplicate()
	cooled["last_intermission"] = 10000.0 - AdPolicy.COOLDOWN - 1.0
	eq(AdPolicy.check("run_end", cooled), "", "intermission allowed after the cooldown")
	var used := base.duplicate()
	used["encore_used"] = true
	ok(AdPolicy.check("encore", used) != "", "one Encore per run")
	var doubled := base.duplicate()
	doubled["double_used"] = true
	ok(AdPolicy.check("double_coins", doubled) != "", "double coins only once per run")
	var tired := base.duplicate()
	tired["rewarded_today"] = AdPolicy.MAX_REWARDED_PER_DAY
	ok(AdPolicy.check("daily_gift", tired) != "", "rewarded ads have a daily cap")
	var tutorial := base.duplicate()
	tutorial["in_tutorial"] = true
	eq(AdPolicy.check("double_coins", tutorial), "", "a rewarded choice is still offered in the guide")
	ok(AdPolicy.check("banner", base) != "", "unknown placements are refused")


## Lose the first show on purpose (one low card per hand), then take an Encore.
func _encore() -> void:
	var run := RunState.create("ENCORETEST", "d_bergamo", 1)
	ok(run.apply({ "a": "select_show" })["ok"], "start the Matinee")
	var guard := 0
	while run.phase == RunState.Phase.IN_SHOW and guard < 50:
		guard += 1
		var lowest: PlayingCard = run.hand[0]
		for card: PlayingCard in run.hand:
			if card.rank < lowest.rank:
				lowest = card
		run.apply({ "a": "play", "cards": [lowest.id] })
	eq(run.phase, RunState.Phase.LOST, "single low cards lose the Matinee")
	ok(run.can_encore(), "an Encore is open after losing a show")
	var score := run.show_score
	var discards := run.discards_left
	ok(run.apply({ "a": "encore" })["ok"], "take the Encore")
	eq(run.phase, RunState.Phase.IN_SHOW, "the show goes on")
	eq(run.hands_left, Economy.ENCORE_HANDS, "Encore hands")
	eq(run.discards_left, discards + Economy.ENCORE_DISCARDS, "Encore discards")
	eq(run.show_score, score, "the score is kept")
	ok(run.hand.size() > 0, "a hand is dealt")
	eq(run.encores(), 1, "the Encore is counted")
	var saved := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(saved.encores(), 1, "the Encore count is saved")
	while run.phase == RunState.Phase.IN_SHOW and guard < 100:
		guard += 1
		run.apply({ "a": "play", "cards": [run.hand[0].id] })
	if run.phase == RunState.Phase.LOST:
		ok(not run.can_encore(), "only one Encore per run")
		ok(not run.apply({ "a": "encore" })["ok"], "a second Encore is refused")
	var given_up := RunState.create("GIVEUPTEST", "d_bergamo", 1)
	given_up.apply({ "a": "select_show" })
	given_up.phase = RunState.Phase.LOST
	ok(not given_up.can_encore(), "giving up doesn't offer an Encore")
