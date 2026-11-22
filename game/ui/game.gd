extends Node




signal changed
## What just happened in a run, for features that react to play (daily goals, tips,
## seasons, Jester mastery) without touching the run code. Kinds and their data:
##   "hand_played" {hand, total, points, mult, cards, show, town}
##   "discarded"   {count, show, town}
##   "show_won"    {show, town, hands_left, discards_left, hands_played, coins}
##   "show_lost"   {show, town, score, target}
##   "jester_bought" {id}
##   "run_finished" {won, mode, town, stake, deck, encores, daily, practice}
signal run_event(kind: String, data: Dictionary)

const RUN_PATH := "user://run.json"
const RUN_META_PATH := "user://run_meta.json"
const PROFILE_PATH := "user://profile.json"
const SEED_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var profile := Profile.new()
var run: RunState = null


var run_meta: Dictionary = {}

var recorded := false

var win_seen := false

## "off", "test" or "live" (core/monetization.gd), fixed for the whole session.
var money_mode := "off"


func _ready() -> void:
	ContentPacks.register_all()
	TranslationServer.set_locale("en")
	money_mode = Monetization.mode()
	profile = _load_profile()
	if profile.first_played == "":
		profile.first_played = Economy.today()
		_save_json(PROFILE_PATH, profile.to_dict(), false)


## The wallet this build uses: test builds keep their free test purchases apart.
func wallet() -> Wallet:
	return profile.test_wallet if money_mode == "test" else profile.wallet



func _exit_tree() -> void:
	run = null
	ContentDB.reset()


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)



func peek_saved_run() -> RunState:
	if not has_saved_run():
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	return RunState.from_dict(data) if data is Dictionary else null



func new_run(deck_id: String, stake: int, challenge_id := "", seed := "", meta := {}) -> void:
	_settle_lost_run()
	var deck := deck_id
	if challenge_id != "":
		deck = str(ContentDB.get_def(challenge_id).data["deck"])
	# The daily run deals the same cards to everyone, so it doesn't depend on which
	# Rare Jesters this player has unlocked: they are all left out of its Market.
	var locked: Array = Unlocks.RARE_FEATS.keys() if meta.has("daily_date") else profile.locked_cards()
	run = RunState.create(seed if seed != "" else _random_seed(), deck, stake, challenge_id, locked, str(meta.get("mode", "tour")))
	run_meta = meta.duplicate()
	recorded = false
	win_seen = false
	_save_json(RUN_META_PATH, run_meta)
	_save_run()
	changed.emit()


func continue_run() -> bool:
	var text := FileAccess.get_file_as_string(RUN_PATH)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return false
	run = RunState.from_dict(data)
	run_meta = _load_json(RUN_META_PATH)
	recorded = false
	win_seen = run.won
	changed.emit()
	return true



func cloud_data() -> Dictionary:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH)) if has_saved_run() else null
	return { "profile": profile.to_dict(), "run": saved, "run_meta": run_meta if saved != null else {} }



func adopt_cloud(data: Dictionary) -> void:
	if data.get("profile") is Dictionary:
		profile = Profile.from_dict(data["profile"])
		_save_json(PROFILE_PATH, profile.to_dict(), false)
	run = null
	if data.get("run") is Dictionary:
		_save_json(RUN_PATH, data["run"], false)
		_save_json(RUN_META_PATH, data.get("run_meta", {}), false)
	elif FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)
	changed.emit()




func act(action: Dictionary, quiet := false) -> Dictionary:
	var before_phase := run.phase
	var before_show := run.show_index
	var before_town := run.town
	var before_won := run.won
	var zanni_before := run.zanni.size()
	var result := run.apply(action)
	if result["ok"]:
		_pay_coins(before_phase, before_show, before_town, before_won)
		_tell_run_events(str(action.get("a", "")), action, result, before_phase, before_show, before_town, zanni_before)
		# A lost show waits for the player to take or decline an Encore.
		if run.phase == RunState.Phase.LOST and not encore_open():
			finish_run()
		else:
			_save_run()
	if not quiet:
		changed.emit()
	return result


