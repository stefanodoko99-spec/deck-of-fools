extends "res://tests/suite.gd"
## Daily goals: which goals a day and a week get (core/goal_defs.gd), how run events move
## them, claiming once, the weekly reward, the day changing, and the save (the Goals
## tracker, ui/goals_tracker.gd). Every test uses a tracker of its own on a fresh profile
## and wallet, so the player's profile is never read or written; nothing here emits
## Game.run_event either, which the live Goals autoload would count into the player's save.

const Tracker := preload("res://ui/goals_tracker.gd")
const DAY := "2026-11-22"
const EVENTS := ["hand_played", "discarded", "show_won", "show_lost", "jester_bought", "run_finished"]


## A tracker of its own, fixed to a day; call free() on it at the end of the test.
func tracker(on_day := DAY, p: Profile = null) -> Tracker:
	var t: Tracker = Tracker.new()
	t.profile = p if p != null else Profile.new()
	t.wallet = t.profile.wallet
	t.day = on_day
	return t


static func date_of(day_number: int) -> String:
	return Time.get_date_string_from_unix_time(day_number * 86400)


## The first day from DAY on whose goals include `goal_id` ("" if none within 40 days).
func day_with(goal_id: String) -> String:
	var start := GoalDefs.day_number(DAY)
	for i in 40:
		if GoalDefs.daily_for(date_of(start + i)).has(goal_id):
			return date_of(start + i)
	return ""


## A day (a Monday) of the first week from DAY on whose weekly goal is `goal_id`.
func week_with(goal_id: String) -> String:
	var start := GoalDefs.day_number(DAY)
	for i in 30:
		var monday := start + 7 * i - posmod(start + 3, 7)
		if GoalDefs.weekly_for(date_of(monday)) == goal_id:
			return date_of(monday)
	return ""


func find(goals: Array, goal_id: String) -> Dictionary:
	for g: Dictionary in goals:
		if g["goal"] == goal_id:
			return g
	return {}


func hand(hand_type: String, total := 120.0, town := 1) -> Dictionary:
	return { "hand": hand_type, "total": total, "points": 30.0, "mult": 4.0, "cards": 5, "show": 0, "town": town }


func show_won(show := 0, town := 1, hands_left := 1, discards_left := 0, hands_played := 3) -> Dictionary:
	return { "show": show, "town": town, "hands_left": hands_left, "discards_left": discards_left, "hands_played": hands_played, "coins": 5 }


# --- Which goals a day and a week get ---------------------------------------------


func test_the_pool_teaches_and_pays_within_bounds() -> void:
	var seen := {}
	for g: Dictionary in GoalDefs.POOL:
		var id := str(g["id"])
		check(not seen.has(id), "goal id %s is used twice" % id)
		seen[id] = true
		check(str(g["tier"]) in GoalDefs.DAILY_TIERS or str(g["tier"]) == GoalDefs.WEEKLY_TIER, "%s has an unknown tier" % id)
		check(str(g["text"]) != "" and str(g["hint"]) != "" and str(g["art"]) != "", "%s has its words and picture" % id)
		check(int(g["target"]) >= 1, "%s has a target" % id)
		var pays := GoalDefs.reward(g)
		if str(g["tier"]) == GoalDefs.WEEKLY_TIER:
			eq(pays, { "coins": 100, "diamonds": 10 }, "%s pays the weekly reward" % id)
		else:
			check(int(pays["coins"]) >= 30 and int(pays["coins"]) <= 80, "%s pays %d coins, outside 30-80" % [id, pays["coins"]])
			eq(int(pays["diamonds"]), 0, "%s pays no diamonds" % id)
		for kind: String in g["on"]:
			check(kind == "*" or EVENTS.has(kind), "%s listens to an unknown event '%s'" % [id, kind])
		var rule: Dictionary = g["rule"]
		if rule.has("contains"):
			check(HandTable.ORDER.has(str(rule["contains"])), "%s names an unknown hand" % id)
		var measure := str(g["measure"])
		check(measure == "count" or measure.begins_with("sum:") or measure.begins_with("best:"), "%s measures '%s'" % [id, measure])
	check(GoalDefs.POOL.size() >= 15 and GoalDefs.POOL.size() <= 25, "%d goals, not 15-25" % GoalDefs.POOL.size())
	for tier: String in GoalDefs.DAILY_TIERS + [GoalDefs.WEEKLY_TIER]:
		check(GoalDefs.ids(tier).size() >= 3, "the %s pool has at least 3 goals" % tier)
	for kind: String in HandTable.ORDER:
		eq(GoalDefs.CONTAINS.has(kind), true, "CONTAINS knows %s" % kind)
		check((GoalDefs.CONTAINS[kind] as Array).has(kind), "%s contains itself" % kind)


