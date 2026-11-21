class_name CardView
extends Control






signal tapped(view: CardView)

const RANKS := { 11: "J", 12: "Q", 13: "K", 14: "A" }
const KIND_COLOURS := {
	"tarocchi": Color("6a3d9a"), "sign": Color("23407a"), "omen": Color("1f6e6a"),
	"pack": Color("7a4a25"), "warrant": Color("8a6a1a"), "show": Color("3d2756"),
}

const RARITY_COLOURS := [Color("3f74c4"), Color("2f9a5a"), Color("c43a4a"), Color("c8962a")]
## Modern four-colour deck: spades navy, hearts red, clubs green, diamonds blue.
const SUIT_COLOURS := [Color("1e2340"), Color("ef2d56"), Color("12a150"), Color("2b7cff")]
## Card bodies as diagonal gradients: Jesters by rarity (blue, green, pink-red, amber),
## other items by kind.
const RARITY_GRADIENTS := [
	[Color("4f8cff"), Color("5b4bdb")], [Color("22c493"), Color("0f8f8a")],
	[Color("ff5d8f"), Color("d6204f")], [Color("ffb547"), Color("f0642a")],
]
## Metallic frames by rarity: steel, emerald, gold; Legendary is holographic.
const FRAME_METALS := [
	[Color("e9eef5"), Color("8e9bb0"), Color("4a5568")], [Color("c9f5e0"), Color("2fae7a"), Color("0f5a40")],
	[Color("fff1c2"), Color("e0a83a"), Color("8a5a14")], [Color("ffe6ff"), Color("b48cff"), Color("4a2a8a")],
]
const KIND_GRADIENTS := {
	"tarocchi": [Color("a26bff"), Color("6a2fd1")], "sign": [Color("5b7cff"), Color("2f3fb8")],
	"omen": [Color("2fd3c0"), Color("118a8f")], "pack": [Color("ff9a4a"), Color("e0562a")],
	"warrant": [Color("ffc94d"), Color("e09a1a")], "patron": [Color("ff5a6e"), Color("b3193a")],
	"favor": [Color("ffd66b"), Color("f0a020")], "show": [Color("7d6bf0"), Color("3d2a8a")],
}
## (Older lacquer colours, kept for any screen that still reads them.)
const RARITY_LACQUER := [Color("1f5a9a"), Color("157a52"), Color("a3152f"), Color("8a5a12")]

const BACKDROPS := [Color("2a1240"), Color("0e2a44"), Color("3a0f1c"), Color("0f3a2e"), Color("3a2a0c"), Color("1c1c4a")]
const EDITION_COLOURS := {
	"ed_silvered": Color("cfd8e0"), "ed_opaline": Color("ff8fd0"),
	"ed_prismatic": Color("7fffd4"), "ed_shadow": Color("101010"),
}
const SEAL_COLOURS := {
	"seal_ducal": Color("f0b84a"), "seal_encore": Color("e0503c"),
	"seal_astral": Color("3f8ed8"), "seal_oracle": Color("9a5ad0"),
}
const INK := Color("2a2433")
const EDGE := Color("3a2e2a")
const PAPER_LINE := Color("c9b48c")

const PIPS := {
	2: [[1, 0.0], [1, 1.0]],
	3: [[1, 0.0], [1, 0.5], [1, 1.0]],
	4: [[0, 0.0], [2, 0.0], [0, 1.0], [2, 1.0]],
	5: [[0, 0.0], [2, 0.0], [1, 0.5], [0, 1.0], [2, 1.0]],
	6: [[0, 0.0], [2, 0.0], [0, 0.5], [2, 0.5], [0, 1.0], [2, 1.0]],
	7: [[0, 0.0], [2, 0.0], [1, 0.25], [0, 0.5], [2, 0.5], [0, 1.0], [2, 1.0]],
	8: [[0, 0.0], [2, 0.0], [1, 0.25], [0, 0.5], [2, 0.5], [1, 0.75], [0, 1.0], [2, 1.0]],
	9: [[0, 0.0], [2, 0.0], [0, 0.33], [2, 0.33], [1, 0.5], [0, 0.67], [2, 0.67], [0, 1.0], [2, 1.0]],
	10: [[0, 0.0], [2, 0.0], [1, 0.17], [0, 0.33], [2, 0.33], [0, 0.67], [2, 0.67], [1, 0.83], [0, 1.0], [2, 1.0]],
}

const COSTUME_COLOURS := [
	Color("e0503c"), Color("3f8ed8"), Color("6cc46a"), Color("f0b84a"),
	Color("9a5ad0"), Color("2e9c8f"), Color("f3ead8"), Color("2a2433"),
]
const SKINS := [Color("f3ead8"), Color("f1c8a0"), Color("d9a27a"), Color("a86f4c"), Color("7a4e34")]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]


signal long_pressed(view: CardView)

signal drag_moved(view: CardView, at: Vector2)
signal drag_ended(view: CardView, at: Vector2)

signal swiped(view: CardView, direction: int)

const HOLD_SECONDS := 0.42
const FOILS := { "ed_silvered": 1, "ed_opaline": 2, "ed_prismatic": 3, "ed_shadow": 4 }

var kind := "card"
var card: PlayingCard
var def_id := ""
var edition := ""
var sticker := ""
var selected := false
var dimmed := false
var face_down := false
## Card back to draw; -1 follows the player's setting.
var back_style := -1
var price_text := ""

var tag: Dictionary = {}

var sway := -1
var draggable := false
var swipeable := false

var baking := false
## Illustrated art for this card, loaded before the bake. Loading a texture for the
## first time inside _draw gives a blank white image in the one-shot bake.
var art_texture: Texture2D = null

var _face: TextureRect
var _overlay: Control
var _material: ShaderMaterial
var _tilt := Vector2.ZERO
var _hovered := false
var _gesture := ""
var _press_at := Vector2.ZERO
var _hold_id := 0


func _init(view_size := Vector2(52, 72)) -> void:
	custom_minimum_size = view_size
	size = view_size
	pivot_offset = view_size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_lift.bind(true))
	mouse_exited.connect(_lift.bind(false))


func _ready() -> void:
	if baking:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_face.size = size
	add_child(_face)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	if Settings.quality > 0:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/card.gdshader")
		_material.set_shader_parameter("card_size", size)
		_material.set_shader_parameter("foil", 0 if face_down else FOILS.get(edition, 0))
		_face.material = _material
	set_art(CardArt.request(self))
	set_process(_material != null or sway >= 0)



func set_art(texture: Texture2D) -> void:
	if _face != null and texture != null:
		_face.texture = texture



func art_key() -> String:
	var face := ""
	if face_down:
		face = "back%d" % _back_index()
	elif kind == "card":
		face = "card %d %d %s %s %s" % [card.rank, card.suit, card.enhancement, edition, card.seal]
	else:
		face = "%s %s %s %s" % [kind, def_id, edition, sticker]
	return "%s @%dx%d q%d" % [face, size.x, size.y, Settings.quality]


func baked_copy() -> CardView:
	var copy := CardView.new(size)
	copy.kind = kind
	copy.card = card
	copy.def_id = def_id
	copy.edition = edition
	copy.sticker = sticker
	copy.face_down = face_down
	copy.back_style = _back_index()
	copy.baking = true
	copy.art_texture = art_for(kind, def_id)
	# Illustrated Jester art is far larger than the card, so shrink it smoothly
	# (the project default is pixel-sharp nearest filtering).
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return copy


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if Settings.reduce_motion:
		rotation = 0.0
		_tilt = Vector2.ZERO
	else:
		if sway >= 0 and _gesture != "drag":
			rotation = sin(t * 1.6 + sway * 0.9) * 0.025
		var target := Vector2.ZERO
		if _hovered or _gesture != "":
			target = ((get_local_mouse_position() / size) - Vector2(0.5, 0.5)) * 2.0
		elif sway >= 0:
			target = Vector2(sin(t * 1.1 + sway), cos(t * 0.8 + sway * 1.3)) * 0.18
		_tilt = _tilt.lerp(target.clamp(Vector2(-1, -1), Vector2(1, 1)), clampf(delta * 10.0, 0.0, 1.0))
	if _material != null:
		_material.set_shader_parameter("tilt", _tilt)




