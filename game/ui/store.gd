extends Node
## Real-money purchases (ShopCatalog.PRODUCTS) through the platform store. Once the
## store confirms a purchase, ShopCatalog.deliver puts it in the wallet.
## In "test" mode PurchaseSheet stands in for the store and charges nothing; in "off"
## mode the store is closed; connect App Store / web checkout in _buy_live and
## _restore_live (docs/MONETIZATION.md).

signal purchased(product_id: String)

var mode := "off"


func _ready() -> void:
	mode = Monetization.mode()


func is_open() -> bool:
	return mode != "off"


func price_text(product_id: String) -> String:
	var p := ShopCatalog.product(product_id)
	if p.is_empty():
		return ""
	match mode:
		"test":
			return "$%.2f" % float(p["usd"])
		"live":
			return _live_price(product_id)
	return "Soon"


## Buy a product. Returns "" when it was bought and delivered, otherwise the reason.
func purchase(product_id: String) -> String:
	var p := ShopCatalog.product(product_id)
	if p.is_empty():
		return "Unknown product."
	if mode == "off":
		return "The store opens soon."
	var wallet: Wallet = Game.profile.wallet
	if bool(p.get("once", false)) and wallet.owns(product_id):
		return "Already bought."
	var transaction := ""
	match mode:
		"test":
			var sheet := PurchaseSheet.new(p, price_text(product_id))
			UiTheme.show_sheet(sheet)
			var confirmed: bool = await sheet.done
			if not confirmed:
				return "Cancelled."
			transaction = "test-%d" % Time.get_ticks_usec()
		"live":
			transaction = await _buy_live(product_id)
			if transaction == "":
				return "The purchase didn't go through."
	var reason := ShopCatalog.deliver(product_id, wallet)
	if reason != "":
		return reason
	wallet.log_purchase(product_id, mode, mode == "test", transaction)
	Game.save_profile()
	Ads.last_purchase = Ads.now()
	Feel.play("jackpot")
	purchased.emit(product_id)
	return ""


## Restore non-consumables (No intermissions, the Starter pack) on a new device.
## In test mode they already live in the (cloud-saved) profile.
func restore() -> String:
	match mode:
		"test":
			return ""
		"live":
			return await _restore_live()
	return "The store opens soon."


## Hooks for the real store (StoreKit 2 through a Godot iOS plugin; a Stripe checkout
## through the API for the web). The live version must validate the receipt on the
## server before crediting diamonds.
func _live_price(_product_id: String) -> String:
	return ""


func _buy_live(product_id: String) -> String:
	await get_tree().process_frame
	push_warning("Store: no live store connected (%s)" % product_id)
	return ""


func _restore_live() -> String:
	await get_tree().process_frame
	return "The store isn't connected yet."
