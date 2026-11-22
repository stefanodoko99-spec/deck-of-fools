extends "res://tests/suite.gd"
## Daily goals: which goals a day and a week get (core/goal_defs.gd), how run events move
## them, claiming once, the weekly reward, goals waiting for the player across days and
## weeks, saves from other builds (the Goals tracker, ui/goals_tracker.gd), and the sheet
## at every text size (ui/goals_sheet.gd). Every test uses a tracker of its own on a fresh
## profile and wallet, or points the live Goals autoload at one for the test only, so the
## player's profile is never read or written; nothing here emits Game.run_event either,
## which the live Goals autoload would count into the player's save.

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


## The saved entry of a goal on a tracker's board (daily or weekly), or {}.
func entry_of(t: Tracker, goal_id: String) -> Dictionary:
	var state: Dictionary = t.profile.state("goals")
	for entry: Dictionary in (state["daily"] as Array) + [state["weekly"]]:
		if entry.get("goal") == goal_id:
			return entry
	return {}


func hand(hand_type: String, total := 120.0, town := 1) -> Dictionary:
	return { "hand": hand_type, "total": total, "points": 30.0, "mult": 4.0, "cards": 5, "show": 0, "town": town }


func show_won(show := 0, town := 1, hands_left := 1, discards_left := 0, hands_played := 3) -> Dictionary:
	return { "show": show, "town": town, "hands_left": hands_left, "discards_left": discards_left, "hands_played": hands_played, "coins": 5 }


## Whether finishing goal `a` always finishes goal `b` along the way: both count the same
## kind of measure, every event that counts for `a` counts for `b` too, and `a` asks for at
## least as much. Reaching Town 2 or later also means beating a Patron on the way.
func implies(a: Dictionary, b: Dictionary) -> bool:
	if str(a["measure"]) == "best:reach" and int(a["target"]) >= 2 and str(b["measure"]) == "count" \
			and (b["on"] as Array) == ["show_won"] and (b["rule"] as Dictionary) == { "show": Shows.PATRON } and int(b["target"]) == 1:
		return true
	if str(a["measure"]) != str(b["measure"]) or int(a["target"]) < int(b["target"]):
		return false
	var on_b: Array = b["on"]
	if not on_b.has("*"):
		for kind: String in a["on"]:
			if kind == "*" or not on_b.has(kind):
				return false
	return stricter(a["rule"], b["rule"])


## Whether every event that meets rule `a` also meets rule `b`.
func stricter(a: Dictionary, b: Dictionary) -> bool:
	for key: String in b:
		if not a.has(key):
			return false
		if key == "contains":
			if not (GoalDefs.CONTAINS.get(str(a[key]), []) as Array).has(b[key]):
				return false
		elif key.ends_with(">="):
			if float(a[key]) < float(b[key]):
				return false
		elif key.ends_with("<="):
			if float(a[key]) > float(b[key]):
				return false
		elif str(a[key]) != str(b[key]):
			return false
	return true


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
		if str(g["tier"]) == GoalDefs.WEEKLY_TIER:
			eq(GoalDefs.reward(g), 100, "%s pays the weekly 100 coins" % id)
		else:
			check(GoalDefs.reward(g) >= 30 and GoalDefs.reward(g) <= 80, "%s pays %d coins, outside 30-80" % [id, GoalDefs.reward(g)])
		check(not g.has("diamonds"), "%s pays coins only" % id)
		for kind: String in g["on"]:
			check(kind == "*" or EVENTS.has(kind), "%s listens to an unknown event '%s'" % [id, kind])
		var rule: Dictionary = g["rule"]
		if rule.has("contains"):
			check(HandTable.ORDER.has(str(rule["contains"])), "%s names an unknown hand" % id)
		var measure := str(g["measure"])
		check(measure == "count" or measure.begins_with("sum:") or measure.begins_with("best:"), "%s measures '%s'" % [id, measure])
	check(GoalDefs.POOL.size() >= 15 and GoalDefs.POOL.size() <= 25, "%d goals, not 15-25" % GoalDefs.POOL.size())
	for tier: String in GoalDefs.DAILY_TIERS + [GoalDefs.WEEKLY_TIER]:
		check(GoalDefs.ids(tier).size() >= 5, "the %s pool has at least 5 goals" % tier)
	for retired: String in ["patron", "hand_1000", "signs_3"]:
		check(GoalDefs.goal(retired).is_empty(), "%s is no longer dealt" % retired)
	for kind: String in HandTable.ORDER:
		eq(GoalDefs.CONTAINS.has(kind), true, "CONTAINS knows %s" % kind)
		check((GoalDefs.CONTAINS[kind] as Array).has(kind), "%s contains itself" % kind)


