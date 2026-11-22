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

## Backs from here on are sold in the shop (ShopCatalog) and drawn richer than the free
## ones: a metal foil frame and a foil emblem.
const FIRST_PREMIUM_BACK := 6
## Metal foils for the premium backs, from highlight to deep shadow.
const FOIL_GOLD := [Color("fff6d8"), Color("f4c95d"), Color("c48a26"), Color("6e420c")]
const FOIL_SILVER := [Color("ffffff"), Color("dbe3ef"), Color("97a5bb"), Color("44506a")]
## Where the foil tones fall across a card (0-1, top left to bottom right): two bright
## streaks, the way light catches a sheet of metal leaf.
const FOIL_STOPS := [[0.0, 1], [0.18, 0], [0.4, 1], [0.6, 2], [0.8, 0], [1.0, 1]]
## The light falls from the top left, so facets facing that way are the bright ones.
const LIGHT_ANGLE := -0.75 * PI

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
## The card shader's foil for a face-down premium back: a slow glint across its metal.
const BACK_GLINT := 5

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
## The big card in the collection's inspect view: a deeper tilt drawn on a fine mesh
## (CardMesh), a brighter sheen, a gentle idle sway and a shadow that moves with it.
var showcase := false
## Report sideways swipes too (the inspect view flips to the next Jester with them).
var swipe_sideways := false

var _face: TextureRect
var _mesh: CardMesh
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
		_material.set_shader_parameter("foil", _foil_mode())
		_face.material = _material
	if showcase:
		_mesh = CardMesh.new(size)
		_mesh.material = _material
		add_child(_mesh)
		move_child(_mesh, _overlay.get_index())
		_face.visible = false
		if _material != null:
			_material.set_shader_parameter("depth", 0.34)
			_material.set_shader_parameter("shine", 1.8)
	set_art(CardArt.request(self))
	set_process(_material != null or sway >= 0 or showcase)



## The shader foil for this card: its edition's, or for a face-down card the glint of a
## premium back. The glint never stops moving, so reduced motion leaves it out.
func _foil_mode() -> int:
	if face_down:
		return BACK_GLINT if _back_index() >= FIRST_PREMIUM_BACK and not Settings.reduce_motion else 0
	return int(FOILS.get(edition, 0))


func set_art(texture: Texture2D) -> void:
	if _face != null and texture != null:
		_face.texture = texture
		if _mesh != null:
			_mesh.texture = texture



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
		# On a touch screen the pointer stays where the finger lifted, so a showcase
		# card follows it only while touched and otherwise sways on its own.
		var follow := _gesture != "" or (_hovered and not (showcase and DisplayServer.is_touchscreen_available()))
		if follow:
			target = ((get_local_mouse_position() / size) - Vector2(0.5, 0.5)) * 2.0
		elif showcase:
			target = Vector2(sin(t * 0.9), sin(t * 1.3 + 1.0)) * 0.45
		elif sway >= 0:
			target = Vector2(sin(t * 1.1 + sway), cos(t * 0.8 + sway * 1.3)) * 0.18
		_tilt = _tilt.lerp(target.clamp(Vector2(-1, -1), Vector2(1, 1)), clampf(delta * 10.0, 0.0, 1.0))
	if _material != null:
		_material.set_shader_parameter("tilt", _tilt)
	if showcase:
		queue_redraw()




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
					if swipe_sideways and absf(moved.x) > absf(moved.y):
						if absf(moved.x) > 26.0:
							swiped.emit(self, 1 if moved.x < 0 else -1)
					elif absf(moved.y) > 26.0:
						swiped.emit(self, 1 if moved.y < 0 else -1)
			_gesture = ""
			accept_event()
	elif event is InputEventMouseMotion and _gesture != "":
		var moved: Vector2 = event.global_position - _press_at
		if _gesture == "press" and moved.length() > 9.0:
			if swipeable and absf(moved.y) > absf(moved.x) * 1.2:
				_gesture = "swipe"
			elif swipe_sideways and absf(moved.x) > absf(moved.y):
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
	if Settings.reduce_motion or baking or showcase:
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (1.08 if up else 1.0), 0.08)



func _draw() -> void:
	if baking:
		_paint_face(Rect2(Vector2.ZERO, size))
		return
	if showcase:
		# A soft shadow under a card held above the table, sliding away from the tilt.
		var drop := Vector2(-_tilt.x * 7.0, 12.0 - _tilt.y * 5.0)
		for i in 5:
			var spread := 2.0 + i * 3.0
			draw_colored_polygon(_round_rect(Rect2(drop - Vector2(spread, spread) * 0.5, size + Vector2(spread, spread)), 8.0 + i * 2.0), Color(0, 0, 0, 0.09))
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


## The card back to draw. An explicit back_style shows exactly that back, which is how
## the shop previews a back for sale and the gallery shows them all. Otherwise it is the
## player's choice, but only while they own it: after a refund, or with a cloud save
## from before the purchase, their cards fall back to the Harlequin rather than wear a
## back they don't have. baked_copy() hands the bake this resolved number, so the
## picture always matches art_key().
func _back_index() -> int:
	if back_style >= 0:
		return back_style if back_style < Settings.CARD_BACKS.size() else 0
	return Settings.shown_back(Game.profile.wallet)


func _draw_back(r: Rect2) -> void:
	var index := _back_index()
	if index >= FIRST_PREMIUM_BACK:
		_draw_premium_back(r, index)
		return
	var body := _round_rect(r, 5.0)
	var inner := r.grow(-maxf(3.0, r.size.x * 0.08))
	match index:
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


## The premium backs sold in the shop: a metal foil frame (gold, or silver for the
## Starter's crest) where the free backs have a white line, deeper colour and a foil
## emblem. Each is drawn for the size it is baked at: the 20 px deck pile keeps only
## the big shapes, hand-sized cards add fine lines and the big inspect card adds the
## small jewellery.
func _draw_premium_back(r: Rect2, index: int) -> void:
	var k := r.size.x / 60.0
	# Corners as round as a playing card's face, so a big back matches the cards around it.
	var radius := maxf(5.0, 6.0 * k)
	var band := maxf(1.7, 3.2 * k)
	var inner := r.grow(-band)
	var inner_radius := maxf(1.2, radius - band * 0.75)
	var panel := _rounded_ring(inner, inner_radius)
	match index:
		6:
			_back_gilded_sun(r, panel, inner, k)
		7:
			_back_venetian_glass(r, panel, inner, k)
		8:
			_back_opera_night(r, panel, inner, k)
		9:
			_back_carnival_gold(r, panel, inner, k)
		_:
			_back_starters_crest(r, panel, inner, k)
	_foil_frame(r, radius, inner, inner_radius, FOIL_SILVER if index == 10 else FOIL_GOLD, k)
	_gloss(r)


