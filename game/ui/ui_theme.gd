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

## Body text: Alegreya Sans Medium, a Renaissance humanist sans that stays clear at small sizes.
static var font: Font
## Buttons and emphasis: Alegreya Sans ExtraBold.
static var bold: Font
## Titles, card names and card numbers: Cinzel Bold, Roman inscriptional capitals.
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


static func build() -> Theme:
	font = _font("res://fonts/AlegreyaSans-Medium.ttf")
	bold = _font("res://fonts/AlegreyaSans-ExtraBold.ttf")
	var cinzel := FontVariation.new()
	cinzel.base_font = _font("res://fonts/Cinzel.ttf")
	cinzel.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }
	display = cinzel
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = px(10)
	t.set_font("font", "Button", bold)
	_style_button(t, null, PANEL_LIGHT)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	var field := box(PANEL_DARK, PANEL_LIGHT, 4)
	field.set_border_width_all(2)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	var focused := field.duplicate() as StyleBoxFlat
	focused.border_color = GOLD
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", focused)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED.darkened(0.15))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	t.set_font_size("font_size", "LineEdit", 11)
	var track := box(PANEL_DARK, PANEL_LIGHT, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := box(GOLD.darkened(0.25), GOLD.darkened(0.25), 3)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return t


static func box(bg: Color, border: Color, radius := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s



static func panel_box(bg := PANEL, border := PANEL_LIGHT) -> StyleBoxFlat:
	var s := box(bg, border, 6)
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s



static func button_box(colour: Color, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	s.border_color = colour.darkened(0.5)
	s.border_width_bottom = 1 if pressed else 3
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4 if pressed else 2
	s.content_margin_bottom = 3 if pressed else 5
	return s


static func _style_button(t: Theme, b: Button, colour: Color) -> void:
	var styles := {
		"normal": button_box(colour), "hover": button_box(colour.lightened(0.15)),
		"pressed": button_box(colour.darkened(0.1), true), "disabled": button_box(colour.darkened(0.55)),
	}
	for state in styles:
		if t != null:
			t.set_stylebox(state, "Button", styles[state])
		else:
			b.add_theme_stylebox_override(state, styles[state])



static func px(size: int) -> int:
	# Layout sizes were set for an 8-10 px pixel font. Body text now reads about a fifth
	# larger, with nothing under 10 px; big titles stay close to their old size.
	var grown := size * 1.2 if size <= 14 else size * 1.05
	return maxi(10, roundi(grown * Settings.text_scale()))


static func label(text: String, size := 10, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	return l



static func segmented(names: Array, chosen: int, pick: Callable, size := 10) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for i in names.size():
		var b := button(str(names[i]), pick.bind(i), size, GOLD.darkened(0.2) if i == chosen else PANEL_DARK)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row



static func title(text: String, size := 16, color := GOLD) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", display)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 12))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	return l



static func button(text: String, on_press: Callable, size := 10, colour := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px(size))
	if colour.a > 0.0:
		_style_button(null, b, colour)
	b.pressed.connect(on_press)
	return b



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
