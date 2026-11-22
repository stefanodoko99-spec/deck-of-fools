extends "res://tests/suite.gd"
## Tips (ui/tips.gd): the one line after a lost show says something specific about the
## run (a Sign still held, discards left, the favourite hand and the Jesters that really
## boost it, a run without Jesters) or nothing at all, and the Jester of the day is the
## same for everyone on a given day and gives every Jester its day in turn. Profiles here
## are fresh test profiles; the player's is never touched.

const Bot := preload("res://tests/bot.gd")


## A run that has just lost its first show by running out of hands, with nothing else
## worth a word yet. Rare Jesters are locked, as for a new player.
func lost_run(seed_text := "TIPS") -> RunState:
	var run := RunState.create(seed_text, "d_bergamo", 1, "", Profile.new().locked_cards())
	run.apply({ "a": "select_show" })
	run.phase = RunState.Phase.LOST
	run.show_counters["lost"] = true
	run.hands_left = 0
	run.discards_left = 0
	return run


func test_nothing_to_say() -> void:
	eq(Tips.insight_after_loss(null), "", "no run")
	eq(Tips.insight_after_loss(RunState.create("TIPS", "d_bergamo", 1), Profile.new()), "", "a run still playing")
	eq(Tips.insight_after_loss(lost_run(), Profile.new()), "", "a lost run with nothing specific to say")


func test_discards_left() -> void:
	var run := lost_run()
	run.discards_left = 2
	eq(Tips.insight_after_loss(run, Profile.new()), "You lost with 2 discards left. Use them to swap weak cards and chase a bigger hand.", "two discards left")
	run.discards_left = 1
	check(Tips.insight_after_loss(run, Profile.new()).begins_with("You lost with 1 discard left."), "one discard, singular")
	run.show_counters.erase("lost")
	eq(Tips.insight_after_loss(run, Profile.new()), "", "a run given up says nothing about its discards")


func test_favourite_hand_and_the_jesters_that_boost_it() -> void:
	var run := lost_run()
	run.hand_levels.played["two_pair"] = 9
	run.hand_levels.played["pair"] = 4
	eq(Tips.favourite_hand(run), "two_pair", "the hand played most")
	eq(Tips.insight_after_loss(run, Profile.new()), "You played Two Pair 9 times. Flavio boosts Two Pair.", "the one Jester that names Two Pair")
	# A Pair: Jesters the player has already met come first.
	run.hand_levels.played["pair"] = 12
	var met := Profile.new()
	met.discovered["z_rugantino"] = true
	eq(Tips.insight_after_loss(run, met), "You played a Pair 12 times. %s and others boost Pairs." % UiTheme.name_of("z_rugantino"), "a Jester met before first")
	var fresh := Tips.insight_after_loss(run, Profile.new())
	eq(fresh, "You played a Pair 12 times. %s and others boost Pairs." % UiTheme.name_of("z_isabella"), "else the commonest")
	# La Ruffiana names a Pair but only changes suits after scoring: never suggested.
	var ruffiana := Profile.new()
	ruffiana.discovered["z_ruffiana"] = true
	check(not Tips.insight_after_loss(run, ruffiana).contains(UiTheme.name_of("z_ruffiana")), "La Ruffiana doesn't boost Pairs")
	note(fresh)
	# Holding a Jester that boosts it already, the hand's Sign is the next step.
	run.hand_levels.played["pair"] = 0
	run.zanni.append(ItemCard.make("z_flavio", 4))
	eq(Tips.insight_after_loss(run, Profile.new()), "You played Two Pair 9 times. The Pisces Sign levels it up: look for it in the Market.", "with Flavio held")
	var high := lost_run("TIPS-HIGH")
	high.hand_levels.played["high_card"] = 6
	eq(Tips.insight_after_loss(high, Profile.new()), "You played High Card 6 times. Even a Pair scores about four times as much: discard to find one.", "High Card")
	high.hand_levels.played["high_card"] = 2
	eq(Tips.favourite_hand(high), "", "twice isn't a habit")