func test_no_goal_finishes_a_goal_of_another_pool() -> void:
	# The check knows the pairs the pools used to deal side by side.
	var patron := { "measure": "count", "target": 1, "on": ["show_won"], "rule": { "show": Shows.PATRON } }
	var score_1000 := { "measure": "best:total", "target": 1000, "on": ["hand_played"], "rule": {} }
	check(implies(GoalDefs.goal("hand_5000"), score_1000) and not implies(score_1000, GoalDefs.goal("hand_5000")), "5,000 in one hand is 1,000 too")
	check(implies(GoalDefs.goal("patron_spare"), patron), "a Patron beaten with hands to spare is a Patron beaten")
	check(implies(GoalDefs.goal("town_3"), patron), "reaching Town 3 beats a Patron on the way")
	check(implies({ "measure": "sum:signs", "target": 3, "on": ["*"], "rule": {} }, GoalDefs.goal("sign")), "three Signs are one Sign too")
	var trips := { "measure": "count", "target": 1, "on": ["hand_played"], "rule": { "contains": "three_kind", "total>=": 1 } }
	check(implies(GoalDefs.goal("full_house"), trips), "a Full House has Three of a Kind")
	check(not implies(GoalDefs.goal("full_house"), GoalDefs.goal("three_kind_2")), "but one hand isn't two")
	for a: Dictionary in GoalDefs.POOL:
		for b: Dictionary in GoalDefs.POOL:
			var tiers := [str(a["tier"]), str(b["tier"])]
			if tiers[0] == tiers[1] or not GoalDefs.DAILY_TIERS.has(tiers[0]) or not GoalDefs.DAILY_TIERS.has(tiers[1]):
				continue
			check(not implies(a, b), "%s (%s) finishes %s (%s) along the way" % [a["id"], tiers[0], b["id"], tiers[1]])


func test_three_distinct_daily_goals_the_same_for_everyone() -> void:
	var start := GoalDefs.day_number(DAY)
	var yesterday: Array[String] = []
	var dealt := {}
	# Two years of days.
	for i in 730:
		var date := date_of(start + i)
		var goals := GoalDefs.daily_for(date)
		eq(goals, GoalDefs.daily_for(date), "%s deals the same goals every time" % date)
		eq(goals.size(), 3, "%s: three goals" % date)
		for slot in goals.size():
			eq(str(GoalDefs.goal(goals[slot])["tier"]), GoalDefs.DAILY_TIERS[slot], "%s goal %d is %s" % [date, slot, GoalDefs.DAILY_TIERS[slot]])
			check(not yesterday.has(goals[slot]), "%s repeats %s from the day before" % [date, goals[slot]])
			dealt[goals[slot]] = true
			for other: String in goals:
				check(other == goals[slot] or not implies(GoalDefs.goal(goals[slot]), GoalDefs.goal(other)), "%s: %s finishes %s" % [date, goals[slot], other])
		check(goals[0] != goals[1] and goals[1] != goals[2] and goals[0] != goals[2], "%s: three different goals" % date)
		yesterday = goals
	for tier: String in GoalDefs.DAILY_TIERS:
		for id: String in GoalDefs.ids(tier):
			check(dealt.has(id), "%s was never dealt in two years" % id)
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


func test_a_held_goal_is_never_dealt_again() -> void:
	var n := GoalDefs.day_number(DAY)
	for tier: String in GoalDefs.DAILY_TIERS:
		var own := GoalDefs.daily_for(DAY)[GoalDefs.DAILY_TIERS.find(tier)]
		eq(GoalDefs.pick(tier, n, []), own, "%s: the day's own goal when nothing is held" % tier)
		var other := GoalDefs.pick(tier, n, [own])
		check(other != own and str(GoalDefs.goal(other)["tier"]) == tier, "%s: another %s goal when it's held (%s)" % [tier, tier, other])
		eq(GoalDefs.pick(tier, n, [own]), other, "the same for everyone holding it")
		var all := GoalDefs.ids(tier)
		eq(GoalDefs.pick(tier, n, all.slice(1)), all[0], "%s: the one goal not held" % tier)
	var week := GoalDefs.week_number(DAY)
	check(GoalDefs.pick(GoalDefs.WEEKLY_TIER, week, [GoalDefs.weekly_for(DAY)]) != GoalDefs.weekly_for(DAY), "a weekly goal too")


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
	var patrons := GoalDefs.goal("week_patrons_5")
	eq(GoalDefs.advance(patrons, 0, "show_won", show_won(Shows.EVENING)), 0, "an Evening show is no Patron")
	eq(GoalDefs.advance(patrons, 0, "show_won", show_won(Shows.PATRON)), 1, "a Patron beaten")
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
	var big := GoalDefs.goal("hand_5000")
	eq(GoalDefs.advance(big, 0, "hand_played", hand("pair", 640.0)), 640, "the best hand so far")
	eq(GoalDefs.advance(big, 640, "hand_played", hand("pair", 300.0)), 640, "a smaller hand keeps the best")
	eq(GoalDefs.advance(big, 640, "hand_played", hand("flush", 2400.0)), 2400, "a bigger one counts")
	eq(GoalDefs.advance(big, 2400, "hand_played", hand("flush", 8000.0)), 5000, "capped at 5,000")
	var town := GoalDefs.goal("town_3")
	eq(GoalDefs.advance(town, 0, "hand_played", { "town": 2, "reach": 2 }), 2, "in Town 2")
	eq(GoalDefs.advance(town, 2, "run_finished", { "town": 1, "reach": 1 }), 2, "a new run in Town 1 keeps the best")
	var sign := GoalDefs.goal("sign")
	eq(GoalDefs.advance(sign, 0, "show_won", { "signs": 1 }), 1, "a Sign seen with any event")
	eq(GoalDefs.advance(sign, 1, "hand_played", { "signs": 2 }, {}, 5), 3, "Signs add up, to the target the goal was dealt with")
	var deck := GoalDefs.goal("deck")
	eq(GoalDefs.advance(deck, 0, "show_won", { "deck": "d_bergamo" }, { "deck": "d_venezia" }), 0, "another deck")
	eq(GoalDefs.advance(deck, 0, "show_won", { "deck": "d_venezia" }, { "deck": "d_venezia" }), 1, "the day's deck")
	eq(GoalDefs.advance(GoalDefs.goal("jesters_2"), 1, "jester_bought", { "id": "z_zanni" }), 2, "a Jester bought")
	eq(GoalDefs.advance(GoalDefs.goal("discards_4"), 0, "discarded", { "count": 3, "show": 0, "town": 1 }), 1, "a discard")