## The premium frame: a band of metal foil whose streaks run across the card, a dark rim
## so it keeps its edge on any table and, on bigger cards, an engraved rule and a small
## jewel in each corner.
func _foil_frame(r: Rect2, radius: float, inner: Rect2, inner_radius: float, tones: Array, k: float) -> void:
	var outer_ring := _rounded_ring(r, radius)
	var inner_ring := _rounded_ring(inner, inner_radius)
	_band(outer_ring, inner_ring, func(p: Vector2) -> Color: return _metal_at(p, r, tones))
	var deep: Color = tones[3]
	draw_polyline(Paint.closed(inner_ring), Color(deep, 0.85), maxf(0.45, 0.5 * k), true)
	draw_polyline(Paint.closed(outer_ring), Color(deep.darkened(0.3), 0.9), maxf(0.5, 0.55 * k), true)
	if r.size.x < 40.0:
		return
	var gap := (r.size.x - inner.size.x) / 2.0
	var rule := _rounded_ring(r.grow(-gap * 0.5), (radius + inner_radius) * 0.5)
	draw_polyline(Paint.closed(rule), Color(deep, 0.4), maxf(0.35, 0.32 * k), true)
	for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		var gem := _diamond(corner + (inner.get_center() - corner).sign() * inner_radius * 0.55, 1.5 * k, 1.5 * k)
		_foil(gem, tones, r)
		draw_polyline(Paint.closed(gem), Color(deep, 0.8), maxf(0.35, 0.3 * k), true)


## 6 Gilded sun: a faceted golden sunburst on midnight blue, ringed with gold beads,
## under a sky of small gold stars.
func _back_gilded_sun(r: Rect2, panel: PackedVector2Array, inner: Rect2, k: float) -> void:
	var w := r.size.x
	var c := inner.get_center()
	_gradient(panel, Color("26399a"), Color("0a1036"))
	_rays(c, 32, r.size.length(), Color(1, 1, 1, 0.045), panel)
	_glow_in(c, w * 0.7, Color("ffb938", 0.55), panel)
	var star: Color = FOIL_GOLD[0]
	for i in 34:
		var at := _scatter(inner.grow(-1.5 * k), i + 5)
		if at.distance_to(c) > w * 0.47:
			_dot(at, w * (0.006 + 0.004 * (i % 3)), Color(star, 0.35 + 0.2 * (i % 3)))
	if w >= 40.0:
		for spot: Vector2 in [Vector2(0.15, 0.09), Vector2(0.85, 0.09), Vector2(0.15, 0.91), Vector2(0.85, 0.91)]:
			_sparkle(inner.position + inner.size * spot, w * 0.05, Color(star, 0.95))
		# An oval of small gold beads round the sun, following the card's shape.
		for i in 44:
			var a := i * TAU / 44.0
			_dot(c + Vector2(cos(a) * w * 0.405, sin(a) * w * 0.54), w * (0.009 if i % 2 == 0 else 0.006), FOIL_GOLD[1])
	# Sixteen rays, long and short, each split into a lit and a shaded facet.
	for i in 16:
		var a := -PI / 2.0 + i * TAU / 16.0
		var long_ray := i % 2 == 0
		var tip := c + Vector2.from_angle(a) * w * (0.38 if long_ray else 0.29)
		var half := 0.22 if long_ray else 0.17
		var foot := w * 0.15
		var mid := c + Vector2.from_angle(a) * foot * 0.96
		draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a - half) * foot, tip, mid]), _facet(a - PI / 2.0, FOIL_GOLD))
		draw_colored_polygon(PackedVector2Array([mid, tip, c + Vector2.from_angle(a + half) * foot]), _facet(a + PI / 2.0, FOIL_GOLD))
	_foil_disc(c, w * 0.18, FOIL_GOLD, k)


## 7 Venetian glass: a leaded window of Murano glass diamonds in teal and aqua around a
## gold-rimmed millefiori medallion, every pane catching the light like glass.
func _back_venetian_glass(r: Rect2, panel: PackedVector2Array, inner: Rect2, k: float) -> void:
	var w := r.size.x
	var c := inner.get_center()
	_gradient(panel, Color("108c88"), Color("04313c"))
	var tints := [Color("2fd3c0"), Color("0f8f8a"), Color("6be8d8"), Color("0a6470"), Color("1aa79b"), Color("3fb8d8")]
	var cell := inner.size.x / 4.0
	var half_h := cell * 0.7
	for row in range(-1, ceili(inner.size.y / half_h) + 2):
		for col in range(-1, 6):
			var at := Vector2(inner.position.x + col * cell + (cell / 2.0 if posmod(row, 2) == 1 else 0.0), inner.position.y + row * half_h)
			var tint: Color = tints[mini(floori(_noise(row * 17 + col + 40, 7) * tints.size()), tints.size() - 1)]
			var pane := _diamond(at, cell / 2.0, half_h)
			for piece in Geometry2D.intersect_polygons(pane, panel):
				_gradient(piece, Color(tint.lightened(0.2), 0.82), Color(tint.darkened(0.3), 0.82))
			if w >= 40.0:
				# Light catching the upper-left edge of each pane.
				var glint := PackedVector2Array([pane[0], pane[3], pane[3].lerp(at, 0.3), pane[0].lerp(at, 0.3)])
				for piece in Geometry2D.intersect_polygons(glint, panel):
					draw_colored_polygon(piece, Color(1, 1, 1, 0.16))
	var width := maxf(0.5, 0.75 * k)
	for seg in _lattice(inner, panel, cell, half_h):
		draw_polyline(seg, Color(FOIL_GOLD[3] as Color, 0.8), width * 1.7, true)
		draw_polyline(seg, FOIL_GOLD[1], width, true)
		if k > 0.6:
			draw_polyline(seg, Color(FOIL_GOLD[0] as Color, 0.7), width * 0.35, true)
	var radius := w * 0.28
	_glow_in(c, w * 0.62, Color("b4fff4", 0.35), panel)
	_dot(c + Vector2(0, radius * 0.1), radius * 1.05, Color(0.0, 0.08, 0.1, 0.35))
	_murano_bead(c, radius, k)
	for dir: float in [-1.0, 1.0]:
		_murano_bead(c + Vector2(0, dir * inner.size.y * 0.37), w * 0.075, k)


