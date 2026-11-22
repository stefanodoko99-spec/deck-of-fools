class_name ShopCatalog
extends RefCounted
## Everything the shop sells. ITEMS cost coins or diamonds and are handled entirely in
## the game; PRODUCTS cost real money and go through the platform store (App Store on
## iPhone, a web checkout in the browser). Their ids are the store product ids to
## create in App Store Connect (docs/MONETIZATION.md).
##
## Rules this catalog keeps (see the research in docs/MONETIZATION.md):
## - nothing is random, so there are no odds to disclose;
## - nothing sold touches a run: diamonds buy cosmetics only;
## - coins are never sold or exchanged for diamonds;
## - diamond prices and pack sizes are multiples of 100, and 100 diamonds cost $0.99
##   at the base rate, so every price can show its real-money value and no pack
##   leaves diamonds that nothing can use;
## - No intermissions removes ad breaks only: it never turns a rewarded ad into a free
##   reward, which would sell coins or Encores for money.

## 100 diamonds = this many US dollars at the base rate (the smallest pack, no bonus).
const USD_PER_100_DIAMONDS := 0.99

## Card backs 0-5 are free for everyone; these are drawn by CardView._draw_back.
const ITEMS := [
	{ "id": "back_gilded_sun", "kind": "card_back", "back": 6, "name": "Gilded sun", "currency": "coins", "price": 600,
		"text": "A golden sunburst on midnight blue." },
	{ "id": "back_venetian_glass", "kind": "card_back", "back": 7, "name": "Venetian glass", "currency": "coins", "price": 900,
		"text": "Murano glass in teal and gold." },
	{ "id": "back_opera_night", "kind": "card_back", "back": 8, "name": "Opera night", "currency": "diamonds", "price": 300,
		"text": "Velvet seats under a chandelier." },
	{ "id": "back_carnival_gold", "kind": "card_back", "back": 9, "name": "Carnival gold", "currency": "diamonds", "price": 300,
		"text": "Gold leaf, confetti and a jester's crown." },
]

## Real-money products. "usd" is only a reference price for the test store; the live
## store shows the platform's own localized price. Pack ids carry the base amount so
## the bonus can change without new products.
const PRODUCTS := [
	{ "id": "dof.starter", "kind": "bundle", "name": "Opening night pack", "usd": 1.99, "once": true,
		"diamonds": 300, "grant": ["back_starter_crest"],
		"text": "300 diamonds and the Starter's crest card back, sold only here. Once per player." },
	{ "id": "dof.remove_ads", "kind": "unlock", "name": "No intermissions", "usd": 3.99, "once": true, "grant": ["remove_ads"],
		"text": "No more ad breaks between towns or after runs. Optional rewarded ads stay your choice." },
	{ "id": "dof.diamonds.100", "kind": "diamonds", "name": "Handful of diamonds", "usd": 0.99, "diamonds": 100,
		"text": "100 diamonds." },
	{ "id": "dof.diamonds.500", "kind": "diamonds", "name": "Pouch of diamonds", "usd": 4.99, "diamonds": 500,
		"text": "500 diamonds." },
	{ "id": "dof.diamonds.1000", "kind": "diamonds", "name": "Box of diamonds", "usd": 9.99, "diamonds": 1100,
		"text": "1,000 diamonds + 100 bonus." },
	{ "id": "dof.diamonds.2000", "kind": "diamonds", "name": "Casket of diamonds", "usd": 19.99, "diamonds": 2300,
		"text": "2,000 diamonds + 300 bonus." },
	{ "id": "dof.diamonds.5000", "kind": "diamonds", "name": "Treasury of diamonds", "usd": 49.99, "diamonds": 6000,
		"text": "5,000 diamonds + 1,000 bonus." },
]

## Card backs that are never sold on their own (they come in a bundle).
const BUNDLE_BACKS := { "back_starter_crest": 10 }
## Names of card backs 6+ (0-5 are named in Settings.CARD_BACKS).
const BACK_NAMES := { 6: "Gilded sun", 7: "Venetian glass", 8: "Opera night", 9: "Carnival gold", 10: "Starter's crest" }


static func item(id: String) -> Dictionary:
	for entry: Dictionary in ITEMS:
		if entry["id"] == id:
			return entry
	return {}


static func product(id: String) -> Dictionary:
	for entry: Dictionary in PRODUCTS:
		if entry["id"] == id:
			return entry
	return {}


## What `diamonds` are worth in real money at the base rate, e.g. "about $2.97".
static func money_value(diamonds: int) -> String:
	return "about $%.2f" % (diamonds / 100.0 * USD_PER_100_DIAMONDS)


## The same worth, short enough for the narrow card-back tiles ("≈$2.97").
static func money_value_short(diamonds: int) -> String:
	return "≈$%.2f" % (diamonds / 100.0 * USD_PER_100_DIAMONDS)


## The wallet id that owns card back `index`, or "" when the back is free.
static func back_id(index: int) -> String:
	for entry: Dictionary in ITEMS:
		if entry["kind"] == "card_back" and int(entry["back"]) == index:
			return str(entry["id"])
	for id: String in BUNDLE_BACKS:
		if int(BUNDLE_BACKS[id]) == index:
			return id
	return ""


static func back_unlocked(index: int, wallet: Wallet) -> bool:
	var id := back_id(index)
	return id == "" or wallet.owns(id)


## Whether `wallet` may buy the item now, and if not, why (in words).
static func why_not(entry: Dictionary, wallet: Wallet) -> String:
	if entry.is_empty():
		return "Not for sale."
	if entry["kind"] == "card_back" and wallet.owns(str(entry["id"])):
		return "Owned."
	if not wallet.can_afford(str(entry["currency"]), int(entry["price"])):
		return "Not enough %s." % entry["currency"]
	return ""


## Buy an in-game item with coins or diamonds. Returns "" on success or the reason.
static func buy(id: String, wallet: Wallet) -> String:
	var entry := item(id)
	var reason := why_not(entry, wallet)
	if reason != "":
		return reason
	if not wallet.spend(str(entry["currency"]), int(entry["price"])):
		return "Not enough %s." % entry["currency"]
	match str(entry["kind"]):
		"card_back":
			wallet.grant(id)
		"item":
			wallet.add_item(str(entry.get("item", id)), int(entry.get("count", 1)))
	return ""


## Deliver a real-money product the store has confirmed. Returns "" or the reason.
static func deliver(product_id: String, wallet: Wallet) -> String:
	var p := product(product_id)
	if p.is_empty():
		return "Unknown product."
	if bool(p.get("once", false)) and wallet.owns(product_id):
		return "Already bought."
	wallet.earn("diamonds", int(p.get("diamonds", 0)))
	for id: Variant in p.get("grant", []):
		wallet.grant(str(id))
	if bool(p.get("once", false)):
		wallet.grant(product_id)
	return ""
