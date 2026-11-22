class_name MenuScreen
extends Control





signal start

const DECK_WORDS := "Your starting cards, plus one special rule."
const STAKE_WORDS := "How hard the run is. Each stake adds its rule on top of every stake below it."
const CHALLENGE_WORDS := "A set run with its own deck and special rules. Every run you win unlocks five."
const RUN_WORDS := "Travel through 8 towns. Each town has three shows: the Matinee, the Evening show and the Patron. Beat each show's target score with poker hands, then spend your ducats in the shop on Jesters that bend the rules."
const LEFT := Vector2(16, 58)
const LEFT_W := 322.0
const RIGHT_X := 348.0
const RIGHT_W := 276.0
## The top bar runs from just right of the title to the right margin. The title ends near
## x=207 at the normal text size, and further right with large text, so the bar starts
## from the title's measured width, never left of BAR_X.
const BAR_X := 214.0
const BAR_END := 624.0
const BAR_GAP := 4
## The account chip shows the name up to CHIP_MAX wide; with less room than CHIP_MIN
## left in the bar it shows only its avatar.
const CHIP_MAX := 170.0
const CHIP_MIN := 78.0

var deck_ids: Array = []
var deck_index := 0
var stake := 1
var challenge_ids: Array = []
var challenge_index := 0
var mode := "deck"
## Which game mode a new run uses: the ranked 8-town tour, a 3-town quick run or a boss rush.
var run_mode := "tour"
const MODES := ["tour", "quick", "bosses"]
const MODE_WORDS := {
	"tour": "8 towns  ·  ranked  ·  unlocks decks and stakes",
	"quick": "3 towns  ·  about 15 minutes  ·  just for fun",
	"bosses": "Only Patrons, a shop between  ·  just for fun",
}

var daily_info: Dictionary = {}
## The wallet and gift state the menu was last built with (see _after_sheet).
var _shown_wallet := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck_ids = ContentDB.pool("deck").map(func(d: ContentDef) -> String: return d.id)
	challenge_ids = ContentDB.pool("challenge").map(func(d: ContentDef) -> String: return d.id)
	_build()
	Online.account_changed.connect(_on_account_changed)
	Feel.settings_changed.connect(func() -> void:
		if is_inside_tree():
			_build())
	# A real-money purchase can finish while a sheet is still open: show it at once.
	Store.purchased.connect(func(_product_id: String) -> void:
		if is_inside_tree():
			_build())
	_fetch_daily()

	if Game.first_run_finished() and Online.signed_in() and Online.is_guest() and not Settings.asked_account:
		Settings.asked_account = true
		Settings.save()
		_open(AccountSheet.new("signup", "You finished your first run! Create an account so your runs, unlocks and cards are kept safe and follow you to any device."))


func _on_account_changed() -> void:
	if is_inside_tree():
		_build()
		_fetch_daily()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	Feel.backdrop(bg)
	Feel.mood("menu")
	var stage := UiTheme.stage(self)

	# A large title over the left column, with the account chip at the top right.
	var title := UiTheme.title("Deck of Fools", 30, UiTheme.GOLD)
	title.position = Vector2(LEFT.x, 0)
	title.size = Vector2(LEFT_W, 38)
	stage.add_child(title)
	var sub := UiTheme.label("A troupe of Jesters against the house", 10, UiTheme.TEXT)
	sub.position = Vector2(LEFT.x + 2, 36)
	sub.size = Vector2(LEFT_W, 16)
	stage.add_child(sub)

	_build_setup(stage)
	_build_side(stage)
	_build_top_bar(stage, maxf(BAR_X, LEFT.x + title.get_combined_minimum_size().x + 8.0))
	_shown_wallet = _wallet_state()