func test_boosters_read_the_card_text() -> void:
	var nobody := Profile.new()
	var pair := Tips.boosters("pair", nobody)
	for id: String in ["z_isabella", "z_rugantino", "z_pappagallo"]:
		check(pair.has(id), "%s boosts a Pair" % id)
	check(not pair.has("z_flavio"), "Flavio names Two Pair, not a Pair")
	check(not pair.has("z_ruffiana"), "La Ruffiana only changes suits after scoring")
	eq(Tips.boosters("two_pair", nobody), ["z_flavio"] as Array[String], "only Flavio names Two Pair")
	var flush := Tips.boosters("flush", nobody)
	check(flush.has("z_stenterello") and flush.has("z_gran_ballo"), "Stenterello and Gran Ballo boost a Flush")
	check(not flush.has("z_pittore") and not Tips.boosters("straight", nobody).has("z_pittore"), "Il Pittore makes Flushes and Straights easier to make, not bigger")
	check(Tips.boosters("straight", nobody).has("z_coviello"), "Coviello names a Straight")
	check(Tips.boosters("full_house", nobody).has("z_rosaura"), "Rosaura names a Full House")
	for hand_type: String in HandTable.ORDER:
		for id: String in Tips.boosters(hand_type, nobody):
			check(Tips.SCORING_HOOKS.any(ContentDB.get_def(id).has_hook), "%s adds to a %s's score" % [id, hand_type])
	var run := lost_run()
	check(not Tips.boosters("flush", nobody, run).has("z_gran_ballo"), "a Rare locked in this run is left out")
	var order := Tips.boosters("pair", nobody)
	for i in range(1, order.size()):
		check(ContentDB.get_def(order[i - 1]).rarity <= ContentDB.get_def(order[i]).rarity, "commoner Jesters first: %s" % [order])
	note("Pair: %s; Flush: %s" % [order, flush])


func test_a_sign_still_held() -> void:
	var run := lost_run()
	run.hand_levels.played["pair"] = 5
	run.consumables.append(ItemCard.make("s_aquarius", 3))
	check(Tips.insight_after_loss(run, Profile.new()).begins_with("You played a Pair 5 times."), "a Sign for a hand never played isn't worth a word")
	run.consumables.append(ItemCard.make("s_gemini", 3))
	run.discards_left = 2
	eq(Tips.insight_after_loss(run, Profile.new()), "You still held the Gemini Sign: it levels up Pair for the rest of the run, so use it early.", "the Sign for the favourite hand comes first")


func test_a_run_without_jesters() -> void:
	var run := lost_run()
	run.counters["shows_won"] = 3
	eq(Tips.insight_after_loss(run, Profile.new()), "You had no Jesters. Buy one in the Market after a show: it keeps working for the rest of the run.", "shows won, no Jesters")
	run.zanni.append(ItemCard.make("z_zanni", 2))
	eq(Tips.insight_after_loss(run, Profile.new()), "", "with a Jester there's nothing to add")


func test_real_lost_shows() -> void:
	# Single cards played into a show that can't be won: High Card four times, every
	# discard left over, and the discards are what the line is about.
	var run := RunState.create("TIPS-REAL", "d_bergamo", 1)
	run.apply({ "a": "select_show" })
	run.show_target = 1e9
	for i in 10:
		if run.phase != RunState.Phase.IN_SHOW:
			break
		run.apply({ "a": "play", "cards": [run.hand[0].id] })
	eq([run.phase, run.hand_levels.times_played("high_card")], [RunState.Phase.LOST, run.stat("hands")], "lost after a High Card on every hand")
	eq(Tips.insight_after_loss(run, Profile.new()), "You lost with %d discards left. Use them to swap weak cards and chase a bigger hand." % run.stat("discards"), "the discards first")
	run.discards_left = 0
	eq(Tips.insight_after_loss(run, Profile.new()), "You played High Card %d times. Even a Pair scores about four times as much: discard to find one." % run.stat("hands"), "then the habit")
	# The bot discards and plays its best; whatever the line says, it is short.
	var played := RunState.create("TIPS-BOT", "d_bergamo", 1)
	played.apply({ "a": "select_show" })
	played.show_target = 1e9
	var bot := Bot.new()
	for i in 40:
		if played.phase != RunState.Phase.IN_SHOW:
			break
		played.apply(bot.next_action(played))
	eq(played.phase, RunState.Phase.LOST, "the bot's show is lost")
	var line := Tips.insight_after_loss(played, Profile.new())
	check(line.length() < 110 and not line.contains("%") and not line.contains("\n"), "a short line: '%s'" % line)
	note(line if line != "" else "(the bot's loss: nothing specific to say)")


