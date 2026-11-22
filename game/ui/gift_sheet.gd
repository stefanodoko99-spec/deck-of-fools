class_name GiftSheet
extends Sheet
## The daily gift: a week of seven gifts (Economy.GIFTS). Each claim moves one step up the
## week; a missed day is simply skipped (nothing resets, per PEGI's 2026 criteria), and
## after day 7 a new week begins.
## It opens only when the player taps the gift on the menu, never by itself: a gift should
## feel like a treat, not a pop-up in the way.
##
## After claiming, a rewarded ad can double the gift's coins when ads are on and AdPolicy allows
## one. While that ad plays the sheet can't be closed, because the gift is doubled here
## once the ad reports back, and closing first would lose a reward the player earned.

const TILE := Vector2(66, 98)
const TODAY := [Color("ffd66b"), Color("f0a020")]
const BIG_DAY := [Color("a26bff"), Color("5a2fc1")]

## The gift claimed in this sheet, with its "day" (empty until the player claims).
var _gift: Dictionary = {}
var _doubled := false
var _watching := false
var _note := ""
var _today_tile: Control
var _coin_label: Label
var _gem_label: Label


func _init() -> void:
	title_text = "Daily gift"
	panel_size = Vector2(540, 300)


## The calendar step the gift marks as today: the one a claim would give now, or the one
## already claimed today. Missed days don't reset the calendar, they only pause it.
static func today_day() -> int:
	var w := Game.wallet()
	if not Game.gift_ready():
		return maxi(1, w.gift_streak)
	return w.gift_streak + 1


## Where a streak day falls in the week, 1 to 7.
static func week_day(day: int) -> int:
	return posmod(day - 1, Economy.GIFTS.size()) + 1


