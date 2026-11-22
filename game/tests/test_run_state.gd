extends "res://tests/suite.gd"
## RunState: the same seed and actions always give the same state; a run saved with to_dict()
## and loaded with from_dict() (also through JSON, as Game saves it) is the same run in every
## phase and plays on the same; illegal actions change nothing; modes; known bugs.

const Bot := preload("res://tests/bot.gd")
const SaveCheck := preload("res://tests/save_check.gd")
const P := RunState.Phase


func new_run(seed: String, mode := "tour", stake := 1, deck := "d_bergamo") -> RunState:
	return RunState.create(seed, deck, stake, "", [], mode)


func ended(run: RunState) -> bool:
	return run.won or run.phase == P.LOST


## Lets the bot play until done(run) is true or the run ends; returns how many actions it took.
func play_until(run: RunState, done: Callable, cap := 3000, bot: Bot = null) -> int:
	if bot == null:
		bot = Bot.new()
	var steps := 0
	while steps < cap and not ended(run) and not done.call(run):
		var action := bot.next_action(run)
		if action.is_empty():
			fail("the bot found no move in phase %s" % P.keys()[run.phase])
			break
		var result := run.apply(action)
		if not check(result["ok"], "bot action %s was refused: %s" % [action, result.get("error", "")]):
			break
		steps += 1
	return steps


func ids(cards: Array[PlayingCard]) -> Array:
	return cards.map(func(c: PlayingCard) -> int: return c.id)


func test_create_is_deterministic() -> void:
	for mode in ["tour", "quick", "bosses"]:
		eq(new_run("SAME-SEED", mode).to_dict(), new_run("SAME-SEED", mode).to_dict(), "two %s runs from one seed" % mode)
	# A run doesn't depend on runs made before it.
	var first := new_run("ORDER-A").to_dict()
	var other := new_run("ORDER-B")
	play_until(other, func(_r: RunState) -> bool: return false, 40)
	eq(new_run("ORDER-A").to_dict(), first, "the same seed after another run was played")


func test_different_seeds_deal_different_hands() -> void:
	var a := new_run("SEED-ONE")
	var b := new_run("SEED-TWO")
	a.apply({ "a": "select_show" })
	b.apply({ "a": "select_show" })
	eq(a.hand.size(), 8, "hand size")
	check(ids(a.hand) != ids(b.hand), "two seeds dealt the same hand %s" % [ids(a.hand)])


func test_same_actions_give_the_same_state() -> void:
	for spec in [["LOCKSTEP-T", "tour", 1], ["LOCKSTEP-Q", "quick", 2], ["LOCKSTEP-B", "bosses", 1], ["LOCKSTEP-S8", "tour", 8]]:
		var a := new_run(spec[0], spec[1], spec[2])
		var b := new_run(spec[0], spec[1], spec[2])
		var bot := Bot.new()
		var steps := 0
		while steps < 300 and not ended(a):
			var action := bot.next_action(a)
			var ra := a.apply(action)
			var rb := b.apply(action)
			steps += 1
			if not eq(rb, ra, "%s: result of action %d %s" % [spec[0], steps, action]):
				break
			if steps % 10 == 0 and not eq(b.to_dict(), a.to_dict(), "%s: state after %d actions" % [spec[0], steps]):
				break
		eq(b.to_dict(), a.to_dict(), "%s: state after %d actions" % [spec[0], steps])
		note("%s %s: %d actions, town %d" % [spec[0], spec[1], steps, a.town])


func test_replaying_the_action_log_rebuilds_the_run() -> void:
	var run := new_run("REPLAY-TOUR")
	play_until(run, func(_r: RunState) -> bool: return false)
	check(ended(run), "the bot finished the run")
	var again := RunState.replay(run.seed_text, run.deck_id, run.stake, run.action_log)
	eq(again.to_dict(), run.to_dict(), "RunState.replay() of a tour")
	for mode in ["quick", "bosses"]:
		var r := new_run("REPLAY-" + mode, mode)
		play_until(r, func(_r: RunState) -> bool: return false)
		var copy := new_run("REPLAY-" + mode, mode)
		for action in r.action_log:
			if not check(copy.apply(action)["ok"], "%s replay refused %s" % [mode, action]):
				break
		eq(copy.to_dict(), r.to_dict(), "create() + apply() of the %s log" % mode)


func test_preview_matches_the_hand_played_and_changes_nothing() -> void:
	# Without Jesters nothing is left to chance, so the preview is the exact score.
	var run := new_run("PREVIEW")
	var bot := Bot.new()
	bot.reserve = 1000000
	var plays := 0
	while plays < 30 and not ended(run):
		var action := bot.next_action(run)
		if action["a"] == "play":
			var before := run.to_dict()
			var guess := run.preview(action["cards"])
			eq(run.to_dict(), before, "state after preview()")
			var result := run.apply(action)
			eq(result["total"], guess, "preview of %s" % [action["cards"]])
			plays += 1
		else:
			run.apply(action)
	check(plays >= 10, "only %d hands played" % plays)
	eq(run.preview([]), -1.0, "preview of no cards outside a show")


