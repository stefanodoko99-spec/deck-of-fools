class_name GoalsSheet
extends Sheet
## The goals: today's three side by side as colour blocks (easy, medium, hard), this
## week's goal as a banner under them, and any finished goals from earlier days waiting to
## be claimed. Claiming plays the cash sound, bursts coins from the goal and counts the
## wallet in the header up to its new balance. It opens only when the player asks
## (Goals.open() from the home screen), never by itself.
##
## Nothing here pushes: it says when the next goals come without a ticking clock,
## unfinished goals simply make way for new ones, and finished ones wait as long as they
## need to. Progress is told in numbers as well as bars, never by colour alone.

## Colour blocks for each pool, top-left to bottom-right. A finished goal turns gold.
const COLOURS := {
	"easy": [Color("27b5a2"), Color("0d5a70")],
	"medium": [Color("4f8dff"), Color("2c30a3")],
	"hard": [Color("ff5f73"), Color("9c1b3d")],
	"weekly": [Color("a46cff"), Color("4a1fa8")],
}
const READY := [Color("ffd66b"), Color("f0a020")]
const DAILY_HEIGHT := 148.0
const WEEKLY_HEIGHT := 64.0
const GAP := 8

var _coins: Label
var _diamonds: Label
var _shown_coins := -1
var _shown_diamonds := -1
## The goal just claimed: once the sheet is rebuilt, its reward counts up.
var _claimed_id := ""
var _claimed_coins := 0
var _reward_label: Label


func _init() -> void:
	title_text = "Goals"
	# Taller when finished goals from earlier days wait in a bar at the bottom.
	panel_size = Vector2(600, 336 if not Goals.earlier().is_empty() else 318)


func _ready() -> void:
	super._ready()
	_add_wallet()


## How long until something comes, in words without seconds ("5 h", "40 min", "3 days"):
## the sheet tells when new goals come, it doesn't count down to them.
static func until(seconds: int) -> String:
	if seconds >= 2 * 86400:
		return "%d days" % floori(seconds / 86400.0)
	if seconds >= 86400:
		return "1 day"
	if seconds >= 3600:
		return "%d h" % floori(seconds / 3600.0)
	return "%d min" % maxi(1, ceili(seconds / 60.0))


## A goal's progress in words: "3/5", "640/1,000", or "Town 2 of 3".
static func progress_words(g: Dictionary) -> String:
	var progress := int(g["progress"])
	var target := int(g["target"])
	match str(g.get("measure", "count")):
		"best:reach":
			return "Town %d of %d" % [clampi(progress, 1, target), target]
		"best:total":
			return "%s/%s" % [UiTheme.number(progress), UiTheme.number(target)]
	return "%d/%d" % [progress, target]


## How full a goal's bar is. A "Reach Town N" bar starts empty in Town 1, where every run
## begins, and fills town by town.
static func share(g: Dictionary) -> float:
	var progress := float(g["progress"])
	var target := float(g["target"])
	if str(g.get("measure", "")) == "best:reach":
		return clampf((maxf(progress, 1.0) - 1.0) / maxf(1.0, target - 1.0), 0.0, 1.0)
	return clampf(progress / maxf(1.0, target), 0.0, 1.0)


