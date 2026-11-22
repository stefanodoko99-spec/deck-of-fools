extends "res://tests/suite.gd"
## Profile: everything survives to_dict()/from_dict() (also through JSON, as Game saves
## user://profile.json and the cloud save), old saves still load, and record_run() counts
## Jesters, wins and badges the way the collection expects.


func sample() -> Profile:
	var p := Profile.new()
	p.discovered = { "z_zanni": true, "z_arlecchino": true, "t_matto": true }
	p.feats = { "won_run": true, "jesters_5": true }
	p.best_stake = { "d_bergamo": 3, "d_venezia": 1 }
	p.total_wins = 4
	p.runs_lost = 7
	p.signs_used = 23
	p.challenges_won = { "c_monologo": true }
	p.badges = { "z_zanni": 3, "z_arlecchino": 1 }
	p.jester_runs = { "z_zanni": 5, "z_arlecchino": 2, "z_capitano": 1 }
	p.jester_wins = { "z_zanni": 3, "z_arlecchino": 1 }
	return p


func fields(p: Profile) -> Dictionary:
	return {
		"discovered": p.discovered, "feats": p.feats, "best_stake": p.best_stake,
		"total_wins": p.total_wins, "runs_lost": p.runs_lost, "signs_used": p.signs_used,
		"challenges_won": p.challenges_won, "badges": p.badges,
		"jester_runs": p.jester_runs, "jester_wins": p.jester_wins,
	}


func test_round_trip_keeps_everything() -> void:
	var p := sample()
	var back := Profile.from_dict(p.to_dict())
	eq(fields(back), fields(p), "every field after from_dict(to_dict())")
	eq(back.to_dict(), p.to_dict(), "to_dict() again")


func test_round_trip_through_json() -> void:
	var p := sample()
	var back := Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	eq(fields(back), fields(p), "every field after a JSON save and load")
	for key in ["z_zanni", "z_arlecchino"]:
		eq(typeof(back.jester_runs[key]), TYPE_INT, "jester_runs[%s] is an int again" % key)
		eq(typeof(back.badges[key]), TYPE_INT, "badges[%s] is an int again" % key)
	eq(typeof(back.jester_wins["z_zanni"]), TYPE_INT, "jester_wins is an int again")
	eq(typeof(back.best_stake["d_bergamo"]), TYPE_INT, "best_stake is an int again")


func test_old_saves_still_load() -> void:
	# Saves from before 22 November 2026 have no jester_runs / jester_wins.
	var old := sample().to_dict()
	old.erase("jester_runs")
	old.erase("jester_wins")
	var p := Profile.from_dict(old)
	eq(p.jester_runs, {}, "jester_runs of an old save")
	eq(p.jester_wins, {}, "jester_wins of an old save")
	eq(p.badges, sample().badges, "badges of an old save")
	var empty := Profile.from_dict({})
	eq(empty.to_dict(), Profile.new().to_dict(), "an empty save is a new profile")


func test_record_run_counts_jesters_wins_and_badges() -> void:
	var p := Profile.new()
	# A won tour at stake 3 holding Zanni twice and Arlecchino: each counts once.
	var won := RunState.create("REC-WON", "d_bergamo", 3)
	for id in ["z_zanni", "z_zanni", "z_arlecchino"]:
		won.zanni.append(ItemCard.make(id, 2))
	won.won = true
	p.record_run(won)
	eq(p.jester_runs, { "z_zanni": 1, "z_arlecchino": 1 }, "runs after a won tour")
	eq(p.jester_wins, { "z_zanni": 1, "z_arlecchino": 1 }, "wins after a won tour")
	eq(p.badges, { "z_zanni": 3, "z_arlecchino": 3 }, "badges after a stake 3 win")
	eq([p.total_wins, p.runs_lost, p.best_stake], [1, 0, { "d_bergamo": 3 }], "wins and best stake")
	# A lost run counts its Jesters, not a win.
	var lost := RunState.create("REC-LOST", "d_bergamo", 1)
	lost.zanni.append(ItemCard.make("z_zanni", 2))
	lost.phase = RunState.Phase.LOST
	p.record_run(lost)
	eq([p.jester_runs["z_zanni"], p.jester_wins["z_zanni"], p.runs_lost, p.total_wins], [2, 1, 1, 1], "after a lost run")
	# A won quick run counts for the collection but gives no badge, win or stake.
	var quick := RunState.create("REC-QUICK", "d_bergamo", 5, "", [], "quick")
	quick.zanni.append(ItemCard.make("z_capitano", 4))
	quick.won = true
	p.record_run(quick)
	eq([p.jester_runs.get("z_capitano"), p.jester_wins.get("z_capitano")], [1, 1], "quick run Jester counts")
	check(not p.badges.has("z_capitano"), "a quick run gives no badge")
	eq([p.total_wins, p.best_stake["d_bergamo"]], [1, 3], "a quick run is no tour win")
	# A win at a lower stake keeps the better badge.
	var low := RunState.create("REC-LOW", "d_bergamo", 1)
	low.zanni.append(ItemCard.make("z_zanni", 2))
	low.won = true
	p.record_run(low)
	eq([p.badges["z_zanni"], p.total_wins, p.jester_wins["z_zanni"]], [3, 2, 2], "after a stake 1 win")
	# A challenge win only marks the challenge.
	var challenge := RunState.create("REC-CH", "d_bergamo", 1, "c_monologo")
	challenge.won = true
	p.record_run(challenge)
	check(p.challenges_won.has("c_monologo"), "challenge marked as won")
	eq(p.total_wins, 2, "a challenge win is no tour win")
	eq(Profile.from_dict(p.to_dict()).to_dict(), p.to_dict(), "round trip after recording runs")


func test_unlock_rules() -> void:
	var p := Profile.new()
	check(p.is_unlocked("z_zanni"), "a common Jester is never locked")
	check(not p.is_unlocked("z_burattinaio"), "Il Burattinaio starts locked")
	p.feats["jesters_5"] = true
	check(p.is_unlocked("z_burattinaio"), "Il Burattinaio unlocks with the jesters_5 feat")
	p.runs_lost = 4
	check(not p.is_unlocked("z_fenice"), "La Fenice is locked after 4 lost runs")
	p.runs_lost = 5
	check(p.is_unlocked("z_fenice"), "La Fenice unlocks after 5 lost runs")
	p.signs_used = 50
	check(p.is_unlocked("z_cometa"), "La Cometa unlocks after 50 Signs")
	eq(Profile.new().locked_cards().size(), Unlocks.RARE_FEATS.size(), "a new profile has every Rare locked")
	eq(p.locked_cards().size(), Unlocks.RARE_FEATS.size() - 3, "three unlocked")
	check(p.deck_unlocked("d_bergamo"), "Bergamo is open from the start")
	check(not p.deck_unlocked("d_palermo"), "Palermo needs a Bergamo win")
	p.best_stake["d_bergamo"] = 1
	check(p.deck_unlocked("d_palermo"), "Palermo opens after a Bergamo win")
	eq(p.max_stake("d_bergamo"), 2, "the next stake opens after a win")
	eq(p.max_stake("d_venezia"), 1, "stake 1 on a deck never won")
