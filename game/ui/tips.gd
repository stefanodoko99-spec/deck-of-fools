class_name Tips
extends RefCounted
## Tips at the right moment: one short insight about a run that just lost a show, and a
## Jester of the day for the home screen. Both are quiet lines a screen may show in its
## own layout, never pop-ups (docs/ROADMAP.md: no pop-ups after a loss); insight_line()
## gives the insight ready to add to the lost-show screen.
##
## The insight looks at what the run actually did and says the most useful thing, in this
## order: a Sign still held for a hand the player has been playing, discards left unused
## in the lost show, the poker hand played most (with the Jesters, or the Sign, that would
## boost it), and a run that never took a Jester. When none of these has anything specific
## to say it returns "", so the screen shows nothing rather than a generic tip.

## A hand played at least this often in the run is the player's favourite.
const FAVOURITE_AT := 3
## Hands whose name takes "a" after "You played" ("a Pair", but "Two Pair").
const WITH_ARTICLE := ["pair", "straight", "flush", "full_house", "straight_flush", "flush_house", "flush_five"]
## Each hand's name in the plural, after "boost".
const PLURALS := {
	"high_card": "High Card hands", "pair": "Pairs", "two_pair": "Two Pair", "three_kind": "Three of a Kind",
	"straight": "Straights", "flush": "Flushes", "full_house": "Full Houses", "four_kind": "Four of a Kind",
	"straight_flush": "Straight Flushes", "five_kind": "Five of a Kind", "flush_house": "Flush Houses",
	"flush_five": "Flush Fives",
}
## At most one day in this many, the Jester of the day is one with illustrated art (when
## any has)...
const ILLUSTRATED_EVERY := 3
## ...and further apart while only a few Jesters have art, so each one's turn comes round
## no more often than every this many days.
const ILLUSTRATED_GAP := 14
## The hooks the scorer runs while a hand's Points and Mult are counted (core/scorer.gd).
## A Jester boosts a hand only with one of these: one that only changes the cards after
## scoring (La Ruffiana) or makes the hand easier to make (Il Pittore) doesn't.
const SCORING_HOOKS := ["after_base", "card_scored", "card_held", "retrigger_scored", "retrigger_held",
	"independent", "scored", "before_total"]

## Every Jester id in sorted order, and the illustrated ones, worked out once (looking for
## art files 150 times on every call would be slow); `_cast_size` notes the count of
## Jesters they were worked out from.
static var _cast: Array[String] = []
static var _illustrated: Array[String] = []
static var _cast_size := -1
## The walk's recent rounds (round number: order), so a day costs no shuffles once seen.
static var _rounds: Dictionary = {}


## One short insight about the run that just lost a show, or "" when there's nothing
## useful. `profile` is whose collection to prefer Jesters from (the player's by default).
static func insight_after_loss(run: RunState, profile: Profile = null) -> String:
	if run == null or run.phase != RunState.Phase.LOST:
		return ""
	var player := profile if profile != null else Game.profile
	var favourite := favourite_hand(run)
	var held_sign := _held_sign(run, favourite)
	if held_sign != "":
		return "You still held the %s Sign: it levels up %s for the rest of the run, so use it early." % [
			UiTheme.name_of(held_sign), hand_name(str(ContentDB.get_def(held_sign).data.get("hand", "")))]
	# Lost by running out of hands, with discards still to use.
	if bool(run.show_counters.get("lost", false)) and run.hands_left <= 0 and run.discards_left > 0:
		var n := run.discards_left
		return "You lost with %d discard%s left. Use them to swap weak cards and chase a bigger hand." % [n, "" if n == 1 else "s"]
	if favourite != "":
		var times := run.hand_levels.times_played(favourite)
		var played := "You played %s %d times." % [_with_article(favourite), times]
		if favourite == HandTable.HIGH_CARD:
			return played + " Even a Pair scores about four times as much: discard to find one."
		var held := run.zanni.map(func(z: ItemCard) -> String: return z.def_id)
		var helpers := boosters(favourite, player, run)
		var holds_one := boosters(favourite, player).any(func(id: String) -> bool: return held.has(id))
		if not helpers.is_empty() and not holds_one:
			var who := UiTheme.name_of(helpers[0])
			if helpers.size() == 1:
				return "%s %s boosts %s." % [played, who, PLURALS[favourite]]
			return "%s %s and others boost %s." % [played, who, PLURALS[favourite]]
		var its_sign := SignCards.for_hand(favourite)
		if its_sign != "":
			return "%s The %s Sign levels it up: look for it in the Market." % [played, UiTheme.name_of(its_sign)]
	# Shows were won (so the Market was open), yet no Jester ever joined.
	if run.zanni.is_empty() and int(run.counters.get("shows_won", 0)) > 0:
		return "You had no Jesters. Buy one in the Market after a show: it keeps working for the rest of the run."
	return ""