## A round Murano bead set in gold: deep teal glass lit from the top left, a millefiori
## flower of white star canes and gold petals, and a bright glassy highlight.
func _murano_bead(c: Vector2, radius: float, k: float) -> void:
	_foil_disc(c, radius, FOIL_GOLD, k)
	var glass := radius * (0.8 if radius > 8.0 else 0.72)
	var focus := c + Vector2(-0.3, -0.38) * glass
	var light := Color("8ff7ea")
	var deep := Color("05414d")
	_fan(focus, _circle(c, glass, 40), func(p: Vector2) -> Color: return light.lerp(deep, clampf(p.distance_to(focus) / (glass * 1.45), 0.0, 1.0)))
	if glass > 12.0:
		# Aventurine: flecks of gold leaf caught in the glass.
		for i in 16:
			_dot(c + Vector2.from_angle(_noise(i, 3) * TAU) * glass * (0.25 + 0.65 * _noise(i, 4)), glass * 0.018, Color(FOIL_GOLD[0] as Color, 0.85))
	if glass > 6.0:
		var canes := 10 if glass > 12.0 else 8
		for i in canes:
			var at := c + Vector2.from_angle(-PI / 2.0 + i * TAU / canes) * glass * 0.66
			_dot(at, glass * 0.15, Color("f4fffd"))
			_dot(at, glass * 0.095, Color("2fd3c0") if i % 2 == 0 else Color("3f8ed8"))
			_dot(at, glass * 0.04, FOIL_GOLD[0])
		for i in 6:
			_leaf(c, c + Vector2.from_angle(-PI / 2.0 + i * TAU / 6.0) * glass * 0.46, glass * 0.22, FOIL_GOLD[1])
	_dot(c, glass * 0.17, Color("ff6b5a"))
	_dot(c, glass * 0.08, FOIL_GOLD[0])
	# Glass: a curved highlight top left and a faint rim of light bottom right.
	draw_arc(c, glass * 0.82, PI * 1.08, PI * 1.42, 16, Color(1, 1, 1, 0.55), glass * 0.1, true)
	_dot(c + Vector2.from_angle(PI * 1.25) * glass * 0.56, glass * 0.06, Color(1, 1, 1, 0.75))
	draw_arc(c, glass * 0.9, PI * 0.1, PI * 0.42, 12, Color(1, 1, 1, 0.28), glass * 0.05, true)


## 8 Opera night: tiers of boxes curving round an opera house under a glowing gold
## chandelier, rows of red velvet seats below; deep red and gold.
func _back_opera_night(r: Rect2, panel: PackedVector2Array, inner: Rect2, k: float) -> void:
	var w := r.size.x
	_gradient(panel, Color("7d1029"), Color("2a0410"))
	var lamp := Vector2(inner.get_center().x, inner.position.y + inner.size.y * 0.2)
	_glow_in(lamp, w * 0.85, Color("ffb54a", 0.5), panel)
	for tier in 3:
		_opera_tier(inner, panel, tier, k)
	_opera_seats(inner, panel)
	_chandelier(lamp, inner.position.y, w, k)


## One tier of boxes: a dark row of lit arched doorways above a velvet balcony front with
## a gold rail, curving round like a horseshoe.
func _opera_tier(inner: Rect2, panel: PackedVector2Array, tier: int, k: float) -> void:
	var w := inner.size.x
	var cx := inner.get_center().x
	var top := inner.position.y + inner.size.y * (0.36 + 0.15 * tier)
	var sag := inner.size.y * 0.1
	var box_h := inner.size.y * 0.085
	var front_h := inner.size.y * 0.04
	var curve := func(x: float, dy: float) -> Vector2:
		var u := (x - cx) / (w * 0.62)
		return Vector2(x, top + sag * (1.0 - u * u) + dy)
	var xs := PackedFloat32Array()
	for i in 25:
		xs.append(lerpf(inner.position.x - 1.0, inner.end.x + 1.0, i / 24.0))
	var boxes := PackedVector2Array()
	var rail := PackedVector2Array()
	var trim := PackedVector2Array()
	for x in xs:
		boxes.append(curve.call(x, -box_h))
		rail.append(curve.call(x, 0.0))
		trim.append(curve.call(x, front_h))
	var front := rail.duplicate()
	for i in range(xs.size() - 1, -1, -1):
		boxes.append(curve.call(xs[i], 0.0))
		front.append(curve.call(xs[i], front_h))
	for piece in Geometry2D.intersect_polygons(boxes, panel):
		_gradient(piece, Color("1c0309"), Color("3d0814"))
	if w >= 34.0:
		var doors := 7
		for j in doors:
			var x := lerpf(inner.position.x, inner.end.x, (j + 0.5) / doors)
			var foot: Vector2 = curve.call(x, -box_h * 0.12)
			var door := Paint.arch(Rect2(foot - Vector2(w * 0.035, box_h * 0.72), Vector2(w * 0.07, box_h * 0.72)), 0.6, 5)
			for piece in Geometry2D.intersect_polygons(door, panel):
				_gradient(piece, Color("ffe3a0"), Color("e0802f"))
	else:
		for seg in Geometry2D.intersect_polyline_with_polygon(boxes.slice(0, xs.size()), panel):
			draw_polyline(seg, Color("ffcf7a", 0.6), maxf(0.4, box_h * 0.3), true)
	for piece in Geometry2D.intersect_polygons(front, panel):
		_gradient(piece, Color("d8314f"), Color("8a1029"))
	for seg in Geometry2D.intersect_polyline_with_polygon(rail, panel):
		draw_polyline(seg, FOIL_GOLD[1], maxf(0.5, 0.85 * k), true)
		if k > 0.6:
			draw_polyline(seg, Color(FOIL_GOLD[0] as Color, 0.8), 0.3 * k, true)
	for seg in Geometry2D.intersect_polyline_with_polygon(trim, panel):
		draw_polyline(seg, Color(FOIL_GOLD[2] as Color, 0.9), maxf(0.35, 0.45 * k), true)


## Rows of red velvet seats at the foot of the card, the nearest row the biggest.
func _opera_seats(inner: Rect2, panel: PackedVector2Array) -> void:
	var w := inner.size.x
	var cx := inner.get_center().x
	for row in 3:
		var seat_w := w * (0.1 + 0.02 * row)
		var seat_h := inner.size.y * (0.055 + 0.012 * row)
		var y := inner.position.y + inner.size.y * (0.84 + 0.075 * row)
		for i in ceili(w / seat_w) + 2:
			var x := inner.position.x + (i - 0.5 + (0.5 if row % 2 == 1 else 0.0)) * seat_w
			var u := (x - cx) / w
			var seat := Rect2(Vector2(x - seat_w * 0.43, y - u * u * inner.size.y * 0.08), Vector2(seat_w * 0.86, seat_h))
			# A seat back: rounded on top, square where it meets the seat.
			var shape := _ellipse_arc(seat.position + Vector2(seat.size.x / 2.0, seat_w * 0.3), Vector2(seat.size.x / 2.0, seat_w * 0.3), PI, TAU, 8)
			shape.append(seat.end)
			shape.append(Vector2(seat.position.x, seat.end.y))
			for piece in Geometry2D.intersect_polygons(shape, panel):
				_gradient(piece, Color("ea4862"), Color("7a0c22"))
			# The velvet's sheen along the top.
			var sheen := _ellipse_arc(seat.position + Vector2(seat.size.x / 2.0, seat_w * 0.34), Vector2(seat.size.x * 0.36, seat_w * 0.22), PI * 1.15, PI * 1.85, 6)
			for seg in Geometry2D.intersect_polyline_with_polygon(sheen, panel):
				draw_polyline(seg, Color(1, 0.8, 0.85, 0.35), maxf(0.3, seat_w * 0.07), true)