func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			long_pressed.emit(self)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_gesture = "press"
			_press_at = event.global_position
			_hold_id += 1
			var id := _hold_id
			get_tree().create_timer(HOLD_SECONDS).timeout.connect(func() -> void:
				if _gesture == "press" and _hold_id == id and is_inside_tree():
					_gesture = "held"
					long_pressed.emit(self))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _gesture != "":
			var moved: Vector2 = event.global_position - _press_at
			match _gesture:
				"press":
					tapped.emit(self)
				"drag":
					drag_ended.emit(self, event.global_position)
				"swipe":
					if absf(moved.y) > 26.0:
						swiped.emit(self, 1 if moved.y < 0 else -1)
			_gesture = ""
			accept_event()
	elif event is InputEventMouseMotion and _gesture != "":
		var moved: Vector2 = event.global_position - _press_at
		if _gesture == "press" and moved.length() > 9.0:
			if swipeable and absf(moved.y) > absf(moved.x) * 1.2:
				_gesture = "swipe"
			elif draggable and absf(moved.x) >= absf(moved.y):
				_gesture = "drag"
				z_index = 2
			else:
				_gesture = "cancel"
		if _gesture == "drag":
			drag_moved.emit(self, event.global_position)
		accept_event()


func _lift(up: bool) -> void:
	_hovered = up
	if _gesture != "drag":
		z_index = 1 if up else 0
	if Settings.reduce_motion or baking:
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (1.08 if up else 1.0), 0.08)



func _draw() -> void:
	if baking:
		_paint_face(Rect2(Vector2.ZERO, size))
		return
	draw_colored_polygon(_round_rect(Rect2(Vector2(1.5, 3.5), size), 5.0), Color(0, 0, 0, 0.38))


func _paint_face(r: Rect2) -> void:
	if face_down:
		_draw_back(r)
	elif kind == "card":
		_draw_playing(r)
	else:
		_draw_named(r)
	if edition != "" and EDITION_COLOURS.has(edition) and not face_down:
		_outline(_round_rect(r.grow(-1.0), 4.5), EDITION_COLOURS[edition], 1.6)


func _draw_overlay() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selected:
		_overlay.draw_polyline(_closed(_round_rect(r.grow(2.0), 6.5)), UiTheme.GOLD, 1.8, true)
	if dimmed:
		_overlay.draw_colored_polygon(_round_rect(r, 5.0), Color(0, 0, 0, 0.55))
	if price_text != "":
		var badge := Rect2(Vector2(size.x - 22, -7), Vector2(26, 13))
		_overlay.draw_style_box(UiTheme.box(UiTheme.GOLD, UiTheme.OUTLINE, 3), badge)
		_overlay.draw_string(UiTheme.font, badge.position + Vector2(4, 10), price_text, HORIZONTAL_ALIGNMENT_LEFT, 22, 8, UiTheme.OUTLINE)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed





static func _round_rect(r: Rect2, radius: float) -> PackedVector2Array:

	radius = minf(radius, minf(r.size.x, r.size.y) / 2.0 - 0.05)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI / 2.0],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2.0],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	for corner in corners:
		for i in 5:
			var a: float = corner[1] + i * PI / 8.0
			points.append(corner[0] + Vector2(cos(a), sin(a)) * radius)
	return points



func _poly(points: PackedVector2Array, colour: Color) -> void:
	# Painted: lit from the top left with a fine sepia ink line.
	Paint.shape(self, points, colour, maxf(0.45, size.x * 0.011))


func _outline(points: PackedVector2Array, colour: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, colour, width, true)



