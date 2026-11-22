class_name AdPolicy
extends RefCounted
## When an ad may appear. Pure rules over a snapshot of the player's state, so they
## can be tested without a screen.
##
## Two kinds of placement:
## - Rewarded ads the player chooses to watch for something (an Encore after losing a
##   show, doubling a show's coins, doubling the daily gift). Never forced.
## - Intermissions: a short ad break at a natural pause, between towns or after a
##   run, never during a show, never at launch, never in the first runs, never for
##   anyone who has paid, and never more often than the caps below.
## The numbers are tuned in one place here; see docs/MONETIZATION.md for the reasons.

const REWARDED := ["encore", "double_coins", "daily_gift"]
const INTERMISSIONS := ["town_break", "run_end"]

## Finished runs before the first intermission (new players see none).
const NEW_PLAYER_RUNS := 3
## Seconds into a session before the first intermission.
const SESSION_WARMUP := 180
## Seconds between two intermissions.
const COOLDOWN := 300
## Seconds after a rewarded ad (or a purchase) during which no intermission shows.
const AFTER_REWARDED := 180
## Intermissions per session and per day.
const MAX_PER_SESSION := 3
const MAX_PER_DAY := 6
## Rewarded ads per day, all placements together.
const MAX_REWARDED_PER_DAY := 15


## Returns "" when the placement may show now, or the reason it may not.
## `s` keys (all optional, with safe defaults):
##   mode: "off" | "test" | "live"; now: seconds; session_start: seconds;
##   runs_finished; in_tutorial; payer; remove_ads; ranked_daily;
##   last_intermission, last_rewarded, last_purchase: seconds (or -1);
##   intermissions_session, intermissions_today, rewarded_today;
##   encore_used (this run), double_used (this show).
static func check(placement: String, s: Dictionary) -> String:
	if str(s.get("mode", "off")) == "off":
		return "ads are off in this build"
	var now := float(s.get("now", 0.0))
	if REWARDED.has(placement):
		if int(s.get("rewarded_today", 0)) >= MAX_REWARDED_PER_DAY:
			return "daily limit for rewarded ads reached"
		match placement:
			"encore":
				if bool(s.get("encore_used", false)):
					return "one Encore per run"
				if bool(s.get("ranked_daily", false)):
					return "no Encore in the ranked daily run"
			"double_coins":
				if bool(s.get("double_used", false)):
					return "already doubled"
		return ""
	if not INTERMISSIONS.has(placement):
		return "unknown placement"
	if bool(s.get("in_tutorial", false)):
		return "not during the guided first run"
	if bool(s.get("payer", false)) or bool(s.get("remove_ads", false)):
		return "no intermissions for supporters"
	if int(s.get("runs_finished", 0)) < NEW_PLAYER_RUNS:
		return "new player"
	if now - float(s.get("session_start", now)) < SESSION_WARMUP:
		return "too early in the session"
	if _within(now, s.get("last_intermission", -1), COOLDOWN):
		return "too soon after the last intermission"
	if _within(now, s.get("last_rewarded", -1), AFTER_REWARDED):
		return "too soon after a rewarded ad"
	if _within(now, s.get("last_purchase", -1), AFTER_REWARDED):
		return "too soon after a purchase"
	if int(s.get("intermissions_session", 0)) >= MAX_PER_SESSION:
		return "session limit reached"
	if int(s.get("intermissions_today", 0)) >= MAX_PER_DAY:
		return "daily limit reached"
	return ""


static func _within(now: float, since: Variant, seconds: float) -> bool:
	var t := float(since) if since != null else -1.0
	return t >= 0.0 and now - t < seconds