## A gilded chandelier hanging from the top of the card: a slim gold stem, two rings of
## arms holding candle flames and a crystal drop.
func _chandelier(at: Vector2, ceiling: float, w: float, k: float) -> void:
	var s := w * 0.065
	var line := maxf(0.5, 0.7 * k)
	draw_line(Vector2(at.x, ceiling), at + Vector2(0, -s * 2.0), Color(FOIL_GOLD[1] as Color, 0.85), line * 0.8, true)
	var stem := PackedVector2Array()
	for p: Vector2 in [Vector2(0, -2.2), Vector2(0.32, -1.8), Vector2(0.18, -1.1), Vector2(0.5, -0.3), Vector2(0.3, 0.6), Vector2(0.12, 1.15)]:
		stem.append(at + p * s)
	for p: Vector2 in [Vector2(-0.12, 1.15), Vector2(-0.3, 0.6), Vector2(-0.5, -0.3), Vector2(-0.18, -1.1), Vector2(-0.32, -1.8)]:
		stem.append(at + p * s)
	_foil(stem, FOIL_GOLD, Paint.bounds(stem))
	var upper := _ellipse_arc(at + Vector2(0, -s * 1.0), Vector2(s * 2.1, s * 0.6), 0.0, PI, 14)
	var lower := _ellipse_arc(at + Vector2(0, s * 0.2), Vector2(s * 3.6, s * 1.0), 0.0, PI, 18)
	draw_polyline(upper, FOIL_GOLD[1], line, true)
	draw_polyline(lower, FOIL_GOLD[1], line * 1.25, true)
	var drop := at + Vector2(0, s * 1.75)
	draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -s * 0.6), drop + Vector2(s * 0.3, 0), drop + Vector2(0, s * 0.45), drop + Vector2(-s * 0.3, 0)]), Color("fff4d6"))
	if w >= 40.0:
		# Crystals hanging from the lower ring.
		for i in range(1, 8):
			var hook := lower[i * 2 + 1]
			draw_line(hook, hook + Vector2(0, s * 0.45), Color(FOIL_GOLD[0] as Color, 0.7), line * 0.5, true)
			_dot(hook + Vector2(0, s * 0.55), s * 0.11, Color("fff4d6"))
	var candles: Array[Vector2] = []
	for i in 3:
		candles.append(upper[i * 7])
	for i in 5:
		candles.append(lower[floori(i * 4.5)])
	for p in candles:
		draw_line(p, p + Vector2(0, -s * 0.45), Color("fff1d6"), line, true)
		var flame := p + Vector2(0, -s * 0.72)
		_dot(flame, s * 0.6, Color("ffd27a", 0.22))
		_dot(flame, s * 0.32, Color("ffe8b0", 0.75))
		_dot(flame, s * 0.15, Color.WHITE)


## 9 Carnival gold: a gilded jester's crown with bells and jewels on deep purple, gold
## leaf flaking in from the corners and confetti in the air.
func _back_carnival_gold(r: Rect2, panel: PackedVector2Array, inner: Rect2, k: float) -> void:
	var w := r.size.x
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.04)
	_gradient(panel, Color("5c1fa6"), Color("1d0640"))
	_rays(c, 24, r.size.length(), Color(1, 1, 1, 0.04), panel)
	_glow_in(c, w * 0.72, Color("c27bff", 0.45), panel)
	_gold_leaf(inner, panel, w)
	_confetti(inner, panel, c, w, k)
	_glow_in(c, w * 0.42, Color("ffd36b", 0.35), panel)
	_jester_crown(c, w * 0.3, k)


## Gold leaf gilding the corners: a warm wash in each corner, big torn flakes tucked
## into it and smaller ones drifting in towards the middle.
func _gold_leaf(inner: Rect2, panel: PackedVector2Array, w: float) -> void:
	var corners := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	var centre := inner.get_center()
	for corner: Vector2 in corners:
		_glow_in(corner + (centre - corner).sign() * w * 0.04, w * 0.34, Color(FOIL_GOLD[1] as Color, 0.3), panel)
	var deep: Color = FOIL_GOLD[3]
	for i in (32 if w >= 40.0 else 16):
		var corner: Vector2 = corners[i % 4]
		var reach := Vector2(_noise(i, 1), _noise(i, 2))
		reach = reach * reach * reach
		var at := corner + (centre - corner).sign() * (Vector2(0.02, 0.02) * w + reach * inner.size * Vector2(0.55, 0.4))
		var s := w * (0.035 + 0.045 * _noise(i, 3)) * (1.0 - 0.55 * minf(1.0, reach.length() * 1.6))
		var turn := _noise(i, 4) * TAU
		var flake := PackedVector2Array()
		for j in 8:
			flake.append(at + (Vector2.from_angle(j * TAU / 8.0) * s * (0.45 + 0.55 * _noise(i * 9 + j, 5)) * Vector2(1.0, 0.65)).rotated(turn))
		var tone := (FOIL_GOLD[1] as Color).lerp(FOIL_GOLD[2], _noise(i, 6))
		for piece in Geometry2D.intersect_polygons(flake, panel):
			_gradient(piece, tone.lightened(0.3), tone.darkened(0.1))
			if w >= 40.0:
				draw_polyline(Paint.closed(piece), Color(deep, 0.45), maxf(0.3, w * 0.004), true)


