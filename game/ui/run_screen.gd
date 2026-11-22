class_name RunScreen
extends Control









signal back_to_menu

const SHOW_NAMES := ["Matinee", "Evening show", "Patron"]
const SHOW_COLOURS := [Color("3f8ed8"), Color("2e9c8f"), Color("e0503c")]
const SUITS := ["Spades", "Hearts", "Clubs", "Diamonds"]
const RANK_NAMES := { 11: "Jack", 12: "Queen", 13: "King", 14: "Ace" }
const RANK_SHORT := { 11: "J", 12: "Q", 13: "K", 14: "A" }
const AREA_X := 156.0

const HAND_CARD := Vector2(66, 92)
const JESTER_CARD := Vector2(54, 76)
const ITEM_CARD := Vector2(48, 66)
const SHOP_CARD := Vector2(60, 84)
const MAX_STAGE_WIDTH := 920.0
## The safe area this layout was built for, and the scale that fits 360 into it.
var safe := Rect2()
var fit := 1.0


const ACTION_CUES := {
	"select_show": "show", "skip_show": "discard", "cash_out": "cash", "buy": "buy",
	"buy_warrant": "buy", "buy_pack": "pack", "pick": "deal", "skip_pack": "click",
	"sell": "sell", "use": "pack", "reroll": "reroll", "leave_shop": "click",
	"swap_patron": "reroll", "reorder_zanni": "deal",
}

const KIND_HELP := {
	"zanni": "Jester: stays with you and works on every hand. Slots are limited (top left); sell one to make room.",
	"tarocchi": "Tarocchi: a one-use card. If it changes cards, select them in your hand first, then tap Use.",
	"sign": "Sign: a one-use card that levels up a poker hand, so it scores more from now on.",
	"omen": "Omen: a powerful one-use card.",
	"pack": "Pack: buy it to open it, then choose the cards you keep.",
	"warrant": "Warrant: a lasting upgrade for the rest of the run.",
}

const EVENT_CUES := {
	"points": "points", "mult": "mult", "xmult": "xmult", "ducats": "buy", "swap": "reroll",
	"not_allowed": "error", "shattered": "discard",
}

var run: RunState:
	get:
		return Game.run

var selected_hand: Array[int] = []

var selection: Dictionary = {}
var sort_by := "rank"
var busy := false
var held_while_scoring: Array = []


var hand_layout: Dictionary = {}
var message := ""


var stage_w := 640.0
var area_w := 480.0
var hand_card := HAND_CARD
var jester_card := JESTER_CARD
var item_card := ITEM_CARD

var custom_order: Array[int] = []

var scoring := false
var skipping := false

var primary := Callable()

var stage: Control
var lbl_place: Label
var lbl_target_caption: Label
var lbl_target: Label
var lbl_score: Label
var lbl_hand: Label
var lbl_points: Label
var lbl_mult: Label
var lbl_hands: Label
var lbl_discards: Label
var lbl_ducats: Label
var info_name: Label
var info_text: Label
var top_row: Control
var middle: Control
var hand_row: Control
var buttons: HBoxContainer
var overlay: Control

var tip: Control

var guide: Guide
## The cards the guide rings on the first hand: the player's best poker hand.
var _suggested: Array = []
var jester_views: Array = []

## Which overlay is up ("encore", "lost", "won" or ""), so a refresh that rebuilds the
## same one doesn't play its entrance (and its sound) again.
var _overlay_kind := ""
## Why the last try at taking the Encore didn't work, shown on its panel.
var _encore_note := ""
## Why the last curtain call didn't double the coins, shown on the end screen.
var _curtain_note := ""
## Set just before the refresh that follows the curtain call: the run's coins before
## they doubled, for the end screen to count up from (-1 when there's nothing to count).
var _curtain_roll := -1
## A rebuild asked for while the board was busy (a resize during an ad or the
## scoring), done at the next refresh instead of pulling the board out from under it.
var _rebuild_pending := false
## The finished run is being left for the menu (an intermission may play first).
var _leaving := false

## How long a panel ignores taps after it appears straight after the scoring, or after
## a first tap that asks for a second one (hold_taps).
const TAP_HOLD := 0.35
## At most this many lines on the cash-out's ducats receipt (_receipt).
const RECEIPT_LINES := 7


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()
	Game.changed.connect(refresh)
	Feel.settings_changed.connect(_rebuild_screen)
	get_viewport().size_changed.connect(_rebuild_screen)
	refresh()
	if not Settings.seen_help and Settings.tutorial_step < 0:
		UiTheme.show_sheet(HowToPlay.new())


func _exit_tree() -> void:
	Engine.time_scale = 1.0




func _layout() -> void:
	# Fit inside the safe area (clear of the notch and home indicator on iPhone):
	# scale down if it is shorter than 360, then use all of its width.
	safe = UiTheme.safe_area(self)
	fit = minf(1.0, safe.size.y / 360.0)
	var room := safe.size.x / fit - 8.0
	stage_w = clampf(room, 640.0, MAX_STAGE_WIDTH)
	area_w = stage_w - AREA_X - 4.0
	var k := Settings.card_scale()
	var widen := clampf(area_w / 480.0, 1.0, 1.15)
	hand_card = (HAND_CARD * k * widen).floor()
	hand_card.y = minf(hand_card.y, 108.0)
	jester_card = (JESTER_CARD * minf(k, 1.0)).floor()
	item_card = (ITEM_CARD * minf(k, 1.06)).floor()


func _build_screen() -> void:
	_layout()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	Feel.backdrop(bg)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -stage_w / 2.0
	stage.offset_right = stage_w / 2.0
	stage.offset_top = -180.0
	stage.offset_bottom = 180.0
	stage.pivot_offset = Vector2(stage_w, 360.0) / 2.0
	stage.scale = Vector2(fit, fit)
	var shift := safe.get_center() - get_viewport_rect().size / 2.0
	stage.offset_left += shift.x
	stage.offset_right += shift.x
	stage.offset_top += shift.y
	stage.offset_bottom += shift.y
	add_child(stage)
	_build_side()
	top_row = _area(Vector2(AREA_X, 4), Vector2(area_w, 80))
	middle = _area(Vector2(AREA_X, 86), Vector2(area_w, 104))
	hand_row = _area(Vector2(AREA_X, 190), Vector2(area_w, 134))
	buttons = HBoxContainer.new()
	buttons.position = Vector2(AREA_X, 326)
	buttons.size = Vector2(area_w, 30)
	buttons.add_theme_constant_override("separation", 6)
	stage.add_child(buttons)
	tip = Control.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(tip)
	guide = Guide.new(fit)
	guide.next_pressed.connect(func() -> void: _coach_to(Settings.tutorial_step + 1))
	guide.skip_pressed.connect(func() -> void: _coach_to(-1))
	add_child(guide)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)



func _rebuild_screen() -> void:
	if not is_inside_tree():
		return
	if busy:
		_rebuild_pending = true
		return
	_rebuild_pending = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	hand_layout = {}
	_build_screen()
	refresh()



func restart() -> void:
	selected_hand.clear()
	selection = {}
	custom_order.clear()
	hand_layout = {}
	_encore_note = ""
	_curtain_note = ""
	_curtain_roll = -1
	refresh()


func _area(pos: Vector2, area_size: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = area_size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(c)
	return c


func _build_side() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(4, 4)
	panel.size = Vector2(146, 352)
	stage.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	lbl_place = UiTheme.label("", 11, UiTheme.GOLD)
	lbl_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl_place)
	var target := _block(col, UiTheme.PANEL_DARK, UiTheme.GOLD.darkened(0.35))
	lbl_target_caption = UiTheme.label("", 8, UiTheme.MUTED)
	target.add_child(lbl_target_caption)
	lbl_target = UiTheme.title("", 16, UiTheme.GOLD)
	target.add_child(lbl_target)
	var score := _block(col, UiTheme.PANEL_DARK, UiTheme.PANEL_LIGHT)
	score.add_child(UiTheme.label("Show score", 8, UiTheme.MUTED))
	lbl_score = UiTheme.title("0", 18, UiTheme.TEXT)
	score.add_child(lbl_score)
	lbl_hand = UiTheme.title("", 12, UiTheme.TEXT)
	lbl_hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hand.custom_minimum_size = Vector2(0, 16)
	col.add_child(lbl_hand)
	var pm := HBoxContainer.new()
	pm.add_theme_constant_override("separation", 2)
	lbl_points = _score_box(UiTheme.POINTS)
	lbl_mult = _score_box(UiTheme.MULT)
	pm.add_child(lbl_points.get_parent())
	var times := UiTheme.title("x", 14, UiTheme.TEXT)
	pm.add_child(times)
	pm.add_child(lbl_mult.get_parent())
	col.add_child(pm)
	var counters := HBoxContainer.new()
	counters.add_theme_constant_override("separation", 3)
	lbl_hands = _counter(counters, "Hands", UiTheme.POINTS)
	lbl_discards = _counter(counters, "Discards", UiTheme.MULT)
	lbl_ducats = _counter(counters, "Ducats", UiTheme.GOLD)
	col.add_child(counters)
	var info := _block(col, UiTheme.PANEL_DARK, UiTheme.PANEL_LIGHT)
	info.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_name = UiTheme.label("", 10, UiTheme.GOLD)
	info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_name.custom_minimum_size = Vector2(122, 0)
	info_text = UiTheme.label("", 10)
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_text.custom_minimum_size = Vector2(122, 0)
	info.add_child(info_name)
	info.add_child(info_text)
	# Round icon buttons: pause, run info, how to play.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.icon_button("pause", _pause, 26.0))
	row.add_child(UiTheme.icon_button("info", func() -> void: _open(RunInfoSheet.new()), 26.0))
	row.add_child(UiTheme.icon_button("help", func() -> void: _open(HowToPlay.new()), 26.0))
	col.add_child(row)