func test_three_distinct_daily_goals_the_same_for_everyone() -> void:
	var start := GoalDefs.day_number(DAY)
	var yesterday: Array[String] = []
	var dealt := {}
	for i in 120:
		var date := date_of(start + i)
		var goals := GoalDefs.daily_for(date)
		eq(goals, GoalDefs.daily_for(date), "%s deals the same goals every time" % date)
		eq(goals.size(), 3, "%s: three goals" % date)
		for slot in goals.size():
			eq(str(GoalDefs.goal(goals[slot])["tier"]), GoalDefs.DAILY_TIERS[slot], "%s goal %d is %s" % [date, slot, GoalDefs.DAILY_TIERS[slot]])
			check(not yesterday.has(goals[slot]), "%s repeats %s from the day before" % [date, goals[slot]])
			dealt[goals[slot]] = true
		check(goals[0] != goals[1] and goals[1] != goals[2] and goals[0] != goals[2], "%s: three different goals" % date)
		yesterday = goals
	for tier: String in GoalDefs.DAILY_TIERS:
		for id: String in GoalDefs.ids(tier):
			check(dealt.has(id), "%s was never dealt in 120 days" % id)
	note("%s: %s" % [DAY, ", ".join(GoalDefs.daily_for(DAY))])
	check(GoalDefs.daily_for("2026-11-23") != GoalDefs.daily_for(DAY), "the next day deals other goals")


func test_one_weekly_goal_per_monday_to_sunday_week() -> void:
	# 22 November 2026 is a Sunday: the 16th to the 22nd are ISO week 47.
	var week := GoalDefs.weekly_for("2026-11-16")
	for date: String in ["2026-11-17", "2026-11-19", "2026-11-22"]:
		eq(GoalDefs.weekly_for(date), week, "%s has the week's goal" % date)
		eq(GoalDefs.week_number(date), GoalDefs.week_number("2026-11-16"), "%s is in the same week" % date)
	eq(GoalDefs.week_number("2026-11-23"), GoalDefs.week_number("2026-11-22") + 1, "a new week starts on Monday")
	check(GoalDefs.weekly_for("2026-11-23") != week, "the next week has another goal")
	eq(str(GoalDefs.goal(week)["tier"]), "weekly", "the weekly goal comes from the weekly pool")
	eq(GoalDefs.week_label("2026-11-22"), "2026-W47", "ISO week of 22 November 2026")
	eq(GoalDefs.week_label("2026-11-23"), "2026-W48", "Monday 23 November")
	eq(GoalDefs.week_label("2026-12-28"), "2026-W53", "2026 has a week 53")
	eq(GoalDefs.week_label("2027-01-01"), "2026-W53", "1 January 2027 still belongs to 2026's last week")
	eq(GoalDefs.week_label("2027-01-04"), "2027-W01", "the first Monday of 2027")
	eq(GoalDefs.week_label("2026-01-01"), "2026-W01", "1 January 2026 is a Thursday, so in week 1")
	var weeks := {}
	var monday := GoalDefs.day_number("2026-11-16")
	for i in 12:
		weeks[GoalDefs.weekly_for(date_of(monday + 7 * i))] = true
	eq(weeks.size(), GoalDefs.ids("weekly").size(), "twelve weeks deal every weekly goal")


