extends Node
## Ads, shown through a provider at the moments AdPolicy allows. Two kinds:
## - rewarded ads the player chooses ("encore", "double_coins", "daily_gift"): call
##   can_offer() to decide whether to show the button, then show_rewarded(), which
##   returns true only when the ad played to the end and the reward is due;
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
var _session_start := 0.0
var _intermissions_session := 0
var _token := 0
var _playing := false


## A "session" restarts after this long in the background (iOS and the installed web
## app keep the process alive for days).
const SESSION_GAP := 1800.0
var _left_at := -1.0


func _ready() -> void:
	mode = Monetization.mode()
	_session_start = now()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_left_at = now()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _left_at >= 0.0 and now() - _left_at > SESSION_GAP:
				_session_start = now()
				_intermissions_session = 0
			_left_at = -1.0


## Wall-clock seconds: they keep counting while a phone sleeps, and the times of the
## last intermission, rewarded ad and purchase are saved in the wallet, so the spacing
## rules hold across sleeps and relaunches.
func now() -> float:
	return Time.get_unix_time_from_system()


## Called by Store after a purchase: no intermission for a while after paying.
func note_purchase() -> void:
	Game.wallet().ad_last_purchase = now()
	Game.save_profile()


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
		"last_intermission": w.ad_last_intermission, "last_rewarded": w.ad_last_rewarded, "last_purchase": w.ad_last_purchase,
		"intermissions_session": _intermissions_session, "intermissions_today": w.intermissions_today,
		"rewarded_today": w.rewarded_today,
	}
	s.merge(context, true)
	return s


func can_offer(placement: String, context := {}) -> bool:
	return not _playing and AdPolicy.check(placement, snapshot(context)) == ""


## Play a rewarded ad. True when the reward is due.
func show_rewarded(placement: String, context := {}) -> bool:
	if not can_offer(placement, context):
		return false
	var completed: bool = await _play(placement, true)
	# Any rewarded ad that was shown starts the pause before an intermission, even if
	# it was closed early: never two full-screen ads back to back.
	Game.wallet().ad_last_rewarded = now()
	if completed:
		Game.wallet().rewarded_today += 1
	Game.save_profile()
	shown.emit(placement, completed)
	return completed


## An intermission at a natural break, only if every rule allows one right now.
func intermission(placement: String, context := {}) -> void:
	if _playing or AdPolicy.check(placement, snapshot(context)) != "":
		return
	Game.wallet().ad_last_intermission = now()
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