## Coins for winning a show (Economy.show_payout: practice pays half, and after the
## daily soft cap shows pay a quarter), the first win of the day, and winning the run.
## run_meta keeps the tally: "run_coins" (all coins this run, for the screens),
## "doublable" (show and win coins, which the curtain-call ad can double once) and
## "show_coins" (what the last show paid, for the cash-out screen).
func _pay_coins(before_phase: int, before_show: int, before_town: int, before_won: bool) -> void:
	var w := wallet()
	var paid := 0
	if before_phase == RunState.Phase.IN_SHOW and run.phase == RunState.Phase.CASH_OUT:
		var today := Economy.today()
		w.roll_coin_day(today)
		var coins := Economy.show_payout(Economy.coins_for_show(before_show, before_town), bool(run_meta.get("practice", false)), w.show_coins_today)
		w.show_coins_today += coins
		var bonus := 0
		if w.first_win_day < today:
			w.first_win_day = today
			bonus = Economy.FIRST_WIN_OF_DAY
		w.earn("coins", coins + bonus)
		run_meta["show_coins"] = { "show": "%d:%d" % [before_town, before_show], "coins": coins, "first_win": bonus }
		run_meta["doublable"] = int(run_meta.get("doublable", 0)) + coins
		paid += coins + bonus
	if run.won and not before_won:
		var win := Economy.coins_for_run_win(run.mode, run.stake)
		w.earn("coins", win)
		run_meta["win_coins"] = win
		run_meta["doublable"] = int(run_meta.get("doublable", 0)) + win
		paid += win
	if paid > 0:
		run_meta["run_coins"] = int(run_meta.get("run_coins", 0)) + paid
		_save_json(RUN_META_PATH, run_meta, false)
		save_profile()


func _tell_run_events(kind: String, action: Dictionary, result: Dictionary, before_phase: int, before_show: int, before_town: int, zanni_before: int) -> void:
	match kind:
		"play":
			run_event.emit("hand_played", { "hand": str(result.get("hand", "")), "total": float(result.get("total", 0.0)),
				"points": float(result.get("points", 0.0)), "mult": float(result.get("mult", 0.0)),
				"cards": (action.get("cards", []) as Array).size(), "show": before_show, "town": before_town })
		"discard":
			run_event.emit("discarded", { "count": (action.get("cards", []) as Array).size(), "show": before_show, "town": before_town })
	if run.zanni.size() > zanni_before and (kind == "buy" or kind == "pick"):
		run_event.emit("jester_bought", { "id": run.zanni[run.zanni.size() - 1].def_id })
	if before_phase == RunState.Phase.IN_SHOW and run.phase == RunState.Phase.CASH_OUT:
		var paid: Variant = run_meta.get("show_coins")
		run_event.emit("show_won", { "show": before_show, "town": before_town, "hands_left": run.hands_left,
			"discards_left": run.discards_left, "hands_played": int(run.show_counters.get("hands_played", 0)),
			"coins": int((paid as Dictionary).get("coins", 0)) if paid is Dictionary else 0 })
	if before_phase == RunState.Phase.IN_SHOW and run.phase == RunState.Phase.LOST:
		run_event.emit("show_lost", { "show": before_show, "town": before_town, "score": run.show_score, "target": run.show_target })


## The curtain call: once a run has ended, its show and win coins can be doubled once
## (after a rewarded ad, or one tap for supporters).
func can_double_run_coins() -> bool:
	return recorded and int(run_meta.get("doublable", 0)) > 0 and not bool(run_meta.get("doubled", false))


func double_run_coins() -> int:
	if not can_double_run_coins():
		return 0
	var coins := int(run_meta["doublable"])
	wallet().earn("coins", coins)
	run_meta["doubled"] = true
	run_meta["run_coins"] = int(run_meta.get("run_coins", 0)) + coins
	_save_json(RUN_META_PATH, run_meta, false)
	save_profile()
	return coins


## The ranked daily run: one try, the same for everyone, so no Encore there.
func is_ranked_daily() -> bool:
	return run_meta.has("daily_date") and not bool(run_meta.get("practice", false))


## An Encore is on offer: the run lost a show and may play on (once per run).
func encore_open() -> bool:
	return run != null and run.can_encore() and not is_ranked_daily()


## In the guided first run the Encore is free: it teaches the idea without an ad.
func encore_free() -> bool:
	return Settings.tutorial_step >= 0


## Take the Encore, paid with "ad" (the caller has already shown the rewarded ad),
## "coins", or "free" in the guided first run. Never with diamonds or money: losing a
## show is the worst moment to sell something. Returns "" on success or the reason.
func take_encore(paid_with: String) -> String:
	if not encore_open():
		return "No Encore now."
	match paid_with:
		"ad":
			pass
		"free":
			if not encore_free():
				return "The Encore isn't free now."
		"coins":
			if not wallet().spend("coins", Economy.ENCORE_COINS):
				return "Not enough coins."
		_:
			return "Unknown payment."
	var result := run.apply({ "a": "encore" })
	if not result["ok"]:
		return str(result.get("error", "No Encore now."))
	run_meta["encore"] = paid_with
	_save_json(RUN_META_PATH, run_meta, false)
	_save_run()
	save_profile()
	changed.emit()
	return ""


## The player let the run end instead of taking an Encore.
func decline_encore() -> void:
	if run != null and run.phase == RunState.Phase.LOST:
		finish_run()
		changed.emit()