func _gradient(points: PackedVector2Array, top: Color, bottom: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for p in points:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var colours := PackedColorArray()
	for p in points:
		colours.append(top.lerp(bottom, (p.y - y0) / maxf(1.0, y1 - y0)))
	draw_polygon(points, colours)


func _dot(at: Vector2, radius: float, colour: Color) -> void:
	draw_circle(at, radius, colour, true, -1.0, true)



func _gloss(r: Rect2) -> void:
	# A clean diagonal sheen across the top-left corner.
	var w := r.size.x
	draw_polygon(PackedVector2Array([Vector2(2, 2), Vector2(w * 0.7, 2), Vector2(2, r.size.y * 0.5)]),
		PackedColorArray([Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))


## Fill with a gradient running from the top-left corner (`a`) to the bottom-right (`b`).
func _diagonal(points: PackedVector2Array, a: Color, b: Color, r: Rect2) -> void:
	var colours := PackedColorArray()
	for p in points:
		colours.append(a.lerp(b, clampf((p.x / r.size.x + p.y / r.size.y) / 2.0, 0.0, 1.0)))
	draw_polygon(points, colours)


static func suit_colour(suit: int) -> Color:
	return SUIT_COLOURS[clampi(suit, 0, 3)]


func _back_index() -> int:
	return back_style if back_style >= 0 else Settings.card_back


func _draw_back(r: Rect2) -> void:
	var body := _round_rect(r, 5.0)
	var inner := r.grow(-maxf(3.0, r.size.x * 0.08))
	match _back_index():
		1:
			_back_sun_and_moon(r, body, inner)
		2:
			_back_mask(r, body, inner)
		3:
			_back_curtain(r, body, inner)
		4:
			_back_night(r, body, inner)
		5:
			_back_filigree(r, body, inner)
		_:
			_back_harlequin(r, body, inner)
	# Every back shares a white inset border.
	var k := r.size.x / 60.0
	_outline(Paint.round_rect(r.grow(-3.0 * k), 4.0 * k), Color(1, 1, 1, 0.6), maxf(0.6, 0.9 * k))
	_gloss(r)


static func _scatter(area: Rect2, n: int) -> Vector2:
	return area.position + area.size * Vector2(fposmod(0.5 + n * 0.7548777, 1.0), fposmod(0.5 + n * 0.5698403, 1.0))



func _leaf(from: Vector2, to: Vector2, width: float, colour: Color) -> void:
	var side := (to - from).orthogonal().normalized() * width / 2.0
	var points := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		points.append(from.lerp(to, t) + side * sin(t * PI))
	for i in range(7, 0, -1):
		var t := i / 8.0
		points.append(from.lerp(to, t) - side * sin(t * PI))
	_poly(points, colour)



func _back_harlequin(r: Rect2, body: PackedVector2Array, inner: Rect2) -> void:
	_gradient(body, Color("ff5d8f"), Color("a1237a"))
	_outline(body, UiTheme.GOLD.darkened(0.25), 1.2)
	_outline(_round_rect(inner, 3.0), UiTheme.GOLD.darkened(0.45), 0.8)
	var c := inner.get_center()
	var k := r.size.x / 60.0
	for row in range(-9, 10):
		for col in range(-5, 6):
			var p := c + Vector2(col * 8 + (4 if row % 2 != 0 else 0), row * 6) * k
			if inner.grow(-3.0 * k).has_point(p):
				_poly(_diamond(p, 2.6 * k, 3.2 * k), Color(1, 1, 1, 0.22))
	_poly(_diamond(c, r.size.x * 0.2, r.size.x * 0.3), UiTheme.GOLD.darkened(0.15))
	_poly(_diamond(c, r.size.x * 0.1, r.size.x * 0.15), Color("6a3058"))



func _back_sun_and_moon(r: Rect2, body: PackedVector2Array, inner: Rect2) -> void:
	_gradient(body, Color("4f8cff"), Color("1e3a8a"))
	_outline(body, UiTheme.GOLD.darkened(0.2), 1.2)
	_outline(_round_rect(inner, 3.0), Color(UiTheme.GOLD, 0.45), 0.8)
	var w := r.size.x
	for i in 22:
		_dot(_scatter(inner.grow(-2.0), i), w * (0.012 + 0.008 * (i % 3)), Color(1, 1, 1, 0.35 + 0.2 * (i % 3)))
	var sun := r.get_center() + Vector2(0, -r.size.y * 0.15)
	for i in 12:
		var a := i * TAU / 12.0
		var tip := sun + Vector2(cos(a), sin(a)) * w * (0.32 if i % 2 == 0 else 0.26)
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * w * 0.045
		_poly(PackedVector2Array([sun + side, tip, sun - side]), UiTheme.GOLD.darkened(0.1))
	_dot(sun, w * 0.18, UiTheme.GOLD)
	_dot(sun + Vector2(-w * 0.05, -w * 0.05), w * 0.06, Color(1, 1, 1, 0.35))
	var moon := r.get_center() + Vector2(0, r.size.y * 0.22)
	_dot(moon, w * 0.16, Color("d8e0ee"))
	_dot(moon + Vector2(w * 0.07, -w * 0.04), w * 0.14, Color("15204a"))



func _back_mask(r: Rect2, body: PackedVector2Array, inner: Rect2) -> void:
	_gradient(body, Color("ff5a6e"), Color("9f1239"))
	_outline(body, UiTheme.GOLD.darkened(0.2), 1.2)
	_outline(_round_rect(inner, 3.0), Color(UiTheme.GOLD, 0.45), 0.8)
	var k := r.size.x / 60.0
	for i in 14:
		var p := _scatter(inner.grow(-2.0), i)
		_poly(_diamond(p, 1.6 * k, 2.4 * k), Color(UiTheme.GOLD, 0.18))
	var c := r.get_center() + Vector2(0, r.size.y * 0.05)
	var s := r.size.x * 0.36
	for f in 3:
		var from := c + Vector2(s * 0.55, -s * 0.3)
		var to := from + Vector2(s * (0.15 + f * 0.25), -s * (1.05 - f * 0.18))
		_leaf(from, to, s * 0.26, [Color("2e9c8f"), Color("f3ead8"), Color("3f8ed8")][f])
		draw_line(from, to, Color(0, 0, 0, 0.3), maxf(0.6, k * 0.6), true)
	var mask := PackedVector2Array()
	for corner in [Vector2(-1.0, -0.08), Vector2(-0.62, -0.42), Vector2(-0.2, -0.3), Vector2(0, -0.18), Vector2(0.2, -0.3),
			Vector2(0.62, -0.42), Vector2(1.0, -0.08), Vector2(0.7, 0.3), Vector2(0.28, 0.26), Vector2(0, 0.1),
			Vector2(-0.28, 0.26), Vector2(-0.7, 0.3)]:
		mask.append(c + corner * s)
	_poly(mask, UiTheme.GOLD)
	_outline(mask, UiTheme.GOLD.darkened(0.4), 0.9)
	for side in [-1.0, 1.0]:
		var eye := PackedVector2Array()
		for i in 14:
			var a := i * TAU / 14.0
			eye.append(c + Vector2(side * s * 0.42 + cos(a) * s * 0.2, -s * 0.04 + sin(a) * s * 0.1))
		_poly(eye, Color("3d0a16"))
	for side in [-1.0, 1.0]:
		var tie := c + Vector2(side * s, -s * 0.08)
		_leaf(tie, tie + Vector2(side * s * 0.12, s * 0.75), s * 0.12, UiTheme.MULT.lightened(0.1))
	_dot(c + Vector2(0, -s * 0.24), s * 0.08, Color("3f8ed8"))



func _back_curtain(r: Rect2, body: PackedVector2Array, inner: Rect2) -> void:
	_gradient(body, Color("8b5cf6"), Color("4c1d95"))
	_outline(body, UiTheme.GOLD.darkened(0.2), 1.2)
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.08)
	var w := inner.size.x
	var h := inner.size.y
	_dot(c, w * 0.42, Color(UiTheme.GOLD, 0.08))
	_dot(c, w * 0.28, Color(UiTheme.GOLD, 0.12))
	_draw_star(c, w * 0.1, UiTheme.GOLD.lightened(0.2))
	var floor_band := Rect2(Vector2(inner.position.x, inner.end.y - h * 0.1), Vector2(w, h * 0.1))
	_gradient(_round_rect(floor_band, 1.0), Color("6e3d1c"), Color("3d2210"))
	for side in [-1.0, 1.0]:
		var edge := inner.position.x if side < 0 else inner.end.x
		var inward: float = -side
		var drape := PackedVector2Array()
		for p in [Vector2(0, 0), Vector2(0.5, 0), Vector2(0.34, 0.32), Vector2(0.2, 0.55), Vector2(0.27, 0.78), Vector2(0.24, 1.0), Vector2(0, 1.0)]:
			drape.append(Vector2(edge + inward * p.x * w, inner.position.y + p.y * h))
		_gradient(drape, UiTheme.MULT, UiTheme.MULT.darkened(0.45))
		for f in 3:
			var x: float = edge + inward * w * (0.08 + f * 0.12)
			draw_line(Vector2(x, inner.position.y), Vector2(edge + inward * w * (0.06 + f * 0.05), inner.position.y + h * 0.55), Color(0, 0, 0, 0.25), maxf(0.6, w * 0.012), true)
		_dot(Vector2(edge + inward * w * 0.2, inner.position.y + h * 0.56), w * 0.05, UiTheme.GOLD)
	var valance := Rect2(inner.position, Vector2(w, h * 0.1))
	_poly(_round_rect(valance, 1.0), UiTheme.MULT.darkened(0.2))
	for i in 5:
		var at := Vector2(inner.position.x + w * (0.1 + i * 0.2), valance.end.y)
		var scallop := PackedVector2Array()
		for j in 9:
			var a := j * PI / 8.0
			scallop.append(at + Vector2(cos(a) * w * 0.1, sin(a) * h * 0.05))
		_poly(scallop, UiTheme.MULT.darkened(0.2))
		draw_arc(at, w * 0.1, 0.1, PI - 0.1, 8, UiTheme.GOLD.darkened(0.1), maxf(0.6, w * 0.012), true)
	_outline(_round_rect(inner, 3.0), Color(UiTheme.GOLD, 0.5), 0.8)



func _back_night(r: Rect2, body: PackedVector2Array, inner: Rect2) -> void:
	_gradient(body, Color("6366f1"), Color("312e81"))
	_outline(body, Color("a8d0ff").darkened(0.2), 1.2)
	_outline(_round_rect(inner, 3.0), Color("a8d0ff", 0.35), 0.8)
	var w := r.size.x
	for i in 40:
		_dot(_scatter(inner.grow(-1.0), i + 7), w * (0.008 + 0.007 * (i % 3)), Color(1, 1, 1, 0.25 + 0.2 * (i % 4)))
	var shape := PackedVector2Array()
	for p in [Vector2(0.18, 0.2), Vector2(0.36, 0.12), Vector2(0.55, 0.24), Vector2(0.72, 0.16), Vector2(0.82, 0.3)]:
		shape.append(inner.position + inner.size * p)
	draw_polyline(shape, Color(UiTheme.GOLD, 0.5), maxf(0.6, w * 0.01), true)
	for p in shape:
		_dot(p, w * 0.022, UiTheme.GOLD.lightened(0.3))
	var c := r.get_center() + Vector2(0, r.size.y * 0.08)
	_dot(c, w * 0.26, Color("8060d0", 0.12))
	_draw_star(c, w * 0.15, Color("f0e8ff"))
	var moon := inner.position + inner.size * Vector2(0.78, 0.82)
	_dot(moon, w * 0.08, Color("f0d860"))
	_dot(moon + Vector2(w * 0.035, -w * 0.02), w * 0.07, Color("0a0c22"))



func _back_filigree(r: Rect2, body: PackedVector2Array, inner: Rect2) -> void:
	_gradient(body, Color("22c493"), Color("065f46"))
	_outline(body, UiTheme.GOLD, 1.3)
	var gold := UiTheme.GOLD.darkened(0.1)
	var line := maxf(0.6, r.size.x * 0.014)
	_outline(_round_rect(inner, 3.0), gold, line)
	_outline(_round_rect(inner.grow(-r.size.x * 0.05), 2.0), Color(gold, 0.6), line * 0.7)
	var step := inner.size.x / 4.0
	for i in range(-6, 7):
		var x := inner.position.x + i * step
		for dir in [1.0, -1.0]:
			var a := Vector2(x, inner.position.y if dir > 0 else inner.end.y)
			var b := a + Vector2(inner.size.y, inner.size.y * dir) * 0.7
			var clipped := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), _round_rect(inner.grow(-r.size.x * 0.07), 2.0))
			for seg in clipped:
				draw_polyline(seg, Color(gold, 0.16), line * 0.6, true)
	for corner in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		var toward: Vector2 = (inner.get_center() - corner).normalized()
		var at: Vector2 = corner + toward * r.size.x * 0.13
		draw_arc(at, r.size.x * 0.06, 0.0, TAU, 16, gold, line, true)
		_dot(at, r.size.x * 0.025, gold)
	var c := r.get_center()
	var s := r.size.x * 0.16
	for i in 8:
		var a := i * TAU / 8.0
		_leaf(c, c + Vector2(cos(a), sin(a)) * s * 1.5, s * 0.55, gold if i % 2 == 0 else gold.darkened(0.25))
	_dot(c, s * 0.45, Color("1a4a34"))
	_dot(c, s * 0.3, UiTheme.MULT)
	_dot(c + Vector2(-s * 0.08, -s * 0.08), s * 0.1, Color(1, 1, 1, 0.4))
	for dir in [-1.0, 1.0]:
		_poly(_diamond(c + Vector2(0, dir * r.size.y * 0.3), s * 0.25, s * 0.45), gold)