## Confetti in carnival colours, kept clear of the crown, and a few curling streamers.
func _confetti(inner: Rect2, panel: PackedVector2Array, crown: Vector2, w: float, k: float) -> void:
	var colours := [Color("ff5d8f"), Color("2fd3c0"), Color("ffd34d"), Color("fbf3e4"), Color("5b8cff"), Color("ff8a3d")]
	for i in (40 if w >= 40.0 else 18):
		var at := _scatter(inner.grow(-0.04 * w), i + 23)
		if ((at - crown) / Vector2(w * 0.44, w * 0.36)).length() < 1.0:
			continue
		var turn := _noise(i, 8) * TAU
		var piece := PackedVector2Array()
		match i % 3:
			0:
				for corner: Vector2 in [Vector2(-1, -0.4), Vector2(1, -0.4), Vector2(1, 0.4), Vector2(-1, 0.4)]:
					piece.append(at + (corner * w * 0.022).rotated(turn))
			1:
				piece = _circle(at, w * 0.012, 10)
			_:
				for j in 3:
					piece.append(at + Vector2.from_angle(turn + j * TAU / 3.0) * w * 0.018)
		for part in Geometry2D.intersect_polygons(piece, panel):
			draw_colored_polygon(part, colours[i % colours.size()])
	if w < 40.0:
		return
	for i in 6:
		var from := _scatter(inner.grow(-0.08 * w), i + 91)
		var heading := Vector2.from_angle(_noise(i, 9) * TAU)
		var curl := PackedVector2Array()
		var clear := true
		for j in 13:
			var t := j / 12.0
			var at := from + heading * t * w * 0.16 + heading.orthogonal() * sin(t * TAU * 1.5) * w * 0.02
			clear = clear and ((at - crown) / Vector2(w * 0.5, w * 0.42)).length() >= 1.0
			curl.append(at)
		if not clear:
			continue
		for seg in Geometry2D.intersect_polyline_with_polygon(curl, panel):
			draw_polyline(seg, colours[(i * 2 + 1) % colours.size()], maxf(0.5, 0.55 * k), true)


## A jester's crown in gold: three points ending in bells (the outer two curling out
## like a jester's cap), a jewel inlaid down each point and a jewelled band.
func _jester_crown(c: Vector2, s: float, k: float) -> void:
	var points := [
		[Vector2(-0.84, 0.24), Vector2(-1.08, -0.08), Vector2(-1.12, -0.74), Vector2(-0.5, -0.3), Vector2(-0.22, 0.24)],
		[Vector2(0.22, 0.24), Vector2(0.5, -0.3), Vector2(1.12, -0.74), Vector2(1.08, -0.08), Vector2(0.84, 0.24)],
		[Vector2(-0.34, 0.24), Vector2(-0.3, -0.45), Vector2(0.0, -1.04), Vector2(0.3, -0.45), Vector2(0.34, 0.24)],
	]
	var jewels := [Color("2fd3c0"), Color("2fd3c0"), Color("ff3b6b")]
	var area := Rect2(c + Vector2(-1.25, -1.15) * s, Vector2(2.5, 1.7) * s)
	var deep: Color = FOIL_GOLD[3]
	var line := maxf(0.4, 0.45 * k)
	for n in points.size():
		var shape := _point_shape(c, s, points[n])
		_foil(shape[0], FOIL_GOLD, area)
		draw_colored_polygon(shape[1], Color(deep, 0.3))
		draw_polyline(Paint.closed(shape[0]), Color(deep, 0.85), line, true)
		if s > 6.5:
			# A long ruby down the middle point, round stones on the curling ones.
			var spine: PackedVector2Array = shape[2]
			if n == 2:
				_jewel(spine[3], spine[7], s * 0.07, jewels[n])
			else:
				_dot(spine[5], s * 0.085, Color(deep, 0.8))
				_dot(spine[5], s * 0.068, jewels[n])
				_dot(spine[5] + Vector2(-0.3, -0.3) * s * 0.068, s * 0.025, Color(1, 1, 1, 0.8))
		var tip := c + (points[n][2] as Vector2) * s
		_bell(tip, s * (0.17 if n == 2 else 0.15), k)
	var band := Rect2(c + Vector2(-0.9, 0.14) * s, Vector2(1.8, 0.4) * s)
	var band_shape := Paint.round_rect(band, s * 0.1)
	_foil(band_shape, FOIL_GOLD, area)
	draw_colored_polygon(PackedVector2Array([band.position + Vector2(0, band.size.y * 0.55), band.position + Vector2(band.size.x, band.size.y * 0.55), band.end, Vector2(band.position.x, band.end.y)]), Color(deep, 0.18))
	draw_polyline(Paint.closed(band_shape), Color(deep, 0.9), line, true)
	var mid := band.get_center()
	if s > 12.0:
		for x: float in [-0.74, -0.26, 0.26, 0.74]:
			_dot(mid + Vector2(x * s, 0), s * 0.045, Color("fff8ee"))
	for side: float in [-1.0, 1.0]:
		var gem := mid + Vector2(side * s * 0.5, 0)
		_dot(gem, s * 0.1, Color(deep, 0.8))
		_dot(gem, s * 0.08, Color("22c493") if side < 0 else Color("4f8cff"))
		_dot(gem + Vector2(-0.3, -0.3) * s * 0.08, s * 0.03, Color(1, 1, 1, 0.8))
	var ruby := _diamond(mid, s * 0.13, s * 0.18)
	draw_colored_polygon(_diamond(mid, s * 0.16, s * 0.21), Color(deep, 0.85))
	_gradient(ruby, Color("ff7aa0"), Color("b0103e"))
	_dot(mid + Vector2(-s * 0.035, -s * 0.06), s * 0.03, Color(1, 1, 1, 0.85))


## 10 Starter's crest: a heraldic shield quartered in blues with a silver lozenge, under a
## jester's cap, framed by laurels and a ribbon; silver on royal blue.
func _back_starters_crest(r: Rect2, panel: PackedVector2Array, inner: Rect2, k: float) -> void:
	var w := r.size.x
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.06)
	_gradient(panel, Color("2f66d4"), Color("0a1d55"))
	if w >= 40.0:
		# A faint diaper of lozenges, like the engraving on a banknote.
		for seg in _lattice(inner, panel, inner.size.x / 6.0, inner.size.x / 6.0 * 0.7):
			draw_polyline(seg, Color(1, 1, 1, 0.07), maxf(0.35, 0.35 * k), true)
	_glow_in(c, w * 0.66, Color("c4dbff", 0.42), panel)
	_laurels(c, w, k)
	_crest_shield(c, w * 0.22, k)
	_jester_cap(c + Vector2(0, -w * 0.205), w * 0.2, k)
	if w >= 40.0:
		_ribbon(c + Vector2(0, w * 0.37), w * 0.34, k)
		for side: float in [-1.0, 1.0]:
			_star5(c + Vector2(side * w * 0.31, -w * 0.47), w * 0.045, FOIL_SILVER[1])


