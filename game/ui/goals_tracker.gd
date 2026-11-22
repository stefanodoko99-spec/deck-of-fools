extends Node
## Daily goals (autoload "Goals"): three goals a day (one easy, one medium, one hard) and
## one a week, paid in coins, the weekly one in diamonds too. What the goals are, and which
## ones a day gets, is in core/goal_defs.gd; this keeps the player's progress in
## Game.profile.state("goals") and pays claims into Game.wallet().
##
## Progress comes only from Game.run_event, so goals watch play and never change a run.
## Every mode counts, daily practice included. A new UTC day deals three new goals and a
## new week (from Monday, UTC) a new weekly one: unfinished goals simply make way, with
## nothing lost or held against the player, and finished ones that weren't claimed wait
## among the earlier goals until they are. The home screen calls current(), ready_count()
## and open(), and can listen to `changed` to refresh its badge.

## Progress moved or a goal was claimed (for the home screen's badge and wallet).
signal changed

## Finished goals from earlier days wait, up to this many; past that the oldest pays out
## by itself, so a long break never loses coins and the save stays small.
const MAX_EARLIER := 9

## Where goals are kept and paid. Left null, the player's own (Game.profile and
## Game.wallet()); tests and probes hand in their own, and then nothing is saved to disk.
var profile: Profile = null
var wallet: Wallet = null
## The UTC day the goals follow (YYYY-MM-DD); "" for today. Tests and probes fix one.
var day := ""

var _sheet: Control = null


func _ready() -> void:
	Game.run_event.connect(_on_run_event)


## Today's goals and this week's goal, each { id, text, progress, target, coins, done,
## claimed }, plus kind ("daily" or "weekly"), tier, hint, art, measure, diamonds, goal
## (its GoalDefs id) and period. The daily ones come first, easy to hard.
func current() -> Array:
	var state := _state()
	var out: Array = []
	for entry: Dictionary in state["daily"]:
		out.append(_view(entry))
	out.append(_view(state["weekly"]))
	return out


## Finished goals from earlier days or weeks still waiting to be claimed, oldest first,
## shaped like current()'s (with "earlier" true).
func earlier() -> Array:
	var out: Array = []
	for entry: Dictionary in _state()["earlier"]:
		out.append(_view(entry))
	return out


## Goals finished but not yet claimed (for a badge on the home screen).
func ready_count() -> int:
	var count := earlier().size()
	for g: Dictionary in current():
		if g["done"] and not g["claimed"]:
			count += 1
	return count


## Claim a finished goal; returns the coins paid (0 if it can't be claimed). A weekly goal
## pays its diamonds as well. Each goal pays once.
func claim(id: String) -> int:
	var state := _state()
	var entry := _entry(state, id)
	if entry.is_empty() or bool(entry.get("claimed", false)) or not _done(entry):
		return 0
	var coins := _pay(entry)
	entry["claimed"] = true
	var waiting: Array = state["earlier"]
	for i in waiting.size():
		if is_same(waiting[i], entry):
			waiting.remove_at(i)
			break
	_save()
	changed.emit()
	return coins


## Claim every finished goal from earlier days at once; returns { coins, diamonds }.
func claim_earlier() -> Dictionary:
	var state := _state()
	var paid := { "coins": 0, "diamonds": 0 }
	var waiting: Array = state["earlier"]
	if waiting.is_empty():
		return paid
	for entry: Dictionary in waiting:
		paid["coins"] = int(paid["coins"]) + _pay(entry)
		paid["diamonds"] = int(paid["diamonds"]) + int(entry.get("diamonds", 0))
	waiting.clear()
	_save()
	changed.emit()
	return paid


## The wallet goals pay into.
func wallet_in_use() -> Wallet:
	if wallet != null:
		return wallet
	return profile.wallet if profile != null else Game.wallet()


## Open the goals sheet (the home screen's goals ring calls this). Only one at a time.
func open() -> void:
	if UiTheme.sheet_host == null:
		return
	if is_instance_valid(_sheet) and _sheet.is_inside_tree() and not _sheet.is_queued_for_deletion():
		return
	Feel.play("click")
	_sheet = GoalsSheet.new()
	UiTheme.show_sheet(_sheet)


