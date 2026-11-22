class_name Economy
extends RefCounted
## How many coins and diamonds playing earns, and what the Encore costs. All the
## numbers live here so they can be tuned in one place (see tests/bot.gd for the
## earnings a run produces). Coins never change a run's rules: they buy cosmetics,
## Encore tickets and nothing else that affects ranked play.

## Coins for winning each show: Matinee, Evening show, Patron.
const SHOW_COINS := [5, 8, 15]
## Extra coins per show for every town after the first.
const TOWN_STEP := 2
## Coins for winning a whole run, by mode.
const RUN_WIN_COINS := { "tour": 150, "quick": 50, "bosses": 80 }
## Coins for finishing the daily run (ranked or practice), once a day.
const DAILY_RUN_COINS := 25

## The daily gift, one step per consecutive day; after day 7 it starts again at day 1.
const GIFTS := [
	{ "coins": 30 },
	{ "coins": 40 },
	{ "coins": 50, "diamonds": 5 },
	{ "coins": 60 },
	{ "coins": 80 },
	{ "coins": 100 },
	{ "coins": 150, "diamonds": 15 },
]

## The Encore: after losing a show, play on with extra hands and discards. Once per run.
const ENCORE_HANDS := 1
const ENCORE_DISCARDS := 1
const ENCORE_DIAMONDS := 25
const ENCORE_COINS := 250


static func coins_for_show(show_index: int, town: int) -> int:
	return int(SHOW_COINS[clampi(show_index, 0, 2)]) + TOWN_STEP * maxi(0, town - 1)


static func coins_for_run_win(mode: String) -> int:
	return int(RUN_WIN_COINS.get(mode, RUN_WIN_COINS["tour"]))


## The gift for a streak of `day` days (1 = first day).
static func gift_for(day: int) -> Dictionary:
	return GIFTS[posmod(maxi(1, day) - 1, GIFTS.size())]


## Today's date as YYYY-MM-DD in local time.
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## Whether `later` is exactly the day after `earlier` (both YYYY-MM-DD).
static func is_next_day(earlier: String, later: String) -> bool:
	if earlier == "" or later == "":
		return false
	var a := Time.get_unix_time_from_datetime_string(earlier + "T12:00:00")
	var b := Time.get_unix_time_from_datetime_string(later + "T12:00:00")
	return absi(int(b - a) - 86400) < 4 * 3600
