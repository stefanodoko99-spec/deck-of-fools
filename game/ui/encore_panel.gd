class_name EncorePanel
extends PanelContainer
## The Encore, offered in place of the run-over screen when a show is lost and the run
## may still play on (Game.encore_open()). It says how close the show was and what an
## Encore gives, then the ways to pay: a rewarded ad and an Encore ticket when they can
## be used, and diamonds and coins always, greyed out with the balance when they can't
## be afforded, so the price is never a surprise. "No thanks" ends the run.
## There's no countdown and nothing flashing: the offer waits for as long as the player
## likes, and even survives closing the app, because the lost run stays saved until it
## is decided. This panel only shows the offer; RunScreen does the paying (chose) and
## the declining (declined).

signal chose(paid_with: String)
signal declined

const WIDTH := 404.0

var run: RunState
## Why the last try at paying didn't work, or "".
var note := ""


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
	var at_no_cost := _free_options()
	var has_free_way := at_no_cost.get_child_count() > 0
	if has_free_way:
		col.add_child(at_no_cost)
	else:
		at_no_cost.free()
	var wallet := Game.profile.wallet
	var affordable := wallet.can_afford("diamonds", Economy.ENCORE_DIAMONDS) or wallet.can_afford("coins", Economy.ENCORE_COINS)
	col.add_child(_paid_options())
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
	if not has_free_way and not affordable:
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


## The ways that cost nothing now: a rewarded ad (only when AdPolicy allows one) and an
## Encore ticket (only when the player holds one).
func _free_options() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if Ads.can_offer("encore", ad_context(run)):
		var play := UiIcon.new("play", UiTheme.TEXT)
		play.custom_minimum_size = Vector2(14, 14)
		row.add_child(_wide(RunCoins.glyph_button(play, "Watch an ad", chose.emit.bind("ad"), 11, UiTheme.POINTS)))
	var tickets := Game.profile.wallet.item_count("encore_ticket")
	if tickets > 0:
		var colour := UiTheme.GOLD.darkened(0.25)
		var ticket := TicketGlyph.new(UiTheme.INK if colour.get_luminance() > 0.55 else UiTheme.TEXT)
		row.add_child(_wide(RunCoins.glyph_button(ticket, "Use a ticket (%d left)" % tickets, chose.emit.bind("ticket"), 11, colour)))
	return row


## Diamonds and coins, side by side, each with the player's balance under it.
func _paid_options() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_price("diamonds", Economy.ENCORE_DIAMONDS))
	row.add_child(_price("coins", Economy.ENCORE_COINS))
	return row


func _price(currency: String, price: int) -> VBoxContainer:
	var wallet := Game.profile.wallet
	var can_pay := wallet.can_afford(currency, price)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var text := "%s %s" % [UiTheme.number(price), currency]
	col.add_child(_wide(RunCoins.glyph_button(CurrencyIcon.new(currency, 14.0), text, chose.emit.bind(currency), 11, UiTheme.TONAL, can_pay)))
	var has := UiTheme.label("You have %s" % UiTheme.number(wallet.balance(currency)), 9, UiTheme.MUTED if can_pay else UiTheme.MULT.lightened(0.4))
	col.add_child(_centred(has))
	return col


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


## A small ticket drawn like the line icons (UiIcon): notched sides and a perforation.
class TicketGlyph extends Control:
	var colour := Color.WHITE

	func _init(tint: Color, side := 14.0) -> void:
		colour = tint
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		var w := maxf(1.2, s * 0.09)
		var outline := PackedVector2Array([o + Vector2(0.08, 0.26) * s, o + Vector2(0.92, 0.26) * s])
		# The right side's notch, bowing inwards, then the left side's on the way back.
		for i in 9:
			var a := -PI / 2.0 - PI * i / 8.0
			outline.append(o + (Vector2(0.92, 0.5) + Vector2(cos(a), sin(a)) * 0.11) * s)
		outline.append(o + Vector2(0.92, 0.74) * s)
		outline.append(o + Vector2(0.08, 0.74) * s)
		for i in 9:
			var a := PI / 2.0 - PI * i / 8.0
			outline.append(o + (Vector2(0.08, 0.5) + Vector2(cos(a), sin(a)) * 0.11) * s)
		outline.append(o + Vector2(0.08, 0.26) * s)
		draw_polyline(outline, colour, w, true)
		for y: float in [0.33, 0.47, 0.61]:
			draw_line(o + Vector2(0.64, y) * s, o + Vector2(0.64, y + 0.07) * s, colour, w, true)