func _build_setup(stage: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = LEFT
	panel.size = Vector2(LEFT_W, 0)
	stage.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)

	# New run / Challenges as an iOS segmented control.
	var tabs := UiTheme.segmented(["New run", "Challenges"], 0 if mode == "deck" else 1, func(i: int) -> void:
		Feel.play("select")
		mode = "deck" if i == 0 else "challenge"
		_build(), 10)
	col.add_child(tabs)

	var locked := false
	if mode == "deck":
		var modes := UiTheme.segmented(["Tour", "Quick", "Boss rush"], MODES.find(run_mode), func(i: int) -> void:
			Feel.play("select")
			run_mode = MODES[i]
			_build(), 9)
		col.add_child(modes)
		col.add_child(_words(MODE_WORDS[run_mode], 8, UiTheme.GOLD.lightened(0.25)))
		var id: String = deck_ids[deck_index]
		var open_count := deck_ids.filter(func(d: String) -> bool: return Game.profile.deck_unlocked(d)).size()
		_heading(col, "1", "Deck", "%d of %d unlocked" % [open_count, deck_ids.size()], UiTheme.POINTS)
		locked = not Game.profile.deck_unlocked(id)
		col.add_child(_picker(UiTheme.name_of(id), locked, _cycle))
		col.add_child(_words(_deck_lock_reason(id) if locked else UiTheme.text_of(id), 10, UiTheme.MULT.lightened(0.3) if locked else UiTheme.TEXT, 26))
		if not locked:
			var top := Game.profile.max_stake(id)
			stake = clampi(stake, 1, top)
			var stake_def: ContentDef = ContentDB.pool("stake")[stake - 1]
			_heading(col, "2", "Stake", "up to %d of %d" % [top, Unlocks.TOP_STAKE], UiTheme.MULT)
			col.add_child(_picker("Stake %d: %s" % [stake, UiTheme.name_of(stake_def.id)], false, _stake))
			col.add_child(_words(UiTheme.text_of(stake_def.id), 10, UiTheme.TEXT, 22))
	else:
		var id: String = challenge_ids[challenge_index]
		var open_count := challenge_ids.filter(func(c: String) -> bool: return Game.profile.challenge_unlocked(c)).size()
		_heading(col, "", "Challenge", "%d of %d unlocked" % [open_count, challenge_ids.size()], UiTheme.GOLD)
		col.add_child(_words(CHALLENGE_WORDS, 8, UiTheme.MUTED))
		locked = not Game.profile.challenge_unlocked(id)
		col.add_child(_picker(UiTheme.name_of(id), locked, _cycle))
		if locked:
			var wins_needed := challenge_index / Unlocks.CHALLENGES_PER_WIN + 1
			col.add_child(_words("Locked. Win %d more run%s to unlock it." % [wins_needed - Game.profile.total_wins, "" if wins_needed - Game.profile.total_wins == 1 else "s"], 10, UiTheme.MULT.lightened(0.3)))
		col.add_child(_words(UiTheme.text_of(id), 10, UiTheme.TEXT, 40))
		var deck := str(ContentDB.get_def(id).data.get("deck", ""))
		if deck != "":
			col.add_child(_words("Deck: %s. %s" % [UiTheme.name_of(deck), UiTheme.text_of(deck)], 8, UiTheme.MUTED))

	var play := UiTheme.button("Locked" if locked else "Play", _on_start, 16, UiTheme.MULT)
	play.disabled = locked
	play.position = Vector2(LEFT.x, 312)
	play.size = Vector2(LEFT_W, 30)
	stage.add_child(play)
	var note := ""
	if Game.has_saved_run() and not locked:
		note = "Starting a new run ends the tour in progress."
	elif Settings.tutorial_step == 0 and not locked:
		note = "Your first run is guided, step by step."
	if note != "":
		var warn := UiTheme.label(note, 8, UiTheme.MUTED if Game.has_saved_run() else UiTheme.GOLD)
		warn.position = Vector2(LEFT.x, 344)
		warn.size = Vector2(LEFT_W, 10)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage.add_child(warn)