func test_the_insight_as_a_quiet_line() -> void:
	var run := lost_run()
	eq(Tips.insight_line(run, 380.0, Profile.new()), null, "nothing to say, no line")
	run.discards_left = 2
	var line := Tips.insight_line(run, 380.0, Profile.new())
	if check(line != null, "a line for the discards left"):
		eq(line.text, Tips.insight_after_loss(run, Profile.new()), "the insight's words")
		eq([line.autowrap_mode, line.custom_minimum_size.x], [TextServer.AUTOWRAP_WORD_SMART, 380.0], "wrapped to the width it's given")
		eq(line.get_theme_color("font_color"), UiTheme.MUTED, "a quiet line")
		line.free()


func test_jester_of_the_day() -> void:
	var start := GoalDefs.day_number("2026-11-22")
	var jesters := CollectionSheet.numbered()
	var every := Tips.illustrated_every()
	check(every >= Tips.ILLUSTRATED_EVERY, "an illustrated Jester every %d days" % every)
	var last_seen := {}
	var longest := 0
	var yesterday := ""
	var repeats := 0
	for i in 1200:
		var date := Time.get_date_string_from_unix_time((start + i) * 86400)
		var id := Tips.jester_of_the_day(date)
		if i < 200:
			eq(id, Tips.jester_of_the_day(date), "%s: the same Jester every time" % date)
		check(jesters.has(id), "%s: %s is a Jester" % [date, id])
		if every > 0 and posmod(start + i, every) == 0:
			check(CardView.art_for("zanni", id) != null, "%s spotlights an illustrated Jester, not %s" % [date, id])
		if id == yesterday:
			repeats += 1
		yesterday = id
		if last_seen.has(id):
			longest = maxi(longest, i - int(last_seen[id]))
		last_seen[id] = i
	eq(repeats, 0, "no Jester two days running")
	eq(last_seen.size(), jesters.size(), "1,200 days spotlight every Jester")
	# The walk gives every Jester its day once a round: a round is as many walk days as there
	# are Jesters, so no Jester waits more than two rounds (and the illustrated days between).
	var round_days := ceili(jesters.size() * (every / float(maxi(1, every - 1)) if every > 0 else 1.0))
	check(longest <= 2 * round_days + 2, "the longest wait is %d days, over two rounds of %d" % [longest, round_days])
	note("illustrated every %d days; longest wait %d days" % [every, longest])
	eq(Tips.jester_of_the_day(), Tips.jester_of_the_day(Economy.today()), "today by default")
	note("today %s: %s" % [Economy.today(), Tips.jester_of_the_day()])


func test_one_round_of_the_walk_shows_every_jester() -> void:
	# The walk days of one whole round, from the first walk day of a round on: each Jester
	# exactly once.
	var jesters := CollectionSheet.numbered()
	var every := Tips.illustrated_every()
	var start := GoalDefs.day_number("2026-11-22")
	var seen := {}
	var walked := 0
	var day := start
	while walked < jesters.size() and day < start + 4 * jesters.size():
		var is_walk := every == 0 or posmod(day, every) != 0
		var walk := day if every == 0 else day - floori(day / float(every)) - 1
		if is_walk and (walked > 0 or posmod(walk, jesters.size()) == 0):
			var id := Tips.jester_of_the_day(Time.get_date_string_from_unix_time(day * 86400))
			seen[id] = int(seen.get(id, 0)) + 1
			walked += 1
		day += 1
	eq(walked, jesters.size(), "a whole round walked")
	eq(seen.size(), jesters.size(), "every Jester has its day in the round")
	check(seen.values().all(func(n: int) -> bool: return n == 1), "each once")