func _on_run_event(kind: String, data: Dictionary) -> void:
	record(kind, data, Game.run)


## Count one run event (a Game.run_event) toward today's and this week's goals. `run` is
## the run it came from: its deck and the Signs it has used are read, never changed.
func record(kind: String, data: Dictionary, run: RunState = null) -> void:
	var state := _state()
	var facts := _facts(state, kind, data, run)
	var moved := false
	var live: Array = (state["daily"] as Array).duplicate()
	live.append(state["weekly"])
	for entry: Dictionary in live:
		var g := GoalDefs.goal(str(entry["goal"]))
		if g.is_empty() or bool(entry.get("claimed", false)):
			continue
		var params: Dictionary = entry["params"] if entry.get("params") is Dictionary else {}
		var before := int(entry.get("progress", 0))
		var after := GoalDefs.advance(g, before, kind, facts, params)
		if after != before:
			entry["progress"] = after
			moved = true
	if moved:
		_save()
		changed.emit()


## The event's data plus what goals also need: the town the troupe has reached ("reach":
## beating a town's Patron takes it on to the next), the run's deck, and the Signs the run
## used since its last event.
func _facts(state: Dictionary, kind: String, data: Dictionary, run: RunState) -> Dictionary:
	var facts := data.duplicate()
	var town := int(data.get("town", 0))
	var patron_won := kind == "show_won" and int(data.get("show", -1)) == Shows.PATRON
	facts["reach"] = town + 1 if patron_won else town
	if not facts.has("deck") and run != null:
		facts["deck"] = run.deck_id
	if not facts.has("signs"):
		facts["signs"] = _new_signs(state, run)
	return facts


## Signs the run has used since the last event seen from it. Its own count is compared
## with the last one seen, which is kept in the save so a restart doesn't count a Sign
## twice; fewer hands played than last seen means a new run on the same seed (a practice
## restart of the daily run). Read on every event, so a Sign counts on the day it's seen.
func _new_signs(state: Dictionary, run: RunState) -> int:
	if run == null:
		return 0
	var used := int(run.counters.get("used_sign", 0))
	var hands := int(run.counters.get("hands_played", 0))
	var mark: Dictionary = state["mark"] if state.get("mark") is Dictionary else {}
	var same_run := str(mark.get("seed", "")) == run.seed_text and hands >= int(mark.get("hands", 0)) \
		and used >= int(mark.get("signs", 0))
	state["mark"] = { "seed": run.seed_text, "hands": hands, "signs": used }
	return used - int(mark.get("signs", 0)) if same_run else used


## The saved goals, brought up to today: a new day deals three new goals and a new week a
## new weekly one, and finished goals they replace move to the earlier ones. A clock
## turned back deals nothing new (that would let goals be farmed).
func _state() -> Dictionary:
	var state := _profile_in_use().state("goals")
	var today := _today()
	_clean(state)
	if (state["daily"] as Array).is_empty() or str(state.get("day", "")) < today:
		if str(state.get("day", "")) < today:
			for entry: Dictionary in state["daily"]:
				_retire(state, entry)
		state["day"] = today
		var dealt: Array = []
		for id: String in GoalDefs.daily_for(today):
			dealt.append(_deal(id, today, "daily"))
		state["daily"] = dealt
	var week := GoalDefs.week_number(today)
	if not state.has("weekly") or int(state.get("week_no", -1)) < week:
		if state.has("weekly"):
			_retire(state, state["weekly"])
		state["week_no"] = week
		state["week"] = GoalDefs.week_label(today)
		state["weekly"] = _deal(GoalDefs.weekly_for(today), str(state["week"]), "weekly")
	return state


## Drops anything a save from another build can't use (a goal id this build doesn't
## know, a broken entry), so the rest of the tracker can trust the state's shape.
func _clean(state: Dictionary) -> void:
	var daily: Array = []
	if state.get("daily") is Array:
		for entry: Variant in state["daily"]:
			if _usable(entry):
				daily.append(entry)
	state["daily"] = daily
	if state.has("weekly") and not _usable(state["weekly"]):
		state.erase("weekly")
	var waiting: Array = []
	if state.get("earlier") is Array:
		for entry: Variant in state["earlier"]:
			if entry is Dictionary and (entry as Dictionary).has("goal"):
				waiting.append(entry)
	state["earlier"] = waiting