func test_refresh_times() -> void:
	var monday_noon := Time.get_unix_time_from_datetime_string("2026-11-23T12:00:00")
	eq(GoalDefs.seconds_to_next_day(monday_noon), 12 * 3600, "noon to midnight")
	eq(GoalDefs.seconds_to_next_week(monday_noon), 6 * 86400 + 12 * 3600, "Monday noon to next Monday")
	var sunday_late := Time.get_unix_time_from_datetime_string("2026-11-22T23:00:00")
	eq(GoalDefs.seconds_to_next_week(sunday_late), 3600, "Sunday 23:00 to Monday")
	eq(GoalsSheet.until(5 * 3600 + 59 * 60), "5 h", "hours, rounded down")
	eq(GoalsSheet.until(40 * 60), "40 min", "under an hour")
	eq(GoalsSheet.until(20), "1 min", "never zero minutes")
	eq(GoalsSheet.until(86400 + 5), "1 day", "a day")
	eq(GoalsSheet.until(3 * 86400 + 7200), "3 days", "days")


# --- How run events move goals ------------------------------------------------------


func test_goal_rules() -> void:
	var g := GoalDefs.goal("pairs_5")
	eq(GoalDefs.advance(g, 0, "hand_played", hand("pair")), 1, "a Pair counts")
	eq(GoalDefs.advance(g, 1, "hand_played", hand("full_house")), 2, "a Full House has a Pair")
	eq(GoalDefs.advance(g, 1, "hand_played", hand("flush")), 1, "a Flush has no Pair")
	eq(GoalDefs.advance(g, 1, "hand_played", hand("pair", 0.0)), 1, "a hand the Patron didn't allow scores nothing and doesn't count")
	eq(GoalDefs.advance(g, 5, "hand_played", hand("pair")), 5, "capped at the target")
	eq(GoalDefs.advance(g, 1, "discarded", hand("pair")), 1, "other events don't count")
	var flush := GoalDefs.goal("flush")
	eq(GoalDefs.advance(flush, 0, "hand_played", hand("straight_flush")), 1, "a Straight Flush is a Flush")
	eq(GoalDefs.advance(flush, 0, "hand_played", hand("straight")), 0, "a Straight is not")
	eq(GoalDefs.advance(GoalDefs.goal("three_kind_2"), 0, "hand_played", hand("full_house")), 1, "a Full House has Three of a Kind")
	var patron := GoalDefs.goal("patron")
	eq(GoalDefs.advance(patron, 0, "show_won", show_won(Shows.EVENING)), 0, "an Evening show is no Patron")
	eq(GoalDefs.advance(patron, 0, "show_won", show_won(Shows.PATRON)), 1, "a Patron beaten")
	eq(GoalDefs.advance(GoalDefs.goal("evening"), 0, "show_won", show_won(Shows.EVENING)), 1, "an Evening show won")
	var spare := GoalDefs.goal("spare_discard")
	eq(GoalDefs.advance(spare, 0, "show_won", show_won(0, 1, 1, 0)), 0, "no discard to spare")
	eq(GoalDefs.advance(spare, 0, "show_won", show_won(0, 1, 1, 2)), 1, "two discards to spare")
	var quick := GoalDefs.goal("two_hands")
	eq(GoalDefs.advance(quick, 0, "show_won", show_won(0, 1, 2, 0, 3)), 0, "three hands is too many")
	eq(GoalDefs.advance(quick, 0, "show_won", show_won(0, 1, 2, 0, 2)), 1, "two hands")
	var spare_hands := GoalDefs.goal("patron_spare")
	eq(GoalDefs.advance(spare_hands, 0, "show_won", show_won(Shows.PATRON, 2, 1)), 0, "one hand to spare")
	eq(GoalDefs.advance(spare_hands, 0, "show_won", show_won(Shows.PATRON, 2, 2)), 1, "two hands to spare")
	var big := GoalDefs.goal("hand_1000")
	eq(GoalDefs.advance(big, 0, "hand_played", hand("pair", 640.0)), 640, "the best hand so far")
	eq(GoalDefs.advance(big, 640, "hand_played", hand("pair", 300.0)), 640, "a smaller hand keeps the best")
	eq(GoalDefs.advance(big, 640, "hand_played", hand("flush", 2400.0)), 1000, "capped at 1,000")
	var town := GoalDefs.goal("town_3")
	eq(GoalDefs.advance(town, 0, "hand_played", { "town": 2, "reach": 2 }), 2, "in Town 2")
	eq(GoalDefs.advance(town, 2, "run_finished", { "town": 1, "reach": 1 }), 2, "a new run in Town 1 keeps the best")
	eq(GoalDefs.advance(GoalDefs.goal("sign"), 0, "show_won", { "signs": 1 }), 1, "a Sign seen with any event")
	eq(GoalDefs.advance(GoalDefs.goal("signs_3"), 1, "hand_played", { "signs": 2 }), 3, "Signs add up")
	var deck := GoalDefs.goal("deck")
	eq(GoalDefs.advance(deck, 0, "show_won", { "deck": "d_bergamo" }, { "deck": "d_venezia" }), 0, "another deck")
	eq(GoalDefs.advance(deck, 0, "show_won", { "deck": "d_venezia" }, { "deck": "d_venezia" }), 1, "the day's deck")
	eq(GoalDefs.advance(GoalDefs.goal("jesters_2"), 1, "jester_bought", { "id": "z_zanni" }), 2, "a Jester bought")
	eq(GoalDefs.advance(GoalDefs.goal("discards_4"), 0, "discarded", { "count": 3, "show": 0, "town": 1 }), 1, "a discard")


