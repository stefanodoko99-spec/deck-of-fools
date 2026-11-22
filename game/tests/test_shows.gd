extends "res://tests/suite.gd"
## Shows and their targets: every town asks for more than the one before, the Evening show
## more than the Matinee, higher stakes raise the table, and a run's targets follow it.

const Bot := preload("res://tests/bot.gd")


func test_base_targets_grow_by_town() -> void:
	for scaling in [1, 2, 3]:
		var last := 0.0
		for town in range(1, 13):
			var target := Shows.base_target(town, scaling)
			check(target > last, "scaling %d: town %d asks %d, not more than town %d (%d)" % [scaling, town, target, town - 1, last])
			last = target


func test_known_targets() -> void:
	eq(Shows.base_target(1, 1), 300.0, "town 1")
	eq(Shows.base_target(2, 1), 800.0, "town 2")
	eq(Shows.base_target(8, 1), 50000.0, "town 8")
	eq(Shows.base_target(8, 2), 100000.0, "town 8, stake 3+")
	eq(Shows.base_target(8, 3), 200000.0, "town 8, stake 6+")
	# Past the last town (after "Keep touring") the target doubles each town and then some.
	eq(Shows.base_target(10, 1), 320000.0, "town 10")
	eq(Shows.base_target(12, 1), 2720000.0, "town 12")
	eq(Shows.base_target(0, 1), 300.0, "a town below 1 counts as town 1")
	eq(Shows.base_target(1, 9), Shows.base_target(1, 3), "scaling is capped at 3")


## Known bug: two endless-town targets come out one short of the round number.
func test_endless_targets_are_round_numbers() -> void:
	# town 8 target x 2^extra x (1 + 0.15 extra^2), worked out exactly in whole numbers.
	var misses: Array[String] = []
	for scaling in [1, 2, 3]:
		var last: int = Shows.TARGETS[scaling - 1][Shows.FINAL_TOWN - 1]
		for town in range(9, 17):
			var extra := town - Shows.FINAL_TOWN
			var exact := last * (1 << extra) * (100 + 15 * extra * extra) / 100
			if Shows.base_target(town, scaling) != float(exact):
				misses.append("scaling %d town %d: %d instead of %d" % [scaling, town, Shows.base_target(town, scaling), exact])
	known_bug("endless-target-rounding", "Shows.base_target() (shows.gd:27) floors a float product and 1.0 + 0.15 * extra * extra is a hair under 1.15 (town 9) and 2.35 (town 11), so those towns ask one point less than the round target")
	check(misses.is_empty(), ", ".join(misses))


func test_higher_scaling_never_lowers_a_target() -> void:
	for town in range(1, 13):
		check(Shows.base_target(town, 2) >= Shows.base_target(town, 1), "town %d: scaling 2 below scaling 1" % town)
		check(Shows.base_target(town, 3) >= Shows.base_target(town, 2), "town %d: scaling 3 below scaling 2" % town)


func test_show_sizes() -> void:
	eq(Shows.SIZE, [1.0, 1.5, 2.0], "Matinee, Evening, Patron")
	check(Shows.MATINEE < Shows.EVENING and Shows.EVENING < Shows.PATRON, "show order")


func test_run_targets_follow_town_show_and_stake() -> void:
	for row in [[1, 1], [2, 1], [3, 2], [5, 2], [6, 3], [8, 3]]:
		var stake: int = row[0]
		var run := RunState.create("TARGETS", "d_bergamo", stake)
		eq(run.stat("target_scaling"), row[1], "stake %d target scaling" % stake)
		var last := 0.0
		for town in range(1, 9):
			run.town = town
			run.town_patron = ""
			var base := Shows.base_target(town, row[1])
			eq(run.target_for_show(Shows.MATINEE), base, "stake %d town %d Matinee" % [stake, town])
			eq(run.target_for_show(Shows.EVENING), floorf(base * 1.5), "stake %d town %d Evening" % [stake, town])
			eq(run.target_for_show(Shows.PATRON), floorf(base * 2.0), "stake %d town %d plain Patron show" % [stake, town])
			check(run.target_for_show(Shows.MATINEE) > last, "stake %d: town %d Matinee doesn't grow" % [stake, town])
			last = run.target_for_show(Shows.MATINEE)


func test_patrons_and_decks_change_targets() -> void:
	var run := RunState.create("PATRON-TARGETS", "d_bergamo", 1)
	run.town = 2
	run.town_patron = "pt_fortezza"
	eq(run.target_for_show(Shows.PATRON), 3200.0, "La Fortezza asks 4x")
	run.town_patron = "pt_contessa"
	eq(run.target_for_show(Shows.PATRON), 800.0, "La Contessa asks 1x")
	run.town = 8
	run.town_patron = "pt_granduca"
	eq(run.target_for_show(Shows.PATRON), 300000.0, "Il Granduca asks 6x")
	eq(RunState.create("MANTOVA", "d_mantova", 1).target_for_show(Shows.MATINEE), 600.0, "Mantova doubles every target")


func test_targets_met_in_play() -> void:
	# The bot plays two tours; each show's target is what target_for_show() says, and the
	# Matinee target grows from town to town.
	for seed in ["TARGETS-PLAY-1", "TARGETS-PLAY-2"]:
		var run := RunState.create(seed, "d_bergamo", 1)
		var bot := Bot.new()
		var matinees := []
		for i in 3000:
			if run.won or run.phase == RunState.Phase.LOST:
				break
			var action := bot.next_action(run)
			run.apply(action)
			if action["a"] == "select_show":
				eq(run.show_target, run.target_for_show(run.show_index), "%s town %d show %d target" % [seed, run.town, run.show_index])
				if run.show_index == Shows.MATINEE:
					matinees.append(run.show_target)
		for i in range(1, matinees.size()):
			check(matinees[i] > matinees[i - 1], "%s: Matinee targets %s don't grow" % [seed, matinees])
		note("%s Matinee targets: %s" % [seed, matinees])
