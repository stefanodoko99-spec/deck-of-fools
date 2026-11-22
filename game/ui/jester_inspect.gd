class_name JesterInspect
extends Control
## One Jester up close, from the collection: the card held large in a glow of its
## rarity colour, tilting toward your finger or pointer and swaying on its own when
## left alone, next to its rarity, effect and your record with it. Swipe the card or
## use the arrows (or the arrow keys) to move along the collection; tap outside the
## card or press Esc to go back.

signal finished(index: int)

const CARD := Vector2(176, 246)
const CARD_AT := Vector2(92, 57)
const INFO_X := 312.0
const INFO_W := 292.0

var ids: Array = []
var index := 0
var _stage: Control
var _glow: Control
var _card: CardView
var _info: VBoxContainer
var _counter: Label
var _down := Vector2.ZERO
var _closing := false


func _init(list: Array, at: int) -> void:
	ids = list
	index = at


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Above the collection's cards, which rise (z_index 1) while hovered.
	z_index = 10
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.05, 0.9)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_stage = UiTheme.stage(self)
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.size = UiTheme.STAGE
	_glow.draw.connect(_draw_glow)
	_stage.add_child(_glow)
	_info = VBoxContainer.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.alignment = BoxContainer.ALIGNMENT_CENTER
	_info.add_theme_constant_override("separation", 6)
	_info.position = Vector2(INFO_X, 30)
	_info.size = Vector2(INFO_W, 300)
	_stage.add_child(_info)
	var close_button := UiTheme.icon_button("close", close, 28.0)
	close_button.position = Vector2(UiTheme.STAGE.x - 40, 10)
	_stage.add_child(close_button)
	if ids.size() > 1:
		var back := UiTheme.icon_button("back", _step.bind(-1), 28.0)
		back.position = Vector2(14, UiTheme.STAGE.y / 2.0 - 14)
		_stage.add_child(back)
		var next := UiTheme.icon_button("forward", _step.bind(1), 28.0)
		next.position = Vector2(UiTheme.STAGE.x - 42, UiTheme.STAGE.y / 2.0 - 14)
		_stage.add_child(next)
	_counter = UiTheme.label("", 9, UiTheme.MUTED)
	_counter.position = Vector2(CARD_AT.x, CARD_AT.y + CARD.y + 20)
	_counter.size = Vector2(CARD.x, 14)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_counter)
	_show(0)
	if not Settings.reduce_motion:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _found() -> bool:
	return Game.profile.discovered.has(str(ids[index]))


func _show(direction: int) -> void:
	var id := str(ids[index])
	var def := ContentDB.get_def(id)
	var rarity := clampi(def.rarity, 0, 3)
	var found := _found()
	if _card != null:
		_card.queue_free()
	_card = CardView.new(CARD)
	_card.kind = "zanni"
	_card.def_id = id
	_card.face_down = not found
	_card.showcase = true
	_card.swipe_sideways = true
	_card.position = CARD_AT
	_card.swiped.connect(func(_v: CardView, d: int) -> void: _step(d))
	_card.tapped.connect(func(_v: CardView) -> void: _pop())
	_stage.add_child(_card)
	_stage.move_child(_card, _glow.get_index() + 1)
	_glow.set_meta("colour", CardView.RARITY_COLOURS[rarity])
	_glow.queue_redraw()
	_counter.text = "%d of %d" % [index + 1, ids.size()] if ids.size() > 1 else ""
	_fill_info(id, def, rarity, found)
	if Settings.reduce_motion:
		return
	# Deal the card in: from the side it was swiped toward, or up from the table.
	var rest := _card.position
	_card.pivot_offset = CARD / 2.0
	_card.modulate.a = 0.0
	if direction == 0:
		_card.scale = Vector2(0.72, 0.72)
		_card.rotation = -0.08
	else:
		_card.position = rest + Vector2(70.0 * direction, 0)
		_card.rotation = 0.12 * direction
	var t := _card.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "position", rest, 0.34)
	t.tween_property(_card, "scale", Vector2.ONE, 0.34)
	t.tween_property(_card, "rotation", 0.0, 0.34)
	t.tween_property(_card, "modulate:a", 1.0, 0.14)
	_info.modulate.a = 0.0
	_info.create_tween().tween_property(_info, "modulate:a", 1.0, 0.22).set_delay(0.06)