func _heading(col: Control, number: String, text: String, note: String, colour: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if number != "":
		row.add_child(UiTheme.title(number, 14, colour))
	var name_label := UiTheme.title(text, 13, UiTheme.GOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiTheme.label(note, 8, UiTheme.MUTED))
	col.add_child(row)


func _picker(text: String, locked: bool, step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(UiTheme.icon_button("back", func() -> void: step.call(-1), 24.0))
	var name_label := UiTheme.title(("Locked: " if locked else "") + text, 13, UiTheme.MUTED if locked else UiTheme.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiTheme.icon_button("forward", func() -> void: step.call(1), 24.0))
	return row


func _words(text: String, font_size: int, colour: Color, min_height := 0.0, width := LEFT_W - 14.0) -> Label:
	var l := UiTheme.label(text, font_size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, min_height)
	return l


func _deck_lock_reason(id: String) -> String:
	var parts := str(Unlocks.DECK_RULES.get(id, "")).split(":")
	if parts[0] == "discover":
		return "Locked. Discover %s different cards across your runs to unlock it (you have %d)." % [parts[1], Game.profile.discovered.size()]
	return "Locked. Win a run with %s to unlock it." % UiTheme.name_of(parts[1])




func _build_side(stage: Control) -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(RIGHT_X, LEFT.y)
	col.size = Vector2(RIGHT_W, 0)
	col.add_theme_constant_override("separation", 6)
	stage.add_child(col)

	var saved := Game.peek_saved_run()
	var tour := _box(col, UiTheme.POINTS.darkened(0.2))
	if saved != null:
		tour.add_child(UiTheme.title("Tour in progress", 12, UiTheme.GOLD))
		var deck_line := UiTheme.name_of(saved.challenge) if saved.challenge != "" else "%s, Stake %d" % [UiTheme.name_of(saved.deck_id), saved.stake]
		tour.add_child(UiTheme.label(deck_line, 10))
		var kind: String = { "quick": "Quick run - ", "bosses": "Boss rush - " }.get(saved.mode, "")
		tour.add_child(UiTheme.label("%sTown %d of %d - %s" % [kind, saved.town, saved.final_town(), RunScreen.SHOW_NAMES[saved.show_index]], 10))
		tour.add_child(UiTheme.label("%d ducats - %d Jesters" % [saved.ducats, saved.zanni.size()], 10, UiTheme.MUTED))
		tour.add_child(UiTheme.button("Continue the tour", _on_continue, 12, UiTheme.POINTS))
	else:
		tour.add_child(UiTheme.title("How a run works", 12, UiTheme.GOLD))
		tour.add_child(_words(RUN_WORDS, 8, UiTheme.TEXT, 0.0, RIGHT_W - 14.0))

	_build_daily(col)
	_build_collection(col)





func _build_daily(col: Control) -> void:
	var box := _box(col, UiTheme.GOOD.darkened(0.25))
	var setup := Online.daily_setup()
	box.add_child(UiTheme.title("Daily run", 12, UiTheme.GOLD))
	box.add_child(_words("Same cards for everyone today: %s deck, Stake 1. One ranked try; practice as often as you like." % UiTheme.name_of(setup["deck"]), 8, UiTheme.MUTED, 0.0, RIGHT_W - 14.0))
	var attempt: Variant = daily_info.get("attempt")
	var ranked_text := "Ranked try"
	var can_rank := Online.online and Online.signed_in() and not daily_info.is_empty()
	if attempt is Dictionary:
		can_rank = false
		ranked_text = "Ranked: town %d" % int(attempt["town"]) if bool(attempt["finished"]) else "Ranked: started"
	elif not can_rank:
		ranked_text = "Ranked: needs a connection"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var ranked := UiTheme.button(ranked_text, _start_daily.bind(true), 11, UiTheme.MULT)
	ranked.disabled = not can_rank
	ranked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ranked)
	var practice := UiTheme.button("Practice", _start_daily.bind(false), 11, UiTheme.PANEL_LIGHT)
	row.add_child(practice)
	box.add_child(row)



## The way into the Jester collection: a small fan of Jesters you've met (illustrated
## ones first), how many of the 150 you've found, and a chevron. The whole card is a button.
func _build_collection(col: Control) -> void:
	var all := CollectionSheet.numbered()
	var found := all.filter(func(id: String) -> bool: return Game.profile.discovered.has(id))
	var shown: Array = found.filter(func(id: String) -> bool: return CardView.art_for("zanni", id) != null)
	for id: String in found:
		if shown.size() >= 3:
			break
		if not shown.has(id):
			shown.append(id)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(RIGHT_W, 62)
	var normal := UiTheme.panel_box(UiTheme.PANEL, UiTheme.GOLD.darkened(0.35))
	var hover := UiTheme.panel_box(UiTheme.PANEL_LIGHT, UiTheme.GOLD.darkened(0.2))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: _open(CollectionSheet.new()))
	UiTheme._press_feel(button)
	col.add_child(button)
	# A fan of three small cards on the left, the best one in the middle and on top.
	for slot in [0, 2, 1]:
		var pick: int = [1, 0, 2][slot]
		var card := CardView.new(Vector2(32, 45))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if pick < shown.size():
			card.kind = "zanni"
			card.def_id = str(shown[pick])
		else:
			card.face_down = true
		card.position = Vector2(8 + slot * 19, 7 + absf(slot - 1) * 2.0)
		card.rotation = (slot - 1) * 0.2
		button.add_child(card)
	var title := UiTheme.title("Jester collection", 12, UiTheme.GOLD)
	title.position = Vector2(84, 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	var count := UiTheme.label("%d of %d found" % [found.size(), all.size()], 9, UiTheme.MUTED)
	count.position = Vector2(84, 28)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	var share := float(found.size()) / maxf(1.0, all.size())
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(85, 45)
	bar.size = Vector2(RIGHT_W - 130, 4)
	bar.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_style_box(UiTheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 99), r)
		if share > 0.0:
			r.size.x = maxf(r.size.y, r.size.x * share)
			bar.draw_style_box(UiTheme.box(UiTheme.GOLD, Color(0, 0, 0, 0), 99), r))
	button.add_child(bar)
	var chevron := UiIcon.new("forward", UiTheme.MUTED)
	chevron.position = Vector2(RIGHT_W - 30, 21)
	chevron.size = Vector2(20, 20)
	button.add_child(chevron)