func _usable(entry: Variant) -> bool:
	return entry is Dictionary and not GoalDefs.goal(str((entry as Dictionary).get("goal", ""))).is_empty()


## A new goal for a day or week. Its target and reward are kept with it, so a later
## update to the goal's numbers never changes one already dealt.
func _deal(goal_id: String, period: String, kind: String) -> Dictionary:
	var g := GoalDefs.goal(goal_id)
	var pays := GoalDefs.reward(g)
	var params := {}
	if str(g.get("text", "")).contains("{deck}"):
		# The deck goal asks for today's daily-run deck, which everyone can play.
		params["deck"] = str(Online.daily_setup(_today())["deck"])
	return { "goal": goal_id, "kind": kind, "period": period, "progress": 0, "target": int(g.get("target", 1)),
		"claimed": false, "coins": int(pays["coins"]), "diamonds": int(pays["diamonds"]), "params": params }


## A goal leaves the board. Finished and unclaimed, it waits among the earlier goals (past
## MAX_EARLIER the oldest pays out by itself); otherwise it simply goes.
func _retire(state: Dictionary, entry: Dictionary) -> void:
	if bool(entry.get("claimed", false)) or not _done(entry):
		return
	entry["earlier"] = true
	var waiting: Array = state["earlier"]
	waiting.append(entry)
	while waiting.size() > MAX_EARLIER:
		_pay(waiting.pop_front())


func _done(entry: Dictionary) -> bool:
	return bool(entry.get("earlier", false)) or int(entry.get("progress", 0)) >= maxi(1, int(entry.get("target", 1)))


func _pay(entry: Dictionary) -> int:
	var w := wallet_in_use()
	var coins := int(entry.get("coins", 0))
	w.earn("coins", coins)
	w.earn("diamonds", int(entry.get("diamonds", 0)))
	return coins


## The goal with a current() id ("<goal>@<day or week>"), wherever it is, or {}.
func _entry(state: Dictionary, id: String) -> Dictionary:
	var everywhere: Array = (state["daily"] as Array) + (state["earlier"] as Array)
	everywhere.append(state["weekly"])
	for entry: Dictionary in everywhere:
		if _id_of(entry) == id:
			return entry
	return {}


func _id_of(entry: Dictionary) -> String:
	return "%s@%s" % [entry.get("goal", ""), entry.get("period", "")]


## A goal as the screens see it.
func _view(entry: Dictionary) -> Dictionary:
	var g := GoalDefs.goal(str(entry.get("goal", "")))
	var params: Dictionary = entry["params"] if entry.get("params") is Dictionary else {}
	var target := maxi(1, int(entry.get("target", g.get("target", 1))))
	var waiting := bool(entry.get("earlier", false))
	var progress := target if waiting else clampi(int(entry.get("progress", 0)), 0, target)
	return {
		"id": _id_of(entry),
		"goal": str(entry.get("goal", "")),
		"kind": str(entry.get("kind", "daily")),
		"tier": str(g.get("tier", entry.get("kind", "daily"))),
		"text": GoalDefs.text_for(g, params) if not g.is_empty() else "A goal from an earlier version",
		"hint": str(g.get("hint", "")),
		"art": str(g.get("art", "trophy")),
		"measure": str(g.get("measure", "count")),
		"progress": progress,
		"target": target,
		"coins": int(entry.get("coins", 0)),
		"diamonds": int(entry.get("diamonds", 0)),
		"done": progress >= target,
		"claimed": bool(entry.get("claimed", false)),
		"earlier": waiting,
		"period": str(entry.get("period", "")),
	}


func _profile_in_use() -> Profile:
	return profile if profile != null else Game.profile


func _today() -> String:
	return day if day != "" else Economy.today()


func _save() -> void:
	if profile == null:
		Game.save_profile()