func _pause() -> void:
	if not busy:
		_open(PauseSheet.new(self))


func _open(sheet: Control) -> void:
	Feel.play("click")
	UiTheme.show_sheet(sheet)



func _block(parent: Control, bg: Color, border: Color) -> VBoxContainer:
	var box := PanelContainer.new()
	var style := UiTheme.box(bg, border, 10)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	box.add_child(inner)
	parent.add_child(box)
	return inner


func _score_box(colour: Color) -> Label:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.button_box(colour))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UiTheme.title("0", 16, UiTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l



func _counter(parent: Control, caption: String, colour: Color) -> Label:
	var inner := _block(parent, UiTheme.PANEL_DARK, colour.darkened(0.2))
	inner.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var number := UiTheme.title("0", 13, colour)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.clip_text = true
	inner.add_child(number)
	# Captions clip rather than widen the side panel into the hand.
	var l := UiTheme.label(caption, 8, UiTheme.MUTED)
	l.add_theme_font_size_override("font_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(l)
	return number




func refresh() -> void:
	if busy or run == null:
		return
	if _rebuild_pending:
		_rebuild_screen()
		return
	_drop_stale_selection()
	Feel.mood(_mood(), run.town)
	Feel.intensity(_heat())
	Feel.danger(run.phase == RunState.Phase.IN_SHOW and run.hands_left <= 1 and run.show_score < run.show_target)
	Feel.gloom(run.phase == RunState.Phase.LOST)
	_update_side()
	_build_top()
	_build_middle()
	_build_hand()
	_build_buttons()
	_build_tip()
	_build_coach()
	_build_overlay()






## The guided first run, one step at a time. Each step belongs to a phase of the run,
## points at one thing (a button by the start of its label, or an area) and moves on
## by itself once the player has done it; steps with "next" wait for a button instead.
## Settings.tutorial_step is the step reached (-1 when finished or skipped).
const GUIDE := [
	{ "phase": RunState.Phase.CHOOSE_SHOW, "title": "Your first show", "at": "button:Play ",
		"text": "Each town has three shows. Score a show's target to win it. Tap Play %s to begin." },
	{ "phase": RunState.Phase.IN_SHOW, "title": "Make a poker hand", "at": "hand",
		"text": "Tap up to 5 cards to make a poker hand. Pairs, straights and flushes score more. %s" },
	{ "phase": RunState.Phase.IN_SHOW, "title": "Points x Mult", "at": "hand_score", "next": "Next",
		"text": "This is what your hand will score: its Points times its Mult. Every card that scores adds its own Points." },
	{ "phase": RunState.Phase.IN_SHOW, "title": "Play it", "at": "button:Play hand",
		"text": "Tap Play hand to score it. You can also flick a card upward to play." },
	{ "phase": RunState.Phase.IN_SHOW, "title": "Reach the target", "at": "score", "next": "Got it",
		"text": "Your score adds up hand by hand. Beat the target before your hands run out." },
	{ "phase": RunState.Phase.IN_SHOW, "title": "Discards", "at": "button:Discard", "next": "Got it",
		"text": "Nothing good to play? Select the cards you don't want and Discard them to draw new ones. Each show gives you a few." },
	{ "phase": RunState.Phase.CASH_OUT, "title": "Show won!", "at": "button:Cash out",
		"text": "You earn ducats for the win, and every hand you didn't need pays extra. Tap Cash out." },
	{ "phase": RunState.Phase.SHOP, "title": "The Market", "at": "shop_jester", "next": "Not now",
		"text": "Jesters stay with you and boost every hand. Tap one to read what it does, then Buy it." },
	{ "phase": RunState.Phase.SHOP, "title": "Your Jesters", "at": "jesters", "next": "Got it",
		"text": "Your Jesters work on every hand, left to right. Drag one to change the order; tap it to read it or sell it." },
	{ "phase": RunState.Phase.SHOP, "title": "On to the next show", "at": "button:Next show",
		"text": "Done shopping? Go on to the next show. That's everything: the tour is yours. Good luck!" },
]



## Move the guide along to match what the player has already done.
func _advance_coach() -> void:
	var s := Settings.tutorial_step
	if s < 0 or s >= GUIDE.size():
		return
	var p := run.phase
	var played := int(run.counters.get("hands_played", 0)) > 0
	# A lost show ends the guide only once the run is really over. While the Encore is
	# on offer (free in the guided run) the guide waits, and carries on in the show if
	# the player takes it.
	if p == RunState.Phase.LOST and not _encore_on_offer():
		s = -1
	if s == 0 and p != RunState.Phase.CHOOSE_SHOW:
		s = 1
	if s == 1 and (not selected_hand.is_empty() or played):
		s = 2
	if (s == 2 or s == 3) and played:
		s = 4
	if s >= 1 and s <= 5 and (p == RunState.Phase.CASH_OUT or p == RunState.Phase.SHOP):
		s = 6
	if s == 6 and p == RunState.Phase.SHOP:
		s = 7
	if s == 7 and not run.zanni.is_empty():
		s = 8
	if s == 8 and run.zanni.is_empty():
		s = 9
	# Leaving the Market finishes the guide; the How to play sheet isn't needed after it.
	if s >= 7 and p != RunState.Phase.SHOP and p != RunState.Phase.PACK:
		s = -1
		Settings.seen_help = true
	if s != Settings.tutorial_step:
		Settings.tutorial_step = s
		Settings.save()


func _build_coach() -> void:
	if guide == null:
		return
	_advance_coach()
	var s := Settings.tutorial_step
	if busy or s < 0 or s >= GUIDE.size():
		guide.hide_step()
		return
	var shown := s
	# Points x Mult and Play hand need cards picked; with none, point at the hand again.
	if (s == 2 or s == 3) and selected_hand.is_empty():
		shown = 1
	var step: Dictionary = GUIDE[shown]
	if run.phase != step["phase"]:
		guide.hide_step()
		return
	var text := str(step["text"])
	match shown:
		0:
			text = text % SHOW_NAMES[run.show_index]
		1:
			text = text % _suggest_hand()
	var at := str(step["at"])
	if shown == 7 and str(selection.get("zone", "")) == "offer":
		at = "button:Buy"
		text = "Tap Buy to take it. Its price in ducats is on its corner."
	guide.show_step("%d %s" % [shown, text], shown, GUIDE.size(), str(step["title"]), text, str(step.get("next", "")), _guide_rect.bind(at), _guide_marks)


func _coach_to(step: int) -> void:
	Feel.play("click")
	Settings.tutorial_step = step if step < GUIDE.size() else -1
	Settings.save()
	_build_coach()


## Finds the player's best poker hand in the cards held, to ring on the first hand,
## and says what it is.
func _suggest_hand() -> String:
	_suggested = []
	if run.hand.is_empty():
		return ""
	var result := HandEvaluator.evaluate(run.hand)
	var cards := result.scoring.slice(0, 5)
	for card: PlayingCard in cards:
		_suggested.append(card.id)
	if result.type == HandTable.HIGH_CARD:
		return "No pair this time: the ringed card is your highest. Play it, or discard and draw new cards."
	return "The ringed cards make a %s." % _hand_name(result.type)


func _guide_marks() -> Array:
	var out := []
	if Settings.tutorial_step < 0 or Settings.tutorial_step > 3 or not selected_hand.is_empty():
		return out
	for child in hand_row.get_children():
		if child is CardView and not child.is_queued_for_deletion() and _suggested.has((child as CardView).card.id):
			out.append((child as CardView).get_global_rect())
	return out


## Where the guide points, in global coordinates: a button found by the start of its
## label, or one of the named areas of the screen.
func _guide_rect(at: String) -> Rect2:
	if at.begins_with("button:"):
		var prefix := at.substr(7)
		for child in buttons.get_children():
			if child is Button and not child.is_queued_for_deletion() and (child as Button).text.begins_with(prefix):
				return (child as Button).get_global_rect()
		return Rect2()
	var area := Rect2()
	match at:
		"hand":
			for child in hand_row.get_children():
				if child is CardView and not child.is_queued_for_deletion():
					var r := (child as Control).get_global_rect()
					area = r if not area.has_area() else area.merge(r)
		"hand_score":
			area = lbl_hand.get_global_rect().merge((lbl_points.get_parent().get_parent() as Control).get_global_rect())
		"score":
			area = (lbl_target.get_parent().get_parent() as Control).get_global_rect().merge((lbl_score.get_parent().get_parent() as Control).get_global_rect())
		"shop_jester":
			for child in middle.get_children():
				if child is CardView and not child.is_queued_for_deletion() and (child as CardView).tag.get("zone", "") == "offer":
					var v := child as CardView
					if v.kind == "zanni":
						return v.get_global_rect()
					if not area.has_area():
						area = v.get_global_rect()
		"jesters":
			for v: Variant in jester_views:
				if v is CardView and is_instance_valid(v):
					var r := (v as Control).get_global_rect()
					area = r if not area.has_area() else area.merge(r)
	return area




func _mood() -> String:
	match run.phase:
		RunState.Phase.SHOP, RunState.Phase.PACK:
			return "shop"
		RunState.Phase.LOST:
			return "patron"
	return "patron" if run.show_index == Shows.PATRON else "show"




func _heat() -> float:
	match run.phase:
		RunState.Phase.IN_SHOW:
			var k := 0.2 + 0.6 * clampf(run.show_score / maxf(1.0, run.show_target), 0.0, 1.0)
			if run.hands_left <= 1:
				k += 0.25
			if run.show_index == Shows.PATRON:
				k += 0.15
			return k
		RunState.Phase.CASH_OUT:
			return 1.0
	return 0.0



func _drop_stale_selection() -> void:
	selected_hand.assign(selected_hand.filter(func(id: int) -> bool: return _hand_card(id) != null))
	if selection.is_empty():
		return
	var i := int(selection.get("index", -1))
	var shop := run.shop
	var still_there := false
	match str(selection.get("zone", "")):
		"zanni":
			still_there = i < run.zanni.size()
		"consumable":
			still_there = i < run.consumables.size()
		"offer":
			still_there = shop != null and i < shop.offers.size() and not shop.offers[i]["sold"]
		"pack":
			still_there = shop != null and i < shop.packs.size() and not shop.packs[i]["sold"]
		"warrant":
			still_there = shop != null and (run.town_warrant != "" and not run.warrant_bought if i == 0 else shop.extra_warrant != "" and not shop.extra_bought)
		"pack_item":
			still_there = run.phase == RunState.Phase.PACK and i < (run.pack.get("items", []) as Array).size()
	if not still_there:
		selection = {}


func _update_side() -> void:
	var r := run
	var daily := "" if not Game.run_meta.has("daily_date") else ("Daily practice: " if Game.run_meta.get("practice", false) else "Daily: ")
	lbl_place.text = daily + "Town %d - %s" % [r.town, SHOW_NAMES[r.show_index]]
	# While an Encore is on offer the lost show's numbers stay up: they're the decision.
	if r.phase == RunState.Phase.IN_SHOW or _encore_on_offer():
		lbl_target_caption.text = "Score at least"
		lbl_target.text = UiTheme.number(r.show_target)
		lbl_score.text = UiTheme.number(r.show_score)
		lbl_hands.text = str(r.hands_left)
		lbl_discards.text = str(r.discards_left)
	else:
		lbl_target_caption.text = "Next show's target"
		lbl_target.text = UiTheme.number(r.target_for_show(r.show_index))
		lbl_score.text = "0"
		lbl_hands.text = str(r.stat("hands"))
		lbl_discards.text = str(r.stat("discards"))
	lbl_ducats.text = str(r.ducats)
	var preview := _selected_cards()
	if preview.is_empty():
		lbl_hand.text = ""
		lbl_points.text = "0"
		lbl_mult.text = "0"
	else:
		var hand_type := HandEvaluator.evaluate(preview, r.eval_options()).type
		lbl_hand.text = "%s lv.%d" % [_hand_name(hand_type), r.hand_levels.level(hand_type)]
		lbl_points.text = UiTheme.number(r.hand_levels.points(hand_type))
		lbl_mult.text = UiTheme.number(r.hand_levels.mult(hand_type))
	_update_info()


func _update_info() -> void:
	if message != "":
		info_name.text = ""
		info_text.text = message
		return
	if not selection.is_empty():
		var id := _selected_def_id()
		info_name.text = UiTheme.name_of(id) if id != "" else ""
		info_text.text = _describe_selection(id)
	elif selected_hand.size() == 1:
		var card := _hand_card(selected_hand[0])
		info_name.text = _card_name(card)
		info_text.text = _describe_card(card)
	else:
		info_name.text = ""
		info_text.text = _phase_hint()


func _phase_hint() -> String:
	match run.phase:
		RunState.Phase.CHOOSE_SHOW:
			return "Play this show, or skip it to take its Favor."
		RunState.Phase.IN_SHOW:
			return "Select up to 5 cards, then Play or Discard."
		RunState.Phase.CASH_OUT:
			return "The show is won. Collect your ducats."
		RunState.Phase.SHOP:
			return "Tap a card to read it, then Buy."
		RunState.Phase.PACK:
			return "Choose %d. Tarocchi and Omens use the cards you select below." % int(run.pack.get("picks", 1))
	return ""




func _build_top() -> void:
	_clear(top_row)
	jester_views.clear()
	var r := run
	var step := minf(57.0, (area_w - 110.0 - jester_card.x) / maxf(1.0, r.zanni.size() - 1))
	for i in r.zanni.size():
		var z := r.zanni[i]
		var v := _named_view("zanni", z.def_id, jester_card, { "zone": "zanni", "index": i })
		v.edition = z.edition
		v.dimmed = z.debuffed
		v.face_down = z.face_down
		v.sticker = "eternal" if z.state.get("eternal", false) else ("perishable" if z.state.has("perish") else ("rented" if z.state.get("rented", false) else ""))
		v.position = Vector2(i * step, 0)
		v.sway = i + 3
		v.draggable = not busy and r.zanni.size() > 1
		v.drag_moved.connect(func(view: CardView, at: Vector2) -> void:
			view.position.x = clampf(at.x - top_row.global_position.x - jester_card.x / 2.0, 0.0, area_w - 110.0 - jester_card.x))
		v.drag_ended.connect(_on_jester_drop)
		top_row.add_child(v)
		jester_views.append(v)
	var count := UiTheme.label("Jesters %d/%d" % [r.zanni.size(), r.stat("zanni_slots")], 8, UiTheme.MUTED)
	count.position = Vector2(0, 72)
	top_row.add_child(count)
	for i in r.consumables.size():
		var c := r.consumables[i]
		var v := _named_view(c.def().kind, c.def_id, item_card, { "zone": "consumable", "index": i })
		v.edition = c.edition
		v.position = Vector2(area_w - 100 + i * 50, 4)
		v.sway = i + 9
		top_row.add_child(v)
	var ccount := UiTheme.label("One-use cards %d/%d" % [r.consumables.size(), r.stat("consumable_slots")], 8, UiTheme.MUTED)
	ccount.position = Vector2(area_w - 100, 72)
	top_row.add_child(ccount)




func _build_tip() -> void:
	_clear(tip)
	var zone := str(selection.get("zone", ""))
	if busy or not (zone == "zanni" or zone == "consumable"):
		return
	var i := int(selection["index"])
	var item: ItemCard = run.zanni[i] if zone == "zanni" else run.consumables[i]
	var def := item.def()
	var panel := PanelContainer.new()
	var border: Color = CardView.RARITY_COLOURS[clampi(def.rarity, 0, 3)] if def.kind == "zanni" else CardView.KIND_COLOURS.get(def.kind, UiTheme.PANEL_LIGHT)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL_DARK, border.lightened(0.2)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var big := CardView.new(Vector2(80, 112))
	big.kind = def.kind
	big.def_id = def.id
	big.edition = item.edition
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(big)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UiTheme.title(UiTheme.name_of(def.id), 13, UiTheme.GOLD))
	var what: String = KIND_HELP.get(def.kind, "").get_slice(":", 0)
	if def.kind == "zanni":
		what = CardView.RARITY_NAMES[clampi(def.rarity, 0, 3)] + " " + what
	col.add_child(UiTheme.label(what, 8, border.lightened(0.35)))
	var text := UiTheme.label(UiTheme.text_of(def.id), 10)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(176, 0)
	col.add_child(text)
	tip.add_child(panel)
	var x: float = AREA_X + ((jester_views[i] as Control).position.x if zone == "zanni" else area_w - 100 + i * 50)
	panel.position = Vector2(clampf(x - 20.0, AREA_X, AREA_X + area_w - 290.0), 84.0)
	if not Settings.reduce_motion:
		panel.modulate.a = 0.0
		panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)