func test_a_hand_contains_what_the_scorer_says() -> void:
	var pairs := GoalDefs.goal("pairs_5")
	# With Il Pittore (Flushes of four cards) a Flush can hold a Pair: K K 3 5 9, four Hearts.
	var played: Array[PlayingCard] = [PlayingCard.make(1, 13, 1), PlayingCard.make(2, 13, 0), PlayingCard.make(3, 3, 1),
		PlayingCard.make(4, 5, 1), PlayingCard.make(5, 9, 1)]
	var result := HandEvaluator.evaluate(played, { "flush_min": 4 })
	eq(result.type, HandTable.FLUSH, "a Flush of four Hearts")
	var facts := hand("flush")
	eq(GoalDefs.advance(pairs, 0, "hand_played", facts), 0, "told only the hand, a Flush has no Pair")
	facts["contains"] = result.contains
	eq(GoalDefs.advance(pairs, 0, "hand_played", facts), 1, "the scorer says this one has a Pair")
	eq(GoalDefs.advance(GoalDefs.goal("flush"), 0, "hand_played", facts), 1, "and is a Flush")
	facts["contains"] = ["flush", "pair"]
	eq(GoalDefs.advance(pairs, 0, "hand_played", facts), 1, "told as a list too")
	facts["contains"] = { "flush": true, "pair": false }
	eq(GoalDefs.advance(pairs, 0, "hand_played", facts), 0, "and not when the scorer says no")
	var straight: Array[PlayingCard] = [PlayingCard.make(6, 5, 0), PlayingCard.make(7, 6, 1), PlayingCard.make(8, 7, 2),
		PlayingCard.make(9, 8, 3), PlayingCard.make(10, 8, 0)]
	var five_to_eight := HandEvaluator.evaluate(straight, { "straight_min": 4 })
	eq(five_to_eight.type, HandTable.STRAIGHT, "5 6 7 8 8 with Straights of four cards")
	var seen := hand("straight")
	seen["contains"] = five_to_eight.contains
	eq(GoalDefs.advance(pairs, 0, "hand_played", seen), 1, "a Straight with a Pair beside it")


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
	for key: String in ["id", "text", "progress", "target", "coins", "done", "claimed", "kind", "tier", "hint", "art", "period"]:
		check(after.has(key), "a goal has '%s'" % key)
	check(not after.has("diamonds"), "goals pay coins only")
	eq(after["id"], "flush@" + date, "ids name the goal and its day")
	eq([t.current()[0]["kind"], t.current()[3]["kind"]], ["daily", "weekly"], "daily goals first, then the weekly")
	t.free()


