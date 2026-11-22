class_name Wallet
extends RefCounted
## The player's meta currencies and what they own, kept in the profile (and so in the
## cloud save). Coins are earned by playing; diamonds are bought with real money (or
## given now and then, e.g. by the daily gift). Neither ever changes a run's rules,
## except the Encore (a second chance after losing a show), which makes that run
## unranked.
##
## Real-money purchases only reach here after the store has confirmed them. When the
## store goes live, diamonds bought with money should be credited by the server after
## receipt validation (docs/MONETIZATION.md); until then the wallet is client-side.

const CURRENCIES := ["coins", "diamonds"]
const MAX_BALANCE := 9_999_999
const MAX_PURCHASE_LOG := 50

var coins := 0
var diamonds := 0
## Things bought once and kept for good: card backs ("back_..."), "remove_ads", "starter".
var owned: Dictionary = {}
## Consumables held, by item id (e.g. "encore_ticket": 2).
var items: Dictionary = {}
## Lifetime totals.
var coins_earned := 0
var coins_spent := 0
var diamonds_earned := 0
var diamonds_spent := 0
## Real-money purchases (or test purchases in a test build), newest last.
var purchases: Array = []
## The daily gift: the last day claimed (YYYY-MM-DD, local time) and the streak length.
var gift_day := ""
var gift_streak := 0
## The last day the daily run paid its coins (once a day).
var daily_run_day := ""
## Coins from shows today (for the daily soft cap) and the day of the first-win bonus.
var coin_day := ""
var show_coins_today := 0
var first_win_day := ""
## The day the daily gift was last doubled (once a day).
var gift_doubled_day := ""
## Ad counters for today (reset when the day changes), to keep ads rare.
var ad_day := ""
var rewarded_today := 0
var intermissions_today := 0


func balance(currency: String) -> int:
	return coins if currency == "coins" else (diamonds if currency == "diamonds" else 0)


func can_afford(currency: String, amount: int) -> bool:
	return amount >= 0 and CURRENCIES.has(currency) and balance(currency) >= amount


## Add currency. Negative or unknown amounts are ignored.
func earn(currency: String, amount: int) -> void:
	if amount <= 0:
		return
	match currency:
		"coins":
			coins = mini(MAX_BALANCE, coins + amount)
			coins_earned += amount
		"diamonds":
			diamonds = mini(MAX_BALANCE, diamonds + amount)
			diamonds_earned += amount


## Take currency if there is enough; returns whether it was taken.
func spend(currency: String, amount: int) -> bool:
	if amount < 0 or not can_afford(currency, amount):
		return false
	match currency:
		"coins":
			coins -= amount
			coins_spent += amount
		"diamonds":
			diamonds -= amount
			diamonds_spent += amount
	return true


func owns(id: String) -> bool:
	return owned.has(id)


func grant(id: String) -> void:
	owned[id] = true


func item_count(id: String) -> int:
	return int(items.get(id, 0))


func add_item(id: String, count := 1) -> void:
	if count > 0:
		items[id] = item_count(id) + count


func use_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	items[id] = item_count(id) - 1
	if int(items[id]) == 0:
		items.erase(id)
	return true


## Someone who has paid real money (or removed ads) never sees an intermission.
func is_payer() -> bool:
	return owns("remove_ads") or purchases.any(func(p: Variant) -> bool: return p is Dictionary and not bool((p as Dictionary).get("refunded", false)))


func log_purchase(product_id: String, provider: String, test: bool, transaction := "") -> void:
	purchases.append({ "id": product_id, "at": int(Time.get_unix_time_from_system()), "provider": provider, "test": test, "transaction": transaction })
	while purchases.size() > MAX_PURCHASE_LOG:
		purchases.pop_front()


## Start a new day's show-coin count if the date changed.
func roll_coin_day(today: String) -> void:
	if coin_day != today:
		coin_day = today
		show_coins_today = 0


## Start a new day's ad counters if the date changed.
func roll_ad_day(today: String) -> void:
	if ad_day != today:
		ad_day = today
		rewarded_today = 0
		intermissions_today = 0


func to_dict() -> Dictionary:
	return {
		"coins": coins, "diamonds": diamonds, "owned": owned.keys(), "items": items.duplicate(),
		"coins_earned": coins_earned, "coins_spent": coins_spent,
		"diamonds_earned": diamonds_earned, "diamonds_spent": diamonds_spent,
		"purchases": purchases.duplicate(true), "gift_day": gift_day, "gift_streak": gift_streak, "daily_run_day": daily_run_day,
		"coin_day": coin_day, "show_coins_today": show_coins_today, "first_win_day": first_win_day, "gift_doubled_day": gift_doubled_day,
		"ad_day": ad_day, "rewarded_today": rewarded_today, "intermissions_today": intermissions_today,
	}


static func from_dict(d: Dictionary) -> Wallet:
	var w := Wallet.new()
	w.coins = clampi(int(d.get("coins", 0)), 0, MAX_BALANCE)
	w.diamonds = clampi(int(d.get("diamonds", 0)), 0, MAX_BALANCE)
	var owned_list: Variant = d.get("owned", [])
	if owned_list is Array:
		for id: Variant in owned_list:
			w.owned[str(id)] = true
	var held: Variant = d.get("items", {})
	if held is Dictionary:
		for id: Variant in held:
			var n := int((held as Dictionary)[id])
			if n > 0:
				w.items[str(id)] = n
	w.coins_earned = maxi(0, int(d.get("coins_earned", 0)))
	w.coins_spent = maxi(0, int(d.get("coins_spent", 0)))
	w.diamonds_earned = maxi(0, int(d.get("diamonds_earned", 0)))
	w.diamonds_spent = maxi(0, int(d.get("diamonds_spent", 0)))
	var history: Variant = d.get("purchases", [])
	if history is Array:
		for p: Variant in history:
			if p is Dictionary:
				# JSON turns whole numbers into floats; keep the log's types stable.
				var entry := p as Dictionary
				var clean := {
					"id": str(entry.get("id", "")), "at": int(entry.get("at", 0)), "provider": str(entry.get("provider", "")),
					"test": bool(entry.get("test", false)), "transaction": str(entry.get("transaction", "")),
				}
				if bool(entry.get("refunded", false)):
					clean["refunded"] = true
				w.purchases.append(clean)
		while w.purchases.size() > MAX_PURCHASE_LOG:
			w.purchases.pop_front()
	w.gift_day = str(d.get("gift_day", ""))
	w.gift_streak = maxi(0, int(d.get("gift_streak", 0)))
	w.daily_run_day = str(d.get("daily_run_day", ""))
	w.coin_day = str(d.get("coin_day", ""))
	w.show_coins_today = maxi(0, int(d.get("show_coins_today", 0)))
	w.first_win_day = str(d.get("first_win_day", ""))
	w.gift_doubled_day = str(d.get("gift_doubled_day", ""))
	w.ad_day = str(d.get("ad_day", ""))
	w.rewarded_today = maxi(0, int(d.get("rewarded_today", 0)))
	w.intermissions_today = maxi(0, int(d.get("intermissions_today", 0)))
	return w
