class_name RunCoins
extends PanelContainer
## The coins a won show paid, on the cash-out screen beside the ducats. Ducats are
## spent in the Market and gone when the run ends; coins stay with the player for good
## (card backs, Encores), so they get a card of their own: the amount with the coin
## symbol, what it is made of when there is more than the show's own coins (the day's
## first win, the run won) and the player's balance. There is nothing to tap on it:
## doubling is the curtain call on the end screens, once per finished run.
## Also holds the small coin pieces the run's other screens share: the end screens'
## coins row with the curtain call, pill buttons that lead with a symbol, and the
## count-up.

## What the show paid: { show, coins, first_win } (Game.run_meta["show_coins"]).
var paid: Dictionary
## The run-win bonus, shown on the cash-out of the show that won the whole run.
var bonus := 0


func _init(show_paid: Dictionary, win_bonus := 0) -> void:
	paid = show_paid
	bonus = win_bonus


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL_DARK, CurrencyIcon.COIN))
	custom_minimum_size = Vector2(168, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	col.add_child(UiTheme.label("Coins", 9, UiTheme.MUTED))
	var show_coins := int(paid.get("coins", 0))
	var first_win := int(paid.get("first_win", 0))
	# Everything this cash-out paid, big, with the coin symbol.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	var icon := CurrencyIcon.new("coins", 22.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(icon)
	var amount := UiTheme.title("+" + UiTheme.number(show_coins + first_win + bonus), 20, CurrencyIcon.COIN)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(amount)
	col.add_child(top)
	# What it's made of, only when there's more than the show's own coins.
	if first_win > 0 or bonus > 0:
		col.add_child(_line("Show won", plus(show_coins)))
		if first_win > 0:
			col.add_child(_line("First win today", plus(first_win)))
		if bonus > 0:
			col.add_child(_line("Run won", plus(bonus)))
	col.add_child(_line("Balance", UiTheme.currency("coins", Game.wallet().coins, 10)))


## A caption on the left and its value on the right.
func _line(caption: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key := UiTheme.label(caption, 9, UiTheme.MUTED)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)
	row.add_child(value)
	return row


## A coin amount with a plus sign, e.g. "+50" after the coin symbol.
static func plus(coins: int, font_size := 10) -> HBoxContainer:
	var row := UiTheme.currency("coins", coins, font_size, CurrencyIcon.COIN)
	(row.get_child(1) as Label).text = "+" + UiTheme.number(coins)
	return row


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


## The end screens' coins: a chip with what the whole run earned and, beside it, the
## curtain call, which doubles the run's show and win coins once after a rewarded ad
## (Game.double_run_coins). The button states the reward before the ad. `offer` is
## whether to show it now; `on_double` plays the ad and pays. Once doubled, a green
## tag takes its place. `finishes` adds a note that doubling ends the run, for the win
## screen, where the run could still tour on. `roll_from` (when 0 or more) counts the
## total up from there, right after doubling. Under the row, a line names the coins
## that came from somewhere other than shows: the win, the daily run, the album.
static func end_row(meta: Dictionary, offer: bool, on_double: Callable, finishes := false, roll_from := -1) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	block.add_child(row)
	var total := int(meta.get("run_coins", 0))
	var chip := PanelContainer.new()
	var style := UiTheme.box(Color(1, 1, 1, 0.07), Color(CurrencyIcon.COIN, 0.45), 99)
	style.content_margin_left = 10
	style.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 5)
	chip.add_child(inside)
	var icon := CurrencyIcon.new("coins", 16.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(icon)
	if total <= 0:
		inside.add_child(_middle(UiTheme.label("No coins this run. Win shows to earn them.", 10, UiTheme.MUTED)))
		return block
	var amount := _middle(UiTheme.title("+" + UiTheme.number(total), 14, CurrencyIcon.COIN))
	inside.add_child(amount)
	inside.add_child(_middle(UiTheme.label("coins this run", 10, UiTheme.TEXT)))
	var doubled := bool(meta.get("doubled", false))
	if doubled:
		var done := tag("Doubled", UiTheme.GOOD.darkened(0.15))
		done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(done)
	elif offer:
		var play := UiIcon.new("play", UiTheme.TEXT)
		play.custom_minimum_size = Vector2(13, 13)
		var reward := int(meta.get("doublable", 0))
		row.add_child(glyph_button(play, "Double coins: +%s" % UiTheme.number(reward), on_double, 10, UiTheme.POINTS))
	if roll_from >= 0:
		roll(amount, roll_from, total, "+", true)
		var t := amount.create_tween()
		t.tween_interval(0.05)
		t.tween_callback(func() -> void:
			Feel.burst(icon.get_global_rect().get_center(), CurrencyIcon.COIN, 18)
			Feel.float_text("+" + UiTheme.number(total - roll_from), amount.get_global_rect().get_center() - Vector2(0, 16), CurrencyIcon.COIN, 13))
	var parts := PackedStringArray()
	var win := int(meta.get("win_coins", 0)) * (2 if doubled else 1)
	if win > 0:
		parts.append("%s for the win" % UiTheme.number(win))
	if int(meta.get("daily_coins", 0)) > 0:
		parts.append("%s for the daily run" % UiTheme.number(int(meta["daily_coins"])))
	var album: Variant = meta.get("album")
	if album is Dictionary and int((album as Dictionary).get("coins", 0)) > 0:
		var gems := int((album as Dictionary).get("diamonds", 0))
		parts.append("%s for the album%s" % [UiTheme.number(int(album["coins"])), " (and %d diamonds)" % gems if gems > 0 else ""])
	if not parts.is_empty():
		var incl := UiTheme.label("incl. " + ", ".join(parts), 9, UiTheme.MUTED)
		incl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(incl)
	if offer and finishes and not doubled:
		var ends := UiTheme.label("Doubling ends the run here.", 9, UiTheme.MUTED)
		ends.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(ends)
	return block


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
## gift) before its words. Godot's buttons only take texture icons, so the symbol and
## the words sit in a row laid over a blank button sized to fit them. A disabled one
## fades its row along with the button.
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
