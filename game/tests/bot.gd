extends RefCounted
## A plain, deterministic player for the headless tests and for balance numbers.
## It acts only through RunState.apply() and decides from what a player can see (it also
## knows the face-down cards in its hand, which a player only learns from the score preview).
##
##   choosing a show  plays it, never skips
##   in a show        rates every choice of 1..max_play cards with HandEvaluator, scores the
##                    best few exactly with RunState.preview() and plays the highest; when that
##                    hand can't keep pace with the target and a discard is left, it first
##                    discards the cards that don't help (keeping pairs, flush and straight draws)
##   cash out         cashes out
##   shop             buys the dearest Jester it can pay for while a slot is free, then leaves
##   pack             skips it (the bot never buys packs, but a Favor can open one)
##
## Usage: var bot := Bot.new(); while running: run.apply(bot.next_action(run))
##
## With `wander` set (a seeded RandomNumberGenerator) it also tries the rest of the game at
## random, for the tests rather than for balance: skipping shows, buying packs and picking
## from them, rerolling, buying Warrants and other offers, selling, using cards on random
## targets, swapping Patrons and reordering Jesters. Some of those are refused (a target the
## card can't take, no ducats left); the tests check a refusal changes nothing.

## How many of the best-rated plays are scored exactly with RunState.preview().
var preview_count := 6
## Ducats the bot keeps when buying. A huge value means it never buys anything.
var reserve := 0
## Random side moves (see above); null for the plain bot.
var wander: RandomNumberGenerator = null
## Decisions made, and preview() calls spent on them (for the stats).
var decisions := 0
var previews := 0
var _moves_here := 0
var _last_phase := -1


## The next action for this run, or {} when there is nothing to do (run over or stuck).
func next_action(run: RunState) -> Dictionary:
	decisions += 1
	if wander != null:
		var side := _wander(run)
		if not side.is_empty():
			return side
	match run.phase:
		RunState.Phase.CHOOSE_SHOW:
			return { "a": "select_show" }
		RunState.Phase.IN_SHOW:
			return show_action(run)
		RunState.Phase.CASH_OUT:
			return { "a": "cash_out" }
		RunState.Phase.SHOP:
			return shop_action(run)
		RunState.Phase.PACK:
			return { "a": "skip_pack" }
	return {}


func shop_action(run: RunState) -> Dictionary:
	var best := -1
	var best_price := -1
	for i in run.shop.offers.size():
		var offer: Dictionary = run.shop.offers[i]
		if offer["kind"] != "zanni" or offer["sold"]:
			continue
		var price := run.offer_price(offer)
		if run.ducats - price < reserve:
			continue
		var item := ItemCard.make(str(offer["id"]), price, str(offer["edition"]))
		if run.zanni.size() >= run.stat("zanni_slots") and not run._takes_no_slot(item):
			continue
		if price > best_price:
			best = i
			best_price = price
	if best >= 0:
		return { "a": "buy", "slot": best }
	return { "a": "leave_shop" }


func show_action(run: RunState) -> Dictionary:
	var hand: Array[PlayingCard] = run.hand
	var n := hand.size()
	if n == 0:
		return {}
	var plays := rate_plays(run)
	if plays.is_empty():
		return {}
	# Score the best-rated plays exactly; look further down the list when none of them is
	# allowed (a Patron or challenge can refuse a hand, which then scores 0).
	var best: Dictionary = {}
	var best_score := -1.0
	var looked := 0
	for entry: Dictionary in plays:
		if looked >= preview_count and best_score > 0.0:
			break
		if looked >= preview_count + 40:
			break
		looked += 1
		var score := _preview(run, entry["mask"])
		if score > best_score:
			best_score = score
			best = entry
	var mask: int = best["mask"]
	var limit := mini(run.stat("max_play"), n)
	# Fill up to max_play with the weakest spare cards: they cycle out like a free discard.
	var padded := _pad(run, mask, limit)
	if padded != mask:
		var score := _preview(run, padded)
		if score >= best_score:
			mask = padded
			best_score = score
	var need := run.show_target - run.show_score
	if best_score < need and best_score * run.hands_left < need and _can_discard(run):
		var ids := discard_choice(run, plays[0]["result"], limit)
		if not ids.is_empty():
			return { "a": "discard", "cards": ids }
	return { "a": "play", "cards": _ids(hand, mask) }


