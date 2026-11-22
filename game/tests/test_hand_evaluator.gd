extends "res://tests/suite.gd"
## HandEvaluator: which poker hand a set of played cards makes, which cards score, and what
## each hand "contains" (Jesters like "if the hand contains a Pair" read that).
## Cards are written like "AS 2H TC": rank (2-9, T, J, Q, K, A) then suit (S, H, C, D).

var _next_id := 1


func cards(text: String) -> Array[PlayingCard]:
	var out: Array[PlayingCard] = []
	for token in text.split(" ", false):
		var rank_text := token.substr(0, token.length() - 1)
		var rank := int({ "T": 10, "J": 11, "Q": 12, "K": 13, "A": 14 }.get(rank_text, int(rank_text)))
		out.append(PlayingCard.make(_next_id, rank, "SHCD".find(token.right(1))))
		_next_id += 1
	return out


func labels(list: Array[PlayingCard]) -> Array:
	var out := list.map(func(c: PlayingCard) -> String: return c.label())
	out.sort()
	return out


## Checks the hand type and scoring cards, in the given order and in two other orders.
func expect(text: String, hand_type: String, scoring: String, options := {}) -> HandEvaluator.Result:
	var hand := cards(text)
	var result := HandEvaluator.evaluate(hand, options)
	eq(result.type, hand_type, text)
	var want := scoring.split(" ", false)
	want.sort()
	eq(labels(result.scoring), Array(want), text + " scoring cards")
	var reversed := hand.duplicate()
	reversed.reverse()
	eq(HandEvaluator.evaluate(reversed, options).type, hand_type, text + " reversed")
	if hand.size() > 2:
		var rotated: Array[PlayingCard] = []
		rotated.append_array(hand.slice(2))
		rotated.append_array(hand.slice(0, 2))
		eq(HandEvaluator.evaluate(rotated, options).type, hand_type, text + " rotated")
	return result


func test_high_card() -> void:
	expect("2S 5H 9C JD KS", HandTable.HIGH_CARD, "KS")
	expect("7D", HandTable.HIGH_CARD, "7D")
	expect("AS KH 4D", HandTable.HIGH_CARD, "AS")


func test_pair() -> void:
	expect("5S 5H 9C JD KS", HandTable.PAIR, "5S 5H")
	expect("QS QD", HandTable.PAIR, "QS QD")


func test_two_pair() -> void:
	var r := expect("5S 5H 9C 9D KS", HandTable.TWO_PAIR, "5S 5H 9C 9D")
	check(r.contains[HandTable.PAIR], "two pair contains a pair")
	check(not r.contains[HandTable.THREE_KIND], "two pair has no three of a kind")


func test_three_of_a_kind() -> void:
	var r := expect("7S 7H 7C 2D KS", HandTable.THREE_KIND, "7S 7H 7C")
	check(r.contains[HandTable.PAIR], "three of a kind contains a pair")
	check(not r.contains[HandTable.TWO_PAIR], "three of a kind alone is not two pair")


func test_straight() -> void:
	expect("5S 6H 7C 8D 9S", HandTable.STRAIGHT, "5S 6H 7C 8D 9S")
	expect("TS JH QC KD AS", HandTable.STRAIGHT, "TS JH QC KD AS")


func test_straight_ace_low() -> void:
	# The ace also counts as 1, so A-2-3-4-5 is a straight.
	expect("AS 2H 3C 4D 5S", HandTable.STRAIGHT, "AS 2H 3C 4D 5S")
	expect("5D 4C AH 3S 2D", HandTable.STRAIGHT, "5D 4C AH 3S 2D")


func test_straight_does_not_wrap_around() -> void:
	expect("QS KH AC 2D 3S", HandTable.HIGH_CARD, "AC")
	expect("2S 3H 4C 5D 7S", HandTable.HIGH_CARD, "7S")


func test_flush() -> void:
	var r := expect("2H 5H 9H JH KH", HandTable.FLUSH, "2H 5H 9H JH KH")
	check(not r.contains[HandTable.STRAIGHT], "a flush is not a straight")


func test_full_house() -> void:
	var r := expect("8S 8H 8C 3D 3S", HandTable.FULL_HOUSE, "8S 8H 8C 3D 3S")
	for t in [HandTable.PAIR, HandTable.TWO_PAIR, HandTable.THREE_KIND]:
		check(r.contains[t], "a full house contains " + t)
	check(not r.contains[HandTable.FOUR_KIND], "a full house is not four of a kind")