func test_save_and_load_in_every_phase() -> void:
	var run := new_run("SAVE-PHASES")
	var saves := SaveCheck.new()
	var bot := Bot.new()
	var seen := {}
	var steps := 0
	while steps < 800 and not ended(run) and seen.size() < 5:
		var key := phase_key(run)
		if not seen.has(key):
			seen[key] = true
			saves.checkpoint(run, key, 25)
		var action := bot.next_action(run)
		var result := run.apply(action)
		saves.follow(action, result, run)
		steps += 1
	saves.finish(run)
	for key in ["CHOOSE_SHOW", "IN_SHOW (first hand)", "IN_SHOW (later)", "CASH_OUT", "SHOP"]:
		check(seen.has(key), "never saved in " + key)
	for p in saves.problems:
		fail(p)
	note("checked %s" % [seen.keys()])


func test_save_and_load_inside_a_pack() -> void:
	var run := new_run("SAVE-PACK")
	play_until(run, func(r: RunState) -> bool: return r.phase == P.SHOP)
	if not check(run.phase == P.SHOP, "reached the shop"):
		return
	run.open_pack("pk_tarocchi_small")
	eq(run.phase, P.PACK, "phase after opening a pack")
	check(not run.hand.is_empty(), "a Tarocchi pack deals a hand to aim at")
	var saves := SaveCheck.new()
	saves.checkpoint(run, "PACK", 3)
	for action in [{ "a": "skip_pack" }, { "a": "leave_shop" }, { "a": "select_show" }]:
		var result := run.apply(action)
		check(result["ok"], "%s refused: %s" % [action, result.get("error", "")])
		saves.follow(action, result, run)
	saves.finish(run)
	for p in saves.problems:
		fail(p)


func test_save_and_load_in_the_middle_of_a_show() -> void:
	var run := new_run("SAVE-MID-SHOW")
	play_until(run, func(r: RunState) -> bool:
		return r.phase == P.IN_SHOW and r.show_index == Shows.EVENING and int(r.show_counters.get("hands_played", 0)) >= 1)
	if not check(run.phase == P.IN_SHOW, "reached the middle of the Evening show"):
		return
	var saved := run.to_dict()
	for loaded in [RunState.from_dict(saved), RunState.from_dict(JSON.parse_string(JSON.stringify(saved)))]:
		eq(ids(loaded.hand), ids(run.hand), "hand, in order")
		eq(ids(loaded.draw_pile), ids(run.draw_pile), "draw pile, in order")
		eq(ids(loaded.discard_pile), ids(run.discard_pile), "discard pile")
		eq([loaded.hands_left, loaded.discards_left, loaded.show_score, loaded.show_target, loaded.ducats],
			[run.hands_left, run.discards_left, run.show_score, run.show_target, run.ducats], "show counters")
		eq(loaded.zanni.map(func(z: ItemCard) -> String: return z.def_id), run.zanni.map(func(z: ItemCard) -> String: return z.def_id), "Jesters")
		eq(loaded.action_log.size(), run.action_log.size(), "action log")
	var saves := SaveCheck.new()
	saves.checkpoint(run, "mid-show", 40)
	var bot := Bot.new()
	for i in 40:
		if ended(run):
			break
		var action := bot.next_action(run)
		saves.follow(action, run.apply(action), run)
	saves.finish(run)
	for p in saves.problems:
		fail(p)


func test_illegal_actions_change_nothing() -> void:
	var run := new_run("ILLEGAL")
	var wrong := {
		P.CHOOSE_SHOW: ["play", "discard", "cash_out", "buy", "reroll", "leave_shop", "buy_pack", "pick", "skip_pack", "buy_warrant", "swap_patron"],
		P.IN_SHOW: ["select_show", "skip_show", "cash_out", "buy", "reroll", "leave_shop", "buy_pack", "pick", "skip_pack", "buy_warrant", "swap_patron"],
		P.CASH_OUT: ["select_show", "skip_show", "play", "discard", "buy", "reroll", "leave_shop", "buy_pack", "pick", "skip_pack", "buy_warrant", "sell", "use"],
		P.SHOP: ["select_show", "skip_show", "play", "discard", "cash_out", "pick", "skip_pack"],
	}
	var tried := {}
	var bot := Bot.new()
	var steps := 0
	while tried.size() < wrong.size() and steps < 300 and not ended(run):
		if wrong.has(run.phase) and not tried.has(run.phase):
			tried[run.phase] = true
			for action_name in wrong[run.phase] + ["fly", ""]:
				try_illegal(run, { "a": action_name, "cards": [run.hand[0].id] if not run.hand.is_empty() else [], "slot": 0, "index": 0 })
			if run.phase == P.IN_SHOW:
				var hand_ids := ids(run.hand)
				for cards in [[], [999999], [hand_ids[0], hand_ids[0]], hand_ids.slice(0, 6)]:
					try_illegal(run, { "a": "play", "cards": cards })
					try_illegal(run, { "a": "discard", "cards": cards })
		var action := bot.next_action(run)
		run.apply(action)
		steps += 1
	eq(tried.size(), wrong.size(), "phases tried")