## Every choice of 1..max_play cards from the hand (always with the card a Patron forces),
## one per set of scoring cards, best estimate first. Whether a Patron or challenge allows
## the hand is left to preview(). Each entry: { "mask": bits of hand indexes,
## "estimate": Points x Mult before Jesters, "result": the HandEvaluator.Result }.
func rate_plays(run: RunState) -> Array:
	var hand: Array[PlayingCard] = run.hand
	var n := hand.size()
	var limit := mini(run.stat("max_play"), n)
	var forced_bit := 0
	var forced_id := int(run.show_counters.get("forced", -1))
	for i in n:
		if hand[i].id == forced_id:
			forced_bit = 1 << i
	var options := run.eval_options()
	var by_scoring := {}
	for mask in range(1, 1 << n):
		var size := _bits(mask)
		if size > limit or (forced_bit != 0 and mask & forced_bit == 0):
			continue
		var cards: Array[PlayingCard] = []
		for i in n:
			if mask & (1 << i):
				cards.append(hand[i])
		var result := HandEvaluator.evaluate(cards, options)
		var key := forced_bit
		for card in result.scoring:
			key |= 1 << hand.find(card)
		var known: Dictionary = by_scoring.get(key, {})
		if not known.is_empty() and _bits(known["mask"]) <= size:
			continue
		by_scoring[key] = { "mask": mask, "estimate": _estimate(run, result), "result": result }
	var out := by_scoring.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["estimate"] != b["estimate"]:
			return a["estimate"] > b["estimate"]
		return a["mask"] < b["mask"])
	return out


## Which cards to throw away: everything that doesn't belong to a made hand worth keeping
## or to a flush or straight draw, weakest first, up to max_play cards.
func discard_choice(run: RunState, made: HandEvaluator.Result, limit: int) -> Array[int]:
	var hand: Array[PlayingCard] = run.hand
	var keep := {}
	var t := made.type
	if t != HandTable.HIGH_CARD and t != HandTable.PAIR:
		for card in made.scoring:
			keep[card.id] = true
	else:
		var suited := _best_suit(hand)
		var straight := _straight_draw(hand)
		if suited.size() >= run.stat("flush_min") - 1:
			_mark(keep, suited)
		elif straight.size() >= run.stat("straight_min") - 1:
			_mark(keep, straight)
		elif t == HandTable.PAIR:
			_mark(keep, made.scoring)
		elif suited.size() >= run.stat("flush_min") - 2 and run.discards_left >= 2:
			_mark(keep, suited)
		else:
			var ranked := hand.duplicate()
			ranked.sort_custom(func(a: PlayingCard, b: PlayingCard) -> bool: return _value(a) > _value(b))
			_mark(keep, ranked.slice(0, 2))
	var spare: Array[PlayingCard] = []
	for card in hand:
		if not keep.has(card.id):
			spare.append(card)
	spare.sort_custom(func(a: PlayingCard, b: PlayingCard) -> bool:
		if _value(a) != _value(b):
			return _value(a) < _value(b)
		return a.id < b.id)
	var out: Array[int] = []
	for card in spare:
		if out.size() >= limit:
			break
		out.append(card.id)
	var forced_id := int(run.show_counters.get("forced", -1))
	if run._hand_card(forced_id) != null and not out.has(forced_id):
		if out.size() >= limit:
			out.pop_back()
		out.append(forced_id)
	return out


## A random side move for the current phase, or {} to play normally. Every phase falls back
## to the normal move after a dozen side moves, so a run always moves on.
func _wander(run: RunState) -> Dictionary:
	if run.phase != _last_phase:
		_last_phase = run.phase
		_moves_here = 0
	_moves_here += 1
	if _moves_here > 12:
		return {}
	var roll := wander.randf()
	match run.phase:
		RunState.Phase.CHOOSE_SHOW:
			if roll < 0.2 and run.show_index < Shows.PATRON:
				return { "a": "skip_show" }
			if roll < 0.25:
				return { "a": "swap_patron" }
			if roll < 0.32:
				return _use_any(run)
			if roll < 0.36:
				return _sell_any(run)
		RunState.Phase.IN_SHOW:
			if roll < 0.08:
				return _use_any(run)
			if roll < 0.11:
				return _sell_any(run)
			if roll < 0.13:
				return _reorder(run)
		RunState.Phase.SHOP:
			if roll < 0.15:
				return { "a": "buy_pack", "slot": wander.randi_range(0, maxi(0, run.shop.packs.size() - 1)) }
			if roll < 0.27:
				return { "a": "buy", "slot": wander.randi_range(0, maxi(0, run.shop.offers.size() - 1)) }
			if roll < 0.35:
				return { "a": "reroll" }
			if roll < 0.42:
				return { "a": "buy_warrant", "index": wander.randi_range(0, 1) }
			if roll < 0.50:
				return _use_any(run)
			if roll < 0.56:
				return _sell_any(run)
			if roll < 0.60:
				return _reorder(run)
			if roll < 0.63:
				return { "a": "swap_patron" }
		RunState.Phase.PACK:
			if roll < 0.8:
				var items: Array = run.pack.get("items", [])
				return { "a": "pick", "index": wander.randi_range(0, maxi(0, items.size() - 1)), "cards": _targets(run) }
	return {}