func test_run_events_move_todays_goals() -> void:
	var date := day_with("flush")
	if not check(date != "", "a day with the Flush goal"):
		return
	var t := tracker(date)
	var before := find(t.current(), "flush")
	eq([before["progress"], before["target"], before["done"], before["claimed"]], [0, 1, false, false], "a fresh goal")
	t.record("hand_played", hand("pair"))
	eq(find(t.current(), "flush")["progress"], 0, "a Pair is no Flush")
	t.record("hand_played", hand("flush"))
	var after := find(t.current(), "flush")
	check(after["done"] and not after["claimed"], "the Flush goal is done")
	eq(t.ready_count(), 1, "one goal ready to claim")
	# The current() shape the home screen relies on.
	eq(t.current().size(), 4, "three daily goals and the weekly one")
	for key: String in ["id", "text", "progress", "target", "coins", "done", "claimed", "kind", "hint", "art", "diamonds"]:
		check(after.has(key), "a goal has '%s'" % key)
	eq(after["id"], "flush@" + date, "ids name the goal and its day")
	eq([t.current()[0]["kind"], t.current()[3]["kind"]], ["daily", "weekly"], "daily goals first, then the weekly")
	t.free()


func test_reach_town_counts_beating_a_patron() -> void:
	var date := day_with("town_3")
	if not check(date != "", "a day with Reach Town 3"):
		return
	var t := tracker(date)
	t.record("hand_played", hand("pair", 50.0, 1))
	eq(find(t.current(), "town_3")["progress"], 1, "playing in Town 1")
	t.record("show_won", show_won(Shows.PATRON, 2))
	var g := find(t.current(), "town_3")
	eq(g["progress"], 3, "beating Town 2's Patron reaches Town 3")
	check(g["done"], "Town 3 reached")
	eq(GoalsSheet.progress_words(g), "Town 3 of 3", "said in towns")
	t.free()