func _draw_playing(r: Rect2) -> void:
	# Clean white card, large corner rank, one big suit in the middle.
	var enh_def := ContentDB.get_def(card.enhancement)
	var k := r.size.x / 60.0
	var paper := Color.WHITE
	if card.enhancement == "enh_marble":
		paper = Color("c9cbd3")
	elif enh_def != null:
		paper = Color.WHITE.lerp(_enhancement_tint(card.enhancement), 0.2)
	var body := Paint.round_rect(r, 6.0 * k)
	_gradient(body, paper, paper.darkened(0.07))
	_outline(body, Color(0, 0, 0, 0.14), 0.8)
	var colour := suit_colour(card.suit)
	if card.has_rank():
		var court := card.rank >= 11 and card.rank <= 13
		if card.enhancement == "enh_motley":
			for su in 4:
				draw_suit(self, r.get_center() + Vector2(((su % 2) - 0.5) * 17 * k, (int(su / 2) - 0.5) * 20 * k), 7.0 * k, su, suit_colour(su))
		elif court:
			_draw_face(r, k, colour)
		else:
			draw_suit(self, r.get_center() + Vector2(0, 1.5 * k), (19.0 if card.rank == 14 else 13.5) * k, card.suit, colour)
		_draw_index(k, colour)
		draw_set_transform(r.size, PI)
		_draw_index(k, colour)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_string(UiTheme.display, Vector2(4, r.size.y / 2.0 + 4 * k), "MARBLE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, int(round(10 * k)), Color("4a4e5c"))
	if enh_def != null and card.enhancement != "enh_marble":
		var short := UiTheme.name_of(card.enhancement).to_upper()
		var font_size := int(round(7.0 * k))
		var width := UiTheme.bold.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8 * k
		var tag := Rect2(Vector2((r.size.x - width) / 2.0, r.size.y - 14 * k), Vector2(width, 10 * k))
		draw_colored_polygon(Paint.round_rect(tag, 5 * k), _enhancement_tint(card.enhancement).darkened(0.15))
		draw_string(UiTheme.bold, tag.position + Vector2(0, tag.size.y * 0.74), short, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, font_size, Color.WHITE)
	if SEAL_COLOURS.has(card.seal):
		var at := Vector2(r.size.x - 9 * k, 9 * k)
		_dot(at, 4.4 * k, Color.WHITE)
		_dot(at, 3.4 * k, SEAL_COLOURS[card.seal])


func _draw_index(k: float, colour: Color) -> void:
	var rank_text := str(RANKS.get(card.rank, card.rank))
	var font_size := int(round((16.0 if rank_text.length() > 1 else 18.0) * k))
	var width := UiTheme.display.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := 5.0 * k
	draw_string(UiTheme.display, Vector2(left, 18.5 * k), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
	draw_suit(self, Vector2(left + width / 2.0, 25.0 * k), 4.0 * k, card.suit, colour)


func _draw_face(r: Rect2, k: float, colour: Color) -> void:
	# Minimal court cards: a large letter in the suit colour over a soft tinted disc,
	# with a fine line emblem (crown, tiara, jester's cap) above it.
	var c := r.get_center() + Vector2(0, 1.0 * k)
	draw_circle(c, 19.0 * k, Color(colour, 0.09), true, -1.0, true)
	_court_emblem(card.rank, c + Vector2(0, -12.5 * k), 7.5 * k, colour)
	var letter := str(RANKS.get(card.rank, ""))
	var font_size := int(round(26.0 * k))
	var width := UiTheme.display.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(UiTheme.display, c + Vector2(-width / 2.0, 12.5 * k), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _court_emblem(rank: int, at: Vector2, s: float, colour: Color) -> void:
	var w := maxf(0.9, s * 0.2)
	var line := func(points: PackedVector2Array) -> void: draw_polyline(points, colour, w, true)
	match rank:
		PlayingCard.KING:
			line.call(PackedVector2Array([at + Vector2(-s, s * 0.45), at + Vector2(-s, -s * 0.35), at + Vector2(-s * 0.5, s * 0.1), at + Vector2(0, -s * 0.6), at + Vector2(s * 0.5, s * 0.1), at + Vector2(s, -s * 0.35), at + Vector2(s, s * 0.45), at + Vector2(-s, s * 0.45)]))
		PlayingCard.QUEEN:
			draw_arc(at + Vector2(0, s * 0.6), s, PI * 1.15, PI * 1.85, 16, colour, w, true)
			for x in [-0.55, 0.0, 0.55]:
				draw_circle(at + Vector2(x * s, -s * 0.15 - (0.25 if x == 0.0 else 0.0) * s), w * 1.3, colour, true, -1.0, true)
		_:
			line.call(PackedVector2Array([at + Vector2(-s, s * 0.45), at + Vector2(-s * 0.85, -s * 0.5), at + Vector2(-s * 0.15, s * 0.15), at + Vector2(0, -s * 0.15), at + Vector2(s * 0.15, s * 0.15), at + Vector2(s * 0.85, -s * 0.5), at + Vector2(s, s * 0.45), at + Vector2(-s, s * 0.45)]))
			draw_circle(at + Vector2(-s * 0.85, -s * 0.5), w * 1.4, colour, true, -1.0, true)
			draw_circle(at + Vector2(s * 0.85, -s * 0.5), w * 1.4, colour, true, -1.0, true)


func _draw_ace(r: Rect2, k: float, colour: Color) -> void:
	draw_suit(self, r.get_center(), 19.0 * k, card.suit, colour)


func _cover_outside(window: Rect2, pane: PackedVector2Array, colour_at: Callable) -> void:
	var box := PackedVector2Array([window.position, Vector2(window.end.x, window.position.y), window.end, Vector2(window.position.x, window.end.y)])
	for piece in Geometry2D.clip_polygons(box, pane):
		# Only the two small corners; never anything that could be the whole window.
		if absf(_area(piece)) > window.get_area() * 0.3:
			continue
		var colours := PackedColorArray()
		for p in piece:
			colours.append(colour_at.call(p.y))
		draw_polygon(piece, colours)


static func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		sum += a.x * b.y - b.x * a.y
	return sum / 2.0


func _draw_named(r: Rect2) -> void:
	# A premium collectible card: art filling the card inside a thick metallic frame,
	# the name on a dark plate at the bottom, a gold cost coin top left and the
	# effect badge top right. Art comes from art/jesters/<id>.webp when it exists,
	# otherwise the figure is drawn in code.
	var def := ContentDB.get_def(def_id)
	var grad: Array = KIND_GRADIENTS.get(kind, KIND_GRADIENTS["show"])
	var rarity := 0
	if kind == "zanni" and def != null:
		rarity = clampi(def.rarity, 0, 3)
		grad = RARITY_GRADIENTS[rarity]
	var metal: Array = FRAME_METALS[rarity if kind == "zanni" else 0]
	var k := r.size.x / 60.0
	var body := Paint.round_rect(r, 7.0 * k)
	# Frame: dark rim, metal band (light at the top, deep at the bottom), bevel line.
	var colours := PackedColorArray()
	for p in body:
		var t := p.y / r.size.y
		colours.append((metal[0] as Color).lerp(metal[1], t / 0.45) if t < 0.45 else (metal[1] as Color).lerp(metal[2], (t - 0.45) / 0.55))
	draw_polygon(body, colours)
	if rarity == 3:
		var holo := PackedColorArray()
		var hues := [Color("ff8fd0"), Color("7fffd4"), Color("f0d060"), Color("8fb0ff")]
		for i in body.size():
			holo.append(Color(hues[(i / 3) % hues.size()], 0.35))
		draw_polygon(body, holo)
	_outline(body, Color(0, 0, 0, 0.55), 1.0)
	var window := r.grow(-3.4 * k)
	var pane := Paint.round_rect(window, 4.6 * k)
	var seed_value := absi(def_id.hash())
	var art: JesterArt = null
	if art_texture != null:
		_draw_art(art_texture, window, pane)
	elif kind == "zanni" and JesterArt.has_design(def_id):
		art = JesterArt.new(self)
		art.defer_badge = true
		art.draw(window, pane, def_id)
	else:
		_diagonal(pane, grad[0], grad[1], r)
		_draw_picture(window, pane, grad[1], seed_value)
	_cover_outside(window, pane, func(y: float) -> Color: return (metal[1] as Color).lerp(metal[2], clampf(y / r.size.y, 0.0, 1.0)))
	# Bevel: a light line just inside the frame.
	_outline(pane, Color(1, 1, 1, 0.55), maxf(0.5, 0.6 * k))
	_draw_ribbon(r, window.end.y - 19.0 * k, grad[1])
	if def != null and def.cost > 0 and kind == "zanni":
		_cost_coin(Vector2(window.position.x + 6.0 * k, window.position.y + 6.0 * k), 5.6 * k, def.cost, k)
	if art != null:
		art.badge_offset = Vector2(window.size.x - 6.0 * k, 6.0 * k)
		art.draw_badge()
	if kind == "zanni" and def != null:
		for i in rarity + 1:
			Paint.lit(self, Paint.diamond(Vector2(r.size.x / 2.0 + (i - rarity / 2.0) * 5.2 * k, r.size.y - 1.7 * k), 1.6 * k, 1.6 * k), Color.WHITE)
	if sticker != "":
		draw_string(UiTheme.bold, Vector2(7, 22) * k, sticker.left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(9 * k)), Color.WHITE)
	_gloss(r)


## The illustrated art for a Jester, or null while it only has a drawn design.
static func art_for(card_kind: String, id: String) -> Texture2D:
	var path := "res://art/jesters/%s.webp" % id
	if card_kind != "zanni" or not ResourceLoader.exists(path):
		return null
	return load(path)


## Draw a texture clipped to a polygon (the rounded art window), filling `window`.
func _draw_art(tex: Texture2D, window: Rect2, pane: PackedVector2Array) -> void:
	var uvs := PackedVector2Array()
	var tex_size := tex.get_size()
	# Cover the window, cropping the art's sides or top/bottom as needed.
	var scale := maxf(window.size.x / tex_size.x, window.size.y / tex_size.y)
	var shown := window.size / scale
	var origin := (tex_size - shown) / 2.0
	origin.y = minf(origin.y, (tex_size.y - shown.y) * 0.25)
	for p in pane:
		var local := (p - window.position) / window.size
		uvs.append((origin + local * shown) / tex_size)
	draw_polygon(pane, PackedColorArray([Color.WHITE]), uvs, tex)


func _cost_coin(at: Vector2, radius: float, cost: int, k: float) -> void:
	draw_circle(at + Vector2(0, 0.6 * k), radius + 0.8 * k, Color(0, 0, 0, 0.45), true, -1.0, true)
	Paint.gold(self, _circle_points(at, radius), maxf(0.5, 0.5 * k))
	var text := str(cost)
	var font_size := int(round(7.5 * k))
	var width := UiTheme.display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(UiTheme.display, at + Vector2(-width / 2.0, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("4a2c08"))


static func _circle_points(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		points.append(at + Vector2(cos(i * TAU / 24.0), sin(i * TAU / 24.0)) * radius)
	return points


func _draw_picture(window: Rect2, pane: PackedVector2Array, colour: Color, seed_value: int) -> void:
	var backdrop: Color = BACKDROPS[(seed_value / 3) % BACKDROPS.size()] if kind == "zanni" else colour.lightened(0.18)
	_gradient(pane, backdrop.lightened(0.18), backdrop.darkened(0.25))
	_draw_pattern(pane, window, colour, seed_value if kind == "zanni" else -1)
	for i in 3:
		_dot(window.get_center(), window.size.x * (0.42 - i * 0.1), Color(colour.lightened(0.4), 0.06))
	match kind:
		"zanni":
			_draw_jester(window, seed_value)
		"tarocchi":
			_draw_star(window.get_center(), window.size.x * 0.32, UiTheme.GOLD)
		"sign":
			_draw_sign(window, seed_value, colour.darkened(0.6))
		"omen":
			_draw_eye(window)
		"pack":
			_draw_pack(window, colour)
		"warrant":
			_draw_scroll(window)
		"patron":
			# Each Patron gets a stern masked Venetian noble, chosen from its id.
			var n := seed_value
			var design := [
				["wine", "night", "slate", "ink", "rust", "plum"][n % 6],
				["curtain", "rays", "plain", "lattice"][(n / 7) % 4],
				["doge", "tricorne", "bicorne", "tophat", "crown", "wig", "hood"][(n / 11) % 7],
				["bauta", "volto", "moretta", "gold", "half", "none"][(n / 13) % 6],
				["frown", "smirk", "sleepy"][(n / 17) % 3],
				["robe", "cape", "sash", "gown"][(n / 19) % 4],
				["crimson", "black", "navy", "purple", "gold"][(n / 23) % 5],
				["gold", "silver", "black"][(n / 29) % 3],
				["coins", "goblet", "scroll", "key", "book", "quill"][(n / 31) % 6],
				"", "",
			]
			JesterArt.new(self).draw_design(window, pane, design, n)
		"favor":
			var c := window.get_center() + Vector2(0, window.size.y * 0.04)
			var rad := window.size.x * 0.32
			Paint.glow(self, c, rad * 1.4, Color(Paint.GOLD_HI, 0.5))
			for side in [-1.0, 1.0]:
				for i in 6:
					var a: float = PI / 2.0 + side * (0.4 + i * 0.4)
					var at: Vector2 = c + Vector2(cos(a), sin(a)) * rad
					var along := Vector2(cos(a + side * PI / 2.0), sin(a + side * PI / 2.0))
					_leaf(at, at + along.rotated(-side * 0.6) * rad * 0.45, rad * 0.22, Color("6f9a32") if i % 2 == 0 else Color("c9a43a"))
			_draw_star(c, rad * 0.45, Paint.GOLD)




func _draw_frame_marks(r: Rect2, window: Rect2, pane: PackedVector2Array, colour: Color, rarity: int, gems: bool) -> void:
	var k := r.size.x / 60.0
	if rarity == 3:
		var sheen := PackedColorArray()
		var hues := [Color("ff8fd0"), Color("7fffd4"), Color("f0d060"), Color("8fb0ff")]
		for i in pane.size():
			sheen.append(Color(hues[i % hues.size()], 0.16))
		draw_polygon(pane, sheen)
	_outline(pane, Color(1, 1, 1, 0.4), maxf(0.5, 0.7 * k))
	if gems:
		for i in rarity + 1:
			_dot(Vector2(r.size.x / 2.0 + (i - rarity / 2.0) * 5.0 * k, r.size.y - 4.5 * k), 1.3 * k, Color(1, 1, 1, 0.9))


func _draw_ribbon(r: Rect2, top: float, colour: Color) -> void:
	# The name on a dark plate across the bottom of the art.
	var title := UiTheme.name_of(def_id) if def_id != "" else ""
	var k := r.size.x / 60.0
	var window := r.grow(-3.4 * k)
	var plate := Rect2(Vector2(window.position.x, top), Vector2(window.size.x, window.end.y - top))
	var shade := PackedVector2Array([plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)])
	var pieces := Geometry2D.intersect_polygons(shade, Paint.round_rect(window, 4.6 * k))
	for piece in pieces:
		var cols := PackedColorArray()
		for p in piece:
			cols.append(Color(0.04, 0.02, 0.08, lerpf(0.15, 0.92, clampf((p.y - plate.position.y) / maxf(1.0, plate.size.y * 0.55), 0.0, 1.0))))
		draw_polygon(piece, cols)
	var font_size := int(round(9.0 * k))
	var fit := window.size.x - 6.0 * k
	var lines := _wrap(title, fit, font_size)
	while font_size > 5 and (lines.size() > 2 or _widest(lines, font_size) > fit):
		font_size -= 1
		lines = _wrap(title, fit, font_size)
	lines = lines.slice(0, 2)
	var line_h := font_size + 0.5
	var y := plate.end.y - 3.0 * k - (lines.size() - 1) * line_h
	for line in lines:
		draw_string_outline(UiTheme.display, Vector2(window.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, window.size.x, font_size, maxi(2, int(2.0 * k)), Color(0, 0, 0, 0.6))
		draw_string(UiTheme.display, Vector2(window.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, window.size.x, font_size, Color.WHITE)
		y += line_h


func _widest(lines: Array, font_size: int) -> float:
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, UiTheme.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest





func _draw_pattern(pane: PackedVector2Array, window: Rect2, colour: Color, n: int) -> void:
	var c := window.get_center()
	var far := window.size.length()
	var light := Color(colour.lightened(0.45), 0.24)
	var shapes: Array[PackedVector2Array] = []
	match (n / 29) % 4 if n >= 0 else 0:
		0:
			for i in 16:
				if i % 2 == 0:
					var a0 := i * TAU / 16.0
					var a1 := (i + 1) * TAU / 16.0
					shapes.append(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * far, c + Vector2(cos(a1), sin(a1)) * far]))
		1:
			var cell := window.size.x / 4.0
			for row in range(-1, 7):
				for col in range(-1, 6):
					if (row + col) % 2 == 0:
						shapes.append(_diamond(window.position + Vector2(col * cell, row * cell * 1.3), cell / 2.0, cell * 0.65))
		2:
			for i in range(7, 0, -1):
				if i % 2 == 1:
					var ring := PackedVector2Array()
					for k in 24:
						ring.append(c + Vector2(cos(k * TAU / 24.0), sin(k * TAU / 24.0)) * window.size.x * 0.13 * i)
					shapes.append(ring)
		3:
			var band := window.size.x / 5.0
			for i in range(-6, 8, 2):
				var x := window.position.x + i * band
				shapes.append(PackedVector2Array([Vector2(x, window.position.y), Vector2(x + band, window.position.y), Vector2(x + band + window.size.y, window.end.y), Vector2(x + window.size.y, window.end.y)]))
	for shape in shapes:
		for piece in Geometry2D.intersect_polygons(shape, pane):
			draw_colored_polygon(piece, light)





func _draw_jester(window: Rect2, n: int) -> void:
	var c := window.get_center() + Vector2(0, window.size.y * 0.02)
	var s := minf(window.size.x, window.size.y) * 0.46
	var a: Color = COSTUME_COLOURS[n % COSTUME_COLOURS.size()]
	var b: Color = COSTUME_COLOURS[(n / 8 + 3) % COSTUME_COLOURS.size()]
	if b == a:
		b = COSTUME_COLOURS[(n + 1) % COSTUME_COLOURS.size()]
	var torso := PackedVector2Array([
		Vector2(c.x - s * 1.0, window.end.y), Vector2(c.x - s * 0.62, c.y + s * 0.55),
		Vector2(c.x + s * 0.62, c.y + s * 0.55), Vector2(c.x + s * 1.0, window.end.y),
	])
	_poly(torso, a)
	var cell := s * 0.28
	for row in 4:
		for col in range(-4, 5):
			var at := Vector2(c.x + col * cell + (cell / 2.0 if row % 2 == 1 else 0.0), c.y + s * 0.7 + row * cell * 0.9)
			var d := _diamond(at, cell * 0.42, cell * 0.5)
			var inside := true
			for p in d:
				if not Geometry2D.is_point_in_polygon(p, torso):
					inside = false
			if inside and (row + col) % 2 == 0:
				_poly(d, b)
	_draw_ruff(c + Vector2(0, s * 0.52), s, b.lerp(Color.WHITE, 0.35))
	_draw_head(c, s, SKINS[(n / 64) % SKINS.size()], n)
	if (n / 17) % 3 == 0:
		_draw_mask(c, s)
	_draw_cap(c, s, a, b, 2 + (n / 5) % 2)
	_draw_prop(window, c, s, (n / 13) % 6, a, b)



func _draw_mask(c: Vector2, s: float) -> void:
	var y := c.y - s * 0.05
	_poly(PackedVector2Array([
		Vector2(c.x - s * 0.4, y - s * 0.02), Vector2(c.x - s * 0.2, y - s * 0.16), Vector2(c.x, y - s * 0.08),
		Vector2(c.x + s * 0.2, y - s * 0.16), Vector2(c.x + s * 0.4, y - s * 0.02), Vector2(c.x + s * 0.22, y + s * 0.12),
		Vector2(c.x, y + s * 0.05), Vector2(c.x - s * 0.22, y + s * 0.12),
	]), Color("1a141f"))
	for side in [-1.0, 1.0]:
		_dot(Vector2(c.x + side * s * 0.16, y), s * 0.06, Color.WHITE)
		_dot(Vector2(c.x + side * s * 0.16, y + s * 0.01), s * 0.035, INK)




func _draw_prop(window: Rect2, c: Vector2, s: float, prop: int, a: Color, b: Color) -> void:
	var hand := Vector2(c.x + s * 0.72, c.y + s * 0.78)
	match prop:
		0:
			var colours := [UiTheme.MULT, UiTheme.POINTS, UiTheme.GOLD]
			for i in 3:
				var at := c + Vector2(s * (0.55 + 0.25 * i), -s * (0.15 + 0.35 * sin(i * 1.3)))
				_dot(at, s * 0.12, colours[i])
				_dot(at + Vector2(-s * 0.04, -s * 0.04), s * 0.04, Color(1, 1, 1, 0.6))
		1:
			var top := Vector2(window.end.x - s * 0.25, c.y - s * 0.35)
			draw_line(Vector2(top.x - s * 0.08, window.end.y), top, Color("8a5a2c"), maxf(1.0, s * 0.07), true)
			_dot(top, s * 0.16, SKINS[1])
			_poly(PackedVector2Array([top + Vector2(-s * 0.18, -s * 0.05), top + Vector2(-s * 0.3, -s * 0.35), top + Vector2(0, -s * 0.12), top + Vector2(s * 0.3, -s * 0.35), top + Vector2(s * 0.18, -s * 0.05)]), b)
			_dot(top + Vector2(-s * 0.3, -s * 0.35), s * 0.06, UiTheme.GOLD)
			_dot(top + Vector2(s * 0.3, -s * 0.35), s * 0.06, UiTheme.GOLD)
		2:
			var body := hand + Vector2(-s * 0.05, -s * 0.05)
			draw_line(body, body + Vector2(s * 0.5, -s * 0.75), Color("5a3a1c"), maxf(1.0, s * 0.08), true)
			var oval := PackedVector2Array()
			for k in 16:
				oval.append(body + Vector2(cos(k * TAU / 16.0) * s * 0.24, sin(k * TAU / 16.0) * s * 0.3))
			_poly(oval, Color("c08040"))
			_dot(body, s * 0.07, Color("4a2a10"))
		3:
			var at := Vector2(c.x - s * 0.75, c.y + s * 0.75)
			for i in 3:
				var angle := -0.5 + i * 0.4
				var card := PackedVector2Array()
				for corner in [Vector2(-0.12, -0.42), Vector2(0.12, -0.42), Vector2(0.12, 0), Vector2(-0.12, 0)]:
					card.append(at + (corner * s).rotated(angle))
				_poly(card, UiTheme.CARD)
				_outline(card, EDGE, 0.5)
				_dot(at + (Vector2(0, -0.28) * s).rotated(angle), s * 0.05, UiTheme.RED_SUIT if i % 2 == 0 else INK)
		4:
			for side in [-1.0, 1.0]:
				var slat := PackedVector2Array([hand + Vector2(-s * 0.05 + side * 0.03 * s, 0), hand + Vector2(s * 0.05 + side * 0.03 * s, 0), hand + Vector2(s * 0.25 + side * 0.1 * s, -s * 0.85), hand + Vector2(s * 0.15 + side * 0.1 * s, -s * 0.85)])
				_poly(slat, Color("d8b070") if side < 0 else Color("b08848"))
			_poly(_round_rect(Rect2(hand - Vector2(s * 0.09, s * 0.02), Vector2(s * 0.18, s * 0.16)), 1.0), a.darkened(0.3))



func _draw_head(c: Vector2, s: float, skin: Color, n: int) -> void:
	_dot(c, s * 0.42, skin)
	draw_arc(c, s * 0.42, 0.0, TAU, 24, skin.darkened(0.3), 0.7, true)
	for side in [-1.0, 1.0]:
		var eye := c + Vector2(side * s * 0.16, -s * 0.05)
		_dot(eye, s * 0.075, Color.WHITE)
		_dot(eye + Vector2(0, s * 0.01), s * 0.042, INK)
		_dot(c + Vector2(side * s * 0.25, s * 0.12), s * 0.07, Color(0.9, 0.35, 0.35, 0.45))
	if (n / 11) % 3 == 0:
		_dot(c + Vector2(0, s * 0.08), s * 0.07, Color("d8433a"))
	else:
		_dot(c + Vector2(0, s * 0.08), s * 0.045, skin.darkened(0.25))
	match (n / 7) % 3:
		0:
			draw_arc(c + Vector2(0, s * 0.1), s * 0.18, 0.35, PI - 0.35, 10, INK, 1.0, true)
		1:
			draw_arc(c + Vector2(0, s * 0.33), s * 0.14, PI + 0.5, TAU - 0.5, 10, INK, 1.0, true)
		2:
			_dot(c + Vector2(0, s * 0.24), s * 0.065, INK)
	if (n / 3) % 2 == 0:
		_poly(_diamond(c + Vector2(s * 0.17, s * 0.15), s * 0.05, s * 0.09), Color("2a2433"))



func _draw_cap(c: Vector2, s: float, a: Color, b: Color, points: int) -> void:
	var left := Vector2(c.x - s * 0.46, c.y - s * 0.26)
	var right := Vector2(c.x + s * 0.46, c.y - s * 0.26)
	var tips := [Vector2(c.x - s * 0.92, c.y - s * 0.6), Vector2(c.x + s * 0.92, c.y - s * 0.6)]
	if points == 3:
		tips.insert(1, Vector2(c.x, c.y - s * 0.98))
	for i in tips.size():
		var from := left.lerp(right, float(i) / tips.size())
		var to := left.lerp(right, float(i + 1) / tips.size())
		_poly(PackedVector2Array([from, tips[i], to, (from + to) / 2.0 + Vector2(0, s * 0.06)]), a if i % 2 == 0 else b)
	var band := PackedVector2Array([left + Vector2(-s * 0.04, -s * 0.06), right + Vector2(s * 0.04, -s * 0.06), right + Vector2(s * 0.04, s * 0.06), left + Vector2(-s * 0.04, s * 0.06)])
	_poly(band, b.darkened(0.25))
	for tip in tips:
		_dot(tip, s * 0.12, UiTheme.GOLD.darkened(0.2))
		_dot(tip + Vector2(-s * 0.03, -s * 0.03), s * 0.06, UiTheme.GOLD.lightened(0.3))


func _draw_crown(c: Vector2, s: float, colour: Color, tall: float) -> void:
	var base := c.y - s * 0.3
	var crown := PackedVector2Array([
		Vector2(c.x - s * 0.45, base), Vector2(c.x - s * 0.45, base - s * tall),
		Vector2(c.x - s * 0.22, base - s * tall * 0.55), Vector2(c.x, base - s * tall * 1.15),
		Vector2(c.x + s * 0.22, base - s * tall * 0.55), Vector2(c.x + s * 0.45, base - s * tall),
		Vector2(c.x + s * 0.45, base),
	])
	_poly(crown, UiTheme.GOLD)
	draw_line(Vector2(c.x - s * 0.45, base - s * 0.06), Vector2(c.x + s * 0.45, base - s * 0.06), UiTheme.GOLD.darkened(0.3), 1.0, true)
	_dot(Vector2(c.x, base - s * tall * 0.45), s * 0.07, colour)
	_dot(Vector2(c.x - s * 0.25, base - s * tall * 0.3), s * 0.045, Color("3f8ed8"))
	_dot(Vector2(c.x + s * 0.25, base - s * tall * 0.3), s * 0.045, Color("6cc46a"))



func _draw_ruff(c: Vector2, s: float, colour: Color) -> void:
	var w := s * 1.1
	var pleats := 6
	for i in pleats:
		var x0 := c.x - w / 2.0 + w * i / pleats
		var x1 := x0 + w / pleats
		_poly(PackedVector2Array([Vector2(x0, c.y - s * 0.1), Vector2(x1, c.y - s * 0.1), Vector2((x0 + x1) / 2.0, c.y + s * 0.2)]), colour if i % 2 == 0 else colour.darkened(0.15))


func _draw_star(c: Vector2, s: float, colour: Color) -> void:
	for i in 12:
		var angle := i * TAU / 12.0
		draw_line(c + Vector2(cos(angle), sin(angle)) * s * 0.6, c + Vector2(cos(angle), sin(angle)) * s * 1.25, Color(colour, 0.35), 1.0, true)
	var points := PackedVector2Array()
	for i in 10:
		var radius := s if i % 2 == 0 else s * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	_poly(points, colour)
	_dot(c, s * 0.2, colour.lightened(0.6))



func _draw_sign(window: Rect2, n: int, sky: Color) -> void:
	var c := window.get_center()
	var s := minf(window.size.x, window.size.y) * 0.34
	var light := Color("a8d0ff")
	draw_arc(c, s * 1.05, 0.0, TAU, 32, light, 1.0, true)
	_dot(c + Vector2(-s * 0.15, 0), s * 0.55, light)
	_dot(c + Vector2(s * 0.08, -s * 0.1), s * 0.5, sky)
	var stars := PackedVector2Array()
	for i in 4:
		var angle := float((n >> (i * 3)) % 8) / 8.0 * TAU + i * 0.4
		stars.append(c + Vector2(cos(angle), sin(angle)) * s * 1.35)
	draw_polyline(stars, Color(UiTheme.GOLD, 0.5), 0.7, true)
	for p in stars:
		_dot(p, 1.4, UiTheme.GOLD)


func _draw_eye(window: Rect2) -> void:
	var c := window.get_center()
	var s := window.size.x * 0.36
	var lid := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		lid.append(c + Vector2(lerpf(-s, s, t), -sin(t * PI) * s * 0.55))
	for i in range(15, 0, -1):
		var t := float(i) / 16.0
		lid.append(c + Vector2(lerpf(-s, s, t), sin(t * PI) * s * 0.55))
	_poly(lid, UiTheme.CARD)
	_dot(c, s * 0.4, Color("2e9c8f"))
	_dot(c, s * 0.18, INK)
	_dot(c + Vector2(-s * 0.12, -s * 0.12), s * 0.08, Color.WHITE)
	for i in 5:
		var x := lerpf(-s * 0.7, s * 0.7, i / 4.0)
		draw_line(c + Vector2(x, -s * 0.5), c + Vector2(x * 1.15, -s * 0.75), UiTheme.CARD, 0.8, true)


func _draw_pack(window: Rect2, colour: Color) -> void:
	var c := window.get_center() + Vector2(0, 2)
	var box := Rect2(c - Vector2(window.size.x * 0.3, window.size.y * 0.22), Vector2(window.size.x * 0.6, window.size.y * 0.5))
	_gradient(_round_rect(box, 2.0), colour.lightened(0.35), colour.lightened(0.05))
	_poly(PackedVector2Array([box.position, box.position + Vector2(box.size.x, 0), box.position + Vector2(box.size.x, box.size.y * 0.22), box.position + Vector2(0, box.size.y * 0.22)]), colour.lightened(0.5))
	draw_rect(Rect2(Vector2(c.x - 2, box.position.y), Vector2(4, box.size.y)), UiTheme.MULT)
	var top := Vector2(c.x, box.position.y)
	_poly(PackedVector2Array([top, top + Vector2(-8, -6), top + Vector2(-7, 3)]), UiTheme.MULT)
	_poly(PackedVector2Array([top, top + Vector2(8, -6), top + Vector2(7, 3)]), UiTheme.MULT)
	_dot(top, 2.2, UiTheme.MULT.darkened(0.2))


func _draw_scroll(window: Rect2) -> void:
	var c := window.get_center()
	var paper := Rect2(c - Vector2(window.size.x * 0.28, window.size.y * 0.3), Vector2(window.size.x * 0.56, window.size.y * 0.6))
	_gradient(_round_rect(paper, 1.5), UiTheme.CARD, UiTheme.CARD.darkened(0.12))
	for y in [paper.position.y, paper.end.y]:
		_poly(_round_rect(Rect2(Vector2(paper.position.x - 3, y - 2.5), Vector2(paper.size.x + 6, 5)), 2.5), UiTheme.CARD.darkened(0.25))
	for i in 4:
		var y := paper.position.y + 7 + i * 5
		draw_line(Vector2(paper.position.x + 4, y), Vector2(paper.end.x - 4 - (8 if i == 3 else 0), y), Color("b0a080"), 0.8, true)
	_dot(Vector2(paper.end.x - 5, paper.end.y - 6), 4.0, UiTheme.MULT)
	_dot(Vector2(paper.end.x - 6, paper.end.y - 7), 1.4, Color(1, 1, 1, 0.5))


static func _diamond(c: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -h), c + Vector2(w, 0), c + Vector2(0, h), c + Vector2(-w, 0)])


func _wrap(text: String, width: float, font_size: int) -> Array:
	var lines := []
	var current := ""
	for word in text.split(" "):
		var attempt := word if current == "" else current + " " + word
		if UiTheme.display.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and current != "":
			lines.append(current)
			current = word
		else:
			current = attempt
	if current != "":
		lines.append(current)
	return lines


func _enhancement_tint(enh: String) -> Color:
	match enh:
		"enh_lacquered":
			return UiTheme.POINTS
		"enh_masked":
			return UiTheme.MULT
		"enh_motley":
			return Color("e0c040")
		"enh_mirror":
			return Color("a8e0ff")
		"enh_iron":
			return Color("707888")
		"enh_gilt":
			return UiTheme.GOLD
		"enh_charmed":
			return UiTheme.GOOD
	return UiTheme.CARD



static func draw_suit(canvas: CanvasItem, c: Vector2, s: float, suit: int, colour: Color) -> void:
	# Flat suit shapes with a whisper of light at the top.
	var shade := func(p: Vector2) -> Color:
		var t := clampf((p.y - (c.y - s)) / (2.0 * s), 0.0, 1.0)
		return colour.lightened(0.1 * (0.5 - t)) if t < 0.5 else colour.darkened(0.08 * (t - 0.5))
	var fill := func(points: PackedVector2Array) -> void:
		var colours := PackedColorArray()
		for p in points:
			colours.append(shade.call(p))
		canvas.draw_polygon(points, colours)
	var circle := func(at: Vector2, radius: float) -> void:
		var points := PackedVector2Array()
		for i in 20:
			points.append(at + Vector2(cos(i * TAU / 20.0), sin(i * TAU / 20.0)) * radius)
		fill.call(points)
	match suit:
		PlayingCard.Suit.HEARTS:
			circle.call(c + Vector2(-s * 0.45, -s * 0.2), s * 0.5)
			circle.call(c + Vector2(s * 0.45, -s * 0.2), s * 0.5)
			fill.call(PackedVector2Array([c + Vector2(-s * 0.93, -s * 0.05), c + Vector2(s * 0.93, -s * 0.05), c + Vector2(0, s)]))
		PlayingCard.Suit.DIAMONDS:
			fill.call(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.72, 0), c + Vector2(0, s), c + Vector2(-s * 0.72, 0)]))
		PlayingCard.Suit.SPADES:
			circle.call(c + Vector2(-s * 0.45, s * 0.2), s * 0.5)
			circle.call(c + Vector2(s * 0.45, s * 0.2), s * 0.5)
			fill.call(PackedVector2Array([c + Vector2(-s * 0.93, s * 0.05), c + Vector2(s * 0.93, s * 0.05), c + Vector2(0, -s)]))
			fill.call(PackedVector2Array([c + Vector2(0, s * 0.3), c + Vector2(s * 0.35, s), c + Vector2(-s * 0.35, s)]))
		PlayingCard.Suit.CLUBS:
			circle.call(c + Vector2(0, -s * 0.45), s * 0.42)
			circle.call(c + Vector2(-s * 0.45, s * 0.15), s * 0.42)
			circle.call(c + Vector2(s * 0.45, s * 0.15), s * 0.42)
			fill.call(PackedVector2Array([c + Vector2(0, 0), c + Vector2(s * 0.35, s), c + Vector2(-s * 0.35, s)]))