func _fill_info(id: String, def: ContentDef, rarity: int, found: bool) -> void:
	for child in _info.get_children():
		child.queue_free()
	var p := Game.profile
	var number := CollectionSheet.numbered().find(id) + 1
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(_pill(CardView.RARITY_NAMES[rarity], CardView.RARITY_COLOURS[rarity]))
	tags.add_child(UiTheme.label("#%d of %d" % [number, CollectionSheet.numbered().size()], 9, UiTheme.MUTED))
	_info.add_child(tags)
	if not found:
		var lock := CollectionSheet.lock_words(id)
		_info.add_child(_wrap(UiTheme.title("Locked" if lock != "" else "Not found yet", 24, UiTheme.TEXT)))
		if lock != "":
			_info.add_child(_wrap(UiTheme.label("To unlock it: %s." % lock, 12, UiTheme.GOLD)))
			_info.add_child(_wrap(UiTheme.label("Once it's unlocked it can turn up in shops and packs.", 10, UiTheme.MUTED)))
		else:
			_info.add_child(_wrap(UiTheme.label("Meet this Jester in a shop or a pack and it joins your collection.", 12, UiTheme.TEXT)))
		return
	_info.add_child(_wrap(UiTheme.title(UiTheme.name_of(id), 26, UiTheme.TEXT)))
	_info.add_child(_wrap(UiTheme.label(UiTheme.text_of(id), 13, UiTheme.TEXT)))
	var gloss := TranslationServer.translate(id + ".gloss")
	if gloss != id + ".gloss":
		_info.add_child(_wrap(UiTheme.label(gloss, 10, UiTheme.MUTED)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_info.add_child(gap)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.add_child(_stat(str(int(p.jester_runs.get(id, 0))), "Runs with it"))
	stats.add_child(_stat(str(int(p.jester_wins.get(id, 0))), "Wins with it", UiTheme.GOOD))
	var best := int(p.badges.get(id, 0))
	stats.add_child(_stat("Stake %d" % best if best > 0 else "None yet", "Best tour won", UiTheme.GOLD))
	_info.add_child(stats)


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INFO_W, 0)
	return l


func _pill(text: String, colour: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.box(colour, colour.lightened(0.25), 99)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 9, Color.WHITE)
	l.add_theme_font_override("font", UiTheme.bold)
	pill.add_child(l)
	return pill


func _stat(value: String, caption: String, colour := UiTheme.TEXT) -> PanelContainer:
	var tile := PanelContainer.new()
	var box := UiTheme.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 12)
	box.set_content_margin_all(6)
	tile.add_theme_stylebox_override("panel", box)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := UiTheme.title(value, 16, colour)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	var small := UiTheme.label(caption, 8, UiTheme.MUTED)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(small)
	tile.add_child(col)
	return tile


func _draw_glow() -> void:
	var colour: Color = _glow.get_meta("colour", UiTheme.GOLD)
	var c := CARD_AT + CARD / 2.0
	Paint.glow(_glow, c, 190.0, Color(colour.lightened(0.2), 0.55), 12)
	Paint.glow(_glow, c, 120.0, Color(colour.lightened(0.5), 0.25), 8)


func _step(direction: int) -> void:
	if ids.size() < 2 or _closing:
		return
	Feel.play("deal")
	Feel.buzz(8)
	index = posmod(index + direction, ids.size())
	_show(direction)


func _pop() -> void:
	Feel.play("select")
	if Settings.reduce_motion:
		return
	var t := _card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "scale", Vector2(1.06, 1.06), 0.08)
	t.tween_property(_card, "scale", Vector2.ONE, 0.2)


func close() -> void:
	if _closing:
		return
	_closing = true
	Feel.play("click")
	finished.emit(index)
	if Settings.reduce_motion:
		queue_free()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)


## A tap on the background closes; a sideways drag on it moves along like a swipe
## on the card.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = event.global_position
		else:
			var moved: Vector2 = event.global_position - _down
			if absf(moved.x) > 40.0 and absf(moved.x) > absf(moved.y) * 1.4:
				_step(1 if moved.x < 0.0 else -1)
			elif moved.length() < 9.0:
				close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			_step(-1)
		KEY_RIGHT:
			_step(1)
		_:
			return
	get_viewport().set_input_as_handled()