func test_progress_stops_at_the_target_the_goal_was_dealt_with() -> void:
	# An update may change a goal's numbers; a goal already dealt keeps its own.
	var date := day_with("pairs_5")
	if not check(date != "", "a day with Play 5 hands with a Pair"):
		return
	var t := tracker(date)
	t.current()
	var pairs := entry_of(t, "pairs_5")
	pairs["target"] = 6
	for i in 10:
		t.record("hand_played", hand("pair"))
	var g := find(t.current(), "pairs_5")
	eq([g["progress"], g["target"], g["done"]], [6, 6, true], "dealt with 6 by a build that asked for 6: 6 of 6, done")
	eq(t.claim(str(g["id"])), int(pairs["coins"]), "and it can be claimed")
	t.free()
	var lower := tracker(date)
	lower.current()
	entry_of(lower, "pairs_5")["target"] = 3
	for i in 4:
		lower.record("hand_played", hand("pair"))
	g = find(lower.current(), "pairs_5")
	eq([g["progress"], g["target"], g["done"]], [3, 3, true], "dealt with 3: done at 3")
	lower.free()
	# A best-score goal keeps a best above the goal's own target.
	var date_big := day_with("hand_5000")
	if not check(date_big != "", "a day with Score 5,000 with one hand"):
		return
	var b := tracker(date_big)
	b.current()
	var big := entry_of(b, "hand_5000")
	big["target"] = 6000
	big["progress"] = 5500
	b.record("hand_played", hand("pair", 50.0))
	eq(find(b.current(), "hand_5000")["progress"], 5500, "a smaller hand keeps the best")
	b.record("hand_played", hand("flush", 5800.0))
	eq(find(b.current(), "hand_5000")["progress"], 5800, "not cut back to the goal's own 5,000")
	b.record("hand_played", hand("flush", 9000.0))
	g = find(b.current(), "hand_5000")
	eq([g["progress"], g["done"]], [6000, true], "done at the 6,000 it was dealt with")
	b.free()
	var monday := week_with("week_shows_20")
	if not check(monday != "", "a week with Win 20 shows"):
		return
	var w := tracker(monday)
	w.current()
	(w.profile.state("goals")["weekly"] as Dictionary)["target"] = 25
	for i in 30:
		w.record("show_won", show_won())
	g = w.current()[3]
	eq([g["progress"], g["target"], g["done"]], [25, 25, true], "the weekly goal too")
	w.free()


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
	# The same Sign isn't counted twice, also after a reload (a goal dealt with a target of 3).
	var p := Profile.new()
	var t3 := tracker(date, p)
	t3.current()
	entry_of(t3, "sign")["target"] = 3
	var run3 := RunState.create("GOALSIGN3", "d_bergamo", 1)
	run3.counters["hands_played"] = 2
	run3.counters["used_sign"] = 1
	t3.record("hand_played", hand("pair"), run3)
	t3.record("hand_played", hand("pair"), run3)
	eq(find(t3.current(), "sign")["progress"], 1, "one Sign, seen twice, counts once")
	t3.free()
	var reloaded := tracker(date, Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict()))))
	run3.counters["hands_played"] = 3
	reloaded.record("show_won", show_won(), run3)
	eq(find(reloaded.current(), "sign")["progress"], 1, "nor after a reload")
	# A practice restart: same seed, fewer hands played, its own Sign.
	var again := RunState.create("GOALSIGN3", "d_bergamo", 1)
	again.counters["hands_played"] = 1
	again.counters["used_sign"] = 1
	reloaded.record("hand_played", hand("pair"), again)
	eq(find(reloaded.current(), "sign")["progress"], 2, "a new run on the same seed counts its own Sign")
	reloaded.free()
	# The deck goal asks for the day's daily-run deck, read from the run that won the show.
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
	# Untouched, it waits into the next day and asks for that day's deck.
	td.day = date_of(GoalDefs.day_number(date_deck) + 1)
	var next_deck := str(Online.daily_setup(td.day)["deck"])
	var waiting := find(td.current(), "deck")
	eq([waiting["id"], waiting["progress"]], [g["id"], 0], "still the same goal the next day")
	check(str(waiting["text"]).contains(UiTheme.name_of(next_deck)), "'%s' names the next day's %s deck" % [waiting["text"], next_deck])
	td.record("show_won", show_won(), RunState.create("GOALDECK", next_deck, 1))
	eq(find(td.current(), "deck")["progress"], 1, "a show won with that day's deck")
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


func test_the_weekly_goal_pays_coins_only() -> void:
	var date := week_with("week_four_kind")
	if not check(date != "", "a week with Score Four of a Kind"):
		return
	var t := tracker(date)
	var weekly: Dictionary = t.current()[3]
	eq([weekly["goal"], weekly["kind"], weekly["coins"]], ["week_four_kind", "weekly", 100], "the weekly goal")
	t.record("hand_played", hand("five_kind", 3000.0))
	check(t.current()[3]["done"], "Five of a Kind has Four of a Kind")
	var coins := t.wallet.coins
	var gems := t.wallet.diamonds
	eq(t.claim(str(weekly["id"])), 100, "100 coins")
	eq([t.wallet.coins - coins, t.wallet.diamonds - gems], [100, 0], "and no diamonds: those come from the gift and the album")
	eq(t.claim(str(weekly["id"])), 0, "once")
	# Later days of the same week keep it; the Monday after deals a new one.
	t.day = date_of(GoalDefs.day_number(date) + 6)
	check(t.current()[3]["claimed"], "still claimed on Sunday")
	t.day = date_of(GoalDefs.day_number(date) + 7)
	var next: Dictionary = t.current()[3]
	check(next["goal"] != "week_four_kind" and next["progress"] == 0 and not next["claimed"], "a new weekly goal on Monday")
	t.free()


# --- New days and weeks: goals wait for the player --------------------------------------


func test_unfinished_goals_wait_for_the_player() -> void:
	var date := day_with("pairs_5")
	if not check(date != "", "a day with Play 5 hands with a Pair"):
		return
	var t := tracker(date)
	var first := t.current()
	for i in 4:
		t.record("hand_played", hand("pair"))
	var slot := GoalDefs.DAILY_TIERS.find("easy")
	# Finish the other two daily goals (as if played) and claim one of them.
	var state: Dictionary = t.profile.state("goals")
	var others: Array[String] = []
	for entry: Dictionary in state["daily"]:
		if entry["goal"] != "pairs_5":
			entry["progress"] = entry["target"]
			others.append(str(entry["goal"]))
	eq(t.claim("%s@%s" % [others[0], date]), int(GoalDefs.goal(others[0])["coins"]), "one claimed")
	# Three days later: missed days are nothing to make up.
	t.day = date_of(GoalDefs.day_number(date) + 3)
	var later := t.current()
	var pairs := find(later, "pairs_5")
	eq([pairs["id"], pairs["progress"], pairs["done"]], [first[slot]["id"], 4, false], "Play 5 hands with a Pair waits at 4/5")
	eq(later[slot]["goal"], "pairs_5", "in its own place")
	for i in 3:
		eq(str(later[i]["tier"]), GoalDefs.DAILY_TIERS[i], "one goal per pool, easy to hard")
		if i != slot:
			check(later[i]["period"] == t.day and later[i]["progress"] == 0, "a finished goal made way for a new one: %s" % later[i]["goal"])
			check(not others.has(str(later[i]["goal"])), "not the one that just left")
	eq(t.earlier().map(func(g: Dictionary) -> String: return g["goal"]), [others[1]], "the finished goal not yet claimed waits among the earlier ones")
	var ids := later.map(func(g: Dictionary) -> String: return g["goal"])
	for id: String in ids:
		eq(ids.count(id), 1, "%s shows once" % id)
	# Finishing it pays as any goal does.
	t.record("hand_played", hand("pair"))
	check(find(t.current(), "pairs_5")["done"], "finished three days later")
	eq(t.claim(str(pairs["id"])), int(GoalDefs.goal("pairs_5")["coins"]), "and claimed")
	# The next day deals a new easy goal in its place, never the one just finished.
	t.day = date_of(GoalDefs.day_number(date) + 4)
	var easy: Dictionary = t.current()[slot]
	check(easy["goal"] != "pairs_5" and easy["progress"] == 0 and easy["period"] == t.day, "a new easy goal: %s" % easy["goal"])
	# The clock turned back deals nothing new: the newer goals stay.
	var newer := t.current()
	t.day = date
	eq(t.current(), newer, "a clock set back keeps the goals")
	t.free()


