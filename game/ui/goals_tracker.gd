extends Node
## Daily goals (autoload "Goals"): three goals a day (one easy, one medium, one hard) and
## one a week, paid in coins. What the goals are, and which ones a day gets, is in
## core/goal_defs.gd; this keeps the player's progress in Game.profile.state("goals") and
## pays claims into Game.wallet().
##
## Progress comes only from Game.run_event, so goals watch play and never change a run.
## Every mode counts, daily practice included. Goals wait for the player (docs/ROADMAP.md:
## nothing resets against them): an unfinished goal stays, with its progress, however many
## days or weeks it takes. A new UTC day deals a new goal only where one was finished, and
## a new week (from Monday, UTC) a new weekly goal once the last one is finished; finished
## goals that weren't claimed wait among the earlier goals until they are. The home screen
## calls current(), ready_count() and open(), and can listen to `changed` to refresh its
## badge.

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


## The daily goals (one per pool, easy to hard) and the weekly goal, each { id, text,
## progress, target, coins, done, claimed }, plus kind ("daily" or "weekly"), tier, hint,
## art, measure, goal (its GoalDefs id), period (the day or week it was dealt) and earlier.
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


## Claim a finished goal; returns the coins paid (0 if it can't be claimed). Each goal
## pays once.
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


## Claim every finished goal from earlier days at once; returns the coins paid.
func claim_earlier() -> int:
	var state := _state()
	var waiting: Array = state["earlier"]
	if waiting.is_empty():
		return 0
	var coins := 0
	for entry: Dictionary in waiting:
		coins += _pay(entry)
	waiting.clear()
	_save()
	changed.emit()
	return coins


## The wallet goals pay into.
func wallet_in_use() -> Wallet:
	if wallet != null:
		return wallet
	return profile.wallet if profile != null else Game.wallet()


## Open the goals sheet (the home screen's goals ring calls this). Only one at a time. The
## caller plays the click, as for every other sheet.
func open() -> void:
	if UiTheme.sheet_host == null:
		return
	if is_instance_valid(_sheet) and _sheet.is_inside_tree() and not _sheet.is_queued_for_deletion():
		return
	_sheet = GoalsSheet.new()
	UiTheme.show_sheet(_sheet)


func _on_run_event(kind: String, data: Dictionary) -> void:
	record(kind, data, Game.run)


## Count one run event (a Game.run_event) toward the daily and weekly goals. `run` is the
## run it came from: its deck and the Signs it has used are read, never changed.
func record(kind: String, data: Dictionary, run: RunState = null) -> void:
	var state := _state()
	var facts := _facts(state, kind, data, run)
	var moved := false
	var live: Array = (state["daily"] as Array).duplicate()
	live.append(state["weekly"])
	for entry: Dictionary in live:
		var g := GoalDefs.goal(str(entry["goal"]))
		# A goal this build doesn't know can't be counted here; it waits as it is.
		if g.is_empty() or bool(entry.get("claimed", false)) or _done(entry):
			continue
		var params: Dictionary = entry["params"] if entry.get("params") is Dictionary else {}
		var before := int(entry.get("progress", 0))
		# Capped at the target the goal was dealt with, which an update never changes.
		var after := GoalDefs.advance(g, before, kind, facts, params, _target(entry))
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


## The saved goals, brought up to today. A new day gives each pool whose goal was finished
## a new one (the finished goal moves to the earlier ones if it wasn't claimed), and leaves
## unfinished goals as they are; a new week does the same for the weekly goal. A clock
## turned back deals nothing new (that would let goals be farmed).
func _state() -> Dictionary:
	var state := _profile_in_use().state("goals")
	var today := _today()
	_clean(state)
	var slots: Array = state["daily"]
	if str(state.get("day", "")) < today or slots.any(func(e: Dictionary) -> bool: return e.is_empty()):
		_new_day(state, today)
	var week := GoalDefs.week_number(today)
	if not state.has("weekly") or int(state.get("week_no", -1)) < week:
		_new_week(state, today, week)
	return state


## A new day: in each pool, a goal still waiting to be finished stays, and every other
## place gets the goal its pool deals today (or the next one not already held). On the
## same day (a save that lost a goal) only the empty places are dealt.
func _new_day(state: Dictionary, today: String) -> void:
	var new_day := str(state.get("day", "")) < today
	var slots: Array = state["daily"]
	var held := _held(state)
	for i in slots.size():
		var entry: Dictionary = slots[i]
		if not entry.is_empty():
			if not new_day:
				continue
			if _waits(entry):
				_follow_day(entry, today)
				continue
			_retire(state, entry)
		var id := GoalDefs.pick(GoalDefs.DAILY_TIERS[i], GoalDefs.day_number(today), held)
		slots[i] = _deal(id, today, "daily")
		held.append(id)
	if new_day:
		state["day"] = today


## A new week: an unfinished weekly goal carries on into it; otherwise the week deals one.
func _new_week(state: Dictionary, today: String, week: int) -> void:
	var entry: Variant = state.get("weekly")
	if entry is Dictionary:
		if _waits(entry):
			state["week_no"] = week
			state["week"] = GoalDefs.week_label(today)
			return
		_retire(state, entry)
	var id := GoalDefs.pick(GoalDefs.WEEKLY_TIER, week, _held(state))
	state["weekly"] = _deal(id, GoalDefs.week_label(today), "weekly")
	if week > int(state.get("week_no", -1)):
		state["week_no"] = week
		state["week"] = GoalDefs.week_label(today)