func _named_view(kind: String, def_id: String, view_size: Vector2, tag: Dictionary) -> CardView:
	var v := CardView.new(view_size)
	v.kind = kind
	v.def_id = def_id
	v.tag = tag
	v.selected = _same(selection, tag)
	v.tapped.connect(_on_tap)
	v.long_pressed.connect(_show_detail)
	return v




func _on_jester_drop(view: CardView, _at: Vector2) -> void:
	var order := range(jester_views.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (jester_views[a] as CardView).position.x < (jester_views[b] as CardView).position.x)
	if order == range(jester_views.size()):
		refresh()
		return
	_act({ "a": "reorder_zanni", "order": order })
	selection = { "zone": "zanni", "index": order.find(int(view.tag["index"])) }
	refresh()



func _show_detail(view: CardView) -> void:
	Feel.play("select")
	Feel.buzz(12)
	var big := CardView.new(Vector2(110, 154))
	big.kind = view.kind
	big.card = view.card
	big.def_id = view.def_id
	big.edition = view.edition
	big.sticker = view.sticker
	big.face_down = false
	var heading := ""
	var lines := []
	if view.kind == "card":
		heading = _card_name(view.card)
		lines = ["Playing card", _describe_card(view.card)]
	else:
		var def := ContentDB.get_def(view.def_id)
		heading = UiTheme.name_of(view.def_id)
		var what: String = KIND_HELP.get(view.kind, "")
		if def != null and view.kind == "zanni":
			what = CardView.RARITY_NAMES[clampi(def.rarity, 0, 3)] + " " + what
		lines = [what.get_slice(":", 0), UiTheme.text_of(view.def_id)]
		var gloss := TranslationServer.translate(view.def_id + ".gloss")
		if gloss != view.def_id + ".gloss":
			lines.append("(" + gloss + ")")
		if view.edition != "":
			lines.append("%s: %s" % [UiTheme.name_of(view.edition), UiTheme.text_of(view.edition)])
		if what.contains(":"):
			var how := what.get_slice(":", 1).strip_edges()
			lines.append(how.left(1).to_upper() + how.substr(1))
	UiTheme.show_sheet(DetailSheet.new(big, heading, lines))




func _build_middle() -> void:
	_clear(middle)
	match run.phase:
		RunState.Phase.CHOOSE_SHOW:
			_middle_shows()
		RunState.Phase.IN_SHOW:
			_middle_show_info()
		RunState.Phase.CASH_OUT:
			_middle_payout()
		RunState.Phase.SHOP:
			_middle_shop()
		RunState.Phase.PACK:
			_middle_pack()