## A run left waiting on the Encore offer (the app was closed there) ends when a new
## run starts, so its loss is still counted.
func _settle_lost_run() -> void:
	if run == null and has_saved_run():
		var saved := peek_saved_run()
		if saved != null and saved.phase == RunState.Phase.LOST:
			run = saved
			run_meta = _load_json(RUN_META_PATH)
			recorded = false
	if run != null and run.phase == RunState.Phase.LOST and not recorded:
		finish_run()


## The daily gift: ready once a day (UTC, like the daily run). A clock set back
## doesn't make it ready again. Each claim moves the 7-day calendar on one step; a
## missed day doesn't reset it. Returns the gift with its "day" (1-7).
func gift_ready() -> bool:
	return wallet().gift_day < Economy.today()


func claim_gift() -> Dictionary:
	if not gift_ready():
		return {}
	var w := wallet()
	var today := Economy.today()
	# The calendar moves on one step per claim; missing days doesn't reset it.
	w.gift_streak += 1
	w.gift_day = today
	var gift := Economy.gift_for(w.gift_streak).duplicate()
	gift["day"] = posmod(w.gift_streak - 1, Economy.GIFTS.size()) + 1
	w.earn("coins", int(gift.get("coins", 0)))
	w.earn("diamonds", int(gift.get("diamonds", 0)))
	save_profile()
	return gift


## Pay a claimed gift's coins once more (after a rewarded ad). Only today's gift, only
## once, and only the coins: an ad never pays out diamonds.
func double_gift(gift: Dictionary) -> bool:
	var w := wallet()
	if w.gift_day != Economy.today() or w.gift_doubled_day == w.gift_day:
		return false
	w.gift_doubled_day = w.gift_day
	w.earn("coins", int(gift.get("coins", 0)))
	save_profile()
	return true


func save_profile() -> void:
	_save_json(PROFILE_PATH, profile.to_dict())



func finish_run() -> void:
	if run == null or recorded:
		return
	var found_before := profile.jesters_found()
	profile.record_run(run)
	recorded = true
	run_event.emit("run_finished", { "won": run.won, "mode": run.mode, "town": run.town, "stake": run.stake,
		"deck": run.deck_id, "encores": run.encores(), "daily": run_meta.has("daily_date"),
		"practice": bool(run_meta.get("practice", false)) })
	var w := wallet()
	# Finishing the daily run (ranked or practice) pays once a day.
	if run_meta.has("daily_date") and w.daily_run_day < Economy.today():
		w.daily_run_day = Economy.today()
		w.earn("coins", Economy.DAILY_RUN_COINS)
		run_meta["daily_coins"] = Economy.DAILY_RUN_COINS
		run_meta["run_coins"] = int(run_meta.get("run_coins", 0)) + Economy.DAILY_RUN_COINS
	# Every 25 Jesters found pays an album milestone.
	var milestones := Economy.album_milestones(found_before, profile.jesters_found())
	if milestones > 0:
		w.earn("coins", Economy.ALBUM_COINS * milestones)
		w.earn("diamonds", Economy.ALBUM_DIAMONDS * milestones)
		run_meta["album"] = { "jesters": profile.jesters_found(), "coins": Economy.ALBUM_COINS * milestones, "diamonds": Economy.ALBUM_DIAMONDS * milestones }
		run_meta["run_coins"] = int(run_meta.get("run_coins", 0)) + Economy.ALBUM_COINS * milestones
	_save_json(RUN_META_PATH, run_meta, false)
	_save_json(PROFILE_PATH, profile.to_dict())
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)
	WebStatus.publish(null)
	# Quick runs and boss rushes are just for fun: only the tour is ranked, and a run
	# that took an Encore isn't ranked either.
	if run.mode == "tour" and run.encores() == 0:
		Online.submit_run(run, run_meta)



func give_up() -> void:
	if run == null or recorded:
		return
	run.phase = RunState.Phase.LOST
	_save_run()
	finish_run()




func restart() -> void:
	if run == null:
		return
	var deck := run.deck_id
	var stake := run.stake
	var challenge := run.challenge
	var meta := run_meta.duplicate()
	var seed := ""
	if meta.has("daily_date"):
		meta["practice"] = true
		seed = run.seed_text
	give_up()
	new_run(deck, stake, challenge, seed, meta)



func first_run_finished() -> bool:
	return profile.total_wins + profile.runs_lost + profile.challenges_won.size() == 1


func _save_run() -> void:
	_save_json(RUN_PATH, run.to_dict())
	WebStatus.publish(run)


func _load_profile() -> Profile:
	var data := _load_json(PROFILE_PATH)
	return Profile.from_dict(data) if not data.is_empty() else Profile.new()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}




func _save_json(path: String, data: Dictionary, changed_here := true) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
	if changed_here:
		Online.mark_dirty()


func _random_seed() -> String:
	var out := ""
	for i in 8:
		out += SEED_LETTERS[randi() % SEED_LETTERS.length()]
	return out
