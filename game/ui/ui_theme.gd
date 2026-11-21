class_name UiTheme
extends RefCounted




const BG := Color("1b1026")
const PANEL := Color("2b1a3d")
const PANEL_DARK := Color("170d22")
const PANEL_LIGHT := Color("3d2756")
const OUTLINE := Color("140b1e")
const STAGE := Vector2(640, 360)
const GOLD := Color("f0b84a")
const POINTS := Color("3f8ed8")
const MULT := Color("e0503c")
const TEXT := Color("fbf3e4")
const MUTED := Color("cbbfe0")
const CARD := Color("f6ecd4")
const RED_SUIT := Color("b5122e")
const BLACK_SUIT := Color("1d2340")
const GOOD := Color("6cc46a")
## Modern surfaces: frosted dark glass over the vivid backdrop, and tonal fills
## (a faint white) for secondary buttons, tracks and grouped rows.
const GLASS := Color(0.09, 0.05, 0.17, 0.76)
const GLASS_EDGE := Color(1, 1, 1, 0.13)
const TONAL := Color(1, 1, 1, 0.1)
const TONAL_EDGE := Color(1, 1, 1, 0.16)
const INK := Color("1d1230")

## Every face is Inter, the open typeface closest to Apple's San Francisco, from one
## variable font file. Body text: Inter Medium at the text optical size.
static var font: Font
## Buttons and emphasis: Inter Bold.
static var bold: Font
## Titles and card numbers: Inter ExtraBold at the display optical size.
static var display: Font


static var sheet_host: Control


static func show_sheet(sheet: Control) -> void:
	if sheet_host != null:
		sheet_host.add_child(sheet)



static func sheet_open() -> bool:
	if sheet_host == null:
		return false
	for child in sheet_host.get_children():
		if child.has_signal("closed") and not child.is_queued_for_deletion():
			return true
	return false


static func _font(path: String) -> FontFile:
	var file: FontFile = load(path)
	file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	file.hinting = TextServer.HINTING_LIGHT
	file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return file


static func _weight(base: Font, weight: int, optical: int) -> FontVariation:
	var ts := TextServerManager.get_primary_interface()
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = { ts.name_to_tag("wght"): weight, ts.name_to_tag("opsz"): optical }
	return v


static func build() -> Theme:
	var inter := _font("res://fonts/Inter.ttf")
	font = _weight(inter, 500, 14)
	bold = _weight(inter, 700, 14)
	display = _weight(inter, 800, 32)
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = px(10)
	t.set_font("font", "Button", bold)
	_style_button(t, null, PANEL_LIGHT)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.42))
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("shadow_outline_size", "Label", 2)
	var field := box(Color(0, 0, 0, 0.3), TONAL_EDGE, 10)
	field.content_margin_left = 10
	field.content_margin_right = 10
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	var focused := field.duplicate() as StyleBoxFlat
	focused.border_color = GOLD
	focused.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", focused)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	t.set_font_size("font_size", "LineEdit", px(11))
	# Slider: a thin pill track, gold where filled, with a round white knob.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.18)
	track.set_corner_radius_all(99)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = GOLD
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob := _knob(14)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	return t


