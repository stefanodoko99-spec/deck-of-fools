class_name SettingsSheet
extends Sheet








func _init() -> void:
	title_text = "Settings"
	panel_size = Vector2(612, 346)


func _ready() -> void:
	super._ready()
	Online.account_changed.connect(func() -> void:
		if is_inside_tree():
			rebuild())


func _build() -> void:
	# Grouped lists in the style of iPhone Settings: a small caption, then a rounded
	# card of rows with the label on the left and its control on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(286, 0)
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	columns.add_child(right)

	var sound := _group(left, "Sound")
	_row(sound, "Music", _volume(Settings.music_volume, Settings.music, func(v: float) -> void: Settings.music_volume = v, func(on: bool) -> void: Settings.music = on))
	_row(sound, "Effects", _volume(Settings.sfx_volume, Settings.sound, func(v: float) -> void: Settings.sfx_volume = v, func(on: bool) -> void: Settings.sound = on))

	var display := _group(left, "Display")
	_row(display, "Graphics", _choice(Settings.QUALITY_NAMES, Settings.quality, func(i: int) -> void:
		Settings.quality = i
		CardArt.clear()))
	_row(display, "Frame rate", _choice(Settings.FPS_CHOICES.map(func(f: int) -> String: return "%d" % f), Settings.FPS_CHOICES.find(Settings.fps), func(i: int) -> void: Settings.fps = Settings.FPS_CHOICES[i]))
	_row(display, "CRT effect", _choice(Settings.CRT_NAMES, Settings.crt, func(i: int) -> void: Settings.crt = i))
	_row(display, "Reduce motion", UiTheme.switch(Settings.reduce_motion, func(on: bool) -> void: _change(func() -> void: Settings.reduce_motion = on, false)))

	var play := _group(right, "Play")
	_row(play, "Game speed", _choice(Settings.SPEEDS.map(func(sp: int) -> String: return "%dx" % sp), Settings.SPEEDS.find(Settings.speed), func(i: int) -> void: Settings.speed = Settings.SPEEDS[i]))
	_row(play, "Text & cards", _choice(Settings.SIZE_NAMES, Settings.size, func(i: int) -> void:
		Settings.size = i
		CardArt.clear()))
	_row(play, "Vibration", _choice(Settings.VIBRATION_NAMES, Settings.vibration_level, func(i: int) -> void:
		Settings.vibration_level = i
		Feel.buzz(30)))
	if Settings.tutorial_step < 0:
		_row(play, "First-run tips", UiTheme.button("Show again", func() -> void: _change(func() -> void: Settings.tutorial_step = 0)))

	var look := _group(right, "Card back")
	var back := HBoxContainer.new()
	back.add_theme_constant_override("separation", 8)
	var preview := CardView.new(Vector2(22, 31))
	preview.face_down = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(preview)
	back.add_child(UiTheme.button("Next design", func() -> void: _change(func() -> void: Settings.card_back = (Settings.card_back + 1) % Settings.CARD_BACKS.size())))
	_row(look, Settings.CARD_BACKS[Settings.card_back], back, 36.0)

	var account := _group(right, "Account")
	if not Online.signed_in():
		_row(account, "Offline", UiTheme.label("Progress stays on this device", 9, UiTheme.MUTED))
	else:
		var who := str(Online.user.get("name", ""))
		var how := "Guest" if Online.is_guest() else str(Online.user.get("email", "")) if str(Online.user.get("email", "")) != "" else "Apple / Google"
		_row(account, who, UiTheme.label(how, 9, UiTheme.MUTED))
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 5)
		if Online.is_guest():
			buttons.add_child(UiTheme.button("Save progress", func() -> void: _open(AccountSheet.new("signup")), 10, UiTheme.GOLD))
			buttons.add_child(UiTheme.button("Log in", func() -> void: _open(AccountSheet.new("login"))))
		else:
			buttons.add_child(UiTheme.button("Sign out", func() -> void:
				await Online.logout()
				if is_inside_tree():
					rebuild()))
		buttons.add_child(UiTheme.button("Profile", func() -> void: _open(ProfileSheet.new())))
		_row(account, "Cloud save: " + ("up to date" if not Online.dirty else "saving soon"), buttons, 30.0)


func _group(parent: Control, caption: String) -> VBoxContainer:
	var cap := UiTheme.label(caption.to_upper(), 8, UiTheme.MUTED)
	cap.add_theme_constant_override("shadow_offset_y", 0)
	parent.add_child(cap)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.border_color = UiTheme.TONAL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.anti_aliasing = true
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	card.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)
	parent.add_child(card)
	return rows


func _row(rows: VBoxContainer, caption: String, control: Control, height := 27.0) -> void:
	if rows.get_child_count() > 0:
		var hairline := ColorRect.new()
		hairline.color = Color(1, 1, 1, 0.08)
		hairline.custom_minimum_size = Vector2(0, 1)
		rows.add_child(hairline)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, height)
	row.add_theme_constant_override("separation", 8)
	var l := UiTheme.label(caption, 10, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.custom_minimum_size = Vector2(60, 0)
	row.add_child(l)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	rows.add_child(row)


func _choice(names: Array, chosen: int, pick: Callable) -> Control:
	var control := UiTheme.segmented(names, chosen, func(i: int) -> void: _change(pick.bind(i)), 9)
	control.custom_minimum_size = Vector2(150, 0)
	return control


func _volume(value: float, on: bool, set_value: Callable, set_on: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(120, 16)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.editable = on
	slider.modulate.a = 1.0 if on else 0.45
	slider.value_changed.connect(func(v: float) -> void:
		set_value.call(v)
		Settings.save()
		Feel.apply_settings())
	slider.drag_ended.connect(func(_changed: bool) -> void: Feel.play("select"))
	box.add_child(slider)
	box.add_child(UiTheme.switch(on, func(now: bool) -> void: _change(set_on.bind(now), true)))
	return box


func _change(apply: Callable, rebuild_after := true) -> void:
	apply.call()
	Settings.save()
	Feel.apply_settings()
	Feel.play("select")
	Feel.settings_changed.emit()
	if rebuild_after:
		rebuild()


func _open(sheet: Control) -> void:
	Feel.play("click")
	UiTheme.show_sheet(sheet)
