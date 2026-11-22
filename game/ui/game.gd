extends Node




signal changed

const RUN_PATH := "user://run.json"
const RUN_META_PATH := "user://run_meta.json"
const PROFILE_PATH := "user://profile.json"
const SEED_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var profile := Profile.new()
var run: RunState = null


var run_meta: Dictionary = {}

var recorded := false

var win_seen := false


func _ready() -> void:
	ContentPacks.register_all()
	TranslationServer.set_locale("en")
	profile = _load_profile()



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
	var deck := deck_id
	if challenge_id != "":
		deck = str(ContentDB.get_def(challenge_id).data["deck"])
	run = RunState.create(seed if seed != "" else _random_seed(), deck, stake, challenge_id, profile.locked_cards(), str(meta.get("mode", "tour")))
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
	var result := run.apply(action)
	if result["ok"]:
		_pay_coins(before_phase, before_show, before_town, before_won)
		# A lost show waits for the player to take or decline an Encore.
		if run.phase == RunState.Phase.LOST and not encore_open():
			finish_run()
		else:
			_save_run()
	if not quiet:
		changed.emit()
	return result


## Coins for winning a show, and for winning the whole run. What this show paid is
## kept in run_meta["show_coins"] so the cash-out screen can show it and offer to
## double it once (Ads placement "double_coins").
func _pay_coins(before_phase: int, before_show: int, before_town: int, before_won: bool) -> void:
	var paid := 0
	if before_phase == RunState.Phase.IN_SHOW and run.phase == RunState.Phase.CASH_OUT:
		var coins := Economy.coins_for_show(before_show, before_town)
		profile.wallet.earn("coins", coins)
		run_meta["show_coins"] = { "show": "%d:%d" % [before_town, before_show], "coins": coins, "doubled": false }
		paid += coins
	if run.won and not before_won:
		var bonus := Economy.coins_for_run_win(run.mode)
		profile.wallet.earn("coins", bonus)
		run_meta["win_coins"] = bonus
		paid += bonus
	if paid > 0:
		run_meta["run_coins"] = int(run_meta.get("run_coins", 0)) + paid
		_save_json(RUN_META_PATH, run_meta, false)
		save_profile()


## Whether the coins of the show just won can still be doubled.
func can_double_show_coins() -> bool:
	var paid: Variant = run_meta.get("show_coins")
	return run != null and run.phase == RunState.Phase.CASH_OUT and paid is Dictionary and not bool(paid["doubled"])


## Pay the show's coins a second time (after the player watched a rewarded ad).
func double_show_coins() -> int:
	if not can_double_show_coins():
		return 0
	var paid: Dictionary = run_meta["show_coins"]
	var coins := int(paid["coins"])
	profile.wallet.earn("coins", coins)
	paid["doubled"] = true
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


## Take the Encore, paid with "ad" (the caller has already shown the rewarded ad),
## "ticket", "diamonds" or "coins". Returns "" on success or the reason.
func take_encore(paid_with: String) -> String:
	if not encore_open():
		return "No Encore now."
	var w := profile.wallet
	match paid_with:
		"ad":
			pass
		"ticket":
			if not w.use_item("encore_ticket"):
				return "No Encore ticket."
		"diamonds":
			if not w.spend("diamonds", Economy.ENCORE_DIAMONDS):
				return "Not enough diamonds."
		"coins":
			if not w.spend("coins", Economy.ENCORE_COINS):
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


## The daily gift: ready once a day. Claiming continues the streak if yesterday was
## claimed too, otherwise it starts again at day 1. Returns the gift with its "day".
func gift_ready() -> bool:
	return profile.wallet.gift_day != Economy.today()


func claim_gift() -> Dictionary:
	if not gift_ready():
		return {}
	var w := profile.wallet
	var today := Economy.today()
	w.gift_streak = w.gift_streak + 1 if Economy.is_next_day(w.gift_day, today) else 1
	w.gift_day = today
	var gift := Economy.gift_for(w.gift_streak).duplicate()
	gift["day"] = w.gift_streak
	w.earn("coins", int(gift.get("coins", 0)))
	w.earn("diamonds", int(gift.get("diamonds", 0)))
	save_profile()
	return gift


## Pay a claimed gift once more (after a rewarded ad).
func double_gift(gift: Dictionary) -> void:
	profile.wallet.earn("coins", int(gift.get("coins", 0)))
	profile.wallet.earn("diamonds", int(gift.get("diamonds", 0)))
	save_profile()


func save_profile() -> void:
	_save_json(PROFILE_PATH, profile.to_dict())



func finish_run() -> void:
	if run == null or recorded:
		return
	profile.record_run(run)
	recorded = true
	# Finishing the daily run (ranked or practice) pays once a day.
	if run_meta.has("daily_date") and profile.wallet.daily_run_day != Economy.today():
		profile.wallet.daily_run_day = Economy.today()
		profile.wallet.earn("coins", Economy.DAILY_RUN_COINS)
		run_meta["daily_coins"] = Economy.DAILY_RUN_COINS
		run_meta["run_coins"] = int(run_meta.get("run_coins", 0)) + Economy.DAILY_RUN_COINS
	_save_json(PROFILE_PATH, profile.to_dict())
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)
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