func _build() -> void:
	var ready_now := Game.gift_ready()
	var day := today_day()
	var intro := UiTheme.label("A gift for every day you play. Each claim moves you one step up the week; days you miss are simply skipped, never lost.", 9, UiTheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(panel_size.x - 28.0, 0)
	body.add_child(intro)
	var week := HBoxContainer.new()
	week.alignment = BoxContainer.ALIGNMENT_CENTER
	week.add_theme_constant_override("separation", 6)
	for i: int in Economy.GIFTS.size():
		var state := "future"
		if i < week_day(day) - 1:
			state = "past"
		elif i == week_day(day) - 1:
			state = "today" if ready_now else "claimed"
		var tile := _day_tile(i, state)
		if state == "today" or state == "claimed":
			_today_tile = tile
		week.add_child(tile)
	body.add_child(week)
	var panel := PanelContainer.new()
	var box := UiTheme.box(Color(1, 1, 1, 0.06), UiTheme.TONAL_EDGE, 14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	if not _gift.is_empty():
		_build_reveal(col)
	elif ready_now:
		_build_claim(col, day)
	else:
		_build_tomorrow(col)
	if _note != "":
		col.add_child(_centred_label(_note, 9, UiTheme.MUTED))
	body.add_child(panel)


## One day of the week: its gift, and whether it's been claimed, is today, or is to come.
## Day 7, the big one, keeps its own colour.
func _day_tile(index: int, state: String) -> Control:
	var gift := Economy.gift_for(index + 1)
	var coins := int(gift.get("coins", 0))
	var gems := int(gift.get("diamonds", 0))
	var colours: Array = ShopSheet.GLASS_TILE
	var ink := UiTheme.TEXT
	if state == "today":
		colours = TODAY
		ink = UiTheme.INK
	elif index == Economy.GIFTS.size() - 1:
		colours = BIG_DAY
	var tile := ShopSheet.Tile.new(colours, 5.0)
	tile.custom_minimum_size = TILE
	tile.col.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.col.add_theme_constant_override("separation", 1)
	if state == "claimed":
		tile.ring = UiTheme.GOOD
	var caption: String = { "today": "Today", "claimed": "Claimed" }.get(state, "Day %d" % (index + 1))
	var top := UiTheme.label(caption, 8, ink)
	top.add_theme_font_override("font", UiTheme.bold)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ink == UiTheme.INK:
		top.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	tile.col.add_child(top)
	var art := ShopSheet.ItemArt.new("coins", clampi(1 + index / 2, 1, 4), Vector2(48, 38))
	if gems > 0:
		var gem := CurrencyIcon.new("diamonds", 17.0)
		gem.position = Vector2(31, 21)
		art.add_child(gem)
	if state == "past" or state == "claimed":
		var tick := ShopSheet.Check.new(14.0)
		tick.position = Vector2(34, 0)
		art.add_child(tick)
	var holder := CenterContainer.new()
	holder.add_child(art)
	tile.col.add_child(holder)
	var amount := UiTheme.title(UiTheme.number(coins), 12, ink)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ink == UiTheme.INK:
		amount.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	tile.col.add_child(amount)
	if gems > 0:
		var extra := UiTheme.currency("diamonds", gems, 8, ink)
		extra.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.col.add_child(extra)
	if state == "past":
		tile.modulate = Color(1, 1, 1, 0.55)
	if state == "today" and not Settings.reduce_motion:
		# Today's gift breathes gently until it's claimed.
		tile.resized.connect(func() -> void: tile.pivot_offset = tile.size / 2.0)
		var pulse := tile.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(tile, "scale", Vector2(1.06, 1.06), 0.7)
		pulse.tween_property(tile, "scale", Vector2.ONE, 0.7)
	return tile


func _build_claim(col: VBoxContainer, day: int) -> void:
	var gift := Economy.gift_for(day)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 3)
	lines.add_child(UiTheme.title("Day %d of %d" % [week_day(day), Economy.GIFTS.size()], 14, UiTheme.TEXT))
	var amounts := HBoxContainer.new()
	amounts.add_theme_constant_override("separation", 10)
	amounts.add_child(UiTheme.currency("coins", int(gift.get("coins", 0)), 11))
	if int(gift.get("diamonds", 0)) > 0:
		amounts.add_child(UiTheme.currency("diamonds", int(gift["diamonds"]), 11))
	lines.add_child(amounts)
	row.add_child(lines)
	var claim := UiTheme.button("Claim", _claim, 14, UiTheme.GOLD)
	claim.custom_minimum_size = Vector2(124, 32)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(claim)
	col.add_child(row)
	col.add_child(_centred_label("Missed a day? Nothing is lost: the calendar just waits for you.", 9, UiTheme.MUTED))


## Just claimed: the gift in big numbers (they count up), then the offer to double it.
func _build_reveal(col: VBoxContainer) -> void:
	var times := 2 if _doubled else 1
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.add_child(_big_amount("coins", int(_gift.get("coins", 0)) * times))
	# Only the coins double: an ad never pays out diamonds.
	if int(_gift.get("diamonds", 0)) > 0:
		row.add_child(_big_amount("diamonds", int(_gift["diamonds"])))
	col.add_child(row)
	var next := "Come back tomorrow for day %d." % week_day(int(_gift.get("day", 1)) + 1)
	if _doubled:
		col.add_child(_centred_label("Doubled. " + next, 10, UiTheme.GOOD))
	elif _watching:
		var waiting := UiTheme.button("Playing the ad…", func() -> void: pass, 11, UiTheme.POINTS)
		waiting.disabled = true
		waiting.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(waiting)
	elif Ads.can_offer("daily_gift"):
		col.add_child(_ad_button())
	else:
		col.add_child(_centred_label(next, 10, UiTheme.MUTED))


func _build_tomorrow(col: VBoxContainer) -> void:
	var w := Game.wallet()
	col.add_child(_centred_label("Come back tomorrow for day %d" % week_day(w.gift_streak + 1), 14, UiTheme.TEXT, true))
	col.add_child(_centred_label("Today's gift is claimed. %d gift%s claimed so far." % [w.gift_streak, "" if w.gift_streak == 1 else "s"], 9, UiTheme.MUTED))


func _big_amount(kind: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := CurrencyIcon.new(kind, 28.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var number := UiTheme.title("+" + UiTheme.number(amount), 26, UiTheme.TEXT)
	row.add_child(number)
	if kind == "coins":
		_coin_label = number
	else:
		_gem_label = number
	return row


## "Watch an ad to double the coins", with the play glyph that marks rewarded ads.
func _ad_button() -> Button:
	var b := UiTheme.button("Watch an ad to double the coins", _double, 11, UiTheme.POINTS)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(0, 28)
	var glyph := UiIcon.new("play", UiTheme.TEXT)
	glyph.position = Vector2(9, 7)
	glyph.size = Vector2(14, 14)
	b.add_child(glyph)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var st := b.get_theme_stylebox(state) as StyleBoxFlat
		if st != null:
			st.content_margin_left = 28
	return b


func _claim() -> void:
	if not _gift.is_empty() or not Game.gift_ready():
		return
	var at := Vector2.ZERO
	if _today_tile != null and is_instance_valid(_today_tile):
		at = _today_tile.get_global_rect().get_center()
	_gift = Game.claim_gift()
	if _gift.is_empty():
		rebuild()
		return
	Feel.play("cash")
	Feel.buzz(35)
	if at != Vector2.ZERO:
		Feel.burst(at, UiTheme.GOLD, 28)
	rebuild()
	_roll(_coin_label, 0, int(_gift.get("coins", 0)))
	_roll(_gem_label, 0, int(_gift.get("diamonds", 0)))


func _double() -> void:
	if _watching or _doubled or _gift.is_empty():
		return
	if not Ads.can_offer("daily_gift"):
		_note = "No ad is available right now, so the gift stays as it is."
		rebuild()
		return
	_watching = true
	_note = ""
	rebuild()
	var completed: bool = await Ads.show_rewarded("daily_gift")
	if not _alive():
		return
	_watching = false
	if not completed:
		_note = "The ad was closed early, so the gift stays as it is."
		rebuild()
		return
	if not Game.double_gift(_gift):
		_note = "Today's gift was already doubled."
		rebuild()
		return
	_doubled = true
	Feel.play("cash")
	Feel.buzz(25)
	rebuild()
	_roll(_coin_label, int(_gift.get("coins", 0)), int(_gift.get("coins", 0)) * 2)


## Count a big number up to its value, then give it a little pop.
func _roll(label: Label, from: int, to: int) -> void:
	if label == null or not is_instance_valid(label) or to <= 0:
		return
	label.text = "+" + UiTheme.number(to)
	if Settings.reduce_motion or from == to:
		return
	label.text = "+" + UiTheme.number(from)
	var roll := label.create_tween()
	roll.tween_method(func(v: float) -> void: label.text = "+" + UiTheme.number(roundi(v)), float(from), float(to), 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	roll.tween_callback(func() -> void:
		label.pivot_offset = label.size / 2.0
		var pop := label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(label, "scale", Vector2(1.15, 1.15), 0.08)
		pop.tween_property(label, "scale", Vector2.ONE, 0.2))


func close() -> void:
	# Not while the ad plays: the gift is doubled here once it reports back.
	if _watching:
		return
	super.close()


func _alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Like Sheet.rebuild, but the old content leaves the tree at once, so it never counts
## toward the panel's size (claiming right after the sheet opens, during its slide-in,
## would otherwise leave the panel too tall).
func rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_build()
	heading.text = title_text


func _centred_label(text: String, font_size: int, colour: Color, heavy := false) -> Label:
	var l := UiTheme.title(text, font_size, colour) if heavy else UiTheme.label(text, font_size, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(panel_size.x - 60.0, 0)
	return l