## Two silver laurel branches curving up round the shield from its foot.
func _laurels(c: Vector2, w: float, k: float) -> void:
	var centre := c + Vector2(0, w * 0.02)
	var radius := w * 0.36
	var leaves := 7 if w >= 40.0 else 5
	for side: float in [-1.0, 1.0]:
		var stem := PackedVector2Array()
		for i in 21:
			stem.append(centre + Vector2.from_angle(PI / 2.0 - side * (0.2 + 1.8 * i / 20.0)) * radius)
		draw_polyline(stem, FOIL_SILVER[2], maxf(0.5, 0.55 * k), true)
		for j in leaves + 1:
			var t := (j + 0.5) / (leaves + 1)
			var a := PI / 2.0 - side * (0.2 + 1.8 * t)
			var at := centre + Vector2.from_angle(a) * radius
			var along := Vector2(-sin(a), cos(a)) * -side
			var out := (at - centre).normalized()
			var length := w * 0.11 * (1.0 - 0.3 * t)
			if j == leaves:
				_leaf(at, at + along * length, w * 0.045, FOIL_SILVER[1])
				continue
			_leaf(at, at + (along + out * 0.8).normalized() * length, w * 0.05, FOIL_SILVER[1])
			_leaf(at, at + (along - out * 0.8).normalized() * length, w * 0.05, FOIL_SILVER[2])


## A heater shield: a silver foil edge, a field quartered in two blues and a silver
## lozenge (the Harlequin's diamond) in the middle.
func _crest_shield(c: Vector2, s: float, k: float) -> void:
	var top := c.y - s * 0.95
	var shoulder := c.y + s * 0.15
	var foot := Vector2(c.x, c.y + s * 1.3)
	var shape := PackedVector2Array([Vector2(c.x - s, top), Vector2(c.x + s, top)])
	shape.append_array(_bezier(Vector2(c.x + s, shoulder), Vector2(c.x + s, c.y + s * 0.95), foot, 10))
	shape.append_array(_bezier(foot, Vector2(c.x - s, c.y + s * 0.95), Vector2(c.x - s, shoulder), 10).slice(1))
	var shadow := PackedVector2Array()
	for p in shape:
		shadow.append(p + Vector2(0, s * 0.1))
	draw_colored_polygon(shadow, Color(0.02, 0.05, 0.16, 0.4))
	_foil(shape, FOIL_SILVER, Paint.bounds(shape))
	var deep: Color = FOIL_SILVER[3]
	var fields := Geometry2D.offset_polygon(shape, -s * 0.14)
	if not fields.is_empty():
		var field: PackedVector2Array = fields[0]
		var split := c.y - s * 0.12
		var dark := Color("1a46a8")
		var light := Color("4f8cf0")
		for quarter: Array in [[c.x - s * 2.0, top - s, split, dark], [c.x, top - s, split, light], [c.x - s * 2.0, split, foot.y + s, light], [c.x, split, foot.y + s, dark]]:
			var x0: float = quarter[0]
			var y0: float = quarter[1]
			var y1: float = quarter[2]
			var box := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + s * 2.0, y0), Vector2(x0 + s * 2.0, y1), Vector2(x0, y1)])
			var tint: Color = quarter[3]
			for piece in Geometry2D.intersect_polygons(box, field):
				_gradient(piece, tint.lightened(0.1), tint.darkened(0.15))
		# A sheen across the upper left of the field.
		var sheen := PackedVector2Array([Vector2(c.x - s, top), Vector2(c.x + s * 0.2, top), Vector2(c.x - s, c.y + s * 0.4)])
		for piece in Geometry2D.intersect_polygons(sheen, field):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.12))
		draw_polyline(Paint.closed(field), Color(deep, 0.7), maxf(0.4, 0.4 * k), true)
		var at := Vector2(c.x, split + s * 0.04)
		var lozenge := _diamond(at, s * 0.3, s * 0.46)
		_foil(lozenge, FOIL_SILVER, Paint.bounds(lozenge))
		draw_polyline(Paint.closed(lozenge), Color(deep, 0.9), maxf(0.4, 0.4 * k), true)
		draw_colored_polygon(_diamond(at, s * 0.12, s * 0.19), dark)
	draw_polyline(Paint.closed(shape), Color(deep, 0.95), maxf(0.45, 0.5 * k), true)


## A jester's cap as the crest above the shield: three soft points in blue and silver,
## a silver bell on each and a silver band.
func _jester_cap(base: Vector2, s: float, k: float) -> void:
	var points := [
		[Vector2(-0.8, 0.0), Vector2(-1.15, -0.25), Vector2(-1.25, -0.78), Vector2(-0.55, -0.4), Vector2(-0.2, 0.0)],
		[Vector2(0.2, 0.0), Vector2(0.55, -0.4), Vector2(1.25, -0.78), Vector2(1.15, -0.25), Vector2(0.8, 0.0)],
		[Vector2(-0.32, 0.0), Vector2(-0.3, -0.5), Vector2(0.0, -1.05), Vector2(0.3, -0.5), Vector2(0.32, 0.0)],
	]
	var deep: Color = FOIL_SILVER[3]
	var line := maxf(0.4, 0.45 * k)
	var area := Rect2(base + Vector2(-1.3, -1.1) * s, Vector2(2.6, 1.3) * s)
	for n in points.size():
		var shape := _point_shape(base, s, points[n])
		if n == 2:
			_foil(shape[0], FOIL_SILVER, area)
		else:
			_gradient(shape[0], Color("3f7be8"), Color("173f9c"))
		draw_colored_polygon(shape[1], Color(0.02, 0.06, 0.2, 0.28))
		draw_polyline(Paint.closed(shape[0]), Color(deep, 0.9), line, true)
		_bell(base + (points[n][2] as Vector2) * s, s * 0.15, k, FOIL_SILVER)
	var band := Rect2(base + Vector2(-0.88, -0.08) * s, Vector2(1.76, 0.3) * s)
	var band_shape := Paint.round_rect(band, s * 0.1)
	_foil(band_shape, FOIL_SILVER, area)
	draw_polyline(Paint.closed(band_shape), Color(deep, 0.9), line, true)
	if s > 8.0:
		for i in 5:
			_dot(band.get_center() + Vector2((i - 2) * s * 0.34, 0), s * 0.05, Color("2456c0"))