func _middle_shows() -> void:
	# The town as a board: a path through the Matinee, the Evening show and the Patron.
	var track := ShowTrack.new()
	# Uses the empty hand row too: no cards are dealt while you choose a show.
	track.size = Vector2(area_w, 165)
	track.setup(run, SHOW_NAMES, SHOW_COLOURS, _favor_text)
	middle.add_child(track)


func _favor_text(slot: int) -> String:
	var text := UiTheme.text_of(run.town_favors[slot])
	var note := run.town_favor_notes[slot]
	return text if note == "" else "%s (%s)" % [text, _hand_name(note)]



func _middle_show_info() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(0, 2)
	col.size = Vector2(area_w, 102)
	col.add_theme_constant_override("separation", 4)
	middle.add_child(col)
	# The goal, always in view: the score to beat, progress and hands left.
	var goal := GoalBar.new()
	goal.title = "%s  ·  Beat %s" % [SHOW_NAMES[run.show_index], UiTheme.number(run.show_target)]
	goal.score = run.show_score
	goal.target = run.show_target
	goal.hands = run.hands_left
	goal.colour = (SHOW_COLOURS[run.show_index] as Color).darkened(0.05)
	col.add_child(goal)
	var patron := run.current_patron()
	if patron != "":
		var l := _wrapped("%s: %s" % [UiTheme.name_of(patron), UiTheme.text_of(patron)], 10, area_w)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UiTheme.MULT.lightened(0.25))
		col.add_child(l)
	var preview := _selected_cards()
	if preview.is_empty():
		col.add_child(_centred(UiTheme.title("Tap up to 5 cards, then press Play hand", 12, UiTheme.TEXT)))
	else:
		var hand_type := HandEvaluator.evaluate(preview, run.eval_options()).type
		col.add_child(_centred(UiTheme.title(_hand_name(hand_type), 24, UiTheme.GOLD)))
		var guess := run.preview(_selected_ids())
		if guess >= 0.0:
			var wins := guess >= run.show_target - run.show_score
			var line := "Scores about %s%s" % [UiTheme.number(guess), "  -  enough to win the show!" if wins else ""]
			col.add_child(_centred(UiTheme.label(line, 12, UiTheme.GOOD if wins else UiTheme.TEXT)))


func _middle_payout() -> void:
	# The ducats the show paid (to spend in the Market) beside the coins it paid (kept
	# for good), on two cards so the two currencies never blur together. The hand row
	# is empty at a cash-out, so the cards may reach down into it (it lets taps through
	# while it is empty, see _build_hand); the receipt is kept short enough to stay
	# clear of the Cash out button.
	var col := VBoxContainer.new()
	col.position = Vector2(0, 4)
	col.size = Vector2(area_w, 0)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(col)
	if run.won and not Game.win_seen:
		col.add_child(_centred(UiTheme.title("The tour is won!", 16, UiTheme.GOLD)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(_ducats_card())
	var paid := _show_coins()
	if not paid.is_empty():
		var bonus := int(Game.run_meta.get("win_coins", 0)) if run.won and not Game.win_seen else 0
		row.add_child(RunCoins.new(paid, bonus))


## The ducats the show paid, line by line like a receipt, and the total.
func _ducats_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL_DARK, UiTheme.GOLD.darkened(0.35)))
	card.custom_minimum_size = Vector2(196, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	card.add_child(lines)
	lines.add_child(UiTheme.label("Ducats", 9, UiTheme.MUTED))
	var total := 0
	for p in run.payout:
		total += int(p["v"])
	for line: Array in _receipt():
		lines.add_child(_receipt_line(str(line[0]), "%+d" % int(line[1]), 10, UiTheme.TEXT))
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.16)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(rule)
	lines.add_child(_receipt_line("Total", "%+d ducats" % total, 12, UiTheme.GOLD))
	return card


func _receipt_line(caption: String, value: String, font_size: int, colour: Color) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var key := UiTheme.label(caption, font_size, colour)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(key)
	line.add_child(UiTheme.label(value, font_size, colour))
	return line


## The receipt's lines as [name, ducats]. Every held Gilt card pays on its own line in
## the run, and every rented Jester charges its rent, so those are added up into one
## line each, after the show's own lines and before the Jesters that pay; past
## RECEIPT_LINES the last lines fold into "Others". That keeps a long cash-out clear
## of the Cash out button, even with larger text.
func _receipt() -> Array:
	var lines: Array = []
	var jesters: Array = []
	var gilt := [0, 0]
	var rent := [0, 0]
	for p in run.payout:
		var src := str(p["src"])
		var v := int(p["v"])
		if src.begins_with("card:"):
			gilt[0] += 1
			gilt[1] += v
		elif v < 0 and _rented(src):
			rent[0] += 1
			rent[1] += v
		elif src in ["show", "hands", "discards", "interest"]:
			lines.append([_payout_name(src), v])
		else:
			jesters.append([_payout_name(src), v])
	for group: Array in [["Gilt card", gilt], ["Rent", rent]]:
		var counted: Array = group[1]
		if int(counted[0]) > 0:
			lines.append([str(group[0]) + (" x%d" % int(counted[0]) if int(counted[0]) > 1 else ""), int(counted[1])])
	lines.append_array(jesters)
	if lines.size() > RECEIPT_LINES:
		var others := 0
		for line: Array in lines.slice(RECEIPT_LINES - 1):
			others += int(line[1])
		lines = lines.slice(0, RECEIPT_LINES - 1)
		lines.append(["Others", others])
	return lines


## Whether a payout line's source ("zanni:<id>#<slot>") is a rented Jester.
func _rented(src: String) -> bool:
	if not src.begins_with("zanni:"):
		return false
	var slot := int(src.get_slice("#", 1))
	return slot >= 0 and slot < run.zanni.size() and bool(run.zanni[slot].state.get("rented", false))


## What the show just won paid in coins ({show, coins, first_win}), or {} when it paid
## none, e.g. a run saved before coins existed.
func _show_coins() -> Dictionary:
	var paid: Variant = Game.run_meta.get("show_coins")
	if paid is Dictionary and str((paid as Dictionary).get("show", "")) == "%d:%d" % [run.town, run.show_index]:
		return paid
	return {}


func _payout_name(src: String) -> String:
	match src:
		"show":
			return "Show reward"
		"hands":
			return "Unused hands"
		"discards":
			return "Unused discards"
		"interest":
			return "Interest"
	if src.begins_with("zanni:"):
		return UiTheme.name_of(src.get_slice(":", 1).get_slice("#", 0))
	if src.begins_with("card:"):
		return "Gilt card"
	return src




func _middle_shop() -> void:
	var r := run
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(UiTheme.PANEL_DARK, 0.92), UiTheme.GOOD.darkened(0.35)))
	panel.size = Vector2(area_w, 236)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(panel)
	var heading := _centred(UiTheme.title("The Market", 18, UiTheme.GOLD))
	heading.position = Vector2(0, 4)
	heading.size = Vector2(area_w, 24)
	middle.add_child(heading)
	middle.add_child(_section("Cards", 14, 28))
	var x := 14.0
	for i in r.shop.offers.size():
		var o: Dictionary = r.shop.offers[i]
		if o["sold"]:
			continue
		var v: CardView
		if o["kind"] == "card":
			v = CardView.new(SHOP_CARD)
			v.card = _card_from(o["card"])
			v.tag = { "zone": "offer", "index": i }
			v.selected = _same(selection, v.tag)
			v.tapped.connect(_on_tap)
			v.long_pressed.connect(_show_detail)
		else:
			v = _named_view(o["kind"], o["id"], SHOP_CARD, { "zone": "offer", "index": i })
			v.edition = o["edition"]
			v.sticker = str(o.get("sticker", "rented" if o.get("rented", false) else ""))
		v.price_text = str(r.offer_price(o))
		v.position = Vector2(x, 42)
		v.sway = i
		middle.add_child(v)
		x += 70
	middle.add_child(_section("Packs", 14, 132))
	x = 14.0
	for i in r.shop.packs.size():
		var p: Dictionary = r.shop.packs[i]
		if p["sold"]:
			continue
		var v := _named_view("pack", p["id"], SHOP_CARD, { "zone": "pack", "index": i })
		v.price_text = str(r.offer_price(p))
		v.position = Vector2(x, 146)
		v.sway = i + 4
		middle.add_child(v)
		x += 70
	x = maxf(x + 24, 200)
	middle.add_child(_section("Warrant", x, 132))
	var warrants := [[r.town_warrant, r.warrant_bought, 0], [r.shop.extra_warrant, r.shop.extra_bought, 1]]
	for w in warrants:
		if w[0] == "" or w[1]:
			continue
		var v := _named_view("warrant", w[0], SHOP_CARD, { "zone": "warrant", "index": w[2] })
		v.price_text = str(ContentDB.get_def(w[0]).cost)
		v.position = Vector2(x, 146)
		v.sway = int(w[2]) + 7
		middle.add_child(v)
		x += 70


func _middle_pack() -> void:
	var items: Array = run.pack.get("items", [])
	middle.add_child(_section("%s: choose %d" % [UiTheme.name_of(run.pack["id"]), int(run.pack["picks"])], 0))
	for i in items.size():
		var entry: Dictionary = items[i]
		var v: CardView
		if entry["kind"] == "card":
			v = CardView.new(item_card)
			v.card = _card_from(entry["card"])
			v.tag = { "zone": "pack_item", "index": i }
			v.selected = _same(selection, v.tag)
			v.tapped.connect(_on_tap)
			v.long_pressed.connect(_show_detail)
		else:
			v = _named_view(entry["kind"], entry["id"], item_card, { "zone": "pack_item", "index": i })
			v.edition = str(entry.get("edition", ""))
		v.position = Vector2(i * 56, 16)
		middle.add_child(v)


func _section(text: String, x: float, y := 0.0) -> Label:
	var l := UiTheme.label(text, 10, UiTheme.MUTED)
	l.position = Vector2(x, y)
	return l