func test_signs_and_deck_come_from_the_run() -> void:
	var date := day_with("sign")
	if not check(date != "", "a day with Use a Sign"):
		return
	var t := tracker(date)
	var run := RunState.create("GOALSIGN", "d_bergamo", 1)
	run.counters["hands_played"] = 1
	t.record("hand_played", hand("pair"), run)
	eq(find(t.current(), "sign")["progress"], 0, "no Sign used yet")
	run.counters["used_sign"] = 1
	t.record("discarded", { "count": 2, "show": 0, "town": 1 }, run)
	eq(find(t.current(), "sign")["progress"], 1, "the Sign used since the last event")
	t.free()
	# The same Sign isn't counted twice, also after a reload.
	var date3 := day_with("signs_3")
	if not check(date3 != "", "a day with Use 3 Signs"):
		return
	var p := Profile.new()
	var t3 := tracker(date3, p)
	var run3 := RunState.create("GOALSIGN3", "d_bergamo", 1)
	run3.counters["hands_played"] = 2
	run3.counters["used_sign"] = 1
	t3.record("hand_played", hand("pair"), run3)
	t3.record("hand_played", hand("pair"), run3)
	eq(find(t3.current(), "signs_3")["progress"], 1, "one Sign, seen twice, counts once")
	t3.free()
	var reloaded := tracker(date3, Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict()))))
	run3.counters["hands_played"] = 3
	reloaded.record("show_won", show_won(), run3)
	eq(find(reloaded.current(), "signs_3")["progress"], 1, "nor after a reload")
	# A practice restart: same seed, fewer hands played, its own Sign.
	var again := RunState.create("GOALSIGN3", "d_bergamo", 1)
	again.counters["hands_played"] = 1
	again.counters["used_sign"] = 1
	reloaded.record("hand_played", hand("pair"), again)
	eq(find(reloaded.current(), "signs_3")["progress"], 2, "a new run on the same seed counts its own Sign")
	reloaded.free()
	# The deck goal asks for today's daily-run deck, read from the run that won the show.
	var date_deck := day_with("deck")
	if not check(date_deck != "", "a day with the deck goal"):
		return
	var td := tracker(date_deck)
	var deck := str(Online.daily_setup(date_deck)["deck"])
	var other := "d_venezia" if deck != "d_venezia" else "d_bergamo"
	var g := find(td.current(), "deck")
	check(str(g["text"]).contains(UiTheme.name_of(deck)), "'%s' names the %s deck" % [g["text"], deck])
	td.record("show_won", show_won(), RunState.create("GOALDECK", other, 1))
	eq(find(td.current(), "deck")["progress"], 0, "a show won with another deck")
	td.record("show_won", show_won(), RunState.create("GOALDECK", deck, 1))
	eq(find(td.current(), "deck")["progress"], 1, "a show won with the day's deck")
	note("%s: %s" % [date_deck, g["text"]])
	td.free()


# --- Claiming -------------------------------------------------------------------------


func test_claim_pays_once() -> void:
	var date := day_with("shows_3")
	if not check(date != "", "a day with Win 3 shows"):
		return
	var t := tracker(date)
	var g := find(t.current(), "shows_3")
	eq(t.claim(str(g["id"])), 0, "an unfinished goal can't be claimed")
	for i in 3:
		t.record("show_won", show_won())
	var coins_before := t.wallet.coins
	var paid := t.claim(str(g["id"]))
	eq(paid, int(GoalDefs.goal("shows_3")["coins"]), "pays the goal's coins")
	eq(t.wallet.coins, coins_before + paid, "into the wallet")
	eq(t.claim(str(g["id"])), 0, "a second claim pays nothing")
	eq(t.wallet.coins, coins_before + paid, "the wallet is paid once")
	check(find(t.current(), "shows_3")["claimed"], "marked as claimed")
	t.record("show_won", show_won())
	eq(find(t.current(), "shows_3")["progress"], 3, "a claimed goal stays as it was")
	eq(t.claim("nonsense@" + date), 0, "an unknown id pays nothing")
	eq(t.claim("shows_3@2020-01-01"), 0, "nor does another day's")
	t.free()


