extends Node
## Ads, shown through a provider at the moments AdPolicy allows. Two kinds:
## - rewarded ads the player chooses ("encore", "double_coins", "daily_gift"): call
##   can_offer() to decide whether to show the button, then show_rewarded(), which
##   returns true only when the ad played to the end and the reward is due;
## - intermissions at natural breaks ("town_break", "run_end"): call intermission(),
##   which does nothing unless every rule allows one right now.
## In "test" mode the provider is AdSheet, a placeholder that charges and tracks
## nothing. Connect the real network in _play_live (see docs/MONETIZATION.md).

signal shown(placement: String, completed: bool)

var mode := "off"
var last_purchase := -1.0
var _session_start := 0.0
var _last_intermission := -1.0
var _last_rewarded := -1.0
var _intermissions_session := 0


func _ready() -> void:
	mode = Monetization.mode()
	_session_start = now()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The state AdPolicy decides on; `context` adds run details such as
## { "encore_used": true } or { "ranked_daily": true }.
func snapshot(context := {}) -> Dictionary:
	var p: Profile = Game.profile
	p.wallet.roll_ad_day(Economy.today())
	var s := {
		"mode": mode, "now": now(), "session_start": _session_start,
		"runs_finished": p.runs_played, "in_tutorial": Settings.tutorial_step >= 0,
		"payer": p.wallet.is_payer(), "remove_ads": p.wallet.owns("remove_ads"),
		"last_intermission": _last_intermission, "last_rewarded": _last_rewarded, "last_purchase": last_purchase,
		"intermissions_session": _intermissions_session, "intermissions_today": p.wallet.intermissions_today,
		"rewarded_today": p.wallet.rewarded_today,
	}
	s.merge(context, true)
	return s


func can_offer(placement: String, context := {}) -> bool:
	return AdPolicy.check(placement, snapshot(context)) == ""


## Play a rewarded ad. True when it played to the end, so the reward is due.
func show_rewarded(placement: String, context := {}) -> bool:
	if not can_offer(placement, context):
		return false
	var completed: bool = await _play(placement, true)
	if completed:
		_last_rewarded = now()
		Game.profile.wallet.rewarded_today += 1
		Game.save_profile()
	shown.emit(placement, completed)
	return completed


## An intermission at a natural break, only if every rule allows one right now.
func intermission(placement: String) -> void:
	if AdPolicy.check(placement, snapshot()) != "":
		return
	_last_intermission = now()
	_intermissions_session += 1
	Game.profile.wallet.intermissions_today += 1
	Game.save_profile()
	await _play(placement, false)
	shown.emit(placement, true)


func _play(placement: String, rewarded: bool) -> bool:
	match mode:
		"test":
			var sheet := AdSheet.new(placement, rewarded)
			UiTheme.show_sheet(sheet)
			var completed: bool = await sheet.done
			return completed
		"live":
			return await _play_live(placement, rewarded)
	return false


## Hook for the real ad network: AdMob through a Godot iOS plugin on iPhone, Google's
## H5 Games Ads (adBreak) through JavaScriptBridge on the web. Must resolve to true
## only when a rewarded ad was watched to the end.
func _play_live(placement: String, rewarded: bool) -> bool:
	await get_tree().process_frame
	push_warning("Ads: no live ad provider connected (placement %s, rewarded %s)" % [placement, rewarded])
	return false
