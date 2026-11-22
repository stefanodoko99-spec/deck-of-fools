extends "res://tests/suite.gd"
## The play bot (bot.gd) plays complete runs through RunState.apply() only: tours, quick runs
## and boss rushes on several decks and stakes, plus a few challenges. Every action must be
## accepted, every phase change legal and every state consistent; each run must end, won or
## lost, within an action cap; save and load at random points must give back the same run
## and play on the same (save_check.gd); and replaying the action log on a new run must
## rebuild it exactly. Then it prints the numbers used for balancing (and --stats-out JSON).
## The wandering bot also tries packs, Warrants, rerolls, selling, using cards on random
## targets and so on; there a refused action is fine but must leave the run exactly as it was.

const Bot := preload("res://tests/bot.gd")
const SaveCheck := preload("res://tests/save_check.gd")
const P := RunState.Phase

const MAX_ACTIONS := 3000
## Chance of a save/load checkpoint after each action, and how long the copies are followed.
const CHECK_CHANCE := 0.04
const FOLLOW := 20
## Decks and stakes for the mixed runs (the first group is always Bergamo at stake 1).
const MIXED_DECKS := ["d_venezia", "d_genova", "d_siena", "d_napoli", "d_verona", "d_ferrara", "d_carnevale",
	"d_firenze", "d_palermo", "d_padova", "d_benevento", "d_bologna", "d_roma", "d_mantova"]
const CHALLENGES := ["c_cinque_carte", "c_divieto", "c_ultima_replica", "c_bancarotta", "c_tassa_lusso",
	"c_notte_bianca", "c_mazzo_doppio", "c_monologo"]

## The phase an action is taken from, and the phases it may lead to. Actions missing from
## FROM work in several phases; "same" means the phase doesn't change.
const FROM := {
	"select_show": P.CHOOSE_SHOW, "skip_show": P.CHOOSE_SHOW, "play": P.IN_SHOW, "discard": P.IN_SHOW,
	"cash_out": P.CASH_OUT, "buy": P.SHOP, "buy_pack": P.SHOP, "reroll": P.SHOP, "buy_warrant": P.SHOP,
	"leave_shop": P.SHOP, "pick": P.PACK, "skip_pack": P.PACK,
}
const TO := {
	"select_show": [P.IN_SHOW],
	"skip_show": [P.CHOOSE_SHOW, P.PACK],
	"play": [P.IN_SHOW, P.CASH_OUT, P.LOST],
	"discard": [P.IN_SHOW],
	"cash_out": [P.SHOP, P.PACK],
	"buy": [P.SHOP],
	"buy_pack": [P.PACK],
	"reroll": [P.SHOP],
	"buy_warrant": [P.SHOP],
	"leave_shop": [P.CHOOSE_SHOW],
	"pick": [P.PACK, P.SHOP, P.CHOOSE_SHOW, P.CASH_OUT],
	"skip_pack": [P.PACK, P.SHOP, P.CHOOSE_SHOW, P.CASH_OUT],
	"sell": "same", "use": "same", "reorder_zanni": "same", "swap_patron": "same",
}
## A refused action may still start an RNG stream it looked at; that alone changes nothing.
const NEW_STREAM := "^\\.rng\\.[^:]+: \\d+, expected no such key$"