func try_illegal(run: RunState, action: Dictionary) -> void:
	var before := run.to_dict()
	var result := run.apply(action)
	check(not result["ok"], "%s was accepted in %s" % [action, P.keys()[run.phase]])
	check(str(result.get("error", "")) != "", "%s was refused without a reason" % [action])
	eq(run.to_dict(), before, "state after the refused %s" % [action])


func test_modes() -> void:
	eq(new_run("MODE-T").final_town(), 8, "tour towns")
	eq(new_run("MODE-Q", "quick").final_town(), 3, "quick towns")
	eq(new_run("MODE-B", "bosses").final_town(), 8, "boss rush towns")
	eq(new_run("MODE-X", "nonsense").mode, "tour", "an unknown mode becomes a tour")
	var bosses := new_run("MODE-B", "bosses")
	for i in 120:
		if ended(bosses):
			break
		if bosses.phase == P.CHOOSE_SHOW or bosses.phase == P.IN_SHOW:
			check(bosses.show_index == Shows.PATRON, "boss rush town %d plays show %d" % [bosses.town, bosses.show_index])
		bosses.apply(Bot.new().next_action(bosses))
	var skip := new_run("MODE-SKIP")
	check(skip.apply({ "a": "skip_show" })["ok"], "skip the Matinee")
	check(skip.apply({ "a": "skip_show" })["ok"], "skip the Evening show")
	check(not skip.apply({ "a": "skip_show" })["ok"], "the Patron's show can't be skipped")
	eq(skip.show_index, Shows.PATRON, "show after two skips")


func test_beating_the_final_patron_wins() -> void:
	for spec in [["tour", 8], ["quick", 3], ["bosses", 8]]:
		var run := new_run("FINALE-" + spec[0], spec[0])
		run.town = spec[1] - 1
		run.show_index = Shows.PATRON
		run.phase = P.SHOP
		run.shop = ShopState.new()
		run.apply({ "a": "leave_shop" })
		eq([run.town, run.show_index, run.phase], [spec[1], Shows.MATINEE if spec[0] != "bosses" else Shows.PATRON, P.CHOOSE_SHOW], spec[0] + " final town start")
		for i in 6:
			if run.show_index == Shows.PATRON and run.phase == P.CHOOSE_SHOW:
				break
			# A skipped show's Favor can open a pack first.
			run.apply({ "a": "skip_pack" } if run.phase == P.PACK else { "a": "skip_show" })
		check(run.apply({ "a": "select_show" })["ok"], spec[0] + ": start the final Patron's show")
		run.show_score = run.show_target - 1.0
		var bot := Bot.new()
		for i in 6:
			if run.phase != P.IN_SHOW:
				break
			run.apply(bot.next_action(run))
		eq(run.phase, P.CASH_OUT, spec[0] + ": phase after beating the final Patron")
		check(run.won, spec[0] + ": the run is won")


func test_final_town_has_a_finale_patron() -> void:
	for mode in ["tour", "bosses"]:
		var run := new_run("FINALE-PATRON-" + mode, mode)
		run.town = 8
		run._start_town()
		var patron := ContentDB.get_def(run.town_patron)
		check(patron != null and bool(patron.data.get("finale", false)), "%s town 8 Patron is a finale Patron, got '%s'" % [mode, run.town_patron])


## Known bug: a quick run's last show has no Patron at all.
func test_quick_run_final_show_has_a_patron() -> void:
	var run := new_run("QUICK-FINALE", "quick")
	# Win towns 1 and 2 the way _advance_show() moves on: town 3 starts with _start_town().
	run.town = 3
	run._start_town()
	eq(run.town, run.final_town(), "town 3 is the quick run's last")
	known_bug("quick-final-patron", "RunState._patron_pool() (run_state.gd:1062-1065) asks for a finale Patron when town % final_town() == 0, but every finale Patron has min_town 8 (patron_cards.gd:112-147), so town 3 of a quick run gets town_patron = \"\" and its Patron show has no Patron")
	check(run.town_patron != "", "quick run town 3 has no Patron (pool: %s)" % [run._patron_pool().map(func(d: ContentDef) -> String: return d.id)])