func _build_hand() -> void:
	_clear(hand_row)
	var holds_cards := busy or run.phase == RunState.Phase.IN_SHOW or run.phase == RunState.Phase.PACK
	# The hand row sits above the middle area, which reaches down into it when there's
	# no hand: the Market's packs and Warrant, the cash-out cards. Empty, it lets taps
	# through to them instead of swallowing them.
	hand_row.mouse_filter = Control.MOUSE_FILTER_PASS if holds_cards else Control.MOUSE_FILTER_IGNORE
	if not holds_cards:
		hand_layout = {}
		return
	var previous := hand_layout
	hand_layout = {}
	var cards := _sorted_hand()
	var step := _hand_step(cards.size())
	var left := (area_w - (step * (cards.size() - 1) + hand_card.x)) / 2.0
	var rest_y := hand_row.size.y - hand_card.y - 6.0
	var forced := int(run.show_counters.get("forced", -1)) if run.phase == RunState.Phase.IN_SHOW else -1
	var dealt := 0
	for i in cards.size():
		var card: PlayingCard = cards[i]
		var v := CardView.new(hand_card)
		v.card = card
		v.edition = card.edition
		v.face_down = card.face_down
		v.dimmed = card.debuffed
		v.selected = selected_hand.has(card.id) or card.id == forced
		v.tag = { "zone": "hand", "id": card.id }
		var to := Vector2(left + i * step, rest_y - 20.0 if v.selected else rest_y)
		hand_layout[card.id] = to
		v.sway = i
		v.draggable = not busy
		v.swipeable = not busy and run.phase == RunState.Phase.IN_SHOW
		v.tapped.connect(_on_tap)
		v.long_pressed.connect(_show_detail)
		v.drag_moved.connect(_on_hand_drag)
		v.drag_ended.connect(_on_hand_drop)
		v.swiped.connect(_on_swipe)
		hand_row.add_child(v)
		if Settings.reduce_motion:
			v.position = to
		elif previous.has(card.id):
			v.position = previous[card.id]
			if v.position != to:
				v.create_tween().tween_property(v, "position", to, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			v.position = Vector2(area_w + 30, rest_y)
			v.modulate.a = 0.0
			var t := v.create_tween().set_parallel()
			t.tween_property(v, "position", to, 0.28).set_delay(dealt * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(v, "modulate:a", 1.0, 0.12).set_delay(dealt * 0.05)
			dealt += 1
	if dealt > 0 and not previous.is_empty():
		Feel.play("deal", 1.1)



func _hand_step(count: int) -> float:
	return minf(hand_card.x + 6.0, (area_w - hand_card.x) / maxf(1.0, count - 1))





func _sorted_hand() -> Array:
	var cards: Array = (held_while_scoring if busy else run.hand).duplicate()
	if sort_by == "rank":
		cards.sort_custom(func(a: PlayingCard, b: PlayingCard) -> bool:
			return a.rank > b.rank if a.rank != b.rank else a.suit < b.suit)
	elif sort_by == "suit":
		cards.sort_custom(func(a: PlayingCard, b: PlayingCard) -> bool:
			return a.suit < b.suit if a.suit != b.suit else a.rank > b.rank)
	else:
		var rank_of := func(c: PlayingCard) -> int:
			var at := custom_order.find(c.id)
			return at if at >= 0 else 1000 + c.id
		cards.sort_custom(func(a: PlayingCard, b: PlayingCard) -> bool: return rank_of.call(a) < rank_of.call(b))
	return cards



func _on_hand_drag(view: CardView, at: Vector2) -> void:
	var local_x := at.x - hand_row.global_position.x - hand_card.x / 2.0
	view.position.x = clampf(local_x, -10.0, area_w - hand_card.x + 10.0)
	var order := _drag_order(view)
	var step := _hand_step(order.size())
	var left := (area_w - (step * (order.size() - 1) + hand_card.x)) / 2.0
	for child in hand_row.get_children():
		if child is CardView and child != view and not child.is_queued_for_deletion():
			var slot := order.find(int(child.tag["id"]))
			child.position.x = lerpf(child.position.x, left + slot * step, 0.35)



func _on_hand_drop(view: CardView, _at: Vector2) -> void:
	custom_order.assign(_drag_order(view))
	sort_by = "custom"
	Feel.play("deal")
	refresh()



func _drag_order(view: CardView) -> Array:
	var views := hand_row.get_children().filter(func(c: Node) -> bool: return c is CardView and not c.is_queued_for_deletion())
	views.sort_custom(func(a: CardView, b: CardView) -> bool:
		var ax := a.position.x if a != view else view.position.x
		var bx := b.position.x if b != view else view.position.x
		return ax < bx)
	return views.map(func(c: CardView) -> int: return int(c.tag["id"]))



func _on_swipe(view: CardView, direction: int) -> void:
	if busy or run.phase != RunState.Phase.IN_SHOW:
		return
	var id := int(view.tag["id"])
	if not selected_hand.has(id) and selected_hand.size() < maxi(5, run.stat("max_play")):
		selected_hand.append(id)
	if direction > 0 and run.hands_left > 0:
		_on_play()
	elif direction < 0 and run.discards_left > 0:
		_on_discard()
	else:
		Feel.play("error")
		refresh()



func _selected_cards() -> Array[PlayingCard]:
	var out: Array[PlayingCard] = []
	for card in _sorted_hand():
		if selected_hand.has(card.id):
			out.append(card)
	return out


func _selected_ids() -> Array:
	return _selected_cards().map(func(c: PlayingCard) -> int: return c.id)




func _build_buttons() -> void:
	_clear(buttons)
	primary = Callable()
	var r := run
	match r.phase:
		RunState.Phase.CHOOSE_SHOW:
			_add_button("Play " + SHOW_NAMES[r.show_index], func() -> void: _act({ "a": "select_show" }), false, UiTheme.MULT, true)
			if r.show_index < Shows.PATRON:
				_add_button("Skip for the Favor", func() -> void: _act({ "a": "skip_show" }))
			if r.town_swaps < r.stat("patron_swaps"):
				_add_button("Swap Patron (10)", func() -> void: _act({ "a": "swap_patron" }))
		RunState.Phase.IN_SHOW:
			var picked := selected_hand.size()
			_add_button("Play hand", _on_play, picked == 0 or picked > r.stat("max_play"), UiTheme.POINTS, true)
			_add_button("Discard", _on_discard, picked == 0, UiTheme.MULT)
			_add_button("Sort by suit" if sort_by == "rank" else "Sort by rank", _toggle_sort)
		RunState.Phase.CASH_OUT:
			var total := 0
			for p in r.payout:
				total += int(p["v"])
			_add_button("Cash out %+d" % total, func() -> void: _act({ "a": "cash_out" }), false, UiTheme.GOLD.darkened(0.25), true)
		RunState.Phase.SHOP:
			_add_button("Next show", _leave_market, false, UiTheme.MULT)
			_add_button("Reroll %d" % r.reroll_price(), func() -> void: _act({ "a": "reroll" }), false, UiTheme.GOOD.darkened(0.3))
		RunState.Phase.PACK:
			if selection.get("zone", "") == "pack_item":
				_add_button("Pick", func() -> void: _act({ "a": "pick", "index": selection["index"], "cards": _selected_ids() }), false, UiTheme.POINTS, true)
			_add_button("Skip pack", func() -> void: _act({ "a": "skip_pack" }))
	_contextual_buttons()
	if r.phase == RunState.Phase.IN_SHOW:
		_add_deck_pile()




func _add_deck_pile() -> void:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	var pile := CardView.new(Vector2(20, 28))
	pile.face_down = true
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(pile)
	_add_button("Deck %d" % run.draw_pile.size(), func() -> void: _open(RunInfoSheet.new("deck")))


func _contextual_buttons() -> void:
	var zone := str(selection.get("zone", ""))
	var i := int(selection.get("index", -1))
	match zone:
		"zanni":
			var z := run.zanni[i]
			if not z.state.get("eternal", false):
				_add_button("Sell +%d" % z.sell_value(), func() -> void: _act({ "a": "sell", "zone": "zanni", "index": i }))
			_add_button("<", func() -> void: _move_jester(i, -1), i == 0)
			_add_button(">", func() -> void: _move_jester(i, 1), i == run.zanni.size() - 1)
		"consumable":
			_add_button("Use", func() -> void: _act({ "a": "use", "index": i, "cards": _selected_ids() }))
			_add_button("Sell +%d" % run.consumables[i].sell_value(), func() -> void: _act({ "a": "sell", "zone": "consumable", "index": i }))
		"offer":
			_add_button("Buy", func() -> void: _act({ "a": "buy", "slot": i }), false, UiTheme.GOLD.darkened(0.25), true)
		"pack":
			_add_button("Buy & open", func() -> void: _act({ "a": "buy_pack", "slot": i }), false, UiTheme.GOLD.darkened(0.25), true)
		"warrant":
			_add_button("Buy", func() -> void: _act({ "a": "buy_warrant", "index": i }), false, UiTheme.GOLD.darkened(0.25), true)



func _add_button(text: String, on_press: Callable, disabled := false, colour := Color.TRANSPARENT, main := false) -> void:
	var b := UiTheme.button(text, on_press, 11, colour)
	b.disabled = disabled or busy
	b.custom_minimum_size.y = 30
	buttons.add_child(b)
	if main and not b.disabled and not primary.is_valid():
		primary = on_press




func _build_overlay() -> void:
	_clear(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := run
	var lost := r.phase == RunState.Phase.LOST
	var just_won := r.won and not Game.win_seen and r.phase == RunState.Phase.SHOP
	var kind := ""
	if lost:
		kind = "encore" if _encore_on_offer() else "lost"
	elif just_won:
		kind = "won"
	var fresh := kind != _overlay_kind
	_overlay_kind = kind
	if fresh:
		_encore_note = ""
		_curtain_note = ""
	if kind == "":
		return
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	# Lighter behind the Encore, so the lost show's score and target stay readable.
	shade.color = Color(0, 0, 0, 0.6 if kind == "encore" else 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	if kind == "encore":
		_build_encore(fresh)
		return
	var accent := UiTheme.MULT if lost else UiTheme.GOLD
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL, accent.darkened(0.2)))
	panel.position = Vector2(110, 34)
	panel.size = Vector2(420, 0)
	# Near the top as before, but lifted when a long one (many Jesters, the coins line,
	# larger text) would run off the bottom.
	panel.resized.connect(func() -> void: panel.position.y = clampf((UiTheme.STAGE.y - panel.size.y) / 2.0, 4.0, 34.0))
	UiTheme.stage(overlay).add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(_centred(UiTheme.title("The show is over" if lost else "All %d towns conquered!" % r.final_town(), 24, accent)))
	var what := UiTheme.name_of(r.challenge) if r.challenge != "" else "%s, Stake %d" % [UiTheme.name_of(r.deck_id), r.stake]
	col.add_child(_centred(UiTheme.label("Town %d - %s   |   %s" % [r.town, SHOW_NAMES[r.show_index], what], 10, UiTheme.MUTED)))
	if lost:
		# One line about this run (a Sign still held, discards left, the favourite hand), or none.
		var tip := Tips.insight_line(r, 392.0)
		if tip != null:
			col.add_child(tip)
	col.add_child(RunCoins.end_row(Game.run_meta, _curtain_call_open(), _on_curtain_call, not Game.recorded, _curtain_roll))
	_curtain_roll = -1
	if _curtain_note != "":
		col.add_child(_centred(UiTheme.label(_curtain_note, 9, UiTheme.MULT.lightened(0.4))))
	col.add_child(_end_stats(r))
	if not r.zanni.is_empty():
		col.add_child(UiTheme.label("Your Jesters", 9, UiTheme.MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for z in r.zanni:
			var v := CardView.new(Vector2(40, 56))
			v.kind = "zanni"
			v.def_id = z.def_id
			v.edition = z.edition
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(v)
		col.add_child(row)
	var daily := Game.run_meta.has("daily_date")
	var ranked: bool = daily and not Game.run_meta.get("practice", false)
	if ranked:
		col.add_child(_centred(UiTheme.label("Your daily run is handed in." if Online.signed_in() else "Log in to rank your daily runs.", 10, UiTheme.GOOD)))
	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 6)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons_row)
	# A won run may tour on until it is finished (by Main menu or the curtain call);
	# after that, the end screen offers what the run-over screen does.
	if lost or Game.recorded:
		buttons_row.add_child(UiTheme.button("Practise this daily" if daily else "New run", func() -> void:
			if busy:
				return
			Feel.play("play")
			Game.restart()
			restart(), 13, UiTheme.MULT))
	else:
		buttons_row.add_child(UiTheme.button("Keep touring", func() -> void:
			if busy:
				return
			Game.win_seen = true
			refresh(), 13, UiTheme.MULT))
	if daily:
		buttons_row.add_child(UiTheme.button("Leaderboards", func() -> void: _open(LeaderboardSheet.new("daily")), 12, UiTheme.GOLD.darkened(0.3)))
	buttons_row.add_child(UiTheme.button("Main menu", _leave_to_menu, 12, UiTheme.POINTS))
	if fresh:
		_pop_in(panel)
		hold_taps(panel)


## Overlay panels scale up and fade in when they first appear.
func _pop_in(panel: Control) -> void:
	if Settings.reduce_motion:
		return
	panel.pivot_offset = panel.size / 2.0
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var t := panel.create_tween().set_parallel()
	t.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.18)


## Ignore taps on `panel` (a PanelContainer) for `seconds`: a clear blocker covers its
## content and catches every tap until it goes. The end panels appear straight after
## the last hand's scoring, which players hurry along by tapping again and again, and
## a tap meant for that must not land on a button that spends coins, starts an ad or
## ends the run. Also used after a first tap that asks for a second, so a double tap
## can't count as both. Timed in real seconds, with or without reduced motion.
static func hold_taps(panel: Control, seconds := TAP_HOLD) -> void:
	if not panel.is_inside_tree():
		return
	var blocker := Control.new()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(blocker)
	panel.get_tree().create_timer(seconds, true, false, true).timeout.connect(blocker.queue_free)


## Main menu from a finished run (lost, or won and left). The end of a run is one of
## the two natural breaks where an intermission may play first; AdPolicy decides, and
## usually nothing shows.
func _leave_to_menu() -> void:
	if _leaving or busy:
		return
	_leaving = true
	Game.finish_run()
	await Ads.intermission("run_end")
	back_to_menu.emit()


## Whether to offer the curtain call on the end screen: the run's show and win coins
## doubled once, after a rewarded ad (Game.can_double_run_coins, which needs the run
## finished). A won run isn't finished while it may still tour on, so there the offer
## stands whenever there are coins to double, and taking it finishes the run first.
func _curtain_call_open() -> bool:
	var meta := Game.run_meta
	var doubled := bool(meta.get("doubled", false))
	var can_double := Game.can_double_run_coins() if Game.recorded \
		else _overlay_kind == "won" and int(meta.get("doublable", 0)) > 0 and not doubled
	return can_double and Ads.can_offer("double_coins", { "double_used": doubled })


## The curtain call: a rewarded ad, then the run's show and win coins paid once more and
## counted up on the end screen. The board holds still while the ad plays; nothing
## changes unless it played to the end.
func _on_curtain_call() -> void:
	if busy or _leaving or not _curtain_call_open():
		return
	Feel.play("click")
	busy = true
	var watched: bool = await Ads.show_rewarded("double_coins", { "double_used": bool(Game.run_meta.get("doubled", false)) })
	busy = false
	if not is_inside_tree():
		return
	if not watched:
		_curtain_note = "The ad didn't play to the end, so the coins weren't doubled."
		refresh()
		return
	# Doubling is for a finished run: on the win screen, this is where it finishes.
	Game.finish_run()
	var before := int(Game.run_meta.get("run_coins", 0))
	if Game.double_run_coins() > 0:
		_curtain_roll = before
		Feel.play("cash")
		Feel.buzz(20)
	refresh()


## Whether the Encore panel belongs on screen: the show is lost, the run may play on,
## and the player hasn't said No thanks (that finishes the run, which Game.encore_open
## doesn't look at, so `recorded` is checked here too).
func _encore_on_offer() -> bool:
	return run != null and run.phase == RunState.Phase.LOST and Game.encore_open() and not Game.recorded


## The Encore offer, in place of the run-over screen. It comes back as it was when the
## app is reopened on a lost run that may still take one (Game.continue_run).
func _build_encore(fresh: bool) -> void:
	var panel := EncorePanel.new(run, _encore_note)
	panel.chose.connect(_take_encore)
	panel.declined.connect(_decline_encore)
	panel.resized.connect(func() -> void: panel.position = ((UiTheme.STAGE - panel.size) / 2.0).floor())
	UiTheme.stage(overlay).add_child(panel)
	if fresh:
		Feel.play("show")
		_pop_in(panel)
		hold_taps(panel)


## Takes the Encore the way the player chose: "ad" (it has to play to the end first),
## "coins" (Game.take_encore checks the wallet) or "free" in the guided first run.
## On success the lost show goes on, with the board back and a fresh hand dealt.
func _take_encore(paid_with: String) -> void:
	if busy or not _encore_on_offer():
		return
	Feel.play("click")
	if paid_with == "ad":
		if not Ads.can_offer("encore", EncorePanel.ad_context(run)):
			_encore_note = "No ad is available right now."
			refresh()
			return
		busy = true
		var watched: bool = await Ads.show_rewarded("encore", EncorePanel.ad_context(run))
		busy = false
		if not is_inside_tree():
			return
		if not watched:
			_encore_note = "The ad didn't play to the end, so there's no Encore yet."
			refresh()
			return
	var reason := Game.take_encore(paid_with)
	if reason != "":
		Feel.play("error")
		_encore_note = reason
		refresh()
		return
	# Game.take_encore has already refreshed the board into the show again.
	if paid_with == "coins":
		Feel.play("buy")
	_encore_fanfare()


## No thanks: the run ends, and the usual run-over screen takes the Encore's place.
func _decline_encore() -> void:
	if busy or not _encore_on_offer():
		return
	Feel.play("click")
	Game.decline_encore()


## The crowd cheers the Encore in: applause, a banner over the board, the new cards
## dealt and the extra hand and discard flying up from their counters. Nothing here
## waits, so the player can go straight on.
func _encore_fanfare() -> void:
	Feel.play("applause")
	Feel.play("deal", 1.1)
	Feel.buzz(30)
	Feel.celebrate(0.4)
	Feel.flash(UiTheme.GOLD, 0.35)
	var l := UiTheme.title("Encore!", 38, UiTheme.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(area_w, 56)
	l.position = Vector2(AREA_X, 104)
	l.pivot_offset = l.size / 2.0
	stage.add_child(l)
	var t := l.create_tween()
	if not Settings.reduce_motion:
		l.scale = Vector2(0.2, 0.2)
		l.rotation = -0.15
		t.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(l, "rotation", 0.0, 0.3)
	t.tween_interval(0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)
	# The side counters are narrow, so each just gets its "+1" in its own colour.
	for pair: Array in [[lbl_hands, Economy.ENCORE_HANDS, UiTheme.POINTS], [lbl_discards, Economy.ENCORE_DISCARDS, UiTheme.MULT]]:
		var counter := (pair[0] as Label).get_parent().get_parent() as Control
		Feel.float_text("+%d" % int(pair[1]), counter.get_global_rect().get_center() - Vector2(0, 18), (pair[2] as Color).lightened(0.3), 14)
		if not Settings.reduce_motion:
			_punch(counter)



func _end_stats(r: RunState) -> GridContainer:
	var most := ""
	for hand_type in HandTable.ORDER:
		if r.hand_levels.times_played(hand_type) > (r.hand_levels.times_played(most) if most != "" else 0):
			most = hand_type
	var stats := [
		# A town is conquered when its Patron falls (the win screen shows in the final
		# town, so town - 1 would count one short).
		["Towns conquered", str(int(r.counters.get("patrons_beaten", 0)))] if r.won else ["Towns reached", str(r.town)],
		["Best hand", UiTheme.number(float(r.counters.get("best_hand", 0)))],
		["Shows won", str(int(r.counters.get("shows_won", 0)))],
		["Hands played", str(int(r.counters.get("hands_played", 0)))],
		["Most played", _hand_name(most) if most != "" else "-"],
		["Cards bought", str(int(r.counters.get("purchases", 0)))],
		["Ducats", str(r.ducats)],
		["Seed", r.seed_text],
	]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	for s in stats:
		var key := UiTheme.label(s[0], 10, UiTheme.MUTED)
		key.custom_minimum_size = Vector2(92, 0)
		grid.add_child(key)
		var value := UiTheme.label(s[1], 11, UiTheme.TEXT)
		value.custom_minimum_size = Vector2(100, 0)
		grid.add_child(value)
	return grid


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l




func _on_tap(view: CardView) -> void:
	if busy:
		return
	message = ""
	Feel.play("deselect" if view.selected else "select")
	Feel.buzz(8)
	var tag := view.tag
	if tag["zone"] == "hand":
		var id: int = tag["id"]
		if selected_hand.has(id):
			selected_hand.erase(id)
		elif selected_hand.size() < maxi(5, run.stat("max_play")):
			selected_hand.append(id)
	elif _same(selection, tag):
		selection = {}
	else:
		selection = tag.duplicate()
	refresh()


func _act(action: Dictionary) -> void:
	_acted(action, Game.act(action, true))
	Game.changed.emit()


## What every action says and sounds like once the run has applied it (or refused).
func _acted(action: Dictionary, result: Dictionary) -> void:
	message = "" if result["ok"] else _sentence(str(result["error"]))
	if result["ok"]:
		selected_hand.clear()
		selection = {}
		Feel.play(ACTION_CUES.get(action["a"], ""))
		if run.phase == RunState.Phase.LOST:
			Feel.play("lose")
	else:
		Feel.play("error")


## Next show. When that show is in a new town, this is a natural break between towns,
## where an intermission may play before the new town's board appears. AdPolicy
## decides, and usually nothing shows: never for new players or supporters, never in
## the guided first run, and never more often than its caps.
func _leave_market() -> void:
	if busy:
		return
	var action := { "a": "leave_shop" }
	var town := run.town
	var result := Game.act(action, true)
	_acted(action, result)
	if result["ok"] and run.town > town:
		busy = true
		# AdPolicy allows a town break only on the way into some towns: tell it which.
		await Ads.intermission("town_break", { "town": run.town })
		busy = false
	Game.changed.emit()




func _on_discard() -> void:
	var ids := _selected_ids()
	Feel.play("discard")
	if not Settings.reduce_motion:
		busy = true
		_build_buttons()
		for child in hand_row.get_children():
			if not child.is_queued_for_deletion() and ids.has(int(child.tag["id"])):
				child.set_process(false)
				var t := child.create_tween().set_parallel()
				t.tween_property(child, "position", child.position + Vector2(40, -60), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				t.tween_property(child, "rotation", 0.4, 0.2)
				t.tween_property(child, "modulate:a", 0.0, 0.2)
		await _wait(0.2)
		busy = false
	_act({ "a": "discard", "cards": ids })


func _toggle_sort() -> void:
	sort_by = "suit" if sort_by == "rank" else "rank"
	refresh()


func _move_jester(index: int, step: int) -> void:
	var order := range(run.zanni.size())
	order[index] = index + step
	order[index + step] = index
	_act({ "a": "reorder_zanni", "order": order })
	selection = { "zone": "zanni", "index": index + step }
	refresh()






func _on_play() -> void:
	var played := _selected_cards()
	var ids := _selected_ids()
	var before := run.show_score
	var held := run.hand.filter(func(c: PlayingCard) -> bool: return not ids.has(c.id))
	var from := _hand_positions()
	var result := Game.act({ "a": "play", "cards": ids }, true)
	if not result["ok"]:
		message = _sentence(str(result["error"]))
		refresh()
		return
	busy = true
	scoring = true
	skipping = false
	Engine.time_scale = float(Settings.speed)
	held_while_scoring = held
	selected_hand.clear()
	selection = {}
	_clear(middle)
	_clear(tip)
	_build_coach()
	_build_hand()
	_build_buttons()
	var views := {}
	for child in hand_row.get_children():
		if not child.is_queued_for_deletion():
			views[int(child.tag["id"])] = child
	var scoring_ids: Array = result.get("scoring", [])
	var played_views: Array[CardView] = []
	var gap := minf(hand_card.x + 4.0, (area_w - hand_card.x) / maxf(1.0, played.size() - 1))
	var left := (area_w - (gap * (played.size() - 1) + hand_card.x)) / 2.0
	for i in played.size():
		var v := CardView.new(hand_card)
		v.card = played[i]
		v.edition = played[i].edition
		middle.add_child(v)
		var scores := scoring_ids.has(played[i].id)
		if not scores:
			v.modulate = Color(1, 1, 1, 0.6)
		_fly(v, from.get(played[i].id, Vector2.ZERO), Vector2(left + i * gap, 4 if scores else 14), i * 0.05)
		views[played[i].id] = v
		played_views.append(v)
	Feel.play("play")
	await _wait(0.2 + played.size() * 0.05)
	lbl_hand.text = _hand_name(str(result["hand"]))
	var events: Array = result["events"]
	var step := clampf(2.2 / maxf(1.0, events.size()), 0.08, 0.3)
	for n in events.size():
		var e: Dictionary = events[n]
		lbl_points.text = UiTheme.number(float(e["points"]))
		lbl_mult.text = UiTheme.number(float(e["mult"]))
		if e["t"] == "not_allowed":
			message = "The Patron doesn't allow that hand: it scores nothing."
		var target: Control = null
		var card_id := int(e["card"])
		if views.has(card_id):
			target = views[card_id]
		elif str(e["src"]).begins_with("zanni:"):
			var index := int(str(e["src"]).get_slice("#", 1))
			if index < jester_views.size():
				target = jester_views[index]
		_feel_event(e, target, n)
		await _wait(step)
	var total := float(result["total"])
	await _slam(total, run.phase == RunState.Phase.CASH_OUT)
	for i in played_views.size():
		_fly_off(played_views[i], i * 0.04)
	await _count_up(lbl_score, before, before + total)
	if run.phase == RunState.Phase.CASH_OUT:
		Feel.play("win")
		Feel.play("applause")
		Feel.intensity(1.0)
		Feel.celebrate(1.0)
		Feel.buzz(40)
		Feel.shake(4.0)
		Feel.kick(2.0)
		Feel.burst(lbl_score.get_global_rect().get_center(), UiTheme.GOLD, 40)
		await _banner("SHOW WON!", UiTheme.GOLD)
	elif run.phase == RunState.Phase.LOST:
		Feel.play("lose")
		await _wait(0.4)
	scoring = false
	skipping = false
	Engine.time_scale = 1.0
	busy = false
	Game.changed.emit()



func _input(event: InputEvent) -> void:
	if not scoring or skipping:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if press:
		skipping = true
		Engine.time_scale = 12.0
		get_viewport().set_input_as_handled()




func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if busy or run == null or UiTheme.sheet_open() or overlay.mouse_filter == Control.MOUSE_FILTER_STOP:
		return
	var key: int = (event as InputEventKey).keycode
	match key:
		KEY_ESCAPE, KEY_P:
			_pause()
		KEY_I:
			_open(RunInfoSheet.new())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if primary.is_valid():
				primary.call()
		KEY_D:
			if run.phase == RunState.Phase.IN_SHOW and not selected_hand.is_empty() and run.discards_left > 0:
				_on_discard()
		KEY_S:
			if run.phase == RunState.Phase.IN_SHOW:
				_toggle_sort()
		_:
			if key < KEY_1 or key > KEY_9:
				return
			_toggle_hand_card(key - KEY_1)
	get_viewport().set_input_as_handled()



func _toggle_hand_card(index: int) -> void:
	var cards := _sorted_hand()
	if index >= cards.size():
		return
	for child in hand_row.get_children():
		if child is CardView and not child.is_queued_for_deletion() and int(child.tag["id"]) == cards[index].id:
			_on_tap(child)
			return



const EVENT_WORDS := {
	"swap": "Swap!", "shattered": "Shattered!", "masked": "Masked!", "halved": "Halved",
	"balanced": "Balanced!", "debuffed": "Debuffed", "not_allowed": "Not allowed!", "ducats_lost": "Ducats lost",
}





func _feel_event(e: Dictionary, target: Control, index: int) -> void:
	var kind := str(e["t"])
	var amount := float(e["v"])
	if EVENT_CUES.has(kind) and not skipping:
		Feel.play(EVENT_CUES[kind], minf(2.0, 1.0 + index * 0.05))
		Feel.buzz(6)
	var text: String = EVENT_WORDS.get(kind, "")
	var colour := UiTheme.GOLD
	var size := 13
	match kind:
		"points":
			text = "+" + UiTheme.number(amount)
			colour = UiTheme.POINTS.lightened(0.25)
		"mult":
			text = "+%s Mult" % _short(amount)
			colour = UiTheme.MULT.lightened(0.15)
		"xmult":
			text = "x%s Mult" % _short(amount)
			colour = Color("ff6a3a")
			size = 17
		"ducats":
			text = "%+d ducats" % int(amount)
		"base":
			_punch(lbl_points.get_parent())
			_punch(lbl_mult.get_parent())
	if kind == "points" or kind == "swap":
		_punch(lbl_points.get_parent())
	if kind == "mult" or kind == "xmult" or kind == "swap":
		_punch(lbl_mult.get_parent())
	if target != null:
		_pop(target)
		var rect := target.get_global_rect()
		var at := rect.get_center() - Vector2(0, rect.size.y * 0.62)
		if target in jester_views:
			at = rect.get_center() + Vector2(0, rect.size.y * 0.66)
		if text != "":
			Feel.float_text(text, at, colour, size)
		Feel.burst(rect.get_center(), colour, 16 if kind == "xmult" else 8)
	elif text != "":
		Feel.float_text(text, lbl_mult.get_parent().get_global_rect().get_center() - Vector2(0, 18), colour, size)
	Feel.kick({ "points": 0.12, "mult": 0.25, "xmult": 0.9 }.get(kind, 0.0))
	if kind == "xmult":
		Feel.shake(2.0)
		Feel.flash(Color("ff6a3a"), 0.45)
	elif kind == "mult":
		Feel.flash(UiTheme.MULT, 0.15)



func _short(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return str(int(roundf(amount)))
	return ("%.2f" % amount).rstrip("0")




func _slam(total: float, won: bool) -> void:
	var l := UiTheme.title(UiTheme.number(total), 30, UiTheme.GOLD if won else UiTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(area_w, 44)
	l.position = Vector2(0, 30)
	l.pivot_offset = l.size / 2.0
	middle.add_child(l)
	_punch(lbl_points.get_parent())
	_punch(lbl_mult.get_parent())
	var share := total / maxf(1.0, float(run.show_target))
	Feel.play("jackpot" if share >= 1.0 else "slam")
	Feel.buzz(25)
	Feel.shake(clampf(log(total + 10.0) / log(10.0), 1.5, 6.0))
	Feel.kick(1.2)
	Feel.flash(UiTheme.GOLD if won else UiTheme.MULT, clampf(0.25 + share * 0.5, 0.25, 0.9))
	if share >= 1.0:
		Feel.celebrate(0.7)
	elif share >= 0.5:
		Feel.celebrate(0.3)
	Feel.burst(l.get_global_rect().get_center(), UiTheme.GOLD if won else UiTheme.MULT, 30)
	if Settings.reduce_motion:
		await _wait(0.6)
		l.queue_free()
		return
	l.scale = Vector2(2.6, 2.6)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.45)
	var target := lbl_score.get_global_rect().get_center() - l.size / 2.0
	t.tween_property(l, "global_position", target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(l, "scale", Vector2(0.4, 0.4), 0.25)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.25)
	await t.finished
	l.queue_free()



func _banner(text: String, colour: Color) -> void:
	var l := UiTheme.title(text, 38, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(stage_w, 56)
	l.position = Vector2(0, 120)
	l.pivot_offset = l.size / 2.0
	stage.add_child(l)
	var area := stage.get_global_rect()
	for i in 6:
		Feel.burst(area.position + Vector2(area.size.x * (0.15 + 0.14 * i), area.size.y * 0.4), [UiTheme.GOLD, UiTheme.MULT, UiTheme.POINTS, UiTheme.GOOD][i % 4], 18)
	if not Settings.reduce_motion:
		l.scale = Vector2(0.2, 0.2)
		l.rotation = -0.2
		var t := l.create_tween().set_parallel()
		t.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "rotation", 0.0, 0.3)
	await _wait(1.0)
	var out := l.create_tween()
	out.tween_property(l, "modulate:a", 0.0, 0.25)
	await out.finished
	l.queue_free()



func _hand_positions() -> Dictionary:
	var out := {}
	for child in hand_row.get_children():
		if not child.is_queued_for_deletion():
			out[int(child.tag["id"])] = child.global_position
	return out



func _fly(v: Control, from_global: Vector2, to: Vector2, delay: float) -> void:
	if Settings.reduce_motion or from_global == Vector2.ZERO:
		v.position = to
		return
	v.global_position = from_global
	v.rotation = randf_range(-0.25, 0.25)
	var t := v.create_tween().set_parallel()
	t.tween_property(v, "position", to, 0.24).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(v, "rotation", 0.0, 0.24).set_delay(delay)



func _fly_off(v: Control, delay: float) -> void:
	var t := v.create_tween().set_parallel()
	if not Settings.reduce_motion:
		t.tween_property(v, "position", v.position + Vector2(area_w, -30), 0.3).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(v, "rotation", 0.5, 0.3).set_delay(delay)
	t.tween_property(v, "modulate:a", 0.0, 0.3).set_delay(delay)



func _pop(v: Control) -> void:
	v.pivot_offset = v.size / 2.0
	if Settings.reduce_motion:
		return
	var t := v.create_tween()
	t.tween_property(v, "scale", Vector2(1.22, 1.22), 0.06)
	t.tween_property(v, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if v is CardView and (v as CardView).sway < 0:
		var r := v.create_tween()
		r.tween_property(v, "rotation", 0.12, 0.05)
		r.tween_property(v, "rotation", -0.08, 0.06)
		r.tween_property(v, "rotation", 0.0, 0.06)



func _punch(box: Control) -> void:
	_pulse(box)
	box.modulate = Color(1.7, 1.7, 1.7)
	var t := box.create_tween()
	t.tween_property(box, "modulate", Color.WHITE, 0.18)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout




func _count_up(label: Label, from: float, to: float) -> void:
	if Settings.reduce_motion or to <= from:
		label.text = UiTheme.number(to)
		return
	var ticks := [0]
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		label.text = UiTheme.number(floorf(v))
		var step := int((v - from) / (to - from) * 10.0)
		if step > ticks[0]:
			ticks[0] = step
			Feel.play("tick", 1.0 + step * 0.06), from, to, 0.45)
	await t.finished


func _pulse(v: Control) -> void:
	v.pivot_offset = v.size / 2.0
	var t := create_tween()
	t.tween_property(v, "scale", Vector2(1.15, 1.15), 0.06)
	t.tween_property(v, "scale", Vector2.ONE, 0.08)




func _selected_def_id() -> String:
	var i := int(selection.get("index", -1))
	match str(selection.get("zone", "")):
		"zanni":
			return run.zanni[i].def_id
		"consumable":
			return run.consumables[i].def_id
		"offer":
			return str(run.shop.offers[i]["id"])
		"pack":
			return str(run.shop.packs[i]["id"])
		"warrant":
			return run.town_warrant if i == 0 else run.shop.extra_warrant
		"pack_item":
			return str(run.pack["items"][i].get("id", ""))
	return ""


func _describe_selection(id: String) -> String:
	var zone := str(selection.get("zone", ""))
	var i := int(selection.get("index", -1))
	if id == "":
		var desc: Dictionary = run.shop.offers[i]["card"] if zone == "offer" else run.pack["items"][i]["card"]
		var card := _card_from(desc)
		return _card_name(card) + "\n" + _describe_card(card)
	var lines := [UiTheme.text_of(id)]
	var gloss := TranslationServer.translate(id + ".gloss")
	if gloss != id + ".gloss":
		lines.push_front("(" + gloss + ")")
	var def := ContentDB.get_def(id)
	if def != null and KIND_HELP.has(def.kind):
		var what: String = KIND_HELP[def.kind]
		if def.kind == "zanni":
			what = CardView.RARITY_NAMES[clampi(def.rarity, 0, 3)] + " " + what
		lines.append("")
		lines.append(what)
	if zone == "zanni":
		var z := run.zanni[i]
		if z.edition != "":
			lines.append("%s: %s" % [UiTheme.name_of(z.edition), UiTheme.text_of(z.edition)])
		if z.state.get("eternal", false):
			lines.append("Eternal: can't be sold or destroyed.")
		if z.state.has("perish"):
			lines.append("Perishable: %d shows left." % int(z.state["perish"]))
		if z.state.get("rented", false):
			lines.append("Rented: -3 ducats at every cash-out.")
	return "\n".join(lines)


func _card_name(card: PlayingCard) -> String:
	if not card.has_rank():
		return "Marble card"
	return "%s of %s" % [RANK_NAMES.get(card.rank, str(card.rank)), SUITS[card.suit]]


func _describe_card(card: PlayingCard) -> String:
	var lines := ["%d Points" % (card.base_points() + card.bonus_points)]
	for mod in [card.enhancement, card.edition, card.seal]:
		if mod != "":
			lines.append("%s: %s" % [UiTheme.name_of(mod), UiTheme.text_of(mod)])
	if card.debuffed:
		lines.append("Debuffed: scores nothing this show.")
	return "\n".join(lines)


func _hand_name(hand_type: String) -> String:
	return TranslationServer.translate("hand." + hand_type)



func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1) + "."




func _hand_card(card_id: int) -> PlayingCard:
	for card in run.hand:
		if card.id == card_id:
			return card
	return null


func _card_from(desc: Dictionary) -> PlayingCard:
	var card := PlayingCard.make(-1, int(desc["rank"]), int(desc["suit"]))
	card.enhancement = str(desc.get("enh", ""))
	card.edition = str(desc.get("ed", ""))
	card.seal = str(desc.get("seal", ""))
	return card


func _wrapped(text: String, font_size: int, width := 148.0) -> Label:
	var l := UiTheme.label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _same(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and a.get("zone") == b.get("zone") and a.get("index") == b.get("index")


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