func test_an_unfinished_weekly_goal_carries_on() -> void:
	var monday := week_with("week_shows_20")
	if not check(monday != "", "a week with Win 20 shows"):
		return
	var start := GoalDefs.day_number(monday)
	var t := tracker(monday)
	for i in 19:
		t.record("show_won", show_won())
	t.day = date_of(start + 6)
	eq(t.current()[3]["progress"], 19, "19 of 20 on Sunday")
	t.day = date_of(start + 7)
	var weekly: Dictionary = t.current()[3]
	eq([weekly["goal"], weekly["progress"], weekly["done"], weekly["period"]], ["week_shows_20", 19, false, GoalDefs.week_label(monday)], "it carries on into the new week")
	t.day = date_of(start + 30)
	eq(t.current()[3]["progress"], 19, "and the weeks after")
	t.record("show_won", show_won())
	eq(t.claim(str(weekly["id"])), 100, "finished and claimed weeks later")
	t.day = date_of(start + 35)
	var next: Dictionary = t.current()[3]
	check(next["goal"] != "week_shows_20" and next["progress"] == 0 and not next["claimed"], "the Monday after deals another: %s" % next["goal"])
	# Finished but not claimed when the week ends: it waits among the earlier goals.
	(t.profile.state("goals")["weekly"] as Dictionary)["progress"] = next["target"]
	t.day = date_of(start + 42)
	eq(t.earlier().map(func(g: Dictionary) -> String: return g["id"]), [next["id"]], "the finished weekly goal waits to be claimed")
	check(t.current()[3]["goal"] != next["goal"], "and a new one is dealt")
	t.free()


func test_a_new_day_keeps_finished_goals_waiting() -> void:
	var date := day_with("discards_4")
	if not check(date != "", "a day with Use 4 discards"):
		return
	var t := tracker(date)
	for i in 4:
		t.record("discarded", { "count": 2, "show": 0, "town": 1 })
	var finished := find(t.current(), "discards_4")
	check(finished["done"], "finished, not claimed")
	t.day = date_of(GoalDefs.day_number(date) + 1)
	var waiting := t.earlier()
	eq(waiting.size(), 1, "the finished goal waits")
	eq([waiting[0]["id"], waiting[0]["done"], waiting[0]["coins"]], [finished["id"], true, finished["coins"]], "the goal waiting")
	check(t.ready_count() >= 1, "it counts as ready")
	var coins := t.wallet.coins
	eq(t.claim(str(finished["id"])), int(finished["coins"]), "claimed a day later")
	eq(t.wallet.coins - coins, int(finished["coins"]), "paid")
	eq(t.earlier().size(), 0, "and gone from the earlier goals")
	eq(t.claim(str(finished["id"])), 0, "once")
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
	eq(claimed, t.wallet.coins - before_claim, "Claim pays the goals waiting")
	eq(t.wallet.coins, paid, "all %d finished goals paid: the oldest by themselves, the rest when claimed" % finished)
	eq(t.wallet.diamonds, 0, "in coins")
	eq(t.earlier().size(), 0, "nothing waits after Claim")
	t.free()