## A silver ribbon across the foot of the crest, its ends folded back and cut in a
## swallowtail.
func _ribbon(c: Vector2, half: float, k: float) -> void:
	var h := half * 0.24
	var deep: Color = FOIL_SILVER[3]
	var line := maxf(0.4, 0.4 * k)
	for side: float in [-1.0, 1.0]:
		var root := c + Vector2(side * half * 0.86, -h * 0.05)
		var tail := PackedVector2Array([root + Vector2(0, -h * 0.35), root + Vector2(side * half * 0.36, -h * 0.15),
			root + Vector2(side * half * 0.26, h * 0.4), root + Vector2(side * half * 0.36, h * 0.95), root + Vector2(0, h * 0.75)])
		_gradient(tail, FOIL_SILVER[2], deep)
		draw_polyline(Paint.closed(tail), Color(deep, 0.9), line, true)
		draw_colored_polygon(PackedVector2Array([root + Vector2(0, h * 0.2), root + Vector2(-side * half * 0.1, h * 0.55), root + Vector2(0, h * 0.75)]), deep)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in 13:
		var x := lerpf(-half, half, i / 12.0)
		var lift := -absf(x / half) * h * 0.4
		upper.append(c + Vector2(x, lift - h / 2.0))
		lower.append(c + Vector2(x, lift + h / 2.0))
	var strip := upper.duplicate()
	var under := lower.duplicate()
	under.reverse()
	strip.append_array(under)
	_foil(strip, FOIL_SILVER, Paint.bounds(strip))
	draw_polyline(Paint.closed(strip), Color(deep, 0.9), line, true)
	# An engraved line along each edge and three blue stars, like a medal ribbon.
	if k > 1.2:
		var inset := Vector2(0, h * 0.2)
		var top_line := PackedVector2Array()
		var bottom_line := PackedVector2Array()
		for i in upper.size():
			top_line.append(upper[i] + inset)
			bottom_line.append(lower[i] - inset)
		draw_polyline(top_line.slice(1, top_line.size() - 1), Color(deep, 0.45), line * 0.7, true)
		draw_polyline(bottom_line.slice(1, bottom_line.size() - 1), Color(deep, 0.45), line * 0.7, true)
	for x: float in [-0.45, 0.0, 0.45]:
		_star5(c + Vector2(x * half, -absf(x) * h * 0.4), h * 0.3, Color("2456c0"))


## The outline of one point of a crown or cap from `spec` (base left, its curve's
## control, tip, the other control, base right; in units of `s` from `c`), plus the half
## that faces away from the light and the spine between the two.
func _point_shape(c: Vector2, s: float, spec: Array) -> Array:
	var base_left: Vector2 = c + (spec[0] as Vector2) * s
	var bend_left: Vector2 = c + (spec[1] as Vector2) * s
	var tip: Vector2 = c + (spec[2] as Vector2) * s
	var bend_right: Vector2 = c + (spec[3] as Vector2) * s
	var base_right: Vector2 = c + (spec[4] as Vector2) * s
	var left_edge := _bezier(base_left, bend_left, tip, 10)
	var right_edge := _bezier(tip, bend_right, base_right, 10)
	var outline := left_edge.duplicate()
	outline.append_array(right_edge.slice(1))
	var spine := _bezier((base_left + base_right) / 2.0, (bend_left + bend_right) / 2.0, tip, 10)
	var shade := spine.duplicate()
	shade.append_array(right_edge.slice(1))
	return [outline, shade, spine]


## A jewel inlaid along a line, lit from the top left.
func _jewel(from: Vector2, to: Vector2, half_w: float, colour: Color) -> void:
	var mid := (from + to) / 2.0
	var side := (to - from).orthogonal().normalized() * half_w
	var gem := PackedVector2Array([from, mid + side, to, mid - side])
	draw_colored_polygon(gem, colour.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([from, mid + side, mid, mid - side]), colour.lightened(0.15))
	_dot(from.lerp(to, 0.3), half_w * 0.35, Color(1, 1, 1, 0.8))


## A round bell: a domed metal ball with a dark slot.
func _bell(at: Vector2, radius: float, k: float, tones: Array = FOIL_GOLD) -> void:
	_foil_disc(at, radius, tones, k)
	if radius > 1.5:
		var deep: Color = tones[3]
		draw_line(at + Vector2(-radius * 0.55, radius * 0.3), at + Vector2(radius * 0.55, radius * 0.3), Color(deep, 0.9), maxf(0.4, radius * 0.16), true)
		_dot(at + Vector2(0, radius * 0.55), radius * 0.16, deep)


## A domed metal disc lit from the top left, with a dark rim and, when big enough, an
## engraved ring.
func _foil_disc(c: Vector2, radius: float, tones: Array, k: float) -> void:
	var focus := c + Vector2(-0.35, -0.4) * radius
	var span := radius * 1.75
	_fan(focus, _circle(c, radius, 40), func(p: Vector2) -> Color: return _ramp(p.distance_to(focus) / span, tones))
	var deep: Color = tones[3]
	draw_arc(c, radius, 0.0, TAU, 40, Color(deep, 0.9), maxf(0.4, 0.45 * k), true)
	if radius > 6.0:
		var groove := maxf(0.35, 0.35 * k)
		draw_arc(c, radius * 0.78, 0.0, TAU, 36, Color(deep, 0.35), groove, true)
		draw_arc(c, radius * 0.78 + groove, PI * 1.05, PI * 1.6, 12, Color(tones[0] as Color, 0.6), groove * 0.8, true)


