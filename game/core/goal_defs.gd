class_name GoalDefs
extends RefCounted
## The daily and weekly goals: what each one asks, which run events move it, and which
## goals a given day and week get. Pure rules and data, the same for every player; the
## Goals autoload (ui/goals_tracker.gd) keeps each player's progress and pays the coins.
##
## Every goal teaches a part of the game (a poker hand, discards, Jesters, Signs, the
## Patrons, travelling on), so a day's three goals are a small lesson plan: one easy,
## one medium and one hard, each from its own pool. A pool is dealt in a shuffled order
## that changes every round, so a goal comes back only after all the others in its pool
## had their turn, and never two days running. Goals only ever watch play: nothing in a
## run changes because of them, and any mode counts, daily practice included.

## A weekly goal pays this many coins and diamonds (daily goals pay their own coins).
const WEEKLY_COINS := 100
const WEEKLY_DIAMONDS := 10
## A day's goals come one from each of these pools, in this order.
const DAILY_TIERS := ["easy", "medium", "hard"]
const WEEKLY_TIER := "weekly"

## The run events that say which town the run is in (for "Reach Town N").
const TOWN_EVENTS := ["hand_played", "discarded", "show_won", "show_lost", "run_finished"]

## The poker hands each played hand contains, read the way the Jesters' "if the hand
## contains" reads it (HandEvaluator), for five ordinary cards. A Full House counts for
## "Three of a Kind" and a Straight Flush for "Flush", as a player would expect.
const CONTAINS := {
	"high_card": ["high_card"],
	"pair": ["pair"],
	"two_pair": ["two_pair", "pair"],
	"three_kind": ["three_kind", "pair"],
	"straight": ["straight"],
	"flush": ["flush"],
	"full_house": ["full_house", "three_kind", "two_pair", "pair"],
	"four_kind": ["four_kind", "three_kind", "pair"],
	"straight_flush": ["straight_flush", "straight", "flush"],
	"five_kind": ["five_kind", "four_kind", "three_kind", "pair"],
	"flush_house": ["flush_house", "full_house", "flush", "three_kind", "two_pair", "pair"],
	"flush_five": ["flush_five", "five_kind", "flush", "four_kind", "three_kind", "pair"],
}