func test_two_years_of_a_board_that_waits() -> void:
	# A player who finishes some goals and leaves others for days: the board always holds
	# one goal per pool, never the same goal twice, never one that finishes another along
	# the way, an unfinished goal keeps its progress, and a goal that makes way doesn't come
	# straight back.
	var t := tracker()
	var start := GoalDefs.day_number(DAY)
	var before: Array = []
	var carried := 0
	for i in 730:
		t.day = date_of(start + i)
		var goals := t.current()
		var ids: Array = goals.map(func(g: Dictionary) -> String: return g["goal"])
		for slot in 3:
			var g: Dictionary = goals[slot]
			if not check(str(g["tier"]) == GoalDefs.DAILY_TIERS[slot], "%s: %s in the %s place" % [t.day, g["goal"], GoalDefs.DAILY_TIERS[slot]]):
				break
			eq(ids.count(g["goal"]), 1, "%s: %s shows once" % [t.day, g["goal"]])
			for other: Dictionary in goals.slice(0, 3):
				check(other["goal"] == g["goal"] or not implies(GoalDefs.goal(g["goal"]), GoalDefs.goal(other["goal"])), "%s: %s finishes %s" % [t.day, g["goal"], other["goal"]])
			if not before.is_empty():
				var was: Dictionary = before[slot]
				if not was["done"]:
					eq([g["id"], g["progress"]], [was["id"], was["progress"]], "%s: the unfinished %s waits" % [t.day, was["goal"]])
					carried += 1
				else:
					check(g["goal"] != was["goal"], "%s: %s came straight back" % [t.day, was["goal"]])
		# Some days the player finishes a goal or two, and claims on even days.
		var state: Dictionary = t.profile.state("goals")
		for slot in 3:
			var entry: Dictionary = state["daily"][slot]
			if posmod(i * 7 + slot * 3, 5) < 2:
				entry["progress"] = entry["target"]
				if i % 2 == 0:
					t.claim("%s@%s" % [entry["goal"], entry["period"]])
		before = t.current().slice(0, 3)
	check(carried > 100, "goals waited on %d days" % carried)
	note("%d days a goal waited for the player" % carried)
	t.free()


# --- Saves ----------------------------------------------------------------------------


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


func test_goals_from_another_version_are_kept() -> void:
	# A newer build dealt goals this one doesn't know; one finished goal from an earlier day
	# is waiting too. Nothing is lost, here or (once saved and synced) for the newer build.
	var p := Profile.new()
	var week := GoalDefs.week_label(DAY)
	var today := GoalDefs.daily_for(DAY)
	p.extra["goals"] = {
		"day": DAY, "week_no": GoalDefs.week_number(DAY), "week": week,
		"daily": [
			{ "goal": "future_easy", "kind": "daily", "tier": "easy", "period": DAY, "progress": 2, "target": 2, "claimed": false, "coins": 60 },
			{ "goal": today[1], "kind": "daily", "period": DAY, "progress": 0, "target": int(GoalDefs.goal(today[1])["target"]), "claimed": false, "coins": 45 },
			{ "goal": "future_hard", "kind": "daily", "period": DAY, "progress": 1, "target": 3, "claimed": false, "coins": 70 },
		],
		"weekly": { "goal": "week_future", "kind": "weekly", "period": week, "progress": 1, "target": 1, "claimed": false, "coins": 100 },
		"earlier": [{ "goal": "old_goal", "kind": "daily", "period": "2026-11-20", "progress": 1, "target": 1, "claimed": false, "coins": 40, "earlier": true }],
	}
	var t := tracker(DAY, p)
	var goals := t.current()
	eq(goals.map(func(g: Dictionary) -> String: return g["goal"]), ["future_easy", today[1], "future_hard", "week_future"], "kept in their places")
	eq(find(goals, "future_easy")["text"], "A goal from another version of the game", "told as such")
	eq(t.ready_count(), 3, "two finished on the board and one from an earlier day")
	t.record("hand_played", hand("pair"))
	t.record("show_won", show_won(Shows.PATRON, 2))
	eq(find(t.current(), "future_hard")["progress"], 1, "nothing counts a goal this build doesn't know")
	eq(t.claim("future_easy@" + DAY), 60, "it pays what it was dealt with")
	eq(t.claim("week_future@" + week), 100, "the weekly one too")
	eq(t.claim_earlier(), 40, "and the earlier one")
	var saved: Dictionary = p.state("goals")
	eq(saved["daily"][2]["goal"], "future_hard", "the save keeps it for the build that knows it")
	# The next day the one this build can't play makes way for a goal it can.
	t.day = date_of(GoalDefs.day_number(DAY) + 1)
	var next := t.current()
	check(next[2]["goal"] != "future_hard" and str(GoalDefs.goal(next[2]["goal"]).get("tier", "")) == "hard", "a hard goal in its place: %s" % next[2]["goal"])
	eq(next[1]["goal"], today[1], "while the unfinished goal it knows waits")
	t.free()


func test_a_broken_save_starts_clean() -> void:
	var p := Profile.new()
	p.extra["goals"] = { "day": DAY, "daily": ["nonsense", { "goal": 7 }, {}], "weekly": 7, "earlier": "x", "week_no": "y" }
	var t := tracker(DAY, p)
	var goals := t.current()
	eq(goals.size(), 4, "today's goals are dealt again")
	eq(goals.map(func(g: Dictionary) -> String: return g["goal"]), GoalDefs.daily_for(DAY) + [GoalDefs.weekly_for(DAY)], "the day's own goals")
	eq(t.earlier(), [], "nothing waits")
	t.free()


func test_the_autoload_listens_to_run_events() -> void:
	check(Game.run_event.is_connected(Goals._on_run_event), "Goals counts Game.run_event")
	eq(Goals.profile, null, "the live tracker keeps the player's own profile")


# --- The sheet -------------------------------------------------------------------------


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


## A place for sheets during a test, with the game's theme as on its own root, under the
## test runner's node (the root is still busy adding it while tests run). Free it after.
func themed_host() -> Control:
	var root := (Engine.get_main_loop() as SceneTree).root
	var place := Control.new()
	place.theme = UiTheme.build()
	root.get_child(root.get_child_count() - 1).add_child(place)
	return place