func test_weekly_goal_pays_coins_and_diamonds() -> void:
	var date := week_with("week_four_kind")
	if not check(date != "", "a week with Score Four of a Kind"):
		return
	var t := tracker(date)
	var weekly: Dictionary = t.current()[3]
	eq([weekly["goal"], weekly["kind"], weekly["coins"], weekly["diamonds"]], ["week_four_kind", "weekly", 100, 10], "the weekly goal")
	t.record("hand_played", hand("five_kind", 3000.0))
	check(t.current()[3]["done"], "Five of a Kind has Four of a Kind")
	var coins := t.wallet.coins
	var gems := t.wallet.diamonds
	eq(t.claim(str(weekly["id"])), 100, "100 coins")
	eq([t.wallet.coins - coins, t.wallet.diamonds - gems], [100, 10], "and 10 diamonds")
	eq(t.claim(str(weekly["id"])), 0, "once")
	# Later days of the same week keep it; the Monday after deals a new one.
	t.day = date_of(GoalDefs.day_number(date) + 6)
	check(t.current()[3]["claimed"], "still claimed on Sunday")
	t.day = date_of(GoalDefs.day_number(date) + 7)
	var next: Dictionary = t.current()[3]
	check(next["goal"] != "week_four_kind" and next["progress"] == 0 and not next["claimed"], "a new weekly goal on Monday")
	t.free()


# --- New days, and the save -----------------------------------------------------------


func test_a_new_day_keeps_finished_goals_and_lets_the_rest_go() -> void:
	var date := day_with("discards_4")
	if not check(date != "", "a day with Use 4 discards"):
		return
	var t := tracker(date)
	for i in 4:
		t.record("discarded", { "count": 2, "show": 0, "town": 1 })
	t.record("hand_played", hand("pair"))
	var finished := find(t.current(), "discards_4")
	check(finished["done"], "finished, not claimed")
	t.day = date_of(GoalDefs.day_number(date) + 1)
	var today := t.current()
	eq(today.size(), 4, "a new day's goals")
	for i in 3:
		eq([today[i]["progress"], today[i]["claimed"], today[i]["period"]], [0, false, t.day], "new goal %d starts fresh" % i)
	var waiting := t.earlier()
	eq(waiting.size(), 1, "only the finished goal waits; unfinished ones simply go")
	eq([waiting[0]["id"], waiting[0]["done"], waiting[0]["coins"]], [finished["id"], true, finished["coins"]], "the goal waiting")
	check(t.ready_count() >= 1, "it counts as ready")
	var coins := t.wallet.coins
	eq(t.claim(str(finished["id"])), int(finished["coins"]), "claimed a day later")
	eq(t.wallet.coins - coins, int(finished["coins"]), "paid")
	eq(t.earlier().size(), 0, "and gone from the earlier goals")
	eq(t.claim(str(finished["id"])), 0, "once")
	# The clock turned back deals nothing new: the newer goals stay.
	var newer := t.current()
	t.day = date
	eq(t.current(), newer, "a clock set back keeps the goals")
	t.free()


func test_a_long_break_never_loses_coins() -> void:
	var t := tracker()
	var start := GoalDefs.day_number(DAY)
	var finished := 0
	var paid := 0
	for i in 8:
		t.day = date_of(start + i)
		for g: Dictionary in t.current():
			if g["kind"] == "daily":
				finished += 1
				paid += int(g["coins"])
		# Finish all three daily goals by hand (as if played), without claiming.
		var state: Dictionary = t.profile.state("goals")
		for entry: Dictionary in state["daily"]:
			entry["progress"] = entry["target"]
	t.day = date_of(start + 8)
	var waiting := t.earlier()
	eq(waiting.size(), Tracker.MAX_EARLIER, "at most %d goals wait" % Tracker.MAX_EARLIER)
	var before_claim := t.wallet.coins
	var claimed := t.claim_earlier()
	eq(int(claimed["coins"]), t.wallet.coins - before_claim, "Claim pays the goals waiting")
	eq(t.wallet.coins, paid, "all %d finished goals paid: the oldest by themselves, the rest when claimed" % finished)
	eq(t.earlier().size(), 0, "nothing waits after Claim")
	t.free()


