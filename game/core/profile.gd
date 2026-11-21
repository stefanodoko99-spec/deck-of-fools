class_name Profile
extends RefCounted





var discovered: Dictionary = {}
var feats: Dictionary = {}

var best_stake: Dictionary = {}
var total_wins := 0
var runs_lost := 0
var signs_used := 0
var challenges_won: Dictionary = {}

var badges: Dictionary = {}



func record_run(run: RunState) -> void:
	for id in run.seen:
		discovered[id] = true
	for f in run.feats:
		feats[f] = true
	signs_used += int(run.counters.get("used_sign", 0))
	if run.won:
		if run.challenge != "":
			challenges_won[run.challenge] = true
		else:
			total_wins += 1
			best_stake[run.deck_id] = maxi(int(best_stake.get(run.deck_id, 0)), run.stake)
			for z in run.zanni:
				badges[z.def_id] = maxi(int(badges.get(z.def_id, 0)), run.stake)
	elif run.phase == RunState.Phase.LOST:
		runs_lost += 1


func is_unlocked(def_id: String) -> bool:
	return not Unlocks.RARE_FEATS.has(def_id) or _met(Unlocks.RARE_FEATS[def_id])



func locked_cards() -> Array:
	return Unlocks.RARE_FEATS.keys().filter(func(id: String) -> bool: return not is_unlocked(id))


func deck_unlocked(deck_id: String) -> bool:
	var rule := str(Unlocks.DECK_RULES.get(deck_id, ""))
	if rule == "":
		return true
	var parts := rule.split(":")
	if parts[0] == "discover":
		return discovered.size() >= int(parts[1])
	return best_stake.has(parts[1])



func max_stake(deck_id: String) -> int:
	return mini(Unlocks.TOP_STAKE, int(best_stake.get(deck_id, 0)) + 1)


func challenge_unlocked(challenge_id: String) -> bool:
	var order := ContentDB.pool("challenge").map(func(d: ContentDef) -> String: return d.id)
	var index := order.find(challenge_id)
	return index >= 0 and index < total_wins * Unlocks.CHALLENGES_PER_WIN


func _met(rule: String) -> bool:
	if not rule.begins_with("lifetime:"):
		return feats.has(rule)
	var spec := rule.substr(9).split(">=")
	var have := 0
	match spec[0]:
		"runs_lost":
			have = runs_lost
		"signs_used":
			have = signs_used
	return have >= int(spec[1])


func to_dict() -> Dictionary:
	return {
		"discovered": discovered.keys(), "feats": feats.keys(), "best_stake": best_stake.duplicate(),
		"total_wins": total_wins, "runs_lost": runs_lost, "signs_used": signs_used,
		"challenges_won": challenges_won.keys(), "badges": badges.duplicate(),
	}


static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	for id in d.get("discovered", []):
		p.discovered[str(id)] = true
	for f in d.get("feats", []):
		p.feats[str(f)] = true
	for deck in d.get("best_stake", {}):
		p.best_stake[str(deck)] = int(d["best_stake"][deck])
	p.total_wins = int(d.get("total_wins", 0))
	p.runs_lost = int(d.get("runs_lost", 0))
	p.signs_used = int(d.get("signs_used", 0))
	for c in d.get("challenges_won", []):
		p.challenges_won[str(c)] = true
	for z in d.get("badges", {}):
		p.badges[str(z)] = int(d["badges"][z])
	return p