## Points the live Goals autoload at a fresh test profile; returns what to restore.
func borrow_goals(on_day: String) -> Array:
	var kept: Array = [Goals.profile, Goals.wallet, Goals.day]
	var p := Profile.new()
	Goals.profile = p
	Goals.wallet = p.wallet
	Goals.day = on_day
	return kept


func give_back_goals(kept: Array) -> void:
	Goals.profile = kept[0]
	Goals.wallet = kept[1]
	Goals.day = kept[2]


## Lays a sheet out now, as the next frames would: every container places its children and
## every label measures its lines at its new width, a few times over; then the panel is
## placed from its new minimum size. Returns the panel.
func lay_out(sheet: GoalsSheet) -> Control:
	var panel := sheet.body.get_parent().get_parent() as Control
	for pass_no in 3:
		_sort(panel)
	# Nudged there and back, the panel takes its place at once.
	panel.offset_left += 1.0
	panel.offset_left -= 1.0
	return panel


func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		if child is Label:
			(child as Label).update_minimum_size()
		_sort(child)


## Finishes the daily goals of the day Goals follows (as if played), so they wait among
## the earlier goals once the next day comes.
func finish_daily_goals() -> void:
	Goals.current()
	for entry: Dictionary in Goals.profile.state("goals")["daily"]:
		entry["progress"] = entry["target"]


func test_the_sheet_shows_the_goals_and_claims() -> void:
	var date := day_with("flush")
	if not check(date != "", "a day with the Flush goal"):
		return
	var place := themed_host()
	var kept := borrow_goals(date)
	var p := Goals.profile
	Goals.record("hand_played", hand("flush"))
	var sheet := GoalsSheet.new()
	place.add_child(sheet)
	var shown := texts(sheet)
	for g: Dictionary in Goals.current():
		check(shown.has(str(g["text"])), "the sheet shows '%s'" % g["text"])
	check(shown.has("Weekly goal") and shown.has("Today"), "the sections")
	check(shown.has("Any mode counts. Goals wait until you finish them."), "goals wait, said up front")
	check(not shown.any(func(t: String) -> bool: return t.begins_with("New goals in") or t.begins_with("New weekly goal")), "no clock runs against a goal")
	var claims := buttons(sheet, "Claim")
	eq(claims.size(), 1, "one goal to claim")
	if claims.size() == 1:
		claims[0].pressed.emit()
		eq(p.wallet.coins, int(GoalDefs.goal("flush")["coins"]), "Claim paid the Flush goal")
		check(texts(sheet).has("Claimed"), "and shows it claimed")
		check(texts(sheet).any(func(t: String) -> bool: return t.begins_with("Next in ")), "with when the next goal comes")
		eq(buttons(sheet, "Claim").size(), 0, "nothing left to claim")
	sheet.free()
	# The other goals finished but not claimed: the next day they wait in the header, where
	# one Claim pays them all, in coins.
	finish_daily_goals()
	Goals.day = date_of(GoalDefs.day_number(date) + 1)
	var waiting := Goals.earlier()
	eq(waiting.size(), 2, "two goals from the day before wait")
	var due := 0
	for g: Dictionary in waiting:
		due += int(g["coins"])
	var later := GoalsSheet.new()
	place.add_child(later)
	check(texts(later).has("2 goals from earlier"), "said in the header")
	var before := p.wallet.coins
	var claim_all := buttons(later, "Claim")
	eq(claim_all.size(), 1, "one Claim, for the earlier goals")
	if claim_all.size() == 1:
		claim_all[0].pressed.emit()
		eq(p.wallet.coins - before, due, "the earlier goals paid")
		eq(Goals.earlier().size(), 0, "and gone")
		check(not texts(later).any(func(t: String) -> bool: return t.ends_with("from earlier")), "the header shows none waiting")
	later.free()
	place.free()
	give_back_goals(kept)


func test_open_shows_one_sheet() -> void:
	var place := themed_host()
	var kept := borrow_goals(DAY)
	var host_before := UiTheme.sheet_host
	UiTheme.sheet_host = place
	Goals.open()
	Goals.open()
	eq(place.get_children().filter(func(n: Node) -> bool: return n is GoalsSheet).size(), 1, "one goals sheet at a time")
	UiTheme.sheet_host = host_before
	place.free()
	give_back_goals(kept)