func test_profile_round_trip() -> void:
	var p := Profile.new()
	var date := day_with("pairs_5")
	if not check(date != "", "a day with Play 5 hands with a Pair"):
		return
	var t := tracker(date, p)
	for i in 2:
		t.record("hand_played", hand("two_pair"))
	for i in 3:
		t.record("show_won", show_won(Shows.PATRON, 1))
	var claimable: Array = t.current().filter(func(g: Dictionary) -> bool: return g["done"])
	for g: Dictionary in claimable:
		t.claim(str(g["id"]))
	var shown := t.current()
	t.free()
	for copy: Profile in [Profile.from_dict(p.to_dict()), Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))]:
		var back := tracker(date, copy)
		eq(back.current(), shown, "the goals after a save and load")
		eq(back.wallet.coins, p.wallet.coins, "the coins paid")
		eq(typeof(back.current()[0]["progress"]), TYPE_INT, "progress is a whole number again")
		for g: Dictionary in claimable:
			eq(back.claim(str(g["id"])), 0, "%s stays claimed" % g["id"])
		back.record("hand_played", hand("pair"))
		eq(find(back.current(), "pairs_5")["progress"], mini(5, int(find(shown, "pairs_5")["progress"]) + 1), "and keeps counting")
		back.free()
	eq(Profile.from_dict(p.to_dict()).to_dict(), p.to_dict(), "the profile itself round-trips")


func test_the_autoload_listens_to_run_events() -> void:
	check(Game.run_event.is_connected(Goals._on_run_event), "Goals counts Game.run_event")
	eq(Goals.profile, null, "the live tracker keeps the player's own profile")


## Every Label's and Button's text under a node.
func texts(node: Node, out: Array[String] = []) -> Array[String]:
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		texts(child, out)
	return out


func buttons(node: Node, text: String, out: Array[Button] = []) -> Array[Button]:
	for child in node.get_children():
		if child is Button and (child as Button).text == text:
			out.append(child)
		buttons(child, text, out)
	return out


func test_the_sheet_shows_the_goals_and_claims() -> void:
	# The live Goals autoload, pointed at a test profile and wallet for this test only, so
	# the sheet (which reads Goals) is built for real and nothing reaches the player's save.
	var date := day_with("flush")
	if not check(date != "", "a day with the Flush goal"):
		return
	UiTheme.build()
	var kept: Array = [Goals.profile, Goals.wallet, Goals.day]
	var p := Profile.new()
	Goals.profile = p
	Goals.wallet = p.wallet
	Goals.day = date
	Goals.record("hand_played", hand("flush"))
	var sheet := GoalsSheet.new()
	# Under the test runner's own node: the root is still busy adding it while tests run.
	var root := (Engine.get_main_loop() as SceneTree).root
	root.get_child(root.get_child_count() - 1).add_child(sheet)
	var shown := texts(sheet)
	for g: Dictionary in Goals.current():
		check(shown.has(str(g["text"])), "the sheet shows '%s'" % g["text"])
	check(shown.has("This week") and shown.has("Today"), "the sections")
	check(shown.any(func(t: String) -> bool: return t.begins_with("New goals in ")), "when new goals come")
	var claims := buttons(sheet, "Claim")
	eq(claims.size(), 1, "one goal to claim")
	if claims.size() == 1:
		claims[0].pressed.emit()
		eq(p.wallet.coins, int(GoalDefs.goal("flush")["coins"]), "Claim paid the Flush goal")
		check(texts(sheet).has("Claimed"), "and shows it claimed")
		eq(buttons(sheet, "Claim").size(), 0, "nothing left to claim")
	sheet.free()
	Goals.profile = kept[0]
	Goals.wallet = kept[1]
	Goals.day = kept[2]


func test_a_broken_save_starts_clean() -> void:
	var p := Profile.new()
	p.extra["goals"] = { "day": DAY, "daily": ["nonsense", { "goal": "no_such_goal" }], "weekly": 7, "earlier": "x", "week_no": "y" }
	var t := tracker(DAY, p)
	var goals := t.current()
	eq(goals.size(), 4, "today's goals are dealt again")
	eq(goals.map(func(g: Dictionary) -> String: return g["goal"]), GoalDefs.daily_for(DAY) + [GoalDefs.weekly_for(DAY)], "the day's own goals")
	eq(t.earlier(), [], "nothing waits")
	t.free()
