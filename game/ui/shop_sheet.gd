class_name ShopSheet
extends Sheet
## The Shop: card backs, Encore tickets and bags of coins for coins or diamonds, and the
## real-money products (the Starter pack, No intermissions and diamonds). The wallet sits
## in the header and counts to its new balance after every purchase. Nothing sold here
## changes how a run plays and nothing is random, so there are no odds to disclose
## (core/shop_catalog.gd).
##
## Coins and diamonds are spent at once through ShopCatalog.buy. Diamonds take a second
## tap, because they usually cost real money and a stray tap shouldn't spend them.
## Real-money products go through Store.purchase, which waits on the store's own sheet,
## so every button locks while one is pending, and every step after an await first
## checks that this sheet is still open.

const TABS := ["featured", "backs", "diamonds"]
const TAB_NAMES := ["Featured", "Card backs", "Diamonds"]
## A second tap this soon after the first is the same double tap, not a decision.
const CONFIRM_MIN_MS := 350
const BACK_COLUMNS := 6
const BACK_TILE := Vector2(93, 118)
const BACK_CARD := Vector2(40, 56)
## Colour blocks, top-left to bottom-right, in the spirit of the item cards in a run.
const STARTER := [Color("ff5a8a"), Color("e0562a")]
const NO_ADS := [Color("2fc6b4"), Color("10708a")]
const PICK := [Color("a26bff"), Color("5a2fc1")]
const ENCORE := [Color("ff5a6e"), Color("a3152f")]
const COINS := [Color("f7a93b"), Color("c25a12")]
const GEMS_LOW := [Color("5b9dff"), Color("2f3fb8")]
const GEMS_HIGH := [Color("b46bff"), Color("4a1fa8")]
const GLASS_TILE := [Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.035)]

## The store request in progress ("" when none), shared by every Shop sheet. It is set and
## cleared by static coroutines, which keep running when a sheet is closed, so closing the
## Shop mid-purchase can neither leave the lock stuck nor let a second purchase start.
static var _store_busy := ""

var tab := 0
var _confirm_id := ""
var _confirm_at := 0
var _status_text := ""
var _status_colour := UiTheme.MUTED
var _status: Label
var _coins: Label
var _diamonds: Label
var _shown_coins := -1
var _shown_diamonds := -1


func _init(start_tab := "featured") -> void:
	tab = maxi(0, TABS.find(start_tab))
	title_text = "Shop"
	panel_size = Vector2(616, 350)


func _ready() -> void:
	super._ready()
	_add_wallet()
	Store.purchased.connect(_on_store_purchased)


## How many card backs there are: the free designs plus the Shop's (indices 0-10).
static func back_count() -> int:
	var last := Settings.CARD_BACKS.size() - 1
	for index: int in ShopCatalog.BACK_NAMES:
		last = maxi(last, index)
	return last + 1


## A card back's name. The catalog names backs 6 and up, Settings.CARD_BACKS the free
## ones, so this works whichever of the two lists is longer.
static func back_name(index: int) -> String:
	if ShopCatalog.BACK_NAMES.has(index):
		return str(ShopCatalog.BACK_NAMES[index])
	if index >= 0 and index < Settings.CARD_BACKS.size():
		return str(Settings.CARD_BACKS[index])
	return "Card back %d" % (index + 1)


## Day of the year for a YYYY-MM-DD date, 0 on 1 January.
static func day_of_year(date: String) -> int:
	var start := Time.get_unix_time_from_datetime_string(date.left(4) + "-01-01T12:00:00")
	var day := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return maxi(0, roundi((day - start) / 86400.0))


## Today's pick on the Featured tab. Walking the catalog from a start that moves one step
## a day, it is the first item the wallet can afford (owned card backs are skipped), so the
## pick is something the player can actually take. When nothing is affordable it is the
## first item still for sale, as something to save up for.
static func todays_pick(wallet: Wallet, date: String) -> Dictionary:
	var items := ShopCatalog.ITEMS
	var first := {}
	for step: int in items.size():
		var entry: Dictionary = items[(day_of_year(date) + step) % items.size()]
		if entry["kind"] == "card_back" and wallet.owns(str(entry["id"])):
			continue
		if first.is_empty():
			first = entry
		if wallet.can_afford(str(entry["currency"]), int(entry["price"])):
			return entry
	return first


