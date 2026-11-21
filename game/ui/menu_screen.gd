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

var deck_ids: Array = []
var deck_index := 0
var stake := 1
var challenge_ids: Array = []
var challenge_index := 0
var mode := "deck"

var daily_info: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck_ids = ContentDB.pool("deck").map(func(d: ContentDef) -> String: return d.id)
	challenge_ids = ContentDB.pool("challenge").map(func(d: ContentDef) -> String: return d.id)
	_build()
	Online.account_changed.connect(_on_account_changed)
	Feel.settings_changed.connect(func() -> void:
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
	_build_top_bar(stage)




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
		var id: String = deck_ids[deck_index]
		var open_count := deck_ids.filter(func(d: String) -> bool: return Game.profile.deck_unlocked(d)).size()
		_heading(col, "1", "Deck", "%d of %d unlocked" % [open_count, deck_ids.size()], UiTheme.POINTS)
		col.add_child(_words(DECK_WORDS, 8, UiTheme.MUTED))
		locked = not Game.profile.deck_unlocked(id)
		col.add_child(_picker(UiTheme.name_of(id), locked, _cycle))
		col.add_child(_words(_deck_lock_reason(id) if locked else UiTheme.text_of(id), 10, UiTheme.MULT.lightened(0.3) if locked else UiTheme.TEXT, 26))
		if not locked:
			var top := Game.profile.max_stake(id)
			stake = clampi(stake, 1, top)
			var stake_def: ContentDef = ContentDB.pool("stake")[stake - 1]
			_heading(col, "2", "Stake", "up to %d of %d" % [top, Unlocks.TOP_STAKE], UiTheme.MULT)
			col.add_child(_words(STAKE_WORDS, 8, UiTheme.MUTED))
			col.add_child(_picker("Stake %d: %s" % [stake, UiTheme.name_of(stake_def.id)], false, _stake))
			col.add_child(_words(UiTheme.text_of(stake_def.id), 10, UiTheme.TEXT, 22))
			if top < Unlocks.TOP_STAKE and stake == top:
				col.add_child(_words("Win a run with %s on this stake to open Stake %d." % [UiTheme.name_of(id), top + 1], 8, UiTheme.MUTED))
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
	if Game.has_saved_run() and not locked:
		var warn := UiTheme.label("Starting a new run ends the tour in progress.", 8, UiTheme.MUTED)
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
		tour.add_child(UiTheme.label("Town %d of 8 - %s" % [saved.town, RunScreen.SHOW_NAMES[saved.show_index]], 10))
		tour.add_child(UiTheme.label("%d ducats - %d Jesters" % [saved.ducats, saved.zanni.size()], 10, UiTheme.MUTED))
		tour.add_child(UiTheme.button("Continue the tour", _on_continue, 12, UiTheme.POINTS))
	else:
		tour.add_child(UiTheme.title("How a run works", 12, UiTheme.GOLD))
		tour.add_child(_words(RUN_WORDS, 8, UiTheme.TEXT, 0.0, RIGHT_W - 14.0))

	_build_daily(col)





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



func _build_top_bar(stage: Control) -> void:
	# Top right, as in iPhone apps: the account chip, then round icon buttons.
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 6)
	bar.position = Vector2(RIGHT_X - 40, 7)
	bar.size = Vector2(RIGHT_W + 40, 30)
	stage.add_child(bar)
	bar.add_child(_account_chip())
	bar.add_child(UiTheme.icon_button("trophy", func() -> void: _open(LeaderboardSheet.new()), 28.0))
	bar.add_child(UiTheme.icon_button("help", func() -> void: _open(HowToPlay.new()), 28.0))
	bar.add_child(UiTheme.icon_button("settings", func() -> void: _open(SettingsSheet.new()), 28.0))


func _account_chip() -> Button:
	var name_text := str(Online.user.get("name", "Offline")) if Online.signed_in() else "Offline"
	var nudge := Online.signed_in() and Online.is_guest()
	var chip := UiTheme.button("", func() -> void: _open(ProfileSheet.new()))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	# Avatar: a gold disc with the profile glyph.
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(22, 22)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := StyleBoxFlat.new()
	disc.bg_color = UiTheme.GOLD
	disc.set_corner_radius_all(99)
	disc.anti_aliasing = true
	avatar.add_theme_stylebox_override("panel", disc)
	var glyph := UiIcon.new("profile", UiTheme.INK)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 4
	glyph.offset_top = 4
	glyph.offset_right = -4
	glyph.offset_bottom = -4
	avatar.add_child(glyph)
	row.add_child(avatar)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -4)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := UiTheme.label(name_text, 10, UiTheme.TEXT)
	who.add_theme_font_override("font", UiTheme.bold)
	lines.add_child(who)
	if nudge:
		lines.add_child(UiTheme.label("Save your progress", 8, UiTheme.GOLD))
	row.add_child(lines)
	var widest := UiTheme.bold.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(10)).x
	if nudge:
		widest = maxf(widest, UiTheme.font.get_string_size("Save your progress", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.px(8)).x)
	chip.custom_minimum_size = Vector2(minf(170.0, widest + 46.0), 30)
	return chip


func _open(sheet: Control) -> void:
	Feel.play("click")
	UiTheme.show_sheet(sheet)


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
		Game.new_run(deck_ids[deck_index], stake)
	else:
		Game.new_run("", 1, challenge_ids[challenge_index])
	start.emit()


func _on_continue() -> void:
	Feel.play("play")
	if Game.continue_run():
		start.emit()