## The goals. Each one has:
##   id       a stable name, saved in profiles (never rename or reuse one)
##   tier     easy, medium or hard (daily), or weekly
##   text     what to do; {deck} is the deck the day picked (today's daily-run deck)
##   hint     one line that teaches how
##   target   how far the progress has to go
##   coins    the reward of a daily goal (weekly ones pay WEEKLY_COINS and WEEKLY_DIAMONDS)
##   on       the Game.run_event kinds that can move it ("*" for any)
##   rule     what the event has to show: "contains" a poker hand, a field equal to a
##            value, or "field>=" / "field<=" a value; "@deck" stands for the day's deck
##   measure  "count" adds 1 per event, "sum:<field>" adds that field, "best:<field>"
##            keeps the highest value seen
##   art      the picture on the goal's tile (GoalsSheet.GoalArt)
## Hand goals ask for "total>=": 1, so a hand the Patron doesn't allow (it scores
## nothing) doesn't count.
const POOL := [
	# Easy: a few minutes of any run.
	{ "id": "pairs_5", "tier": "easy", "text": "Play 5 hands with a Pair",
		"hint": "Two cards of the same rank. Bigger hands with a Pair count too.",
		"target": 5, "coins": 30, "on": ["hand_played"], "rule": { "contains": "pair", "total>=": 1 }, "measure": "count", "art": "pair" },
	{ "id": "shows_3", "tier": "easy", "text": "Win 3 shows",
		"hint": "Reach a show's target score before your hands run out.",
		"target": 3, "coins": 35, "on": ["show_won"], "rule": {}, "measure": "count", "art": "trophy" },
	{ "id": "discards_4", "tier": "easy", "text": "Use 4 discards",
		"hint": "Swap the cards you don't need for new ones from your deck.",
		"target": 4, "coins": 30, "on": ["discarded"], "rule": {}, "measure": "count", "art": "discard" },
	{ "id": "evening", "tier": "easy", "text": "Win an Evening show",
		"hint": "The second show in each town: its target is 1.5 times the Matinee's.",
		"target": 1, "coins": 35, "on": ["show_won"], "rule": { "show": 1 }, "measure": "count", "art": "moon" },
	{ "id": "jesters_2", "tier": "easy", "text": "Buy 2 Jesters",
		"hint": "Jesters from the Market work on every hand you play.",
		"target": 2, "coins": 40, "on": ["jester_bought"], "rule": {}, "measure": "count", "art": "jester" },
	{ "id": "spare_discard", "tier": "easy", "text": "Win a show with a discard to spare",
		"hint": "Brighella pays a ducat for every discard you don't use.",
		"target": 1, "coins": 35, "on": ["show_won"], "rule": { "discards_left>=": 1 }, "measure": "count", "art": "discard" },

	# Medium: a good run of a town or two.
	{ "id": "flush", "tier": "medium", "text": "Score a Flush",
		"hint": "Five cards of the same suit.",
		"target": 1, "coins": 45, "on": ["hand_played"], "rule": { "contains": "flush", "total>=": 1 }, "measure": "count", "art": "flush" },
	{ "id": "straight", "tier": "medium", "text": "Score a Straight",
		"hint": "Five ranks in a row, like 5 6 7 8 9.",
		"target": 1, "coins": 50, "on": ["hand_played"], "rule": { "contains": "straight", "total>=": 1 }, "measure": "count", "art": "straight" },
	{ "id": "three_kind_2", "tier": "medium", "text": "Play 2 hands with Three of a Kind",
		"hint": "Three cards of the same rank. A Full House counts too.",
		"target": 2, "coins": 50, "on": ["hand_played"], "rule": { "contains": "three_kind", "total>=": 1 }, "measure": "count", "art": "three" },
	{ "id": "patron", "tier": "medium", "text": "Beat a Patron",
		"hint": "The last show in each town. Every Patron brings a rule of their own.",
		"target": 1, "coins": 55, "on": ["show_won"], "rule": { "show": 2 }, "measure": "count", "art": "crown" },
	{ "id": "hand_1000", "tier": "medium", "text": "Score 1,000 with one hand",
		"hint": "A hand scores its Points times its Mult: raise both.",
		"target": 1000, "coins": 50, "on": ["hand_played"], "rule": {}, "measure": "best:total", "art": "score" },
	{ "id": "sign", "tier": "medium", "text": "Use a Sign",
		"hint": "A Sign levels up a poker hand for the rest of the run.",
		"target": 1, "coins": 45, "on": ["*"], "rule": {}, "measure": "sum:signs", "art": "star" },
	{ "id": "deck", "tier": "medium", "text": "Win a show with the {deck} deck",
		"hint": "Today's daily run deals this deck to everyone.",
		"target": 1, "coins": 45, "on": ["show_won"], "rule": { "deck": "@deck" }, "measure": "count", "art": "deck" },

	# Hard: a strong run, or a bit of luck.
	{ "id": "town_3", "tier": "hard", "text": "Reach Town 3",
		"hint": "Beat a town's Patron to travel on to the next town.",
		"target": 3, "coins": 70, "on": TOWN_EVENTS, "rule": {}, "measure": "best:reach", "art": "flag" },
	{ "id": "two_hands", "tier": "hard", "text": "Win a show in 2 hands or fewer",
		"hint": "Discard to build one big hand, then play it.",
		"target": 1, "coins": 65, "on": ["show_won"], "rule": { "hands_played<=": 2 }, "measure": "count", "art": "bolt" },
	{ "id": "full_house", "tier": "hard", "text": "Score a Full House",
		"hint": "Three of a Kind and a Pair in the same hand.",
		"target": 1, "coins": 70, "on": ["hand_played"], "rule": { "contains": "full_house", "total>=": 1 }, "measure": "count", "art": "house" },
	{ "id": "hand_5000", "tier": "hard", "text": "Score 5,000 with one hand",
		"hint": "Level up your favourite hand with its Sign, then add Mult.",
		"target": 5000, "coins": 75, "on": ["hand_played"], "rule": {}, "measure": "best:total", "art": "score" },
	{ "id": "patron_spare", "tier": "hard", "text": "Beat a Patron with 2 hands to spare",
		"hint": "Every hand you don't need pays a ducat at cash-out.",
		"target": 1, "coins": 75, "on": ["show_won"], "rule": { "show": 2, "hands_left>=": 2 }, "measure": "count", "art": "crown" },
	{ "id": "signs_3", "tier": "hard", "text": "Use 3 Signs",
		"hint": "Signs turn up in the Market and in its packs.",
		"target": 3, "coins": 65, "on": ["*"], "rule": {}, "measure": "sum:signs", "art": "star" },

	# Weekly: something to work toward over a few sessions.
	{ "id": "week_shows_20", "tier": "weekly", "text": "Win 20 shows",
		"hint": "Every mode counts, the daily run too.",
		"target": 20, "on": ["show_won"], "rule": {}, "measure": "count", "art": "trophy" },
	{ "id": "week_patrons_5", "tier": "weekly", "text": "Beat 5 Patrons",
		"hint": "The last show of each town, in any run.",
		"target": 5, "on": ["show_won"], "rule": { "show": 2 }, "measure": "count", "art": "crown" },
	{ "id": "week_town_5", "tier": "weekly", "text": "Reach Town 5",
		"hint": "Halfway through a tour: build a troupe that keeps up.",
		"target": 5, "on": TOWN_EVENTS, "rule": {}, "measure": "best:reach", "art": "flag" },
	{ "id": "week_four_kind", "tier": "weekly", "text": "Score Four of a Kind",
		"hint": "Four cards of the same rank in one hand.",
		"target": 1, "on": ["hand_played"], "rule": { "contains": "four_kind", "total>=": 1 }, "measure": "count", "art": "four" },
	{ "id": "week_jesters_8", "tier": "weekly", "text": "Buy 8 Jesters",
		"hint": "Every Jester you meet joins your collection.",
		"target": 8, "on": ["jester_bought"], "rule": {}, "measure": "count", "art": "jester" },
	{ "id": "week_hand_10000", "tier": "weekly", "text": "Score 10,000 with one hand",
		"hint": "Stack Mult with your Jesters and level the hand up with Signs.",
		"target": 10000, "on": ["hand_played"], "rule": {}, "measure": "best:total", "art": "score" },
]