## A white round slider knob with a soft shadow, drawn once into a texture.
static func _knob(diameter: int) -> ImageTexture:
	var scale := 3
	var n := diameter * scale
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c + Vector2(0, scale * 0.8))
			var shadow := clampf((n * 0.46 - d) / (scale * 2.0), 0.0, 1.0) * 0.35
			var e := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var body := clampf((n * 0.4 - e) / scale, 0.0, 1.0)
			var col := Color(0, 0, 0, shadow).blend(Color(1, 1, 1, body))
			img.set_pixel(x, y, col)
	img.resize(diameter, diameter, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func box(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(maxi(radius, 6))
	s.anti_aliasing = true
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func panel_box(bg := PANEL, border := PANEL_LIGHT) -> StyleBoxFlat:
	# Frosted glass: a translucent dark pane, a hairline edge (tinted by `border`
	# when it is an accent colour) and a soft drop shadow.
	var tint := GLASS.lerp(Color(bg, GLASS.a), 0.35) if bg != PANEL else GLASS
	var edge := GLASS_EDGE if border == PANEL_LIGHT else Color(border.lightened(0.15), 0.55)
	var s := box(tint, edge, 14)
	s.shadow_color = Color(0, 0, 0, 0.32)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


static func button_box(colour: Color, pressed := false) -> StyleBoxFlat:
	# Pill buttons. Neutral colours become a tonal glass pill; any other colour is
	# a filled pill with a soft shadow that flattens when pressed.
	var neutral := colour == PANEL_LIGHT or colour == PANEL_DARK or colour == TONAL
	var s := StyleBoxFlat.new()
	s.anti_aliasing = true
	s.set_corner_radius_all(99)
	if neutral:
		s.bg_color = TONAL.lightened(0.0) if not pressed else Color(1, 1, 1, 0.06)
		s.border_color = TONAL_EDGE
		s.set_border_width_all(1)
	else:
		s.bg_color = colour
		s.border_color = colour.lightened(0.25)
		s.border_width_top = 1
		if not pressed:
			s.shadow_color = Color(0, 0, 0, 0.3)
			s.shadow_size = 4
			s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func _style_button(t: Theme, b: Button, colour: Color) -> void:
	var neutral := colour == PANEL_LIGHT or colour == PANEL_DARK or colour == TONAL
	var hover := button_box(colour.lightened(0.12))
	if neutral:
		hover = button_box(colour)
		hover.bg_color = Color(1, 1, 1, 0.16)
	# Disabled: a solid, dimmed pill that stays readable over the bright backdrop.
	var disabled := button_box(colour)
	disabled.bg_color = Color(0.08, 0.05, 0.14, 0.82) if neutral else Color(colour.darkened(0.55).lerp(GLASS, 0.35), 0.9)
	disabled.border_color = Color(1, 1, 1, 0.1)
	disabled.set_border_width_all(1)
	disabled.shadow_size = 0
	var styles := { "normal": button_box(colour), "hover": hover, "pressed": button_box(colour.darkened(0.12), true), "disabled": disabled }
	for state in styles:
		if t != null:
			t.set_stylebox(state, "Button", styles[state])
		else:
			b.add_theme_stylebox_override(state, styles[state])
	# Light fills (gold, cream) take dark text.
	if b != null and not neutral and colour.get_luminance() > 0.55:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(key, INK)
		b.add_theme_color_override("font_disabled_color", Color(TEXT, 0.42))


static func px(size: int) -> int:
	# Layout sizes were set for an 8-10 px pixel font. Inter's tall lowercase reads larger
	# than that already, so body text grows a tenth, with nothing under 10 px.
	var grown: float = size * 1.1 if size <= 14 else float(size)
	return maxi(10, roundi(grown * Settings.text_scale()))


static func label(text: String, size := 10, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	return l



static func segmented(names: Array, chosen: int, pick: Callable, size := 10) -> PanelContainer:
	# An iOS segmented control: a dark track with the chosen option as a light pill.
	var track := PanelContainer.new()
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = Color(0, 0, 0, 0.28)
	track_box.border_color = TONAL_EDGE
	track_box.set_border_width_all(1)
	track_box.set_corner_radius_all(99)
	track_box.anti_aliasing = true
	track_box.set_content_margin_all(2)
	track.add_theme_stylebox_override("panel", track_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	track.add_child(row)
	for i in names.size():
		var b := Button.new()
		b.text = str(names[i])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", px(size))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pill := StyleBoxFlat.new()
		pill.set_corner_radius_all(99)
		pill.anti_aliasing = true
		pill.content_margin_left = 8
		pill.content_margin_right = 8
		pill.content_margin_top = 2
		pill.content_margin_bottom = 2
		if i == chosen:
			pill.bg_color = TEXT
			pill.shadow_color = Color(0, 0, 0, 0.3)
			pill.shadow_size = 3
			pill.shadow_offset = Vector2(0, 1)
			for state in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(state, pill)
			for key in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(key, INK)
		else:
			pill.bg_color = Color(1, 1, 1, 0.0)
			var over := pill.duplicate() as StyleBoxFlat
			over.bg_color = Color(1, 1, 1, 0.1)
			b.add_theme_stylebox_override("normal", pill)
			b.add_theme_stylebox_override("hover", over)
			b.add_theme_stylebox_override("pressed", over)
			b.add_theme_color_override("font_color", MUTED)
			b.add_theme_color_override("font_hover_color", TEXT)
		b.pressed.connect(pick.bind(i))
		row.add_child(b)
	return track


static func title(text: String, size := 16, color := GOLD) -> Label:
	# Modern titles: heavy Inter with a soft blurred shadow instead of an outline.
	var l := label(text, size, color)
	l.add_theme_font_override("font", display)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 14))
	l.add_theme_constant_override("shadow_outline_size", maxi(3, size / 4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	return l



static func button(text: String, on_press: Callable, size := 10, colour := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", px(size))
	if colour.a > 0.0:
		_style_button(null, b, colour)
	b.pressed.connect(on_press)
	_press_feel(b)
	return b


## Buttons dip slightly when pressed and spring back, like system buttons.
static func _press_feel(b: Control) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.gui_input.connect(func(event: InputEvent) -> void:
		if Settings.reduce_motion or not (event is InputEventMouseButton or event is InputEventScreenTouch):
			return
		var down: bool = event.pressed
		var tween := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(b, "scale", Vector2(0.95, 0.95) if down else Vector2.ONE, 0.07 if down else 0.16))


## A round glass button holding a line icon (settings, profile, trophy, help...).
static func icon_button(icon: String, on_press: Callable, diameter := 26.0, colour := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button(null, b, colour if colour.a > 0.0 else TONAL)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var st := b.get_theme_stylebox(state) as StyleBoxFlat
		if st != null:
			st.set_content_margin_all(0)
	var glyph := UiIcon.new(icon, INK if colour.a > 0.0 and colour.get_luminance() > 0.55 else TEXT)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = diameter * 0.22
	glyph.offset_top = diameter * 0.22
	glyph.offset_right = -diameter * 0.22
	glyph.offset_bottom = -diameter * 0.22
	b.add_child(glyph)
	b.pressed.connect(on_press)
	_press_feel(b)
	return b


static func switch(on: bool, changed: Callable) -> UiSwitch:
	var sw := UiSwitch.new(on)
	sw.toggled.connect(changed)
	return sw


static func stage(parent: Control) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.offset_left = -STAGE.x / 2.0
	s.offset_right = STAGE.x / 2.0
	s.offset_top = -STAGE.y / 2.0
	s.offset_bottom = STAGE.y / 2.0
	parent.add_child(s)
	return s



static func number(value: float) -> String:
	if absf(value) >= 100000000000.0:
		var exponent := floori(log(absf(value)) / log(10.0))
		return "%.2fe%d" % [value / pow(10.0, exponent), exponent]
	var digits := str(int(value))
	var negative := digits.begins_with("-")
	if negative:
		digits = digits.substr(1)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if negative else "") + digits + out


static func name_of(def_id: String) -> String:
	return TranslationServer.translate(def_id + ".name")


static func text_of(def_id: String) -> String:
	return TranslationServer.translate(def_id + ".text")
