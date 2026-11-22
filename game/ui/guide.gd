class_name Guide
extends Control
## The guided first run's overlay. It dims the screen except for one spotlight on the
## thing to use next (a button, the hand, a panel), rings it with a slow pulse, and
## puts a short card of instructions beside it. Smaller rings can mark single cards
## (the first hand's suggested poker hand). It never blocks the game: every tap
## outside the card goes through, so the player always presses the real buttons.
## RunScreen decides which step to show (show_step) and when to hide it.

signal next_pressed
signal skip_pressed

const DIM := 0.58
const BUBBLE_W := 236.0

## Returns the spotlight's rect in global coordinates; an empty rect means none.
var target := Callable()
## Returns an Array of Rect2 to ring individually.
var marks := Callable()
var ui_scale := 1.0

var _key := ""
var _active := false
var _shown := 0.0
var _hole := Rect2()
var _t := 0.0
var _dim: ColorRect
var _material: ShaderMaterial
var _rings: Control
var _bubble: PanelContainer
var _caret := PackedVector2Array()


func _init(scale_factor: float) -> void:
	ui_scale = scale_factor
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/spotlight.gdshader")
	_material.set_shader_parameter("dim", 0.0)
	_dim.material = _material
	add_child(_dim)
	_rings = Control.new()
	_rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.draw.connect(_draw_rings)
	add_child(_rings)
	visible = false


## Show a step. Calling it again with the same key keeps the card where it is and only
## refreshes what it points at, so a rebuild of the screen doesn't make it flash.
func show_step(key: String, step: int, count: int, title: String, text: String, button_text: String, point_at: Callable, ring: Callable) -> void:
	target = point_at
	marks = ring
	_active = true
	visible = true
	if key == _key and _bubble != null:
		return
	_key = key
	if _bubble != null:
		_bubble.queue_free()
	_bubble = _make_bubble(step, count, title, text, button_text)
	add_child(_bubble)
	_bubble.modulate.a = 0.0
	_hole = Rect2()


func hide_step() -> void:
	_active = false
	_key = ""