static var _by_id: Dictionary = {}


## The goal with this id, or {} when there's none (an id from a newer or older build).
static func goal(id: String) -> Dictionary:
	if _by_id.is_empty():
		for g: Dictionary in POOL:
			_by_id[str(g["id"])] = g
	return _by_id.get(id, {})


## The ids of a pool (a tier), in the order POOL lists them.
static func ids(tier: String) -> Array[String]:
	var out: Array[String] = []
	for g: Dictionary in POOL:
		if str(g["tier"]) == tier:
			out.append(str(g["id"]))
	return out


## A date's three daily goals (YYYY-MM-DD, UTC): one easy, one medium, one hard.
static func daily_for(date: String) -> Array[String]:
	var out: Array[String] = []
	for tier: String in DAILY_TIERS:
		out.append(_dealt(tier, day_number(date)))
	return out


## The weekly goal of the (Monday to Sunday) week a date falls in.
static func weekly_for(date: String) -> String:
	return _dealt(WEEKLY_TIER, week_number(date))


## What a goal pays: { coins, diamonds }.
static func reward(g: Dictionary) -> Dictionary:
	if str(g.get("tier", "")) == WEEKLY_TIER:
		return { "coins": WEEKLY_COINS, "diamonds": WEEKLY_DIAMONDS }
	return { "coins": int(g.get("coins", 0)), "diamonds": 0 }


## A goal's words, with the day's deck filled in.
static func text_for(g: Dictionary, params: Dictionary) -> String:
	var text := str(g.get("text", ""))
	if text.contains("{deck}"):
		text = text.replace("{deck}", TranslationServer.translate(str(params.get("deck", "")) + ".name"))
	return text