func _build() -> void:
	_reward_label = null
	var now := int(Time.get_unix_time_from_system())
	var goals := Goals.current()
	body.add_child(_section("Today", "New goals in " + until(GoalDefs.seconds_to_next_day(now))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	for g: Dictionary in goals:
		if g["kind"] == "daily":
			row.add_child(_daily_tile(g))
	body.add_child(row)
	for g: Dictionary in goals:
		if g["kind"] == "weekly":
			body.add_child(_weekly_tile(g, now))
	# Whatever comes last sits at the bottom of the sheet.
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gap)
	var waiting := Goals.earlier()
	if waiting.is_empty():
		var foot := UiTheme.label("Goals fill up as you play, in any mode. Finished goals wait for you to claim them.", 8, UiTheme.MUTED)
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.custom_minimum_size = Vector2(panel_size.x - 40.0, 0)
		body.add_child(foot)
	else:
		body.add_child(_earlier_bar(waiting))
	if _reward_label != null:
		_roll(_reward_label, _claimed_coins)
	_claimed_id = ""


## A heading with a note on the right ("Today ... New goals in 5 h").
func _section(text: String, note: String) -> Control:
	var row := HBoxContainer.new()
	var caption := UiTheme.label(text, 11, UiTheme.TEXT)
	caption.add_theme_font_override("font", UiTheme.bold)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var right := UiTheme.label(note, 9, UiTheme.MUTED)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return row


## One of today's goals: its picture and reward, what to do, a line on how, and then its
## progress, a Claim button, or a tick once claimed.
func _daily_tile(g: Dictionary) -> Control:
	var ready_now: bool = g["done"] and not g["claimed"]
	var ink := UiTheme.INK if ready_now else UiTheme.TEXT
	var tile := ShopSheet.Tile.new(_colours(g), 9.0)
	tile.custom_minimum_size = Vector2(0, DAILY_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.col.add_theme_constant_override("separation", 4)
	var width := (panel_size.x - 28.0 - 2.0 * GAP) / 3.0 - 18.0
	var top := HBoxContainer.new()
	top.add_child(GoalArt.new(str(g["art"]), ink, 36.0, int(g["target"])))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(space)
	top.add_child(_reward(g, ink))
	tile.col.add_child(top)
	tile.col.add_child(_words(str(g["text"]), 11, ink, width, true))
	tile.col.add_child(_words(str(g["hint"]), 8, Color(ink, 0.8), width))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.col.add_child(gap)
	tile.col.add_child(_state_row(g, tile, ink))
	_settle(tile, g)
	return tile


## This week's goal: a banner with the picture, the words, the reward and the progress.
func _weekly_tile(g: Dictionary, now: int) -> Control:
	var ready_now: bool = g["done"] and not g["claimed"]
	var ink := UiTheme.INK if ready_now else UiTheme.TEXT
	var tile := ShopSheet.Tile.new(_colours(g), 9.0)
	tile.custom_minimum_size = Vector2(0, WEEKLY_HEIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	tile.col.add_child(row)
	row.add_child(GoalArt.new(str(g["art"]), ink, 44.0, int(g["target"])))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	tags.add_child(_tag("This week", ink))
	var next := _words("New weekly goal in " + until(GoalDefs.seconds_to_next_week(now)), 8, Color(ink, 0.8), 0.0)
	next.autowrap_mode = TextServer.AUTOWRAP_OFF
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tags.add_child(next)
	words.add_child(tags)
	words.add_child(_words(str(g["text"]), 12, ink, 250.0, true))
	words.add_child(_words(str(g["hint"]), 8, Color(ink, 0.8), 250.0))
	row.add_child(words)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(156, 0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 5)
	var reward := _reward(g, ink)
	reward.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(reward)
	side.add_child(_state_row(g, tile, ink))
	row.add_child(side)
	_settle(tile, g)
	return tile


## Finished goals from earlier days, all claimed with one tap.
func _earlier_bar(waiting: Array) -> Control:
	var coins := 0
	var gems := 0
	for g: Dictionary in waiting:
		coins += int(g["coins"])
		gems += int(g["diamonds"])
	var panel := PanelContainer.new()
	var box := UiTheme.box(Color(1, 1, 1, 0.08), UiTheme.TONAL_EDGE, 12)
	box.content_margin_left = 10
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var tick := ShopSheet.Check.new(14.0)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
	var n := waiting.size()
	var text := "A goal you finished earlier is waiting" if n == 1 else "%d goals you finished earlier are waiting" % n
	var words := UiTheme.label(text, 9, UiTheme.TEXT)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.clip_text = true
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(words)
	row.add_child(UiTheme.currency("coins", coins, 10))
	if gems > 0:
		row.add_child(UiTheme.currency("diamonds", gems, 10))
	var claim := UiTheme.button("Claim", _claim_earlier.bind(panel), 10, UiTheme.GOLD)
	claim.custom_minimum_size = Vector2(72, 22)
	row.add_child(claim)
	return panel


## The bottom of a goal: a Claim button when it's finished, a tick once claimed, and
## otherwise its bar and its progress in numbers.
func _state_row(g: Dictionary, tile: Control, ink: Color) -> Control:
	if g["claimed"]:
		var done_row := HBoxContainer.new()
		done_row.add_theme_constant_override("separation", 5)
		done_row.add_child(ShopSheet.Check.new(13.0))
		var claimed := UiTheme.label("Claimed", 9, ink)
		claimed.add_theme_font_override("font", UiTheme.bold)
		done_row.add_child(claimed)
		return done_row
	if g["done"]:
		var claim := UiTheme.button("Claim", _claim.bind(str(g["id"]), tile), 11, UiTheme.TEXT)
		claim.custom_minimum_size = Vector2(0, 24)
		claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return claim
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var bar := Bar.new(share(g), ink, Color(ink, 0.22))
	row.add_child(bar)
	var count := UiTheme.label(progress_words(g), 9, ink)
	count.add_theme_font_override("font", UiTheme.bold)
	row.add_child(count)
	return row


## The coins (and diamonds) a goal pays, as a small pill.
func _reward(g: Dictionary, ink: Color) -> Control:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(ink, 0.16) if ink == UiTheme.INK else Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 99)
	box.content_margin_left = 6
	box.content_margin_right = 7
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	var coins := UiTheme.currency("coins", int(g["coins"]), 10, ink)
	row.add_child(coins)
	if int(g["diamonds"]) > 0:
		row.add_child(UiTheme.currency("diamonds", int(g["diamonds"]), 10, ink))
	var amount := coins.get_child(1) as Label
	amount.text = "+" + amount.text
	if ink == UiTheme.INK:
		amount.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if str(g["id"]) == _claimed_id:
		_reward_label = amount
	return pill


## Finished goals breathe gently until claimed; claimed ones step back a little.
func _settle(tile: Control, g: Dictionary) -> void:
	if g["claimed"]:
		tile.modulate = Color(1, 1, 1, 0.82)
	elif g["done"] and not Settings.reduce_motion:
		tile.resized.connect(func() -> void: tile.pivot_offset = tile.size / 2.0)
		var pulse := tile.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(tile, "scale", Vector2(1.025, 1.025), 0.8)
		pulse.tween_property(tile, "scale", Vector2.ONE, 0.8)


func _colours(g: Dictionary) -> Array:
	if g["claimed"]:
		return ShopSheet.GLASS_TILE
	if g["done"]:
		return READY
	return COLOURS.get(str(g["tier"]), COLOURS["easy"])


func _claim(id: String, tile: Control) -> void:
	var at := tile.get_global_rect().get_center() if is_instance_valid(tile) else Vector2.ZERO
	var coins := Goals.claim(id)
	if coins <= 0:
		# Already claimed (a double tap): just show it as it is now.
		rebuild()
		return
	_celebrate(at, coins)
	_claimed_id = id
	_claimed_coins = coins
	rebuild()
	_refresh_wallet(true)


func _claim_earlier(bar: Control) -> void:
	var at := bar.get_global_rect().get_center() if is_instance_valid(bar) else Vector2.ZERO
	var paid := Goals.claim_earlier()
	if int(paid["coins"]) <= 0 and int(paid["diamonds"]) <= 0:
		rebuild()
		return
	_celebrate(at, int(paid["coins"]))
	rebuild()
	_refresh_wallet(true)


## The cash sound, a short buzz, coins bursting from the goal and "+45" rising from it.
func _celebrate(at: Vector2, coins: int) -> void:
	Feel.play("cash")
	Feel.buzz(35)
	if at != Vector2.ZERO:
		Feel.burst(at, UiTheme.GOLD, 28)
		Feel.float_text("+" + UiTheme.number(coins), at - Vector2(0, 8), UiTheme.GOLD, 16)


## Count a reward up from nothing, then give it a little pop.
func _roll(label: Label, to: int) -> void:
	if label == null or not is_instance_valid(label) or to <= 0 or Settings.reduce_motion:
		return
	label.text = "+0"
	var roll := label.create_tween()
	roll.tween_method(func(v: float) -> void: label.text = "+" + UiTheme.number(roundi(v)), 0.0, float(to), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	roll.tween_callback(func() -> void:
		label.pivot_offset = label.size / 2.0
		var pop := label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(label, "scale", Vector2(1.2, 1.2), 0.08)
		pop.tween_property(label, "scale", Vector2.ONE, 0.2))


## Like Sheet.rebuild, but the old content leaves the tree at once, so it never counts
## toward the panel's size while the new content is built.
func rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_build()
	heading.text = title_text


func _words(text: String, font_size: int, colour: Color, width: float, heavy := false) -> Label:
	var l := UiTheme.label(text, font_size, colour)
	if heavy:
		l.add_theme_font_override("font", UiTheme.bold)
	if colour.get_luminance() < 0.5:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## A small pill label on a tile.
func _tag(text: String, ink: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.box(Color(ink, 0.18) if ink == UiTheme.INK else Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 99)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := UiTheme.label(text, 8, ink)
	l.add_theme_font_override("font", UiTheme.bold)
	if ink == UiTheme.INK:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	pill.add_child(l)
	return pill


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
	var w := Goals.wallet_in_use()
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
	roll.tween_method(func(v: float) -> void: label.text = UiTheme.number(roundi(v)), float(from), float(to), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label.pivot_offset = label.size / 2.0
	var pop := label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector2(1.18, 1.18), 0.08)
	pop.tween_property(label, "scale", Vector2.ONE, 0.22)


## A pill-shaped progress bar that fills up as the sheet opens (at once with Reduce motion).
class Bar extends Control:
	var part := 0.0
	var fill := Color.WHITE
	var track := Color(1, 1, 1, 0.22)

	func _init(amount: float, fill_colour: Color, track_colour: Color) -> void:
		fill = fill_colour
		track = track_colour
		custom_minimum_size = Vector2(0, 6)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		var goal_part := clampf(amount, 0.0, 1.0)
		if Settings.reduce_motion or goal_part <= 0.0:
			part = goal_part
		else:
			create_tween().tween_method(_set_part, 0.0, goal_part, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.12)

	func _set_part(value: float) -> void:
		part = value
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiTheme.box(track, Color(0, 0, 0, 0), 99), r)
		if part > 0.0:
			r.size.x = maxf(r.size.y, r.size.x * part)
			draw_style_box(UiTheme.box(fill, Color(0, 0, 0, 0), 99), r)


## A goal's picture, drawn in code in the tile's ink on a soft disc: a little fan of
## playing cards for the poker-hand goals, a crown for the Patrons, a flag for travelling
## on, a jester's hat for buying Jesters, and so on (GoalDefs.POOL names one per goal).
class GoalArt extends Control:
	## The cards each poker-hand picture fans out: rank and suit (PlayingCard.Suit).
	const HANDS := {
		"pair": [["K", 0], ["K", 1]],
		"three": [["7", 2], ["7", 1], ["7", 3]],
		"four": [["A", 0], ["A", 1], ["A", 2], ["A", 3]],
		"flush": [["3", 1], ["8", 1], ["Q", 1]],
		"straight": [["6", 2], ["7", 3], ["8", 0]],
		"house": [["Q", 0], ["Q", 1], ["4", 3]],
	}

	var art := ""
	var ink := Color.WHITE
	var target := 0

	func _init(art_name: String, ink_colour: Color, side: float, goal_target := 0) -> void:
		art = art_name
		ink = ink_colour
		target = goal_target
		custom_minimum_size = Vector2(side, side)
		size = custom_minimum_size
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if art == "trophy":
			var glyph := UiIcon.new("trophy", ink)
			glyph.position = Vector2(side, side) * 0.2
			glyph.size = Vector2(side, side) * 0.6
			add_child(glyph)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size / 2.0
		draw_circle(c, s * 0.5, Color(ink, 0.15), true, -1.0, true)
		if HANDS.has(art):
			_cards(c, s, HANDS[art])
			return
		match art:
			"crown":
				_fill(c, s, [[0.22, 0.68], [0.2, 0.36], [0.36, 0.5], [0.5, 0.27], [0.64, 0.5], [0.8, 0.36], [0.78, 0.68]])
				_fill(c, s, [[0.22, 0.71], [0.78, 0.71], [0.78, 0.77], [0.22, 0.77]])
				for tip: Array in [[0.2, 0.33], [0.5, 0.24], [0.8, 0.33]]:
					draw_circle(_at(c, s, tip), s * 0.045, ink, true, -1.0, true)
			"flag":
				draw_line(_at(c, s, [0.33, 0.2]), _at(c, s, [0.33, 0.82]), ink, maxf(1.5, s * 0.06), true)
				_fill(c, s, [[0.35, 0.22], [0.76, 0.3], [0.63, 0.4], [0.76, 0.5], [0.35, 0.52]])
			"bolt":
				_fill(c, s, [[0.56, 0.15], [0.28, 0.56], [0.48, 0.56], [0.42, 0.87], [0.74, 0.43], [0.54, 0.43], [0.62, 0.15]])
			"star":
				_sparkle(_at(c, s, [0.45, 0.54]), s * 0.32, s * 0.09)
				_sparkle(_at(c, s, [0.72, 0.28]), s * 0.13, s * 0.04)
			"moon":
				_moon(c + Vector2(-s * 0.03, s * 0.02), s * 0.3, s * 0.26, Vector2(s * 0.15, -s * 0.09))
				_sparkle(_at(c, s, [0.72, 0.3]), s * 0.09, s * 0.03)
			"jester":
				# A jester's cap: two points drooping to the sides in the paler colour, one
				# standing up in the middle, a bell on each, over a band.
				_fill(c, s, [[0.26, 0.66], [0.08, 0.47], [0.24, 0.38], [0.46, 0.62]], 0.7)
				_fill(c, s, [[0.74, 0.66], [0.92, 0.47], [0.76, 0.38], [0.54, 0.62]], 0.7)
				_fill(c, s, [[0.36, 0.65], [0.5, 0.15], [0.64, 0.65]])
				_fill(c, s, [[0.24, 0.64], [0.76, 0.64], [0.74, 0.76], [0.26, 0.76]])
				for bell: Array in [[0.07, 0.48], [0.5, 0.13], [0.93, 0.48]]:
					draw_circle(_at(c, s, bell), s * 0.06, ink, true, -1.0, true)
			"discard":
				_card_back(_at(c, s, [0.38, 0.58]), s, -0.3, Color(ink, 0.45))
				_card_back(_at(c, s, [0.62, 0.52]), s, 0.18, ink)
				draw_arc(_at(c, s, [0.5, 0.56]), s * 0.3, PI * 1.12, PI * 1.62, 12, ink, maxf(1.2, s * 0.05), true)
				var head := _at(c, s, [0.5, 0.56]) + Vector2(cos(PI * 1.62), sin(PI * 1.62)) * s * 0.3
				draw_colored_polygon(PackedVector2Array([head + Vector2(-s * 0.02, -s * 0.07), head + Vector2(s * 0.08, s * 0.0), head + Vector2(-s * 0.02, s * 0.07)]), ink)
			"deck":
				for i: int in 3:
					_card_back(_at(c, s, [0.4 + i * 0.08, 0.6 - i * 0.07]), s, -0.08, Color(1, 1, 1, 0.55 + i * 0.2))
			"score":
				var text := "%dK" % floori(target / 1000.0) if target >= 1000 else str(target)
				var font_px := maxi(8, roundi(s * 0.34))
				var w := UiTheme.display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
				draw_string(UiTheme.display, c + Vector2(-w / 2.0, font_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)

	func _at(c: Vector2, s: float, p: Array) -> Vector2:
		return c + Vector2(float(p[0]) - 0.5, float(p[1]) - 0.5) * s

	func _fill(c: Vector2, s: float, points: Array, alpha := 1.0) -> void:
		var poly := PackedVector2Array()
		for p: Array in points:
			poly.append(_at(c, s, p))
		draw_colored_polygon(poly, Color(ink, ink.a * alpha))

	## A four-pointed sparkle, the Signs' star.
	func _sparkle(at: Vector2, long: float, short: float) -> void:
		var poly := PackedVector2Array()
		for i: int in 8:
			var a := -PI / 2.0 + i * PI / 4.0
			poly.append(at + Vector2(cos(a), sin(a)) * (long if i % 2 == 0 else short))
		draw_colored_polygon(poly, ink)

	## A crescent: the part of one circle outside another, nudged towards the top right.
	func _moon(c: Vector2, outer: float, inner: float, offset: Vector2) -> void:
		var bite := c + offset
		var away := (-offset).angle()
		var poly := PackedVector2Array()
		for i: int in 33:
			var p := c + Vector2.from_angle(away - PI + i * TAU / 32.0) * outer
			if p.distance_to(bite) > inner:
				poly.append(p)
		for i: int in 33:
			var p := bite + Vector2.from_angle(away + PI - i * TAU / 32.0) * inner
			if p.distance_to(c) < outer:
				poly.append(p)
		if poly.size() >= 3:
			draw_colored_polygon(poly, ink)

	## A small card back, tilted, for the discard and deck pictures.
	func _card_back(at: Vector2, s: float, angle: float, colour: Color) -> void:
		var w := s * 0.3
		var h := s * 0.42
		draw_set_transform(at, angle, Vector2.ONE)
		var r := Rect2(-w / 2.0, -h / 2.0, w, h)
		draw_colored_polygon(Paint.round_rect(Rect2(r.position + Vector2(0, s * 0.02), r.size), w * 0.18), Color(0, 0, 0, 0.18))
		draw_colored_polygon(Paint.round_rect(r, w * 0.18), colour)
		draw_colored_polygon(Paint.round_rect(r.grow(-w * 0.17), w * 0.1), Color(UiTheme.MULT, colour.a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A fan of small white playing cards: rank in the corner, suit in the middle.
	func _cards(c: Vector2, s: float, cards: Array) -> void:
		var w := s * 0.36
		var h := s * 0.5
		var n := cards.size()
		for i: int in n:
			var t := 0.0 if n == 1 else float(i) / (n - 1) - 0.5
			draw_set_transform(c + Vector2(t * s * (0.3 + 0.04 * n), s * 0.04 + absf(t) * s * 0.06), t * (0.5 + 0.1 * n), Vector2.ONE)
			var r := Rect2(-w / 2.0, -h / 2.0, w, h)
			draw_colored_polygon(Paint.round_rect(Rect2(r.position + Vector2(0, s * 0.02), r.size), w * 0.16), Color(0, 0, 0, 0.22))
			draw_colored_polygon(Paint.round_rect(r, w * 0.16), Color("fffaf0"))
			var suit := int(cards[i][1])
			var colour := CardView.suit_colour(suit)
			var font_px := maxi(6, roundi(h * 0.34))
			draw_string(UiTheme.bold, Vector2(r.position.x + w * 0.1, r.position.y + font_px * 0.92), str(cards[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, colour)
			CardView.draw_suit(self, Vector2(w * 0.08, h * 0.14), w * 0.22, suit, colour)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