func _make_bubble(step: int, count: int, title: String, text: String, button_text: String) -> PanelContainer:
	var bubble := PanelContainer.new()
	var glass := UiTheme.panel_box(Color(0.1, 0.055, 0.19, 0.97), UiTheme.GOLD.darkened(0.15))
	glass.set_corner_radius_all(14)
	glass.shadow_size = 12
	glass.shadow_color = Color(0, 0, 0, 0.45)
	glass.content_margin_left = 12
	glass.content_margin_right = 12
	glass.content_margin_top = 8
	glass.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", glass)
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.scale = Vector2(ui_scale, ui_scale)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	bubble.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var dots := Control.new()
	dots.custom_minimum_size = Vector2(count * 9.0 + 4.0, 12)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.draw.connect(func() -> void:
		for i in count:
			var on := i == step
			var c := Vector2(4.0 + i * 9.0, dots.size.y / 2.0)
			dots.draw_circle(c, 3.2 if on else 2.4, UiTheme.GOLD if i <= step else Color(1, 1, 1, 0.25), true, -1.0, true))
	top.add_child(dots)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var skip := UiTheme.button("Skip guide", func() -> void: skip_pressed.emit(), 8)
	skip.add_theme_color_override("font_color", UiTheme.MUTED)
	top.add_child(skip)
	col.add_child(top)
	var heading := UiTheme.title(title, 14, UiTheme.GOLD)
	col.add_child(heading)
	var body := UiTheme.label(text, 10, UiTheme.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(BUBBLE_W - 24.0, 0)
	col.add_child(body)
	if button_text != "":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var next := UiTheme.button(button_text, func() -> void: next_pressed.emit(), 10, UiTheme.POINTS)
		next.custom_minimum_size = Vector2(74, 24)
		row.add_child(next)
		col.add_child(row)
	bubble.size = Vector2(BUBBLE_W, 0)
	return bubble


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var rect := Rect2()
	if _active and target.is_valid():
		var found: Variant = target.call()
		if found is Rect2:
			rect = get_global_transform().affine_inverse() * (found as Rect2)
	if rect.has_area():
		var grown := rect.grow(5.0 * ui_scale)
		if not _hole.has_area() or Settings.reduce_motion:
			_hole = grown
		else:
			var k := clampf(delta * 14.0, 0.0, 1.0)
			_hole = Rect2(_hole.position.lerp(grown.position, k), _hole.size.lerp(grown.size, k))
	var speed := 99.0 if Settings.reduce_motion else 5.0
	_shown = move_toward(_shown, 1.0 if _active else 0.0, delta * speed)
	_material.set_shader_parameter("area_size", _dim.size)
	_material.set_shader_parameter("hole", Vector4(_hole.position.x, _hole.position.y, _hole.size.x, _hole.size.y) if _hole.has_area() else Vector4.ZERO)
	_material.set_shader_parameter("radius", 12.0 * ui_scale)
	_material.set_shader_parameter("dim", DIM * _shown)
	if _bubble != null:
		_bubble.modulate.a = _shown
		_place_bubble()
	_rings.queue_redraw()
	if _shown <= 0.0 and not _active:
		visible = false
		if _bubble != null:
			_bubble.queue_free()
			_bubble = null


## Put the card next to the spotlight: below it, above it, to its right or its left,
## whichever fits first, with a small caret pointing at it.
func _place_bubble() -> void:
	var view := size
	var b := _bubble.get_combined_minimum_size() * ui_scale
	_bubble.size = _bubble.get_combined_minimum_size()
	var gap := 12.0 * ui_scale
	var margin := 8.0
	var at := (view - b) / 2.0
	_caret = PackedVector2Array()
	if _hole.has_area():
		var c := _hole.get_center()
		var x := clampf(c.x - b.x / 2.0, margin, view.x - margin - b.x)
		var y := clampf(c.y - b.y / 2.0, margin, view.y - margin - b.y)
		var options := [
			["below", Vector2(x, _hole.end.y + gap), _hole.end.y + gap + b.y <= view.y - margin],
			["above", Vector2(x, _hole.position.y - gap - b.y), _hole.position.y - gap - b.y >= margin],
			["right", Vector2(_hole.end.x + gap, y), _hole.end.x + gap + b.x <= view.x - margin],
			["left", Vector2(_hole.position.x - gap - b.x, y), _hole.position.x - gap - b.x >= margin],
		]
		var side := "above"
		at = Vector2(x, maxf(margin, _hole.position.y - gap - b.y))
		for o in options:
			if o[2]:
				side = o[0]
				at = o[1]
				break
		var s := 7.0 * ui_scale
		match side:
			"below":
				var cx := clampf(c.x, at.x + 18.0, at.x + b.x - 18.0)
				_caret = PackedVector2Array([Vector2(cx - s, at.y + 1), Vector2(cx + s, at.y + 1), Vector2(cx, at.y - s)])
			"above":
				var cx := clampf(c.x, at.x + 18.0, at.x + b.x - 18.0)
				_caret = PackedVector2Array([Vector2(cx - s, at.y + b.y - 1), Vector2(cx + s, at.y + b.y - 1), Vector2(cx, at.y + b.y + s)])
			"right":
				var cy := clampf(c.y, at.y + 18.0, at.y + b.y - 18.0)
				_caret = PackedVector2Array([Vector2(at.x + 1, cy - s), Vector2(at.x + 1, cy + s), Vector2(at.x - s, cy)])
			"left":
				var cy := clampf(c.y, at.y + 18.0, at.y + b.y - 18.0)
				_caret = PackedVector2Array([Vector2(at.x + b.x - 1, cy - s), Vector2(at.x + b.x - 1, cy + s), Vector2(at.x + b.x + s, cy)])
	_bubble.position = at.round()


func _draw_rings() -> void:
	if _shown <= 0.0:
		return
	var pulse := 0.0 if Settings.reduce_motion else 0.5 + 0.5 * sin(_t * 4.0)
	if _hole.has_area():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = Color(UiTheme.GOLD, (0.55 + 0.4 * pulse) * _shown)
		ring.set_border_width_all(2)
		ring.set_corner_radius_all(int(12.0 * ui_scale + 3.0))
		ring.anti_aliasing = true
		_rings.draw_style_box(ring, _hole.grow(1.0 + 3.0 * pulse * ui_scale))
	if marks.is_valid() and _active:
		var found: Variant = marks.call()
		if found is Array:
			var inverse := get_global_transform().affine_inverse()
			for r: Variant in found:
				if not (r is Rect2):
					continue
				# A gold wash and outline on the card, and a small arrow bobbing above it.
				var card := (inverse * (r as Rect2)).grow(2.0 * ui_scale)
				var mark := StyleBoxFlat.new()
				mark.bg_color = Color(UiTheme.GOLD, (0.1 + 0.08 * pulse) * _shown)
				mark.border_color = Color(UiTheme.GOLD.lightened(0.25), _shown)
				mark.set_border_width_all(maxi(2, roundi(3.0 * ui_scale)))
				mark.set_corner_radius_all(int(8.0 * ui_scale))
				mark.anti_aliasing = true
				_rings.draw_style_box(mark, card)
				var tip := Vector2(card.get_center().x, card.position.y - (5.0 + 4.0 * pulse) * ui_scale)
				var w := 7.0 * ui_scale
				var arrow := PackedVector2Array([tip, tip + Vector2(-w, -w * 1.1), tip + Vector2(w, -w * 1.1)])
				_rings.draw_colored_polygon(arrow, Color(UiTheme.GOLD.lightened(0.25), _shown))
	if _caret.size() == 3 and _bubble != null:
		_rings.draw_colored_polygon(_caret, Color(UiTheme.GOLD.darkened(0.15), _shown))