func _use_any(run: RunState) -> Dictionary:
	if run.consumables.is_empty():
		return {}
	return { "a": "use", "index": wander.randi_range(0, run.consumables.size() - 1), "cards": _targets(run) }


func _sell_any(run: RunState) -> Dictionary:
	var zone := "zanni" if wander.randf() < 0.6 else "consumables"
	var size := run.zanni.size() if zone == "zanni" else run.consumables.size()
	if size == 0:
		return {}
	return { "a": "sell", "zone": zone, "index": wander.randi_range(0, size - 1) }


func _reorder(run: RunState) -> Dictionary:
	var order := range(run.zanni.size())
	for i in range(order.size() - 1, 0, -1):
		var j := wander.randi_range(0, i)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	return { "a": "reorder_zanni", "order": order }


## Nought to three different cards from the hand, at random.
func _targets(run: RunState) -> Array:
	var pool := run.hand.map(func(c: PlayingCard) -> int: return c.id)
	var out := []
	for i in wander.randi_range(0, mini(3, pool.size())):
		out.append(pool.pop_at(wander.randi_range(0, pool.size() - 1)))
	return out


func _preview(run: RunState, mask: int) -> float:
	previews += 1
	return run.preview(_ids(run.hand, mask))


func _can_discard(run: RunState) -> bool:
	# With the draw pile empty a discard only shrinks the hand, so the bot never does it.
	return run.discards_left > 0 and not run.draw_pile.is_empty()


func _pad(run: RunState, mask: int, limit: int) -> int:
	var hand: Array[PlayingCard] = run.hand
	var spare: Array[int] = []
	for i in hand.size():
		if mask & (1 << i) == 0:
			spare.append(i)
	spare.sort_custom(func(a: int, b: int) -> bool:
		if _value(hand[a]) != _value(hand[b]):
			return _value(hand[a]) < _value(hand[b])
		return a < b)
	var out := mask
	for i in spare:
		if _bits(out) >= limit:
			break
		out |= 1 << i
	return out


func _estimate(run: RunState, result: HandEvaluator.Result) -> float:
	var points := run.hand_levels.points(result.type)
	for card in result.scoring:
		if not card.debuffed:
			points += card.base_points() + card.bonus_points
	return points * run.hand_levels.mult(result.type)


## How much a card is worth keeping: its Points, more when it is enhanced, least when debuffed.
static func _value(card: PlayingCard) -> int:
	if card.debuffed:
		return -1
	var v := card.base_points() + card.bonus_points
	if card.enhancement != "" or card.edition != "" or card.seal != "":
		v += 8
	return v


static func _best_suit(hand: Array[PlayingCard]) -> Array[PlayingCard]:
	var best: Array[PlayingCard] = []
	for s in 4:
		var same: Array[PlayingCard] = []
		for card in hand:
			if not card.debuffed and card.has_rank() and card.has_suit(s):
				same.append(card)
		if same.size() > best.size():
			best = same
	return best


## The most cards (one per rank) that fit in a window of five ranks, aces high or low.
static func _straight_draw(hand: Array[PlayingCard]) -> Array[PlayingCard]:
	var best: Array[PlayingCard] = []
	for low in range(1, 11):
		var picked: Array[PlayingCard] = []
		var ranks := {}
		for card in hand:
			if card.debuffed or not card.has_rank():
				continue
			var r := 1 if card.rank == PlayingCard.ACE and low == 1 else card.rank
			if r >= low and r <= low + 4 and not ranks.has(r):
				ranks[r] = true
				picked.append(card)
		if picked.size() > best.size():
			best = picked
	return best


static func _mark(keep: Dictionary, cards: Array) -> void:
	for card: PlayingCard in cards:
		keep[card.id] = true


static func _ids(hand: Array[PlayingCard], mask: int) -> Array[int]:
	var out: Array[int] = []
	for i in hand.size():
		if mask & (1 << i):
			out.append(hand[i].id)
	return out


static func _bits(mask: int) -> int:
	var count := 0
	while mask != 0:
		mask &= mask - 1
		count += 1
	return count
