class_name EncorePanel
extends PanelContainer
## The Encore, offered in place of the run-over screen when a show is lost and the run
## may still play on (Game.encore_open()). It says how close the show was and what an
## Encore gives, then the ways to take it: a rewarded ad when one may play, and coins,
## always shown with the price and the player's balance (greyed out when they can't be
## afforded), so the cost is never a surprise. In the guided first run the Encore is
## free instead: one button, to teach the idea. Never diamonds or money: straight after
## a loss is the worst moment to sell something (docs/MONETIZATION.md). "No thanks"
## ends the run.
## There's no countdown and nothing flashing: the offer waits for as long as the player
## likes, and even survives closing the app, because the lost run stays saved until it
## is decided. Spending coins takes a second tap ("Tap again"), and a moment's pause
## after that first tap, so a double tap can't spend them. This panel only shows the
## offer; RunScreen does the paying (chose) and the declining (declined), and holds
## taps while the panel appears (RunScreen.hold_taps).

signal chose(paid_with: String)
signal declined

const WIDTH := 404.0

var run: RunState
## Why the last try at taking the Encore didn't work, or "".
var note := ""
## The coins were tapped once: the next tap on them pays.
var _confirming := false
## Holds the ways to take the Encore, rebuilt when the coins ask for their second tap.
var _options: VBoxContainer


func _init(lost_run: RunState, why_not := "") -> void:
	run = lost_run
	note = why_not


## What AdPolicy needs to know about this run before the Encore's ad may play.
static func ad_context(lost_run: RunState) -> Dictionary:
	return { "encore_used": lost_run.encores() > 0, "ranked_daily": Game.is_ranked_daily() }


## Whether this run would lose its place on the leaderboards: tour and challenge runs
## are ranked (Game.finish_run); quick runs, boss rushes and daily practice never are.
static func costs_rank(lost_run: RunState) -> bool:
	return lost_run.mode == "tour" and not bool(Game.run_meta.get("practice", false))


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	var style := UiTheme.panel_box(UiTheme.PANEL, UiTheme.MULT)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	col.add_child(RunCoins.tag("Town %d  ·  %s" % [run.town, RunScreen.SHOW_NAMES[run.show_index]], UiTheme.MULT))
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.add_child(_centred(UiTheme.title("Encore?", 28, UiTheme.GOLD)))
	heading.add_child(_centred(UiTheme.label("The crowd wants more.", 12, UiTheme.TEXT)))
	col.add_child(heading)
	col.add_child(_facts())
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 1)
	col.add_child(_options)
	_build_options()
	if note != "":
		var why := _centred(UiTheme.label(note, 10, UiTheme.MULT.lightened(0.4)))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
		col.add_child(why)
	var no := UiTheme.button("No thanks", declined.emit, 11, UiTheme.TONAL)
	no.custom_minimum_size = Vector2(170, 26)
	no.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(no)
	if costs_rank(run):
		col.add_child(_footnote("lock", "An Encore makes this run unranked."))
	var free := Game.encore_free()
	var ad := not free and Ads.can_offer("encore", ad_context(run))
	if not free and not ad and not Game.wallet().can_afford("coins", Economy.ENCORE_COINS):
		col.add_child(_footnote("", "Win shows to earn coins: %s buy an Encore." % UiTheme.number(Economy.ENCORE_COINS)))


## Two tiles: how far short the show fell, and what an Encore adds to it.
func _facts() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var short := ceilf(maxf(0.0, run.show_target - run.show_score))
	var gap := UiTheme.title(UiTheme.number(short), 18, UiTheme.MULT.lightened(0.35))
	row.add_child(_tile(UiTheme.MULT, gap, "points short of %s" % UiTheme.number(run.show_target)))
	var gives := HBoxContainer.new()
	gives.add_theme_constant_override("separation", 8)
	gives.add_child(UiTheme.title(_more(Economy.ENCORE_HANDS, "hand"), 16, UiTheme.POINTS.lightened(0.35)))
	gives.add_child(UiTheme.title(_more(Economy.ENCORE_DISCARDS, "discard"), 16, UiTheme.MULT.lightened(0.35)))
	row.add_child(_tile(UiTheme.POINTS, gives, "and your score of %s stays" % UiTheme.number(run.show_score)))
	return row


func _more(count: int, what: String) -> String:
	return "+%d %s%s" % [count, what, "" if count == 1 else "s"]


## A tinted tile, colour-blocked like the counters beside the board.
func _tile(colour: Color, top: Control, caption: String) -> PanelContainer:
	var tile := PanelContainer.new()
	var style := UiTheme.box(Color(colour, 0.2), Color(colour.lightened(0.2), 0.5), 12)
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	tile.add_theme_stylebox_override("panel", style)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	tile.add_child(col)
	top.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(top)
	col.add_child(_centred(UiTheme.label(caption, 9, UiTheme.MUTED)))
	return tile


## The ways to take the Encore. In the guided first run, one free button. Otherwise a
## rewarded ad (only when AdPolicy allows one) beside the coins.
func _build_options() -> void:
	# Hidden at once (the coins button being replaced is still mid-press), freed later.
	for child in _options.get_children():
		(child as Control).hide()
		child.queue_free()
	if Game.encore_free():
		var gift := UiIcon.new("gift", UiTheme.INK)
		gift.custom_minimum_size = Vector2(14, 14)
		_options.add_child(_wide(RunCoins.glyph_button(gift, "Take the Encore", chose.emit.bind("free"), 12, UiTheme.GOLD)))
		_options.add_child(_centred(UiTheme.label("Free in your first run", 9, UiTheme.MUTED)))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_options.add_child(row)
	if Ads.can_offer("encore", ad_context(run)):
		var play := UiIcon.new("play", UiTheme.TEXT)
		play.custom_minimum_size = Vector2(14, 14)
		var watch := _wide(RunCoins.glyph_button(play, "Watch an ad", chose.emit.bind("ad"), 11, UiTheme.POINTS))
		watch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(watch)
	row.add_child(_coins_option())


## The coins, with the player's balance under them. The first tap asks for a second.
func _coins_option() -> VBoxContainer:
	var wallet := Game.wallet()
	var can_pay := wallet.can_afford("coins", Economy.ENCORE_COINS)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var price := UiTheme.number(Economy.ENCORE_COINS)
	var text := "Tap again: %s coins" % price if _confirming else "%s coins" % price
	var colour := UiTheme.GOLD.darkened(0.35) if _confirming else UiTheme.TONAL
	col.add_child(_wide(RunCoins.glyph_button(CurrencyIcon.new("coins", 14.0), text, _on_coins, 11, colour, can_pay)))
	var has := UiTheme.label("You have %s" % UiTheme.number(wallet.coins), 9, UiTheme.MUTED if can_pay else UiTheme.MULT.lightened(0.4))
	col.add_child(_centred(has))
	return col


## Coins are spent on the second tap only. After the first, the panel waits a moment
## before it takes taps again, so a quick double tap doesn't count as both.
func _on_coins() -> void:
	if not _confirming:
		Feel.play("select")
		_confirming = true
		_build_options()
		RunScreen.hold_taps(self)
		return
	chose.emit("coins")


func _footnote(glyph: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	if glyph != "":
		var icon := UiIcon.new(glyph, UiTheme.MUTED)
		icon.custom_minimum_size = Vector2(11, 11)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	row.add_child(UiTheme.label(text, 9, UiTheme.MUTED))
	return row


func _wide(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 28
	return b


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