func _build() -> void:
	body.add_child(UiTheme.segmented(TAB_NAMES, tab, _pick_tab, 10))
	var area := VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 6)
	body.add_child(area)
	match str(TABS[tab]):
		"featured":
			_build_featured(area)
		"backs":
			_build_backs(area)
		_:
			_build_diamonds(area)
	# The footer: what just happened (or a hint for the tab), and Restore purchases.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	_status = UiTheme.label("", 9, UiTheme.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(_status)
	_show_status()
	if Store.is_open():
		var restore := _text_button("Restore purchases", _restore)
		restore.disabled = _store_busy != ""
		foot.add_child(restore)
	body.add_child(foot)
	if not Settings.reduce_motion:
		area.modulate.a = 0.0
		area.create_tween().tween_property(area, "modulate:a", 1.0, 0.16)


# --- Featured --------------------------------------------------------------------


func _build_featured(area: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	area.add_child(row)
	var wallet := Game.wallet()
	var tiles := 0
	if not wallet.owns("dof.starter"):
		row.add_child(_starter_tile())
		tiles += 1
	if Store.is_open() and not wallet.owns("dof.remove_ads") and not wallet.owns("remove_ads"):
		row.add_child(_no_ads_tile())
		tiles += 1
	var pick := todays_pick(wallet, Economy.today())
	if not pick.is_empty():
		row.add_child(_pick_tile(pick))
		tiles += 1
	# Once the offers are bought, the row still leads somewhere.
	for target: String in ["backs", "diamonds"]:
		if tiles < 3:
			row.add_child(_promo_tile(target))
			tiles += 1


func _starter_tile() -> Control:
	var p := ShopCatalog.product("dof.starter")
	var tile := Tile.new(STARTER, 10.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_stretch_ratio = 1.45
	tile.col.add_theme_constant_override("separation", 4)
	tile.col.add_child(_tag("Once per player"))
	tile.col.add_child(UiTheme.title(str(p["name"]), 18, UiTheme.TEXT))
	# What's inside, read from the catalog, beside the card back that comes with it.
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	inside.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if int(p.get("diamonds", 0)) > 0:
		lines.add_child(_line(CurrencyIcon.new("diamonds", 14), "%s diamonds" % UiTheme.number(int(p["diamonds"]))))
	if int(p.get("coins", 0)) > 0:
		lines.add_child(_line(CurrencyIcon.new("coins", 14), "%s coins" % UiTheme.number(int(p["coins"]))))
	var extra: Dictionary = p.get("items", {})
	for id: String in extra:
		var count := int(extra[id])
		var item_name := str(ShopCatalog.item(id).get("name", id))
		lines.add_child(_line(ItemArt.new("ticket", 1, Vector2(16, 14)), "%d %s%s" % [count, item_name, "" if count == 1 else "s"]))
	var crest := -1
	for id: Variant in p.get("grant", []):
		if ShopCatalog.BUNDLE_BACKS.has(str(id)):
			crest = int(ShopCatalog.BUNDLE_BACKS[str(id)])
			lines.add_child(_line(_back_card(crest, Vector2(10, 14)), "%s card back" % back_name(crest)))
	inside.add_child(lines)
	if crest >= 0:
		var holder := CenterContainer.new()
		var card := _back_card(crest, Vector2(62, 86))
		card.rotation = 0.08
		holder.add_child(card)
		inside.add_child(holder)
	tile.col.add_child(inside)
	tile.col.add_child(_store_button("dof.starter"))
	return tile


func _no_ads_tile() -> Control:
	var p := ShopCatalog.product("dof.remove_ads")
	var tile := Tile.new(NO_ADS)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.col.add_theme_constant_override("separation", 4)
	tile.col.add_child(_tag("One-time"))
	var title := UiTheme.title(str(p["name"]), 15, UiTheme.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.col.add_child(title)
	tile.col.add_child(_wrap(str(p["text"]), 9, UiTheme.TEXT, 120))
	tile.col.add_child(_gap())
	tile.col.add_child(_store_button("dof.remove_ads"))
	return tile


func _pick_tile(entry: Dictionary) -> Control:
	var tile := Tile.new(PICK)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.col.add_theme_constant_override("separation", 4)
	tile.col.add_child(_tag("Today's pick"))
	tile.col.add_child(_centred(_art_for(entry, Vector2(64, 60))))
	var title := UiTheme.title(str(entry["name"]), 13, UiTheme.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.col.add_child(title)
	tile.col.add_child(_wrap(str(entry["text"]), 8, UiTheme.TEXT, 120))
	tile.col.add_child(_gap())
	tile.col.add_child(_price_row(entry))
	return tile


## When the offers are bought, these lead to the other tabs instead.
func _promo_tile(target: String) -> Control:
	var tile := Tile.new(GLASS_TILE)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.col.add_theme_constant_override("separation", 4)
	if target == "backs":
		var open_count := range(back_count()).filter(func(i: int) -> bool: return ShopCatalog.back_unlocked(i, Game.wallet())).size()
		tile.col.add_child(_tag("Card backs"))
		tile.col.add_child(_centred(_back_fan()))
		tile.col.add_child(UiTheme.title("Dress your deck", 13, UiTheme.TEXT))
		tile.col.add_child(_wrap("%d of %d designs unlocked. They only change the look." % [open_count, back_count()], 8, UiTheme.MUTED, 120))
		tile.col.add_child(_gap())
		tile.col.add_child(_small_button("Browse", _pick_tab.bind(1), 10, 22.0))
	else:
		tile.col.add_child(_tag("Diamonds"))
		tile.col.add_child(_centred(CurrencyIcon.new("diamonds", 44)))
		tile.col.add_child(UiTheme.title("Rare card backs", 13, UiTheme.TEXT))
		tile.col.add_child(_wrap("You hold %s diamonds. They buy looks, never an edge in a run." % UiTheme.number(Game.wallet().diamonds), 8, UiTheme.MUTED, 120))
		tile.col.add_child(_gap())
		tile.col.add_child(_small_button("See diamonds", _pick_tab.bind(TABS.find("diamonds")), 10, 22.0))
	return tile


## Three card backs the player hasn't got yet (or any three), fanned out.
func _back_fan() -> Control:
	var wanted: Array[int] = []
	for i: int in back_count():
		if not ShopCatalog.back_unlocked(i, Game.wallet()):
			wanted.append(i)
	for i: int in back_count():
		if wanted.size() >= 3:
			break
		if not wanted.has(i):
			wanted.append(i)
	var fan := Control.new()
	fan.custom_minimum_size = Vector2(84, 60)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: int in [0, 2, 1]:
		var card := _back_card(wanted[slot], Vector2(36, 50))
		card.position = Vector2(6 + slot * 18, 6 + absf(slot - 1) * 3.0)
		card.rotation = (slot - 1) * 0.2
		fan.add_child(card)
	return fan


# --- Card backs ------------------------------------------------------------------


func _build_backs(area: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = BACK_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	area.add_child(grid)
	for i: int in back_count():
		grid.add_child(_back_tile(i))


## One design: its card, its name, then what it costs or why it's yours, and what you can
## do with it (use it, buy it, or see the pack it comes in).
func _back_tile(index: int) -> Control:
	var id := ShopCatalog.back_id(index)
	var entry := ShopCatalog.item(id)
	var unlocked := ShopCatalog.back_unlocked(index, Game.wallet())
	var in_use := Settings.card_back == index
	var tile := Tile.new(GLASS_TILE, 5.0)
	tile.custom_minimum_size = BACK_TILE
	if in_use:
		tile.ring = UiTheme.GOLD
	tile.col.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.col.add_theme_constant_override("separation", 2)
	var holder := CenterContainer.new()
	var card := _back_card(index, BACK_CARD)
	if in_use:
		var tick := Check.new(14.0)
		tick.position = BACK_CARD - Vector2(10, 10)
		card.add_child(tick)
		# The card adds its face when it enters the tree; keep the tick above it.
		card.ready.connect(func() -> void: card.move_child(tick, -1))
	holder.add_child(card)
	tile.col.add_child(holder)
	var title := UiTheme.label(back_name(index), 9, UiTheme.TEXT)
	title.add_theme_font_override("font", UiTheme.bold)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.col.add_child(_centred(title))
	if unlocked:
		tile.col.add_child(_centred(UiTheme.label("Free" if id == "" else "Owned", 8, UiTheme.MUTED)))
		if in_use:
			tile.col.add_child(_in_use_pill())
		else:
			tile.col.add_child(_small_button("Use", _use_back.bind(index)))
	elif entry.is_empty():
		# Not sold alone: a link to the pack it comes in, over two lines (one is too narrow).
		var where := _text_button("In the Starter pack", _pick_tab.bind(0))
		where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		where.custom_minimum_size = Vector2(0, 30)
		tile.col.add_child(where)
	else:
		tile.col.add_child(_price(entry, 8, false))
		tile.col.add_child(_buy_button(entry, true))
	return tile


func _in_use_pill() -> Control:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(UiTheme.GOOD, 0.22), Color(UiTheme.GOOD, 0.6), 99)
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", box)
	pill.custom_minimum_size = Vector2(0, 18)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var tick := Check.new(10.0)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
	row.add_child(UiTheme.label("In use", 8, UiTheme.TEXT))
	pill.add_child(row)
	return pill


# --- Items -----------------------------------------------------------------------


func _build_diamonds(area: VBoxContainer) -> void:
	if not Store.is_open():
		area.add_child(_banner())
	elif Store.mode == "test":
		var ribbon := _tag("Test store: nothing is charged", UiTheme.GOLD, UiTheme.INK)
		ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		area.add_child(ribbon)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var packs := ShopCatalog.PRODUCTS.filter(func(p: Dictionary) -> bool: return p["kind"] == "diamonds")
	for i: int in packs.size():
		row.add_child(_diamond_tile(packs[i], i, packs.size()))
	area.add_child(row)


## Shown while the real-money store is closed (the "off" builds): friendly, and pointing to
## where diamonds come from meanwhile.
func _banner() -> Control:
	var panel := PanelContainer.new()
	var box := UiTheme.box(Color(UiTheme.GOLD, 0.14), Color(UiTheme.GOLD, 0.45), 12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := UiIcon.new("lock", UiTheme.GOLD)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var title := UiTheme.label("The diamond store opens soon", 10, UiTheme.TEXT)
	title.add_theme_font_override("font", UiTheme.bold)
	row.add_child(title)
	var more := UiTheme.label("Until then, diamonds come with the daily gift.", 9, UiTheme.MUTED)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.clip_text = true
	more.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(more)
	panel.add_child(row)
	return panel


func _diamond_tile(p: Dictionary, tier: int, tiers: int) -> Control:
	# Richer colour and a bigger heap for bigger packs.
	var k := tier / maxf(1.0, tiers - 1.0)
	var tile := Tile.new([(GEMS_LOW[0] as Color).lerp(GEMS_HIGH[0], k), (GEMS_LOW[1] as Color).lerp(GEMS_HIGH[1], k)], 8.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.col.add_theme_constant_override("separation", 2)
	tile.col.add_child(_centred(ItemArt.new("diamonds", tier + 1, Vector2(70, 58))))
	tile.col.add_child(_centred(UiTheme.title(UiTheme.number(int(p["diamonds"])), 18, UiTheme.TEXT)))
	var title := UiTheme.label(str(p["name"]), 9, UiTheme.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(80, 0)
	tile.col.add_child(_centred(title))
	var bonus := RegEx.create_from_string("\\+\\s*([\\d,]+)\\s*bonus").search(str(p.get("text", "")))
	if bonus != null:
		var tag := _tag("+%s bonus" % bonus.get_string(1), UiTheme.GOLD, UiTheme.INK)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.col.add_child(tag)
	tile.col.add_child(_gap())
	tile.col.add_child(_store_button(str(p["id"])))
	return tile


# --- Buying ----------------------------------------------------------------------


## Buy an item with coins or diamonds. Diamonds need a second tap: the first only arms the
## button and says what it will cost.
func _buy(id: String) -> void:
	if _store_busy != "":
		return
	var entry := ShopCatalog.item(id)
	var wallet := Game.wallet()
	var reason := ShopCatalog.why_not(entry, wallet)
	if reason != "":
		_fail(reason)
		return
	if str(entry["currency"]) == "diamonds":
		var now := Time.get_ticks_msec()
		if _confirm_id != id:
			_confirm_id = id
			_confirm_at = now
			Feel.play("select")
			_set_status("Tap again to spend %s diamonds on %s." % [UiTheme.number(int(entry["price"])), entry["name"]], UiTheme.GOLD)
			rebuild()
			return
		if now - _confirm_at < CONFIRM_MIN_MS:
			return
	_confirm_id = ""
	reason = ShopCatalog.buy(id, wallet)
	if reason != "":
		_fail(reason)
		return
	Game.save_profile()
	Feel.play("buy")
	Feel.buzz(15)
	_set_status(_bought_words(entry), UiTheme.GOOD)
	_refresh_wallet()
	rebuild()


func _bought_words(entry: Dictionary) -> String:
	match str(entry["kind"]):
		"card_back":
			return "%s is yours. Tap Use to play with it." % entry["name"]
		"coins":
			return "Added %s coins." % UiTheme.number(int(entry["amount"]))
	var held := Game.wallet().item_count(str(entry.get("item", entry["id"])))
	return "Added %s. You hold %d." % [str(entry["name"]) if int(entry.get("count", 1)) > 1 else "an Encore ticket", held]


## Buy a real-money product through the store (the test store's sheet in "test" builds).
func _buy_product(id: String) -> void:
	if _store_busy != "" or not Store.is_open():
		return
	_confirm_id = ""
	_set_status("Waiting for the store…", UiTheme.MUTED)
	var reason: String = await _store_purchase(id)
	if not _alive():
		return
	if reason == "":
		Feel.buzz(30)
		_set_status(_delivered_words(id), UiTheme.GOOD)
	elif reason == "Cancelled.":
		_set_status("Cancelled. Nothing was charged.", UiTheme.MUTED)
	else:
		_fail(reason, false)
	_refresh_wallet()
	rebuild()


## Runs Store.purchase from a static coroutine, which isn't tied to this sheet, so the
## lock always clears. Rebuilding the open Shop sheets shows the lock (and its release)
## at once, also in a Shop reopened while the store was busy.
static func _store_purchase(id: String) -> String:
	_store_busy = id
	_refresh_open_sheets()
	var reason: String = await Store.purchase(id)
	_store_busy = ""
	_refresh_open_sheets()
	return reason


static func _store_restore() -> String:
	_store_busy = "restore"
	_refresh_open_sheets()
	var reason: String = await Store.restore()
	_store_busy = ""
	_refresh_open_sheets()
	return reason


static func _refresh_open_sheets() -> void:
	if UiTheme.sheet_host == null:
		return
	for child: Node in UiTheme.sheet_host.get_children():
		if child is ShopSheet and not child.is_queued_for_deletion():
			(child as ShopSheet).rebuild()


func _delivered_words(id: String) -> String:
	var p := ShopCatalog.product(id)
	match str(p.get("kind", "")):
		"diamonds":
			return "Added %s diamonds. Thank you!" % UiTheme.number(int(p["diamonds"]))
		"unlock":
			return "No more intermissions. Thank you for supporting the troupe!"
	return "%s added. Thank you!" % p.get("name", "Your purchase")


func _restore() -> void:
	if _store_busy != "":
		return
	_set_status("Checking your purchases…", UiTheme.MUTED)
	var reason: String = await _store_restore()
	if not _alive():
		return
	if reason == "":
		Feel.play("click")
		_set_status("Your purchases are restored.", UiTheme.GOOD)
	else:
		_fail(reason, false)
	_refresh_wallet()
	rebuild()


func _use_back(index: int) -> void:
	if Settings.card_back == index or not ShopCatalog.back_unlocked(index, Game.wallet()):
		return
	Settings.card_back = index
	Settings.save()
	# Every baked card face shows the old back: drop them so they bake again, and let the
	# screens behind rebuild (the menu and the run screen listen for this).
	CardArt.clear()
	Feel.play("select")
	Feel.buzz(8)
	Feel.settings_changed.emit()
	_set_status("%s is your card back now." % back_name(index), UiTheme.GOOD)
	rebuild()


func _fail(reason: String, rebuild_after := true) -> void:
	_confirm_id = ""
	Feel.play("error")
	Feel.buzz(20)
	_set_status(reason, UiTheme.MULT.lightened(0.35))
	if rebuild_after:
		rebuild()


func _pick_tab(index: int) -> void:
	if index == tab:
		return
	Feel.play("select")
	tab = index
	_confirm_id = ""
	_status_text = ""
	rebuild()


func _on_store_purchased(_product_id: String) -> void:
	if _alive():
		_refresh_wallet()


func _alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Like Sheet.rebuild, but the old content leaves the tree at once. Waiting to be freed it
## would still count toward the panel's minimum size for a frame, and if the panel moves
## in that frame (its slide-in) it keeps the taller size and runs off the screen.
func rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_build()
	heading.text = title_text


func _set_status(text: String, colour: Color) -> void:
	_status_text = text
	_status_colour = colour
	_show_status()


func _show_status() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = _status_text if _status_text != "" else _hint()
	_status.add_theme_color_override("font_color", _status_colour if _status_text != "" else UiTheme.MUTED)


## A line about the tab, for when nothing has happened yet.
func _hint() -> String:
	match str(TABS[tab]):
		"featured":
			return "Coins come from winning shows. Nothing here changes how a run plays."
		"backs":
			return "Card backs only change the look of your cards."
	return "100 diamonds cost $0.99. They buy rare card backs, never an edge in a run."


# --- The wallet in the header ----------------------------------------------------


func _add_wallet() -> void:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(0, 0, 0, 0.32), UiTheme.TONAL_EDGE, 99)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	var coins := UiTheme.currency("coins", 0, 11)
	var gems := UiTheme.currency("diamonds", 0, 11)
	row.add_child(coins)
	row.add_child(gems)
	_coins = coins.get_child(1) as Label
	_diamonds = gems.get_child(1) as Label
	var top := heading.get_parent()
	top.add_child(pill)
	top.move_child(pill, heading.get_index() + 1)
	var space := Control.new()
	space.custom_minimum_size = Vector2(4, 0)
	top.add_child(space)
	top.move_child(space, pill.get_index() + 1)
	_refresh_wallet(false)


## Show the wallet's balances, counting to them from what was shown before.
func _refresh_wallet(animate := true) -> void:
	var w := Game.wallet()
	_count(_coins, _shown_coins, w.coins, animate)
	_count(_diamonds, _shown_diamonds, w.diamonds, animate)
	_shown_coins = w.coins
	_shown_diamonds = w.diamonds


func _count(label: Label, from: int, to: int, animate: bool) -> void:
	if label == null or not is_instance_valid(label):
		return
	if not animate or from < 0 or from == to or Settings.reduce_motion:
		label.text = UiTheme.number(to)
		return
	var roll := label.create_tween()
	roll.tween_method(func(v: float) -> void: label.text = UiTheme.number(roundi(v)), float(from), float(to), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label.pivot_offset = label.size / 2.0
	var pop := label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector2(1.18, 1.18), 0.08)
	pop.tween_property(label, "scale", Vector2.ONE, 0.22)


# --- Small parts -----------------------------------------------------------------


func _back_card(index: int, card_size: Vector2) -> CardView:
	var card := CardView.new(card_size)
	card.face_down = true
	card.back_style = index
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## The picture for an item: its card back, Encore tickets, or a heap of coins.
func _art_for(entry: Dictionary, art_size: Vector2) -> Control:
	match str(entry["kind"]):
		"card_back":
			var holder := CenterContainer.new()
			holder.custom_minimum_size = art_size
			holder.add_child(_back_card(int(entry["back"]), Vector2(roundf(art_size.y * 0.72), art_size.y)))
			return holder
		"coins":
			return ItemArt.new("coins", 3 if int(entry.get("amount", 0)) < 1000 else 5, art_size)
	return ItemArt.new("ticket", int(entry.get("count", 1)), art_size)


## The price of an item in coins or diamonds; red when the wallet is short (on glass).
func _price(entry: Dictionary, font_size: int, on_colour: bool) -> Control:
	var short := not Game.wallet().can_afford(str(entry["currency"]), int(entry["price"]))
	var colour := UiTheme.TEXT if on_colour or not short else UiTheme.MULT.lightened(0.35)
	var row := UiTheme.currency(str(entry["currency"]), int(entry["price"]), font_size, colour)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Diamond prices show what they are worth in money at the base rate (EU CPC rules).
	if str(entry["currency"]) == "diamonds":
		var worth := UiTheme.label("(" + ShopCatalog.money_value(int(entry["price"])) + ")", maxi(8, font_size - 3), UiTheme.TEXT if on_colour else UiTheme.MUTED)
		worth.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(worth)
	return row


## A price and a Buy button side by side, for the wider tiles.
func _price_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var price := _price(entry, 11, true)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price)
	var buy := _buy_button(entry)
	buy.custom_minimum_size = Vector2(64, 24)
	row.add_child(buy)
	return row


func _buy_button(entry: Dictionary, compact := false) -> Button:
	var armed := _confirm_id == str(entry["id"])
	var b := _small_button("Tap again" if armed else "Buy", _buy.bind(str(entry["id"])), 9 if compact else 10, 18.0 if compact else 22.0, UiTheme.GOLD if armed else UiTheme.TEXT)
	b.disabled = _store_busy != ""
	return b


## A real-money product's button: its price from the store, "Soon" while the store is
## closed, and locked while any store request is pending.
func _store_button(id: String) -> Button:
	var price := Store.price_text(id)
	var text := "Waiting…" if _store_busy == id else (price if price != "" else "Buy")
	var b := _small_button(text, _buy_product.bind(id), 11, 26.0, UiTheme.TEXT)
	b.disabled = not Store.is_open() or _store_busy != ""
	return b


func _small_button(text: String, on_press: Callable, font_size := 9, height := 18.0, colour := UiTheme.PANEL_LIGHT) -> Button:
	var b := UiTheme.button(text, on_press, font_size, colour)
	b.custom_minimum_size = Vector2(0, height)
	b.clip_text = true
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var st := b.get_theme_stylebox(state) as StyleBoxFlat
		if st != null:
			st.content_margin_left = 6
			st.content_margin_right = 6
			st.content_margin_top = 1
			st.content_margin_bottom = 1
	return b


func _text_button(text: String, on_press: Callable) -> Button:
	var b := UiTheme.button(text, on_press, 9)
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 4
	none.content_margin_right = 4
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, none)
	b.add_theme_color_override("font_color", UiTheme.GOLD)
	b.add_theme_color_override("font_hover_color", UiTheme.GOLD.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD.darkened(0.15))
	return b


## A small pill label, white glass by default.
func _tag(text: String, bg := Color(1, 1, 1, 0.22), fg := UiTheme.TEXT) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.box(bg, Color(1, 1, 1, 0.28) if bg.a < 1.0 else bg, 99)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := UiTheme.label(text, 8, fg)
	l.add_theme_font_override("font", UiTheme.bold)
	if fg.get_luminance() < 0.5:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	pill.add_child(l)
	return pill


## An icon and a bold line of text. The icon sits centred in a fixed slot, so the lines
## of a list align (and a small card keeps the size its face was drawn at).
func _line(icon: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(16, 14)
	slot.add_child(icon)
	row.add_child(slot)
	var l := UiTheme.label(text, 10, UiTheme.TEXT)
	l.add_theme_font_override("font", UiTheme.bold)
	row.add_child(l)
	return row


func _wrap(text: String, font_size: int, colour: Color, width: float) -> Label:
	var l := UiTheme.label(text, font_size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _gap() -> Control:
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _centred(c: Control) -> Control:
	if c is Label:
		(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return c
	if c is BoxContainer:
		(c as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		return c
	var holder := CenterContainer.new()
	holder.add_child(c)
	return holder


## A colour-blocked tile: a diagonal gradient in a rounded rectangle with a soft shadow, a
## sheen on top and a fine light edge (or a ring, e.g. round the card back in use). Its
## children go in `col`, inside the margin.
class Tile extends PanelContainer:
	var col := VBoxContainer.new()
	var top_colour := Color.WHITE
	var bottom_colour := Color.WHITE
	var ring := Color(0, 0, 0, 0)
	var radius := 12.0

	func _init(colours: Array, margin := 9.0) -> void:
		top_colour = colours[0]
		bottom_colour = colours[1]
		var pad := StyleBoxEmpty.new()
		pad.set_content_margin_all(margin)
		add_theme_stylebox_override("panel", pad)
		col.add_theme_constant_override("separation", 3)
		add_child(col)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0)
		shadow.set_corner_radius_all(roundi(radius))
		shadow.shadow_color = Color(0, 0, 0, 0.26 * top_colour.a if top_colour.a < 1.0 else 0.28)
		shadow.shadow_size = 6
		shadow.shadow_offset = Vector2(0, 3)
		draw_style_box(shadow, r)
		var outline := Paint.round_rect(r, radius, 8)
		var fill := PackedColorArray()
		var sheen := PackedColorArray()
		for p: Vector2 in outline:
			var t := clampf((p.x / maxf(1.0, r.size.x) + p.y / maxf(1.0, r.size.y)) / 2.0, 0.0, 1.0)
			fill.append(top_colour.lerp(bottom_colour, t))
			sheen.append(Color(1, 1, 1, 0.12 * clampf(1.0 - p.y / maxf(1.0, r.size.y * 0.55), 0.0, 1.0)))
		draw_polygon(outline, fill)
		draw_polygon(outline, sheen)
		if ring.a > 0.0:
			draw_polyline(Paint.closed(outline), ring, 2.0, true)
		else:
			draw_polyline(Paint.closed(outline), Color(1, 1, 1, 0.16), 1.0, true)


## A round green tick: the card back in use.
class Check extends Control:
	func _init(diameter: float) -> void:
		custom_minimum_size = Vector2(diameter, diameter)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_circle(c + Vector2(0, 1), r, Color(0, 0, 0, 0.3), true, -1.0, true)
		draw_circle(c, r, UiTheme.GOOD, true, -1.0, true)
		var k := r / 7.0
		var mark := PackedVector2Array([c + Vector2(-3.3, 0.2) * k, c + Vector2(-1.0, 2.7) * k, c + Vector2(3.5, -2.5) * k])
		draw_polyline(mark, Color.WHITE, maxf(1.2, 1.6 * k), true)


## A small picture drawn in code: Encore tickets fanned out, or a heap of coins or diamonds
## that grows with the amount (the heaps are CurrencyIcons, so they match the wallet).
class ItemArt extends Control:
	## Where each coin or gem of a heap sits: x and y as a share of the picture, then its
	## size as a share of the smaller side. The last one is drawn in front.
	const HEAPS := [
		[Vector3(0.5, 0.52, 0.74)],
		[Vector3(0.62, 0.4, 0.56), Vector3(0.4, 0.6, 0.62)],
		[Vector3(0.3, 0.4, 0.5), Vector3(0.7, 0.4, 0.5), Vector3(0.5, 0.62, 0.58)],
		[Vector3(0.5, 0.28, 0.44), Vector3(0.24, 0.52, 0.46), Vector3(0.76, 0.52, 0.46), Vector3(0.5, 0.66, 0.54)],
		[Vector3(0.3, 0.3, 0.4), Vector3(0.7, 0.3, 0.4), Vector3(0.18, 0.62, 0.42), Vector3(0.82, 0.62, 0.42), Vector3(0.5, 0.6, 0.56)],
	]

	var kind := "ticket"
	var count := 1

	func _init(art_kind: String, how_many: int, art_size: Vector2) -> void:
		kind = art_kind
		count = clampi(how_many, 1, HEAPS.size())
		custom_minimum_size = art_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "ticket":
			return
		var side := minf(art_size.x, art_size.y)
		for spot: Vector3 in HEAPS[count - 1]:
			var piece := CurrencyIcon.new(kind, roundf(side * spot.z))
			piece.position = Vector2(art_size.x * spot.x, art_size.y * spot.y) - piece.size / 2.0
			add_child(piece)

	func _draw() -> void:
		if kind != "ticket":
			return
		var w := minf(size.x * 0.82, size.y * 1.5)
		var h := w * 0.56
		for i: int in count:
			var shift := i - (count - 1) / 2.0
			draw_set_transform(size / 2.0 + Vector2(shift * w * 0.16, -shift * h * 0.12), -shift * 0.2, Vector2.ONE)
			_ticket(Rect2(-w / 2.0, -h / 2.0, w, h))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## One ticket: a red stub with a star, a dashed tear line and ENCORE on cream.
	func _ticket(r: Rect2) -> void:
		var corner := r.size.y * 0.18
		draw_colored_polygon(Paint.round_rect(Rect2(r.position + Vector2(0, maxf(1.0, r.size.y * 0.06)), r.size), corner), Color(0, 0, 0, 0.28))
		draw_colored_polygon(Paint.round_rect(r, corner), Color("fff4dc"))
		var stub_w := r.size.x * 0.3
		draw_colored_polygon(Paint.round_rect(Rect2(r.position, Vector2(stub_w, r.size.y)), corner), UiTheme.MULT)
		draw_rect(Rect2(r.position + Vector2(stub_w * 0.5, 0), Vector2(stub_w * 0.5, r.size.y)), UiTheme.MULT)
		var tear := r.position.x + stub_w
		var dashes := 5
		for k: int in dashes:
			var y0 := r.position.y + r.size.y * (k + 0.25) / dashes
			draw_line(Vector2(tear, y0), Vector2(tear, y0 + r.size.y * 0.5 / dashes), Color(UiTheme.MULT, 0.6), maxf(0.8, r.size.y * 0.04), true)
		var star := PackedVector2Array()
		var c := r.position + Vector2(stub_w * 0.5, r.size.y * 0.5)
		for k: int in 10:
			var a := -PI / 2.0 + k * PI / 5.0
			star.append(c + Vector2(cos(a), sin(a)) * r.size.y * (0.26 if k % 2 == 0 else 0.11))
		draw_colored_polygon(star, Color("fff4dc"))
		var font_px := maxi(5, roundi(r.size.y * 0.3))
		if r.size.x - stub_w > font_px * 3.6:
			var word := "ENCORE"
			var tw := UiTheme.bold.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
			var left := tear + (r.end.x - tear - tw) / 2.0
			draw_string(UiTheme.bold, Vector2(left, c.y + font_px * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, UiTheme.INK)
