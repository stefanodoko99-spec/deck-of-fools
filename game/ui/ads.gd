extends Node
## Ads, shown through a provider at the moments AdPolicy allows. Two kinds:
## - rewarded ads the player chooses ("encore", "double_coins", "daily_gift"): call
##   can_offer() to decide whether to show the button, then show_rewarded(), which
##   returns true only when the reward is due (the ad played to the end, or the
##   player owns No intermissions, which grants these rewards with one tap);
## - intermissions at natural breaks ("town_break", "run_end"): call intermission(),
##   which does nothing unless every rule allows one right now.
## While an ad plays the game's sound is muted. In "test" mode the provider is
## AdSheet, a placeholder that charges and tracks nothing. Connect the real network in
## _play_live (see docs/MONETIZATION.md); it is given LIVE_TIMEOUT seconds at most, so
## an ad that never answers can't block the game.

signal shown(placement: String, completed: bool)
signal _live_done(token: int, completed: bool)

const LIVE_TIMEOUT := 45.0

var mode := "off"
var last_purchase := -1.0
var _session_start := 0.0
var _last_intermission := -1.0
var _last_rewarded := -1.0
var _intermissions_session := 0
var _token := 0
var _playing := false


func _ready() -> void:
	mode = Monetization.mode()
	_session_start = now()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The state AdPolicy decides on; `context` adds details such as { "encore_used": true }
## or { "town": 3 } for a town break.
func snapshot(context := {}) -> Dictionary:
	var p: Profile = Game.profile
	var w: Wallet = Game.wallet()
	w.roll_ad_day(Economy.today())
	var s := {
		"mode": mode, "now": now(), "session_start": _session_start,
		"runs_finished": p.runs_played, "install_days": p.days_played_since(Economy.today()),
		"in_tutorial": Settings.tutorial_step >= 0,
		"payer": w.is_payer(), "remove_ads": w.owns("remove_ads"),
		"ranked_daily": Game.run != null and Game.is_ranked_daily(),
		"last_intermission": _last_intermission, "last_rewarded": _last_rewarded, "last_purchase": last_purchase,
		"intermissions_session": _intermissions_session, "intermissions_today": w.intermissions_today,
		"rewarded_today": w.rewarded_today,
	}
	s.merge(context, true)
	return s


func can_offer(placement: String, context := {}) -> bool:
	return not _playing and AdPolicy.check(placement, snapshot(context)) == ""


## True when the player owns No intermissions: rewarded choices then skip the ad.
func ad_free() -> bool:
	return Game.wallet().owns("remove_ads")


## Play a rewarded ad. True when the reward is due.
func show_rewarded(placement: String, context := {}) -> bool:
	if not can_offer(placement, context):
		return false
	var completed := true
	if not ad_free():
		completed = await _play(placement, true)
	if completed:
		_last_rewarded = now()
		Game.wallet().rewarded_today += 1
		Game.save_profile()
	shown.emit(placement, completed)
	return completed


## An intermission at a natural break, only if every rule allows one right now.
func intermission(placement: String, context := {}) -> void:
	if _playing or AdPolicy.check(placement, snapshot(context)) != "":
		return
	_last_intermission = now()
	_intermissions_session += 1
	Game.wallet().intermissions_today += 1
	Game.save_profile()
	await _play(placement, false)
	shown.emit(placement, true)


func _play(placement: String, rewarded: bool) -> bool:
	_playing = true
	var master := AudioServer.get_bus_index("Master")
	var was_muted := AudioServer.is_bus_mute(master)
	AudioServer.set_bus_mute(master, true)
	var completed := false
	match mode:
		"test":
			var sheet := AdSheet.new(placement, rewarded)
			UiTheme.show_sheet(sheet)
			completed = await sheet.done
		"live":
			completed = await _play_live_guarded(placement, rewarded)
	AudioServer.set_bus_mute(master, was_muted)
	_playing = false
	return completed


## Runs the live provider with a timeout: whichever answers first wins.
func _play_live_guarded(placement: String, rewarded: bool) -> bool:
	_token += 1
	var token := _token
	get_tree().create_timer(LIVE_TIMEOUT).timeout.connect(func() -> void: _live_done.emit(token, false))
	_run_live(token, placement, rewarded)
	while true:
		var answer: Array = await _live_done
		if int(answer[0]) == token:
			return bool(answer[1])
	return false


func _run_live(token: int, placement: String, rewarded: bool) -> void:
	var completed := await _play_live(placement, rewarded)
	_live_done.emit(token, completed)


## Hook for the real ad network: AdMob through a Godot iOS plugin on iPhone, Google's
## H5 Games Ads (adBreak) through JavaScriptBridge on the web. Must resolve to true
## only when a rewarded ad was watched to the end.
func _play_live(placement: String, rewarded: bool) -> bool:
	await get_tree().process_frame
	push_warning("Ads: no live ad provider connected (placement %s, rewarded %s)" % [placement, rewarded])
	return false