func _fetch_daily() -> void:
	var res := await Online.daily()
	if res["ok"] and is_inside_tree():
		daily_info = res["data"]
		_build()


func _start_daily(ranked: bool) -> void:
	var setup := Online.daily_setup()
	var meta := { "daily_date": setup["date"] }
	if ranked:
		var res := await Online.start_daily()
		if not res["ok"]:
			Feel.play("error")
			_fetch_daily()
			return
		setup = res["data"]
		meta["daily_date"] = setup["date"]
	else:
		meta["practice"] = true
	Feel.play("play")
	Game.new_run(str(setup["deck"]), int(setup["stake"]), "", str(setup["seed"]), meta)
	start.emit()



func _build_top_bar(stage: Control, start_x: float) -> void:
	# Top right, as in iPhone apps: the daily gift and the wallet (the way into the Shop),
	# the account chip, then round icon buttons. Everything but the chip has a fixed
	# width, and the chip gets the room that is left, so the bar never runs into the
	# title, whatever the balances, the name or the text size.
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", BAR_GAP)
	bar.position = Vector2(start_x, 7)
	bar.size = Vector2(BAR_END - start_x, 30)
	stage.add_child(bar)
	var lead: Array[Control] = []
	if _can_install():
		lead.append(_install_button())
	lead.append(_gift_button())
	lead.append(_wallet_pill())
	var tail: Array[Control] = []
	tail.append(UiTheme.icon_button("trophy", func() -> void: _open(LeaderboardSheet.new()), 28.0))
	tail.append(UiTheme.icon_button("help", func() -> void: _open(HowToPlay.new()), 28.0))
	tail.append(UiTheme.icon_button("settings", func() -> void: _open(SettingsSheet.new()), 28.0))
	var room := bar.size.x - BAR_GAP * (lead.size() + tail.size())
	for item: Control in lead:
		room -= item.custom_minimum_size.x
		bar.add_child(item)
	for item: Control in tail:
		room -= item.custom_minimum_size.x
	bar.add_child(_account_chip(room))
	for item: Control in tail:
		bar.add_child(item)


## In a browser that can add the game as an app (and isn't already running as
## one), offer it. web/shell.html does the work: the browser's own install
## prompt where there is one, otherwise a sheet of steps (Share, Add to Home Screen).
func _can_install() -> bool:
	if not OS.has_feature("web"):
		return false
	var state := str(JavaScriptBridge.eval("window.dofInstallState ? window.dofInstallState() : 'none'", true))
	return state != "installed" and state != "none"


## A round gold button with the download glyph: round so the bar keeps room for the
## wallet and the account chip.
func _install_button() -> Button:
	return UiTheme.icon_button("download", func() -> void:
		Feel.play("click")
		JavaScriptBridge.eval("window.dofInstall && window.dofInstall()", true), 28.0, UiTheme.GOLD)


## The daily gift. A small red dot says one is waiting; the sheet never opens by itself.
func _gift_button() -> Button:
	var b := UiTheme.icon_button("gift", func() -> void: _open(GiftSheet.new()), 28.0)
	b.name = "GiftButton"
	if Game.gift_ready():
		var dot := Control.new()
		dot.name = "GiftDot"
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(19, 0)
		dot.size = Vector2(10, 10)
		dot.draw.connect(func() -> void:
			dot.draw_circle(dot.size / 2.0, 5.0, UiTheme.INK, true, -1.0, true)
			dot.draw_circle(dot.size / 2.0, 3.6, UiTheme.MULT, true, -1.0, true))
		b.add_child(dot)
	return b