## Known bug: shop offers lose their eternal/perishable/rented stickers on save and load.
func test_save_and_load_keeps_shop_stickers() -> void:
	# Stake 8 has Eternal (30%), Perishable and Rented (30%) Jesters in the shop. Take the first
	# seed whose first shop shows one (the bot buys nothing on the way).
	var run: RunState = null
	var found := -1
	for n in range(1, 31):
		run = new_run("STICKERS-%d" % n, "tour", 8)
		var bot := Bot.new()
		bot.reserve = 1000000
		play_until(run, func(r: RunState) -> bool: return r.phase == P.SHOP, 200, bot)
		if run.phase != P.SHOP:
			continue
		for slot in run.shop.offers.size():
			if run.shop.offers[slot].has("sticker") or run.shop.offers[slot].has("rented"):
				found = slot
		if found >= 0:
			break
	if not check(found >= 0, "a stake 8 shop with a sticker on an offer"):
		return
	var offer: Dictionary = run.shop.offers[found]
	note("seed %s, stake 8, d_bergamo, actions %s: shop offer %d is %s" % [run.seed_text, run.action_log, found, offer])
	known_bug("shop-stickers", "ShopState.from_dict() (shop_state.gd:26-35) rebuilds each offer without its \"sticker\" and \"rented\" keys, so after Continue a Jester bought from a stake 4+ shop is no longer Eternal/Perishable/Rented (and a Rented one costs 1 ducat with no rent)")
	var loaded := RunState.from_dict(run.to_dict())
	eq(loaded.shop.offers[found], offer, "offer after save and load")
	# What the player gets when buying it after Continue.
	run.ducats = 100
	loaded.ducats = 100
	run.apply({ "a": "buy", "slot": found })
	loaded.apply({ "a": "buy", "slot": found })
	if not run.zanni.is_empty() and not loaded.zanni.is_empty():
		eq(loaded.zanni.back().state, run.zanni.back().state, "state of the Jester bought after loading")


## Known bug: discarding the last cards leaves the show with no cards and no way out.
func test_running_out_of_cards_by_discarding_ends_the_show() -> void:
	# Verona's 40-card deck with 6 discards a show (Cestino and Riciclo Warrants plus Il
	# Macchinista, all things a player can buy): two plays and six discards use every card.
	var run := new_run("OUT-OF-CARDS", "tour", 1, "d_verona")
	run.warrants.append("w_cestino")
	run.warrants.append("w_riciclo")
	check(run.add_zanni("z_macchinista"), "took Il Macchinista")
	eq(run.full_deck.size(), 40, "Verona deck size")
	eq(run.stat("discards"), 6, "discards per show")
	run.apply({ "a": "select_show" })
	for i in 2:
		run.apply({ "a": "play", "cards": weakest_five(run) })
	if not check(run.phase == P.IN_SHOW and run.show_score < run.show_target, "two weak hands didn't win the show"):
		return
	while run.discards_left > 0 and not run.hand.is_empty():
		var ids_now := ids(run.hand)
		run.apply({ "a": "discard", "cards": ids_now.slice(0, 5) })
	known_bug("out-of-cards", "_discard() (run_state.gd:758-781) never ends the show when the hand and draw pile are both empty, unlike _play() (run_state.gd:699-700): the run stays IN_SHOW with hands left while every play and discard is refused")
	note("after %s: phase %s, hand %d, draw pile %d, hands left %d, discards left %d, score %d of %d" % [
		run.action_log, P.keys()[run.phase], run.hand.size(), run.draw_pile.size(), run.hands_left,
		run.discards_left, run.show_score, run.show_target])
	var stuck := run.phase == P.IN_SHOW and run.hand.is_empty() and run.draw_pile.is_empty()
	check(not stuck, "the show goes on with no cards in hand or draw pile and %d hands left: play and discard are both refused ('%s')" % [
		run.hands_left, run.apply({ "a": "play", "cards": [] }).get("error", "")])


## The five cards from the hand whose play scores least.
func weakest_five(run: RunState) -> Array:
	var hand := ids(run.hand)
	var best: Array = hand.slice(0, 5)
	var low := INF
	for mask in range(1, 1 << hand.size()):
		if Bot._bits(mask) != 5:
			continue
		var five := []
		for i in hand.size():
			if mask & (1 << i):
				five.append(hand[i])
		var score := run.preview(five)
		if score >= 0.0 and score < low:
			low = score
			best = five
	return best


func phase_key(run: RunState) -> String:
	var key: String = P.keys()[run.phase]
	if run.phase == P.IN_SHOW:
		key += " (first hand)" if int(run.show_counters.get("hands_played", 0)) == 0 else " (later)"
	return key