## Whether a goal stays for the player: unfinished, and one this build can count. A goal
## from another version of the game that this build doesn't know can't move here, so it
## stays only for its own day or week, then makes way (it pays out if it was finished).
func _waits(entry: Dictionary) -> bool:
	return not _done(entry) and not GoalDefs.goal(str(entry["goal"])).is_empty()


## A goal tied to the day (the daily-run deck) follows the new day while nothing has been
## done toward it, so its words stay true.
func _follow_day(entry: Dictionary, today: String) -> void:
	if int(entry.get("progress", 0)) == 0:
		entry["params"] = _params_for(GoalDefs.goal(str(entry["goal"])), today)


## The goal ids on the board (daily and weekly), which no new goal may repeat.
func _held(state: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in state["daily"]:
		if not entry.is_empty():
			out.append(str(entry["goal"]))
	if state.get("weekly") is Dictionary:
		out.append(str((state["weekly"] as Dictionary)["goal"]))
	return out


## Brings a save from any build into the shape the rest of the tracker trusts: one daily
## goal per pool ({} where there's none, in DAILY_TIERS order), the weekly goal if there is
## one, and the earlier goals. Goals this build doesn't know (from a newer build, or one
## since retired) are kept: nothing counts them here, but they show, and once finished
## they pay what they were dealt with. Only entries without a goal are dropped. A second
## goal for the same pool waits among the earlier goals if it was finished.
func _clean(state: Dictionary) -> void:
	var slots: Array = []
	for tier: String in GoalDefs.DAILY_TIERS:
		slots.append({})
	var extra: Array = []
	var saved: Array = state["daily"] if state.get("daily") is Array else []
	for i in saved.size():
		if not _usable(saved[i]):
			continue
		var entry: Dictionary = saved[i]
		var slot := GoalDefs.DAILY_TIERS.find(_tier_of(entry, i))
		if slot >= 0 and (slots[slot] as Dictionary).is_empty():
			entry["tier"] = GoalDefs.DAILY_TIERS[slot]
			slots[slot] = entry
		else:
			extra.append(entry)
	state["daily"] = slots
	if state.has("weekly") and not _usable(state["weekly"]):
		state.erase("weekly")
	var waiting: Array = []
	if state.get("earlier") is Array:
		for entry: Variant in state["earlier"]:
			if _usable(entry):
				waiting.append(entry)
	state["earlier"] = waiting
	for entry: Dictionary in extra:
		_retire(state, entry)


func _usable(entry: Variant) -> bool:
	return entry is Dictionary and (entry as Dictionary).get("goal") is String and str((entry as Dictionary)["goal"]) != ""


## The pool a saved daily goal belongs to: the one it was dealt from, else its goal's,
## else its place in the list (saves from before goals kept their pool).
func _tier_of(entry: Dictionary, index: int) -> String:
	var tier := str(entry.get("tier", ""))
	if GoalDefs.DAILY_TIERS.has(tier):
		return tier
	var g := GoalDefs.goal(str(entry["goal"]))
	if not g.is_empty():
		return str(g["tier"])
	return GoalDefs.DAILY_TIERS[index] if index < GoalDefs.DAILY_TIERS.size() else ""


## A new goal for a day or week. Its target and reward are kept with it, so a later
## update to the goal's numbers never changes one already dealt.
func _deal(goal_id: String, period: String, kind: String) -> Dictionary:
	var g := GoalDefs.goal(goal_id)
	return { "goal": goal_id, "kind": kind, "tier": str(g.get("tier", "")), "period": period, "progress": 0,
		"target": maxi(1, int(g.get("target", 1))), "claimed": false, "coins": GoalDefs.reward(g),
		"params": _params_for(g, _today()) }


## What a goal's words need from the day: the deck goal asks for that day's daily-run deck,
## which everyone can play.
func _params_for(g: Dictionary, date: String) -> Dictionary:
	if str(g.get("text", "")).contains("{deck}"):
		return { "deck": str(Online.daily_setup(date)["deck"]) }
	return {}


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
	return bool(entry.get("earlier", false)) or int(entry.get("progress", 0)) >= _target(entry)


## The target a goal was dealt with.
func _target(entry: Dictionary) -> int:
	return maxi(1, int(entry.get("target", 1)))


## Goals pay coins only (docs/ROADMAP.md, docs/MONETIZATION.md).
func _pay(entry: Dictionary) -> int:
	var coins := maxi(0, int(entry.get("coins", 0)))
	wallet_in_use().earn("coins", coins)
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
	var target := _target(entry)
	var waiting := bool(entry.get("earlier", false))
	var progress := target if waiting else clampi(int(entry.get("progress", 0)), 0, target)
	return {
		"id": _id_of(entry),
		"goal": str(entry.get("goal", "")),
		"kind": str(entry.get("kind", "daily")),
		"tier": str(entry.get("tier", g.get("tier", entry.get("kind", "daily")))),
		"text": GoalDefs.text_for(g, params) if not g.is_empty() else "A goal from another version of the game",
		"hint": str(g.get("hint", "")),
		"art": str(g.get("art", "trophy")),
		"measure": str(g.get("measure", "count")),
		"progress": progress,
		"target": target,
		"coins": maxi(0, int(entry.get("coins", 0))),
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
