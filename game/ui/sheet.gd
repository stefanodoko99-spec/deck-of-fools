class_name Sheet
extends Control




signal closed

var title_text := ""
var panel_size := Vector2(420, 320)

var closable := true
var body: VBoxContainer
var heading: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	var glass := UiTheme.panel_box()
	glass.bg_color = Color(0.1, 0.055, 0.19, 0.985)
	glass.set_corner_radius_all(18)
	glass.shadow_size = 18
	glass.shadow_color = Color(0, 0, 0, 0.45)
	glass.content_margin_left = 14
	glass.content_margin_right = 14
	glass.content_margin_top = 10
	glass.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", glass)
	panel.position = (UiTheme.STAGE - panel_size) / 2.0
	panel.size = panel_size
	UiTheme.stage(self).add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	# Header: the title on the left, a round close button on the right.
	var top := HBoxContainer.new()
	heading = UiTheme.title(title_text, 18, UiTheme.GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	if closable:
		top.add_child(UiTheme.icon_button("close", close, 24.0))
	col.add_child(top)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_build()
	heading.text = title_text
	# Slide up and fade in, like a system sheet.
	if not Settings.reduce_motion:
		var rest := panel.position
		panel.position = rest + Vector2(0, 26)
		panel.modulate.a = 0.0
		shade.modulate.a = 0.0
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position", rest, 0.26)
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)
		tween.tween_property(shade, "modulate:a", 1.0, 0.2)


func _build() -> void:
	pass



func _unhandled_input(event: InputEvent) -> void:
	if closable and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func rebuild() -> void:
	for child in body.get_children():
		child.queue_free()
	_build()
	heading.text = title_text


func close() -> void:
	Feel.play("click")
	closed.emit()
	queue_free()



func words(text: String, font_size := 10, colour := UiTheme.TEXT) -> Label:
	var l := UiTheme.label(text, font_size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(panel_size.x - 24, 0)
	return l


func field(placeholder: String, secret := false) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.secret = secret
	f.custom_minimum_size = Vector2(0, 24)
	return f



func pair(caption: String, value: String, colour := UiTheme.TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key := UiTheme.label(caption, 10, UiTheme.MUTED)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key)
	row.add_child(UiTheme.label(value, 10, colour))
	return row



static func ago(unix: float) -> String:
	var seconds := int(Time.get_unix_time_from_system() - unix)
	if seconds < 90:
		return "just now"
	if seconds < 5400:
		return "%d minutes ago" % (seconds / 60)
	if seconds < 129600:
		return "%d hours ago" % (seconds / 3600)
	return "%d days ago" % (seconds / 86400)