func test_the_sheet_fits_the_stage_at_every_text_size() -> void:
	# Every daily and weekly goal, at Small, Normal and Large text, fresh, finished (Claim
	# buttons) and claimed, with finished goals from the day before waiting in the header.
	var place := themed_host()
	var kept := borrow_goals(DAY)
	var settings: Array = [Settings.size, Settings.reduce_motion]
	Settings.reduce_motion = true
	var start := GoalDefs.day_number(DAY)
	var pools: Array = [GoalDefs.ids("easy"), GoalDefs.ids("medium"), GoalDefs.ids("hard"), GoalDefs.ids("weekly")]
	var boards := 0
	for pool: Array in pools:
		boards = maxi(boards, pool.size())
	for size in 3:
		Settings.size = size
		place.theme = UiTheme.build()
		var tallest := 0.0
		for state_name: String in ["fresh", "finished", "claimed"]:
			for k in boards:
				Goals.profile = Profile.new()
				Goals.wallet = Goals.profile.wallet
				var date := date_of(start + k)
				if state_name != "fresh":
					Goals.day = date_of(start + k - 1)
					finish_daily_goals()
				Goals.day = date
				Goals.current()
				var state: Dictionary = Goals.profile.state("goals")
				var daily: Array = []
				for slot in 3:
					daily.append(Goals._deal(pools[slot][k % (pools[slot] as Array).size()], date, "daily"))
				state["daily"] = daily
				state["weekly"] = Goals._deal(pools[3][k % (pools[3] as Array).size()], str(state["week"]), "weekly")
				if state_name != "fresh":
					for entry: Dictionary in daily + [state["weekly"]]:
						entry["progress"] = entry["target"]
						entry["claimed"] = state_name == "claimed"
				var sheet := GoalsSheet.new()
				place.add_child(sheet)
				var what := "%s, %s, %s" % [Settings.SIZE_NAMES[size], state_name, ", ".join(Goals.current().map(func(g: Dictionary) -> String: return g["goal"]))]
				check(state_name == "fresh" or not Goals.earlier().is_empty(), "%s: earlier goals wait" % what)
				tallest = maxf(tallest, fits(sheet, what))
				# Claiming rebuilds the sheet: it still fits, still centred.
				var claims := buttons(sheet, "Claim")
				if state_name == "finished" and not claims.is_empty():
					claims[claims.size() - 1].pressed.emit()
					fits(sheet, what + ", after a claim")
				sheet.free()
		note("%s: tallest panel %.0f of 360" % [Settings.SIZE_NAMES[size], tallest])
	Settings.size = settings[0]
	Settings.reduce_motion = settings[1]
	UiTheme.build()
	place.free()
	give_back_goals(kept)


## Checks that a sheet's panel, laid out, holds its content inside the 640x360 stage,
## centred; returns its height.
func fits(sheet: GoalsSheet, what: String) -> float:
	var panel := lay_out(sheet)
	var rect := Rect2(panel.position, panel.size)
	check(panel.size.y >= panel.get_combined_minimum_size().y - 0.5, "%s: the panel holds its content" % what)
	check(Rect2(Vector2.ZERO, UiTheme.STAGE).encloses(rect), "%s: the panel %s is inside the 640x360 stage" % [what, rect])
	check(absf(rect.position.y - (UiTheme.STAGE.y - rect.end.y)) <= 1.0 and absf(rect.position.x - (UiTheme.STAGE.x - rect.end.x)) <= 1.0,
		"%s: the panel %s is centred" % [what, rect])
	return rect.size.y


func test_reduce_motion_keeps_the_sheet_still() -> void:
	var place := themed_host()
	var kept := borrow_goals(DAY)
	var calm := Settings.reduce_motion
	var tree := Engine.get_main_loop() as SceneTree
	Goals.current()
	for entry: Dictionary in Goals.profile.state("goals")["daily"]:
		entry["progress"] = int(entry["target"]) - 1 if int(entry["target"]) > 1 else entry["target"]
	for still: bool in [true, false]:
		Settings.reduce_motion = still
		var before := tree.get_processed_tweens().size()
		var sheet := GoalsSheet.new()
		place.add_child(sheet)
		var started := tree.get_processed_tweens().size() - before
		if still:
			eq(started, 0, "with Reduce motion nothing moves: no slide, no filling bars, no breathing tiles")
		else:
			check(started > 0, "otherwise the sheet slides in and its bars fill")
		sheet.free()
	Settings.reduce_motion = calm
	place.free()
	give_back_goals(kept)


## WCAG contrast between two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_words_on_the_tiles_keep_their_contrast() -> void:
	# Over the whole gradient of each tile, with the sheen at its strongest where it can be
	# (ShopSheet.Tile: the gradient runs from the top-left corner to the bottom-right one,
	# the sheen fades out by 55% of the height).
	var glass := Color(0.1, 0.055, 0.19)
	var cases: Array = []
	for tier: String in GoalsSheet.COLOURS:
		cases.append([tier, GoalsSheet.COLOURS[tier][0], GoalsSheet.COLOURS[tier][1], UiTheme.TEXT, 1.0])
	cases.append(["finished", GoalsSheet.READY[0], GoalsSheet.READY[1], UiTheme.INK, 1.0])
	# Claimed tiles are glass on the sheet's panel, and step back to 82%.
	cases.append(["claimed", glass.blend(ShopSheet.GLASS_TILE[0]), glass.blend(ShopSheet.GLASS_TILE[1]), UiTheme.TEXT, 0.82])
	for c: Array in cases:
		var worst := 99.0
		for i in 41:
			var t := i / 40.0
			var sheen := GoalsSheet.SHEEN * clampf(1.0 - maxf(0.0, 2.0 * t - 1.0) / 0.55, 0.0, 1.0)
			var bg := (c[1] as Color).lerp(c[2], t).lerp(Color.WHITE, sheen)
			worst = minf(worst, contrast(bg.lerp(c[3], c[4]), bg))
		check(worst >= GoalsSheet.CONTRAST, "%s tiles: %.2f:1, under %.1f:1" % [c[0], worst, GoalsSheet.CONTRAST])
		note("%s: at least %.2f:1" % [c[0], worst])