## The run list: 1/3 Bergamo stake 1 tours, 1/6 quick runs, 1/6 boss rushes (both Bergamo
## stake 1), and 1/3 mixed decks, stakes and modes.
static func specs(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mixed := 0
	for i in count:
		match i % 6:
			0, 1:
				out.append({ "group": "tour s1", "mode": "tour", "deck": "d_bergamo", "stake": 1, "seed": "BOT-T%03d" % i })
			2:
				out.append({ "group": "quick s1", "mode": "quick", "deck": "d_bergamo", "stake": 1, "seed": "BOT-Q%03d" % i })
			3:
				out.append({ "group": "bosses s1", "mode": "bosses", "deck": "d_bergamo", "stake": 1, "seed": "BOT-B%03d" % i })
			_:
				out.append({ "group": "mixed", "mode": ["tour", "tour", "quick", "bosses"][mixed % 4],
					"deck": MIXED_DECKS[mixed % MIXED_DECKS.size()], "stake": 1 + (mixed * 3) % 8, "seed": "BOT-M%03d" % i })
				mixed += 1
	return out


func test_bot_plays_complete_runs() -> void:
	var count := int(options.get("bot_runs", 48))
	var rows: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for spec in specs(count):
		rows.append(play(spec))
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	var groups := ["tour s1", "quick s1", "bosses s1", "mixed"]
	print_table("Play bot: %d complete runs in %.1f s" % [rows.size(), seconds], rows, groups)
	var known := 0
	for row in rows:
		known += int(row["sticker_drops"])
	if known > 0:
		print("  known bug shop-stickers: a save/load dropped shop stickers %d times (stake 4+ shops)" % known)
	write_stats(rows, groups, seconds)


func test_bot_plays_challenges() -> void:
	var rows: Array[Dictionary] = []
	for i in CHALLENGES.size():
		var id: String = CHALLENGES[i]
		var deck := str(ContentDB.get_def(id).data["deck"])
		rows.append(play({ "group": "challenges", "mode": "tour", "deck": deck, "stake": 1, "challenge": id, "seed": "BOT-C%03d" % i }))
	print_table("Play bot: %d challenge runs" % rows.size(), rows, ["challenges"])


func test_wandering_bot_keeps_the_run_valid() -> void:
	var count := maxi(4, int(options.get("bot_runs", 48)) / 2)
	var rows: Array[Dictionary] = []
	var tried := {}
	var refused := 0
	for i in count:
		var spec := { "group": "wander", "mode": ["tour", "quick", "bosses"][i % 3], "deck": (["d_bergamo"] + MIXED_DECKS)[i % 15],
			"stake": 1 + (i * 5) % 8, "seed": "BOT-W%03d" % i, "wander": true }
		var row := play(spec)
		rows.append(row)
		refused += int(row["refused"])
		for name in row["tried"]:
			tried[name] = int(tried.get(name, 0)) + int(row["tried"][name])
	print_table("Wandering bot: %d runs" % rows.size(), rows, ["wander"])
	print("    actions taken: %s; refused (state unchanged): %d" % [tried, refused])
	# With a dozen runs or more every kind of side move should have gone through at least once.
	if count >= 12:
		for name in ["skip_show", "buy_pack", "pick", "reroll", "use", "sell", "reorder_zanni", "buy_warrant"]:
			check(tried.has(name), "the wandering bot never managed a '%s'" % name)


## Plays one run to its end with every check on; returns its numbers.
func play(spec: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var label := "%s %s %s stake %d%s" % [spec["seed"], spec["mode"], spec["deck"], spec["stake"],
		(" " + str(spec["challenge"])) if spec.has("challenge") else ""]
	var run := RunState.create(spec["seed"], spec["deck"], spec["stake"], str(spec.get("challenge", "")), [], spec["mode"])
	var bot := Bot.new()
	var wandering := bool(spec.get("wander", false))
	if wandering:
		bot.wander = RandomNumberGenerator.new()
		bot.wander.seed = hash(str(spec["seed"]) + "/wander")
	var saves := SaveCheck.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(str(spec["seed"]) + "/checks")
	var row := spec.duplicate()
	for key in ["actions", "cashout", "cashouts", "in_show_ducats", "spent", "jesters_bought", "cards_used", "plays", "discards", "refused"]:
		row[key] = 0
	row["tried"] = {}
	row["cashed"] = []
	var new_stream := RegEx.create_from_string(NEW_STREAM)
	var problems: Array[String] = []
	var next_id_at_show := 0
	var matinees := []
	var visited := {}
	_invariants(run, -1, problems)
	while not run.won and run.phase != P.LOST and problems.is_empty():
		if int(row["actions"]) >= MAX_ACTIONS:
			problems.append("stuck: still going after %d actions (town %d, %s)" % [MAX_ACTIONS, run.town, P.keys()[run.phase]])
			break
		var action := bot.next_action(run)
		if action.is_empty():
			problems.append("no move in %s: hand %d, draw pile %d, hands left %d, discards left %d" % [
				P.keys()[run.phase], run.hand.size(), run.draw_pile.size(), run.hands_left, run.discards_left])
			break
		var name: String = action["a"]
		var from := run.phase
		var ducats := run.ducats
		var jesters := run.zanni.size()
		if name == "select_show":
			next_id_at_show = run._next_card_id
		var before: Dictionary = run.to_dict() if wandering else {}
		var result := run.apply(action)
		row["actions"] += 1
		if not result["ok"]:
			if not wandering:
				problems.append("%s refused in %s: %s" % [action, P.keys()[from], result.get("error", "")])
				break
			row["refused"] += 1
			var changed: Array[String] = []
			diff(run.to_dict(), before, "", changed)
			changed = changed.filter(func(line: String) -> bool: return new_stream.search(line) == null)
			if not changed.is_empty():
				problems.append("%s was refused (%s) but changed the run: %s" % [action, result.get("error", ""), "; ".join(changed.slice(0, 4))])
			saves.follow(action, result, run)
			continue
		row["tried"][name] = int(row["tried"].get(name, 0)) + 1
		var allowed: Variant = TO.get(name, "same")
		if FROM.get(name, from) != from or (allowed is String and run.phase != from) or (allowed is Array and not (allowed as Array).has(run.phase)):
			problems.append("%s went from %s to %s" % [name, P.keys()[from], P.keys()[run.phase]])
		_invariants(run, next_id_at_show, problems)
		match name:
			"select_show":
				if run.show_target != run.target_for_show(run.show_index) or run.show_target <= 0.0:
					problems.append("town %d show %d target %d, expected %d" % [run.town, run.show_index, run.show_target, run.target_for_show(run.show_index)])
				if run.show_index == Shows.MATINEE and not wandering:
					if not matinees.is_empty() and run.show_target <= matinees.back():
						problems.append("Matinee target %d is not above the last town's %d" % [run.show_target, matinees.back()])
					matinees.append(run.show_target)
			"play", "discard":
				row["in_show_ducats"] += run.ducats - ducats
				row["plays" if name == "play" else "discards"] += 1
			"cash_out":
				row["cashout"] += int(result["ducats"])
				row["cashouts"] += 1
				row["cashed"].append([run.town, run.show_index, int(result["ducats"])])
			"buy":
				row["spent"] += ducats - run.ducats
				if run.zanni.size() > jesters:
					row["jesters_bought"] += 1
			"use":
				row["cards_used"] += 1
		saves.follow(action, result, run)
		var key := "%s %d" % [P.keys()[run.phase], run.show_index]
		if dice.randf() < CHECK_CHANCE or not visited.has(key):
			visited[key] = true
			saves.checkpoint(run, "%s after %d actions (town %d, %s)" % [spec["seed"], row["actions"], run.town, P.keys()[run.phase]], FOLLOW)
	saves.finish(run)
	problems.append_array(saves.problems)
	if run.won and (run.town != run.final_town() or run.show_index != Shows.PATRON or run.phase != P.CASH_OUT):
		problems.append("won in town %d show %d, %s" % [run.town, run.show_index, P.keys()[run.phase]])
	_check_replay(spec, run, problems)
	row["won"] = run.won
	row["town"] = run.town
	row["shows_won"] = int(run.counters.get("shows_won", 0))
	row["end_ducats"] = run.ducats
	row["jesters"] = run.zanni.map(func(z: ItemCard) -> String: return z.def_id)
	row["best_hand"] = float(run.counters.get("best_hand", 0.0))
	row["checkpoints"] = saves.checkpoints
	row["sticker_drops"] = saves.sticker_drops
	row["decisions"] = bot.decisions
	row["previews"] = bot.previews
	row["ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	for p in problems.slice(0, 5):
		fail("%s: %s" % [label, p])
	if bool(options.get("verbose", false)):
		print("      %-44s %s town %d, %2d shows, %3d ducats cashed, %4d actions, %5.0f ms%s" % [label,
			"WON " if run.won else "lost", run.town, row["shows_won"], row["cashout"], row["actions"], row["ms"],
			"" if problems.is_empty() else "  PROBLEMS: %d" % problems.size()])
	return row


## Replays the action log on a new run (also with RunState.replay() for a tour) and compares.
func _check_replay(spec: Dictionary, run: RunState, problems: Array[String]) -> void:
	var again := RunState.create(spec["seed"], spec["deck"], spec["stake"], str(spec.get("challenge", "")), [], spec["mode"])
	for action in run.action_log:
		var result := again.apply(action)
		if not result["ok"]:
			problems.append("replaying the log: %s refused: %s" % [action, result.get("error", "")])
			return
	var out: Array[String] = []
	diff(again.to_dict(), run.to_dict(), "", out)
	if not out.is_empty():
		problems.append("replaying the log gave another run: " + "; ".join(out.slice(0, 4)))
	if spec["mode"] == "tour":
		var replayed := RunState.replay(spec["seed"], spec["deck"], spec["stake"], run.action_log, str(spec.get("challenge", "")))
		out.clear()
		diff(replayed.to_dict(), run.to_dict(), "", out)
		if not out.is_empty():
			problems.append("RunState.replay() gave another run: " + "; ".join(out.slice(0, 4)))


## Things that hold after every action.
func _invariants(run: RunState, next_id_at_show: int, problems: Array[String]) -> void:
	var where := "after %d actions (town %d, %s)" % [run.action_log.size(), run.town, P.keys()[run.phase] if run.phase >= 0 and run.phase < P.size() else str(run.phase)]
	if not P.values().has(run.phase):
		problems.append("unknown phase %d %s" % [run.phase, where])
		return
	if run.show_index < Shows.MATINEE or run.show_index > Shows.PATRON or run.town < 1:
		problems.append("town %d show %d %s" % [run.town, run.show_index, where])
	if not run.won and run.town > run.final_town():
		problems.append("past the final town without a win " + where)
	if run.mode == "bosses" and run.show_index != Shows.PATRON and (run.phase == P.CHOOSE_SHOW or run.phase == P.IN_SHOW):
		problems.append("a boss rush on a show that is not a Patron's " + where)
	var deck := {}
	for card in run.full_deck:
		if deck.has(card.id):
			problems.append("card %d twice in the deck %s" % [card.id, where])
		deck[card.id] = true
	for t in HandTable.ORDER:
		if run.hand_levels.level(t) < 1:
			problems.append("%s at level %d %s" % [t, run.hand_levels.level(t), where])
	if (run.phase == P.SHOP) != (run.shop != null) and run.phase != P.PACK:
		problems.append("shop is %s in %s" % ["missing" if run.shop == null else "still open", where])
	if run.phase != P.IN_SHOW:
		return
	var piles := {}
	for pile: Array[PlayingCard] in [run.draw_pile, run.hand, run.discard_pile]:
		for card in pile:
			if not deck.has(card.id):
				problems.append("card %d is in a pile but not in the deck %s" % [card.id, where])
			if piles.has(card.id):
				problems.append("card %d is in two piles %s" % [card.id, where])
			piles[card.id] = true
	for card in run.full_deck:
		# Cards made during this show (Il Tipografo) join the deck for the next one.
		if not piles.has(card.id) and card.id < next_id_at_show:
			problems.append("card %d (%s) is in the deck but in no pile %s" % [card.id, card.label(), where])
	if run.hands_left < 1 or run.discards_left < 0:
		problems.append("in a show with %d hands and %d discards left %s" % [run.hands_left, run.discards_left, where])
	if run.show_score >= run.show_target:
		problems.append("show still on at %d of %d %s" % [run.show_score, run.show_target, where])


func print_table(title: String, rows: Array[Dictionary], groups: Array) -> void:
	print("")
	print("  " + title)
	print("    %-15s %4s %5s %6s %6s %7s %7s %8s %8s %7s %7s %8s" % ["group", "runs", "won", "win%", "towns", "shows",
		"duc/sh", "duc/run", "in-show", "spent", "acts", "ms/run"])
	for g in groups + ["all"]:
		var a := aggregate(rows, g)
		if int(a["runs"]) == 0:
			continue
		print("    %-15s %4d %5d %5.1f%% %6.2f %6.2f %7.2f %7.1f %8.1f %7.1f %7.0f %8.0f" % [g, a["runs"], a["won"], a["win_pct"],
			a["towns"], a["shows_won"], a["ducats_per_show"], a["ducats_per_run"], a["in_show_per_run"], a["spent_per_run"],
			a["actions_per_run"], a["ms_per_run"]])
	var all := aggregate(rows, "all")
	print("    towns reached (runs per town): %s" % [all["town_spread"]])
	print("    ducats cashed out per show won: %s" % [all["cash_by_show"]])
	print("    ducats cashed out per show won, by town: %s" % [all["cash_by_town"]])
	print("    duc/sh = ducats cashed out per show won; duc/run = cashed out per run; in-show = net ducats")
	print("    from Jesters and Patrons during shows; spent = in the shop; acts = actions per run")


func aggregate(rows: Array[Dictionary], group: String) -> Dictionary:
	var picked := rows.filter(func(r: Dictionary) -> bool: return group == "all" or r["group"] == group)
	var n := picked.size()
	var sums := { "won": 0.0, "town": 0.0, "shows_won": 0.0, "cashout": 0.0, "cashouts": 0.0, "in_show_ducats": 0.0,
		"spent": 0.0, "actions": 0.0, "ms": 0.0 }
	var spread := {}
	var by_show := [[0, 0], [0, 0], [0, 0]]
	var by_town := {}
	for r: Dictionary in picked:
		for key in sums:
			sums[key] += float(r[key])
		spread[int(r["town"])] = int(spread.get(int(r["town"]), 0)) + 1
		for c in r["cashed"]:
			by_show[int(c[1])][0] += int(c[2])
			by_show[int(c[1])][1] += 1
			if not by_town.has(int(c[0])):
				by_town[int(c[0])] = [0, 0]
			by_town[int(c[0])][0] += int(c[2])
			by_town[int(c[0])][1] += 1
	var towns := spread.keys()
	towns.sort()
	var d := maxf(1.0, n)
	return {
		"runs": n, "won": int(sums["won"]), "win_pct": 100.0 * sums["won"] / d,
		"towns": sums["town"] / d, "shows_won": sums["shows_won"] / d,
		"ducats_per_show": sums["cashout"] / maxf(1.0, sums["cashouts"]), "ducats_per_run": sums["cashout"] / d,
		"in_show_per_run": sums["in_show_ducats"] / d, "spent_per_run": sums["spent"] / d,
		"actions_per_run": sums["actions"] / d, "ms_per_run": sums["ms"] / d,
		"town_spread": ", ".join(towns.map(func(t: int) -> String: return "%d:%d" % [t, spread[t]])),
		"cash_by_show": "Matinee %.2f (%d), Evening %.2f (%d), Patron %.2f (%d)" % [
			by_show[0][0] / maxf(1.0, by_show[0][1]), by_show[0][1], by_show[1][0] / maxf(1.0, by_show[1][1]), by_show[1][1],
			by_show[2][0] / maxf(1.0, by_show[2][1]), by_show[2][1]],
		"cash_by_town": ", ".join(_sorted_keys(by_town).map(func(t: int) -> String:
			return "%d: %.2f (%d)" % [t, by_town[t][0] / maxf(1.0, by_town[t][1]), by_town[t][1]])),
	}


static func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


func write_stats(rows: Array[Dictionary], groups: Array, seconds: float) -> void:
	var path := str(options.get("stats_out", ""))
	if path == "":
		return
	var summary := {}
	for g in groups + ["all"]:
		summary[g] = aggregate(rows, g)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not check(f != null, "can't write %s" % path):
		return
	f.store_string(JSON.stringify({ "runs": rows, "summary": summary, "seconds": seconds,
		"bot": "tests/bot.gd: plays the best hand by preview, discards weak hands, buys the dearest affordable Jester, never skips, rerolls, sells or uses cards" }, "  "))
	print("    numbers written to %s" % path)