## A five-pointed star.
func _star5(at: Vector2, s: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		points.append(at + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (s if i % 2 == 0 else s * 0.42))
	draw_colored_polygon(points, colour)


## A four-pointed twinkle.
func _sparkle(at: Vector2, s: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		points.append(at + Vector2.from_angle(-PI / 2.0 + i * PI / 4.0) * (s if i % 2 == 0 else s * 0.22))
	draw_colored_polygon(points, colour)
	_dot(at, s * 0.2, Color(1, 1, 1, colour.a))


## Wedges of light from `at`, every other one of `count`, kept inside `clip`.
func _rays(at: Vector2, count: int, far: float, colour: Color, clip: PackedVector2Array) -> void:
	for i in range(0, count, 2):
		var wedge := PackedVector2Array([at, at + Vector2.from_angle(i * TAU / count) * far, at + Vector2.from_angle((i + 1) * TAU / count) * far])
		for piece in Geometry2D.intersect_polygons(wedge, clip):
			draw_colored_polygon(piece, colour)


## The lines of a diamond lattice over `inner` (diamonds `cell` wide and `half_h` * 2
## tall, rows offset by half a diamond), clipped to `clip`.
func _lattice(inner: Rect2, clip: PackedVector2Array, cell: float, half_h: float) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var steps := ceili(inner.size.y / half_h) + 3
	for j in range(-steps, 6 + steps):
		var start := Vector2(inner.position.x + j * cell, inner.position.y - half_h)
		for dir: Vector2 in [Vector2(cell / 2.0, half_h), Vector2(-cell / 2.0, half_h)]:
			lines.append_array(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([start, start + dir * steps]), clip))
	return lines


## Soft light from `at`, fading to nothing by `radius`, kept inside the convex `clip`:
## rings of points on spokes from the middle, each spoke stopped at the clip's edge.
func _glow_in(at: Vector2, radius: float, colour: Color, clip: PackedVector2Array) -> void:
	var spokes := 48
	var rings := 5
	var points := PackedVector2Array([at])
	var colours := PackedColorArray([colour])
	var indices := PackedInt32Array()
	for i in spokes:
		var dir := Vector2.from_angle(i * TAU / spokes)
		var reach := _reach(at, dir, radius, clip)
		for j in rings:
			var d := minf(reach, radius * (j + 1) / rings)
			points.append(at + dir * d)
			colours.append(Color(colour, colour.a * pow(1.0 - d / radius, 1.8)))
	for i in spokes:
		var next := (i + 1) % spokes
		indices.append_array(PackedInt32Array([0, 1 + i * rings, 1 + next * rings]))
		for j in rings - 1:
			var a := 1 + i * rings + j
			var b := 1 + next * rings + j
			indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## How far from `at` along `dir` (at most `far`) before leaving the convex `clip`.
static func _reach(at: Vector2, dir: Vector2, far: float, clip: PackedVector2Array) -> float:
	var best := far
	var far_point := at + dir * far
	for i in clip.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(at, far_point, clip[i], clip[(i + 1) % clip.size()])
		if hit is Vector2:
			best = minf(best, at.distance_to(hit))
	return best


## Fill the shape `outline` encloses as a fan of triangles from `focus` (which must see
## every point of it, as the middle of a circle does), coloured per point. Light that
## spreads from one spot stays smooth this way, where a plain polygon would band.
func _fan(focus: Vector2, outline: PackedVector2Array, colour_at: Callable) -> void:
	var points := PackedVector2Array([focus])
	var colours := PackedColorArray([colour_at.call(focus)])
	var indices := PackedInt32Array()
	var n := outline.size()
	for i in n:
		points.append(outline[i])
		colours.append(colour_at.call(outline[i]))
		indices.append_array(PackedInt32Array([0, i + 1, (i + 1) % n + 1]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## Fill the ring between two outlines that pair up point for point, coloured per point.
func _band(outer: PackedVector2Array, inner: PackedVector2Array, colour_at: Callable) -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var n := outer.size()
	for i in n:
		points.append(outer[i])
		points.append(inner[i])
		colours.append(colour_at.call(outer[i]))
		colours.append(colour_at.call(inner[i]))
		var a := i * 2
		var b := ((i + 1) % n) * 2
		indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## Fill a shape with metal foil (see _metal_at) mapped over `area`, with extra points
## along long edges so the streaks can bend across it.
func _foil(points: PackedVector2Array, tones: Array, area: Rect2) -> void:
	var dense := _dense(points, maxf(1.0, area.size.x * 0.08))
	var colours := PackedColorArray()
	for p in dense:
		colours.append(_metal_at(p, area, tones))
	draw_polygon(dense, colours)


## The foil's colour at `p` within `area`. The streaks run on the diagonal, so when
## `area` is the whole card the frame and the emblem catch the same light.
static func _metal_at(p: Vector2, area: Rect2, tones: Array) -> Color:
	var t := ((p.x - area.position.x) * 0.8 + (p.y - area.position.y) * 0.6) / maxf(0.001, area.size.x * 0.8 + area.size.y * 0.6)
	return _metal(t, tones)


## The foil's colour at `t` (0-1) along FOIL_STOPS.
static func _metal(t: float, tones: Array) -> Color:
	t = clampf(t, 0.0, 1.0)
	for i in range(1, FOIL_STOPS.size()):
		var stop: Array = FOIL_STOPS[i]
		if t <= float(stop[0]):
			var before: Array = FOIL_STOPS[i - 1]
			var from: Color = tones[int(before[1])]
			return from.lerp(tones[int(stop[1])], (t - float(before[0])) / (float(stop[0]) - float(before[0])))
	return tones[1]


## Highlight to body to shadow of a foil (t 0-1), for domes and facets.
static func _ramp(t: float, tones: Array) -> Color:
	t = clampf(t, 0.0, 1.0)
	var hi: Color = tones[0]
	var body: Color = tones[1]
	var low: Color = tones[2]
	return hi.lerp(body, t * 2.0) if t < 0.5 else body.lerp(low, t * 2.0 - 1.0)


## A metal facet's colour: bright when it faces the top-left light, deep facing away.
static func _facet(normal_angle: float, tones: Array) -> Color:
	return _ramp(0.5 - 0.5 * cos(normal_angle - LIGHT_ANGLE), tones)


## A rounded rectangle with the same number of points at any size, so an outer and an
## inner one pair up point for point (see _band). `per_side` splits each straight side.
static func _rounded_ring(r: Rect2, radius: float, per_side := 8) -> PackedVector2Array:
	radius = clampf(radius, 0.5, minf(r.size.x, r.size.y) / 2.0 - 0.05)
	var centres := [Vector2(r.end.x - radius, r.position.y + radius), Vector2(r.end.x - radius, r.end.y - radius),
		Vector2(r.position.x + radius, r.end.y - radius), Vector2(r.position.x + radius, r.position.y + radius)]
	var points := PackedVector2Array()
	for corner in 4:
		var start := -PI / 2.0 + corner * PI / 2.0
		var centre: Vector2 = centres[corner]
		for i in 6:
			points.append(centre + Vector2.from_angle(start + i * PI / 10.0) * radius)
		var from := points[points.size() - 1]
		var to: Vector2 = (centres[(corner + 1) % 4] as Vector2) + Vector2.from_angle(start + PI / 2.0) * radius
		for i in range(1, per_side):
			points.append(from.lerp(to, float(i) / per_side))
	return points


## Extra points along edges longer than `spacing`, so colours given per point can vary
## along them.
static func _dense(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		out.append(a)
		var n := floori(a.distance_to(b) / spacing)
		for j in range(1, n):
			out.append(a.lerp(b, float(j) / n))
	return out


static func _circle(at: Vector2, radius: float, n := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in n:
		points.append(at + Vector2.from_angle(i * TAU / n) * radius)
	return points


static func _ellipse_arc(c: Vector2, radii: Vector2, from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from_angle, to_angle, float(i) / steps)
		points.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points


static func _bezier(a: Vector2, control: Vector2, b: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points


## A fixed pseudo-random number in 0-1 for (n, salt): integer hashing, so it is the same
## on every bake and every device.
static func _noise(n: int, salt := 0) -> float:
	var x := ((n * 73856093) ^ (salt * 19349663)) & 0xFFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFFFFFF
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65535.0


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
		# Keep the effect badge (Mult, Chips, ...) that the drawn figures carry.
		art = JesterArt.new(self)
		art.prepare_badge(window, def_id)
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


