class_name RunCoins
extends PanelContainer
## The coins a won show paid, on the cash-out screen beside the ducats. Ducats are
## spent in the Market and gone when the run ends; coins stay with the player for good
## (card backs, Encores), so they get a card of their own: the amount with the coin
## symbol, the player's balance and, when an ad may double them, an optional Double
## coins button. RunScreen plays the ad (double_pressed); Cash out never waits on it.
## Also holds the small coin pieces the run's other screens share: the coins-this-run
## chip of the end screens, pill buttons that lead with a symbol, and the count-up.

signal double_pressed

## What the show paid: { show, coins, doubled } (Game.run_meta["show_coins"]).
var paid: Dictionary
## The run-win bonus, shown on the cash-out of the show that won the whole run.
var bonus := 0
var offer_double := false
## { show, balance }: the numbers to count up from, right after the coins doubled.
var count_from: Dictionary


func _init(show_paid: Dictionary, win_bonus := 0, can_double := false, roll_from := {}) -> void:
	paid = show_paid
	bonus = win_bonus
	offer_double = can_double
	count_from = roll_from


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL_DARK, CurrencyIcon.COIN))
	custom_minimum_size = Vector2(168, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	col.add_child(UiTheme.label("Coins", 9, UiTheme.MUTED))
	var doubled := bool(paid.get("doubled", false))
	var earned := int(paid.get("coins", 0)) * (2 if doubled else 1)
	# The amount, big, with the coin symbol, and a green x2 once doubled.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	var icon := CurrencyIcon.new("coins", 22.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(icon)
	var amount := UiTheme.title("+" + UiTheme.number(earned), 20, CurrencyIcon.COIN)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(amount)
	if doubled:
		var times := tag("x2", UiTheme.GOOD.darkened(0.15))
		times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(times)
	col.add_child(top)
	if bonus > 0:
		var won := UiTheme.currency("coins", bonus, 10, CurrencyIcon.COIN)
		(won.get_child(1) as Label).text = "+" + UiTheme.number(bonus)
		col.add_child(_line("Run won", won))
	var balance := UiTheme.currency("coins", Game.profile.wallet.coins, 10)
	col.add_child(_line("Balance", balance))
	if offer_double and not doubled:
		# At the foot of the card, level with the ducats' total beside it.
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(gap)
		var play := UiIcon.new("play", UiTheme.GOLD)
		play.custom_minimum_size = Vector2(14, 14)
		col.add_child(glyph_button(play, "Double coins", double_pressed.emit, 10))
	if not count_from.is_empty():
		_celebrate(icon, amount, balance.get_child(1) as Label, earned)


## A caption on the left and its value on the right.
func _line(caption: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key := UiTheme.label(caption, 9, UiTheme.MUTED)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)
	row.add_child(value)
	return row


## Right after the coins doubled: both numbers count up from where they were, with a
## sparkle and the extra coins floating off the coin.
func _celebrate(icon: Control, amount: Label, balance: Label, earned: int) -> void:
	var before := int(count_from.get("show", earned))
	roll(amount, before, earned, "+", true)
	roll(balance, int(count_from.get("balance", Game.profile.wallet.coins)), Game.profile.wallet.coins)
	# Wait a moment for the card to be laid out, so the sparkle lands on the coin.
	var t := create_tween()
	t.tween_interval(0.05)
	t.tween_callback(func() -> void:
		Feel.burst(icon.get_global_rect().get_center(), CurrencyIcon.COIN, 18)
		Feel.float_text("+" + UiTheme.number(earned - before), amount.get_global_rect().get_center() - Vector2(0, 16), CurrencyIcon.COIN, 13))


## Counts a number up on its label, ticking as it climbs if `ticking`; with reduced
## motion the final number simply appears. The label keeps its final width from the
## start so nothing beside it shuffles while it counts.
static func roll(label: Label, from: int, to: int, prefix := "", ticking := false) -> void:
	label.text = prefix + UiTheme.number(to)
	if Settings.reduce_motion or to <= from:
		return
	var font := label.get_theme_font("font")
	if font != null:
		label.custom_minimum_size.x = ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x) + 1.0
	label.text = prefix + UiTheme.number(from)
	var ticks := [0]
	var t := label.create_tween()
	t.tween_interval(0.12)
	t.tween_method(func(v: float) -> void:
		label.text = prefix + UiTheme.number(floorf(v))
		var step := int((v - from) / float(to - from) * 6.0)
		if ticking and step > int(ticks[0]):
			ticks[0] = step
			Feel.play("tick", 1.0 + step * 0.08), float(from), float(to), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The coins a whole run earned, for the run-over and win screens, naming the run-win
## bonus and the daily run's coins when they are part of it. With none yet, it says how
## coins are earned instead.
static func earned_chip(meta: Dictionary) -> PanelContainer:
	var total := int(meta.get("run_coins", 0))
	var chip := PanelContainer.new()
	var style := UiTheme.box(Color(1, 1, 1, 0.07), Color(CurrencyIcon.COIN, 0.45), 99)
	style.content_margin_left = 10
	style.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var icon := CurrencyIcon.new("coins", 16.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	if total <= 0:
		row.add_child(_middle(UiTheme.label("No coins this run. Win shows to earn them.", 10, UiTheme.MUTED)))
		return chip
	row.add_child(_middle(UiTheme.title("+" + UiTheme.number(total), 14, CurrencyIcon.COIN)))
	row.add_child(_middle(UiTheme.label("coins this run", 10, UiTheme.TEXT)))
	var parts := PackedStringArray()
	if int(meta.get("win_coins", 0)) > 0:
		parts.append("%s for the win" % UiTheme.number(int(meta["win_coins"])))
	if int(meta.get("daily_coins", 0)) > 0:
		parts.append("%s for the daily run" % UiTheme.number(int(meta["daily_coins"])))
	if not parts.is_empty():
		row.add_child(_middle(UiTheme.label("(incl. %s)" % ", ".join(parts), 9, UiTheme.MUTED)))
	return chip


static func _middle(l: Label) -> Label:
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A small filled pill holding a word or two, like a badge.
static func tag(text: String, colour: Color, font_size := 9) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := UiTheme.box(colour, colour.lightened(0.2), 99)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := UiTheme.label(text, font_size, UiTheme.INK if colour.get_luminance() > 0.55 else UiTheme.TEXT)
	words.add_theme_font_override("font", UiTheme.bold)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(words)
	return pill


## A pill button that leads with a small symbol (a play sign for an ad, a coin, a
## diamond, a ticket) before its words. Godot's buttons only take texture icons, so the
## symbol and the words sit in a row laid over a blank button sized to fit them. A
## disabled one fades its row along with the button.
static func glyph_button(glyph: Control, text: String, on_press: Callable, font_size := 11, colour := UiTheme.TONAL, enabled := true) -> Button:
	var b := UiTheme.button("", on_press, font_size, colour)
	b.disabled = not enabled
	# Same rule as UiTheme's buttons: light fills (gold, cream) take dark text.
	var neutral := colour == UiTheme.PANEL_LIGHT or colour == UiTheme.PANEL_DARK or colour == UiTheme.TONAL
	var ink := not neutral and colour.get_luminance() > 0.55
	var words := UiTheme.label(text, font_size, UiTheme.INK if ink else UiTheme.TEXT)
	words.add_theme_font_override("font", UiTheme.bold)
	words.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.modulate.a = 1.0 if enabled else 0.45
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	row.add_child(words)
	b.add_child(row)
	var text_w := UiTheme.bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(font_size)).x
	b.custom_minimum_size = Vector2(ceilf(text_w + glyph.custom_minimum_size.x + 5.0 + 28.0), 26.0)
	return b