## The progress a goal has after one run event: the event is checked against the goal's
## rule, then counted, summed or kept as the best so far, and capped at the target.
## `facts` is the event's data plus what the tracker adds (reach, deck, signs).
static func advance(g: Dictionary, progress: int, kind: String, facts: Dictionary, params := {}) -> int:
	var on: Array = g.get("on", [])
	if not (on.has(kind) or on.has("*")) or not matches(g.get("rule", {}), facts, params):
		return progress
	var measure := str(g.get("measure", "count"))
	var value := progress + 1
	if measure.begins_with("sum:"):
		value = progress + maxi(0, int(facts.get(measure.substr(4), 0)))
	elif measure.begins_with("best:"):
		value = maxi(progress, int(facts.get(measure.substr(5), 0)))
	return clampi(value, 0, int(g.get("target", 1)))


## Whether an event's facts meet a goal's rule (see POOL).
static func matches(rule: Dictionary, facts: Dictionary, params := {}) -> bool:
	for key: String in rule:
		var want: Variant = rule[key]
		if want is String and (want as String).begins_with("@"):
			want = params.get((want as String).substr(1), "")
		if key == "contains":
			var inside: Variant = CONTAINS.get(str(facts.get("hand", "")), [])
			if not (inside as Array).has(want):
				return false
		elif key.ends_with(">=") or key.ends_with("<="):
			var field := key.left(-2)
			if not facts.has(field) or not _is_number(facts[field]):
				return false
			var have := float(facts[field])
			if (key.ends_with(">=") and have < float(want)) or (key.ends_with("<=") and have > float(want)):
				return false
		elif not _same(facts.get(key), want):
			return false
	return true


## Days since 1 January 1970 (UTC) for a YYYY-MM-DD date.
static func day_number(date: String) -> int:
	return floori(_noon(date) / 86400.0)


## Weeks since the Monday before 1 January 1970; a new week starts every Monday (UTC).
static func week_number(date: String) -> int:
	# 1 January 1970 was a Thursday, three days after a Monday.
	return floori((day_number(date) + 3) / 7.0)


## The ISO 8601 week a date falls in, as "2026-W47": weeks start on Monday and week 1
## is the one with the year's first Thursday.
static func week_label(date: String) -> String:
	var noon := _noon(date)
	var weekday := int(Time.get_datetime_dict_from_unix_time(noon)["weekday"])
	var iso_day := posmod(weekday - 1, 7) + 1
	var thursday := noon + (4 - iso_day) * 86400
	var year := int(Time.get_datetime_dict_from_unix_time(thursday)["year"])
	var first := _noon("%04d-01-01" % year)
	return "%04d-W%02d" % [year, floori((thursday - first) / 86400.0 / 7.0) + 1]


## Seconds from a moment (unix time) until the next UTC day, when new daily goals come.
static func seconds_to_next_day(unix: int) -> int:
	return 86400 - posmod(unix, 86400)


## Seconds from a moment until the next Monday 00:00 UTC, when a new weekly goal comes.
static func seconds_to_next_week(unix: int) -> int:
	var days := floori(unix / 86400.0)
	var monday_based := posmod(days + 3, 7)
	return (days - monday_based + 7) * 86400 - unix


## The goal a pool deals on day (or week) `n`. Each round of a pool (as many days as it
## has goals) deals every goal once, in an order shuffled from the round number alone,
## so every player gets the same goals on the same day.
static func _dealt(tier: String, n: int) -> String:
	var pool := ids(tier)
	if pool.is_empty():
		return ""
	var round_no := floori(n / float(pool.size()))
	return pool[int(_round_order(tier, round_no, pool.size())[posmod(n, pool.size())])]


## A round's order. When it would open with the goal the round before ended on, its first
## two swap, so no goal is dealt two days running.
static func _round_order(tier: String, round_no: int, count: int) -> Array:
	var order := _shuffled(tier, round_no, count)
	if count > 2 and int(order[0]) == int(_shuffled(tier, round_no - 1, count)[count - 1]):
		var first: Variant = order[0]
		order[0] = order[1]
		order[1] = first
	return order


static func _shuffled(tier: String, round_no: int, count: int) -> Array:
	var order := range(count)
	ZRng.new(ZRng.hash_string("goals/%s/%d" % [tier, round_no])).shuffle(order)
	return order


static func _noon(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T12:00:00")


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _same(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return float(a) == float(b)
	return a != null and str(a) == str(b)
