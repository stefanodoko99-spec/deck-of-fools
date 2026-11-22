class_name Economy
extends RefCounted
## How many coins and diamonds playing earns, and what the Encore costs. All the
## numbers live here so they can be tuned in one place (tests/money_tests.gd checks
## them; docs/MONETIZATION.md explains them).
##
## Coins are earned only: they are never sold, never inside a paid pack and never
## exchanged for diamonds. That keeps them a pure reward for playing (and outside the
## EU rules for purchasable virtual currencies). They never change a run's rules
## except through the Encore, which makes the run unranked.

## Coins for winning each show: Matinee, Evening show, Patron.
const SHOW_COINS := [5, 8, 15]
## Extra coins per show for every town after the first.
const TOWN_STEP := 1
## Daily-run practice pays half (it can be replayed on the same cards).
const PRACTICE_SHARE := 0.5
## After this many coins from shows in a day, further shows pay a quarter.
const DAILY_SOFT_CAP := 1500
const AFTER_CAP_SHARE := 0.25
## The first show won each day pays this bonus.
const FIRST_WIN_OF_DAY := 50
## Coins for winning a whole run, by mode; tours pay more on higher stakes.
const RUN_WIN_COINS := { "tour": 100, "quick": 40, "bosses": 50 }
const TOUR_STAKE_BONUS := 15
## Coins for finishing the daily run (ranked or practice), once a day.
const DAILY_RUN_COINS := 50
## Every 25 Jesters found in the collection pays this once.
const ALBUM_STEP := 25
const ALBUM_COINS := 250
const ALBUM_DIAMONDS := 20

## The daily gift calendar: one step per day the gift is claimed. Missing a day only
## pauses it (nothing is lost for not coming back); after day 7 it starts at day 1.
const GIFTS := [
	{ "coins": 30 },
	{ "coins": 40 },
	{ "coins": 50, "diamonds": 5 },
	{ "coins": 60 },
	{ "coins": 80 },
	{ "coins": 100 },
	{ "coins": 150, "diamonds": 15 },
]

## The Encore: after losing a show, play on with extra hands and discards, once per
## run. Paid with a rewarded ad or coins (less than one won quick run pays), never
## with money at that frustrating moment.
const ENCORE_HANDS := 1
const ENCORE_DISCARDS := 1
const ENCORE_COINS := 100


static func coins_for_show(show_index: int, town: int) -> int:
	return int(SHOW_COINS[clampi(show_index, 0, 2)]) + TOWN_STEP * maxi(0, town - 1)


## What a won show actually pays, after the practice share and the daily soft cap.
## `earned_today` is what shows already paid today.
static func show_payout(base: int, practice: bool, earned_today: int) -> int:
	var coins := float(base) * (PRACTICE_SHARE if practice else 1.0)
	if earned_today >= DAILY_SOFT_CAP:
		coins *= AFTER_CAP_SHARE
	return maxi(1, roundi(coins))


static func coins_for_run_win(mode: String, stake := 1) -> int:
	var coins := int(RUN_WIN_COINS.get(mode, RUN_WIN_COINS["tour"]))
	if mode == "tour":
		coins += TOUR_STAKE_BONUS * maxi(0, stake - 1)
	return coins


## The gift for a streak of `day` days (1 = first day).
static func gift_for(day: int) -> Dictionary:
	return GIFTS[posmod(maxi(1, day) - 1, GIFTS.size())]


## Album milestones passed when the collection grows from `before` to `after` Jesters.
static func album_milestones(before: int, after: int) -> int:
	return maxi(0, floori(after / float(ALBUM_STEP)) - floori(before / float(ALBUM_STEP)))


## Today's date as YYYY-MM-DD in UTC, the same day the daily run uses.
static func today() -> String:
	return Time.get_date_string_from_system(true)


## Whether `later` is exactly the day after `earlier` (both YYYY-MM-DD).
static func is_next_day(earlier: String, later: String) -> bool:
	if earlier == "" or later == "":
		return false
	var a := Time.get_unix_time_from_datetime_string(earlier + "T12:00:00")
	var b := Time.get_unix_time_from_datetime_string(later + "T12:00:00")
	return absi(int(b - a) - 86400) < 4 * 3600