func test_four_of_a_kind() -> void:
	var r := expect("9S 9H 9C 9D 2S", HandTable.FOUR_KIND, "9S 9H 9C 9D")
	check(r.contains[HandTable.THREE_KIND] and r.contains[HandTable.PAIR], "four of a kind contains three of a kind and a pair")


func test_straight_flush() -> void:
	var r := expect("5H 6H 7H 8H 9H", HandTable.STRAIGHT_FLUSH, "5H 6H 7H 8H 9H")
	check(r.contains[HandTable.STRAIGHT] and r.contains[HandTable.FLUSH], "a straight flush contains a straight and a flush")
	expect("AH 2H 3H 4H 5H", HandTable.STRAIGHT_FLUSH, "AH 2H 3H 4H 5H")
	expect("TS JS QS KS AS", HandTable.STRAIGHT_FLUSH, "TS JS QS KS AS")


func test_secret_hands_with_duplicate_cards() -> void:
	# Five of a kind and the flush hands above it need copied cards (Tarocchi, special decks).
	expect("9S 9H 9C 9D 9S", HandTable.FIVE_KIND, "9S 9H 9C 9D 9S")
	expect("8H 8H 8H 3H 3H", HandTable.FLUSH_HOUSE, "8H 8H 8H 3H 3H")
	expect("QD QD QD QD QD", HandTable.FLUSH_FIVE, "QD QD QD QD QD")


func test_short_hands_need_options() -> void:
	expect("2H 5H 9H JH", HandTable.HIGH_CARD, "JH")
	expect("2H 5H 9H JH", HandTable.FLUSH, "2H 5H 9H JH", { "flush_min": 4 })
	expect("5S 6H 7C 8D", HandTable.HIGH_CARD, "8D")
	expect("5S 6H 7C 8D", HandTable.STRAIGHT, "5S 6H 7C 8D", { "straight_min": 4 })


func test_straight_with_gaps_option() -> void:
	expect("2S 4H 6C 8D TS", HandTable.HIGH_CARD, "TS")
	expect("2S 4H 6C 8D TS", HandTable.STRAIGHT, "2S 4H 6C 8D TS", { "straight_gap": true })


func test_all_score_option() -> void:
	expect("5S 5H 9C JD KS", HandTable.PAIR, "5S 5H 9C JD KS", { "all_score": true })


func test_marble_card_always_scores_and_has_no_rank() -> void:
	var hand := cards("5S 5H 5C")
	hand[2].enhancement = "enh_marble"
	if not check(ContentDB.get_def("enh_marble") != null, "enh_marble is registered"):
		return
	var r := HandEvaluator.evaluate(hand)
	eq(r.type, HandTable.PAIR, "a marble card doesn't count for its rank")
	eq(r.scoring.size(), 3, "a marble card scores anyway")


func test_empty_play() -> void:
	var none: Array[PlayingCard] = []
	var r := HandEvaluator.evaluate(none)
	eq(r.type, HandTable.HIGH_CARD, "type of no cards")
	check(not r.contains[HandTable.HIGH_CARD], "no cards contain nothing")
	eq(r.scoring.size(), 0, "no cards score")


func test_better_hands_are_worth_more() -> void:
	# At level 1 each hand in HandTable.ORDER is worth more Points x Mult than the one before.
	var levels := HandLevels.new()
	var last := 0.0
	for t in HandTable.ORDER:
		var value := levels.points(t) * levels.mult(t)
		check(value > last, "%s (%d) is worth more than the hand before it (%d)" % [t, value, last])
		last = value


func test_scorer_points_times_mult() -> void:
	# The plain scoring pipeline: hand Points + each scoring card's Points, times the hand Mult.
	var run := RunState.create("SCORER", "d_bergamo", 1)
	run.apply({ "a": "select_show" })
	var none: Array[PlayingCard] = []
	var pair := Scorer.score(run, cards("5S 5H 9C"), none)
	eq([pair.hand_type, pair.points, pair.mult, pair.total], [HandTable.PAIR, 20.0, 2.0, 40.0], "pair of fives")
	var royal := Scorer.score(run, cards("AS KS QS JS TS"), none)
	eq([royal.hand_type, royal.points, royal.mult, royal.total], [HandTable.STRAIGHT_FLUSH, 151.0, 8.0, 1208.0], "royal flush")
	run.hand_levels.level_up(HandTable.PAIR)
	var levelled := Scorer.score(run, cards("5S 5H"), none)
	eq([levelled.points, levelled.mult, levelled.total], [35.0, 3.0, 105.0], "pair of fives at level 2")