## The insight as a quiet line for the lost-show screen, wrapped to `width`, or null when
## there's nothing specific to say (the screen then shows nothing).
static func insight_line(run: RunState, width: float, profile: Profile = null) -> Label:
	var text := insight_after_loss(run, profile)
	if text == "":
		return null
	var line := UiTheme.label(text, 9, UiTheme.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(width, 0)
	return line


## The poker hand the run played most (at least FAVOURITE_AT times), or "". Ties go to the
## lower hand, as on the run-over screen's "Most played".
static func favourite_hand(run: RunState) -> String:
	var best := ""
	var most := FAVOURITE_AT - 1
	for hand: String in HandTable.ORDER:
		if run.hand_levels.times_played(hand) > most:
			most = run.hand_levels.times_played(hand)
			best = hand
	return best


## The Jesters that boost a poker hand: their card text names it and they add to a hand's
## score (SCORING_HOOKS). Best suggestions first: ones the player has met before the rest,
## then the commoner ones (easier to find in the Market), then in collection order. With a
## run, Jesters it holds or keeps out of its Market are left out. A longer hand's name
## doesn't count for a shorter one ("Two Pair" isn't "Pair").
static func boosters(hand: String, player: Profile, run: RunState = null) -> Array[String]:
	var wanted := hand_name(hand)
	var longer: Array[String] = []
	for other: String in HandTable.ORDER:
		var other_name := hand_name(other)
		if other_name != wanted and other_name.contains(wanted):
			longer.append(other_name)
	var held := {}
	if run != null:
		for z: ItemCard in run.zanni:
			held[z.def_id] = true
	var out: Array[String] = []
	var order := {}
	for d: ContentDef in ContentDB.pool("zanni"):
		order[d.id] = order.size()
		if held.has(d.id) or (run != null and run.locked.has(d.id)) or not SCORING_HOOKS.any(d.has_hook):
			continue
		var text := UiTheme.text_of(d.id)
		for other_name: String in longer:
			text = text.replace(other_name, "")
		if text.contains(wanted):
			out.append(d.id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var met_a := player != null and player.discovered.has(a)
		var met_b := player != null and player.discovered.has(b)
		if met_a != met_b:
			return met_a
		var rarity_a := ContentDB.get_def(a).rarity
		var rarity_b := ContentDB.get_def(b).rarity
		if rarity_a != rarity_b:
			return rarity_a < rarity_b
		return int(order[a]) < int(order[b]))
	return out


## Today's spotlight Jester (a def id), the same for everyone on a given UTC day. Now and
## then (see illustrated_every) it is one of the Jesters with illustrated art, in turn; the
## other days walk through every Jester in an order shuffled once a round, so each one has
## its day before any comes back. `date` (YYYY-MM-DD) is for tests; "" means today.
static func jester_of_the_day(date := "") -> String:
	_load_cast()
	if _cast.is_empty():
		return ""
	var day := GoalDefs.day_number(date if date != "" else Economy.today())
	var every := _every()
	if every == 0 or posmod(day, every) != 0:
		return _walked(day, every)
	# The illustrated Jesters take turns; one the days either side already spotlight
	# waits for its next turn.
	var turn := floori(day / float(every))
	var around := [_walked(day - 1, every), _walked(day + 1, every)]
	for k in _illustrated.size():
		var id := _illustrated[posmod(turn + k, _illustrated.size())]
		if not around.has(id):
			return id
	return _illustrated[posmod(turn, _illustrated.size())]


## Every how many days an illustrated Jester has the spotlight (0 when none has art):
## every ILLUSTRATED_EVERY days, or less often while so few have art that each would be
## back within ILLUSTRATED_GAP days.
static func illustrated_every() -> int:
	_load_cast()
	return _every()


static func _every() -> int:
	if _illustrated.is_empty():
		return 0
	return maxi(ILLUSTRATED_EVERY, ceili(ILLUSTRATED_GAP / float(_illustrated.size())))


## The walk's Jester on a day that isn't an illustrated one. The walk counts only those
## days, so it never skips a place in its order (`every` 0: every day is a walk day).
static func _walked(day: int, every: int) -> String:
	var walk := day if every == 0 else day - floori(day / float(every)) - 1
	return _cast[int(_walk_order(floori(walk / float(_cast.size())))[posmod(walk, _cast.size())])]


static func _load_cast() -> void:
	var jesters := ContentDB.pool("zanni")
	if jesters.size() == _cast_size:
		return
	_cast_size = jesters.size()
	_rounds.clear()
	_cast.clear()
	for d: ContentDef in jesters:
		_cast.append(d.id)
	_cast.sort()
	_illustrated.assign(_cast.filter(func(id: String) -> bool: return CardView.art_for("zanni", id) != null))


## A round of the walk: every Jester once, shuffled from the round number. When it would
## open with the Jester the round before ended on, its first two swap, so no Jester has two
## days running.
static func _walk_order(round_no: int) -> Array:
	if _rounds.has(round_no):
		return _rounds[round_no]
	var order := _shuffled_cast(round_no)
	if order.size() > 2 and int(order[0]) == int(_shuffled_cast(round_no - 1)[order.size() - 1]):
		var first: Variant = order[0]
		order[0] = order[1]
		order[1] = first
	if _rounds.size() >= 4:
		_rounds.clear()
	_rounds[round_no] = order
	return order


static func _shuffled_cast(round_no: int) -> Array:
	var order := range(_cast.size())
	ZRng.new(ZRng.hash_string("jester-of-the-day/%d" % round_no)).shuffle(order)
	return order


## A poker hand's name as the game shows it ("Two Pair").
static func hand_name(hand: String) -> String:
	return TranslationServer.translate("hand." + hand)


## A Sign the run still holds, for its favourite hand if there is one, else for any hand
## it has played; "" when it holds none worth mentioning.
static func _held_sign(run: RunState, favourite: String) -> String:
	var played_sign := ""
	for item: ItemCard in run.consumables:
		var def := item.def()
		if def == null or def.kind != "sign":
			continue
		var hand := str(def.data.get("hand", ""))
		if hand == favourite and favourite != "":
			return def.id
		if played_sign == "" and run.hand_levels.times_played(hand) > 0:
			played_sign = def.id
	return played_sign


static func _with_article(hand: String) -> String:
	return ("a " if WITH_ARTICLE.has(hand) else "") + hand_name(hand)