## The wallet: coins and diamonds after a gold Shop badge (the bag). The whole pill opens
## the Shop. Its width is measured from the numbers, so the bar can budget for it.
func _wallet_pill() -> Button:
	var w := Game.wallet()
	var pill := UiTheme.button("", func() -> void: _open(ShopSheet.new()))
	pill.name = "WalletPill"
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -9
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	row.add_child(_disc("shop"))
	for kind: String in ["coins", "diamonds"]:
		var amount := UiTheme.currency(kind, w.balance(kind), 10)
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(amount)
	var widths := 0.0
	for kind: String in ["coins", "diamonds"]:
		widths += UiTheme.px(10) * 1.25 + 3.0 + UiTheme.bold.get_string_size(UiTheme.number(w.balance(kind)), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(10)).x
	pill.custom_minimum_size = Vector2(ceilf(4.0 + 22.0 + 6.0 * 2.0 + widths + 9.0 + 1.0), 30)
	return pill


## A gold disc with a dark glyph: the account chip's avatar, the wallet's Shop badge.
func _disc(glyph_name: String) -> Panel:
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(22, 22)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.GOLD
	fill.set_corner_radius_all(99)
	fill.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", fill)
	var glyph := UiIcon.new(glyph_name, UiTheme.INK)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 4
	glyph.offset_top = 4
	glyph.offset_right = -4
	glyph.offset_bottom = -4
	disc.add_child(glyph)
	return disc


## The account chip, at most `room` wide. A long name ends in an ellipsis; a guest's
## reminder gets shorter before it's cut; with very little room only the avatar shows.
func _account_chip(room: float) -> Button:
	var name_text := str(Online.user.get("name", "Offline")) if Online.signed_in() else "Offline"
	var nudge := Online.signed_in() and Online.is_guest()
	var chip := UiTheme.button("", func() -> void: _open(ProfileSheet.new()))
	chip.name = "AccountChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(_disc("profile"))
	if room < CHIP_MIN:
		row.offset_right = -4
		chip.custom_minimum_size = Vector2(30, 30)
		return chip
	var reminder := "Save your progress"
	var name_width := UiTheme.bold.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(10)).x
	var widest := name_width
	if nudge:
		widest = maxf(name_width, UiTheme.font.get_string_size(reminder, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(8)).x)
		if widest + 46.0 > room:
			reminder = "Save progress"
			widest = maxf(name_width, UiTheme.font.get_string_size(reminder, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(8)).x)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -4)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := UiTheme.label(name_text, 10, UiTheme.TEXT)
	who.add_theme_font_override("font", UiTheme.bold)
	lines.add_child(who)
	if nudge:
		lines.add_child(UiTheme.label(reminder, 8, UiTheme.GOLD))
	for line: Label in lines.get_children():
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(lines)
	chip.custom_minimum_size = Vector2(floorf(minf(minf(CHIP_MAX, widest + 46.0), room)), 30)
	return chip


func _open(sheet: Control) -> void:
	Feel.play("click")
	# Whatever happened in the sheet (a purchase, the gift, a new card back) shows here
	# once it closes.
	if sheet.has_signal("closed"):
		sheet.connect("closed", _after_sheet)
	UiTheme.show_sheet(sheet)


## The menu shows the wallet and the gift's dot, so rebuild it when either changed while a
## sheet was open (sheets opened from sheets, like the Shop from Settings, included).
func _after_sheet() -> void:
	if is_inside_tree() and _wallet_state() != _shown_wallet:
		_build()


func _wallet_state() -> String:
	var w := Game.wallet()
	return "%d/%d/%s" % [w.coins, w.diamonds, Game.gift_ready()]


func _box(parent: Control, border: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL, border))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	panel.add_child(inner)
	parent.add_child(panel)
	return inner


func _cycle(step: int) -> void:
	Feel.play("select")
	if mode == "deck":
		deck_index = posmod(deck_index + step, deck_ids.size())
	else:
		challenge_index = posmod(challenge_index + step, challenge_ids.size())
	_build()


func _stake(step: int) -> void:
	Feel.play("select")
	stake = clampi(stake + step, 1, Game.profile.max_stake(deck_ids[deck_index]))
	_build()


func _on_start() -> void:
	Feel.play("play")
	if mode == "deck":
		Game.new_run(deck_ids[deck_index], stake, "", "", { "mode": run_mode })
	else:
		Game.new_run("", 1, challenge_ids[challenge_index])
	start.emit()


func _on_continue() -> void:
	Feel.play("play")
	if Game.continue_run():
		start.emit()
