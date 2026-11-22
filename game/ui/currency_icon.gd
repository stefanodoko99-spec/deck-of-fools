class_name CurrencyIcon
extends Control
## The coin and diamond symbols, drawn in code so they stay sharp at any size.
## Coins are gold with a jester's-hat stamp (so they don't look like the in-run
## ducats, which are only ever shown as numbers); diamonds are a faceted blue gem.

const COIN := Color("f2bd4b")
const COIN_DARK := Color("b9801f")
const DIAMOND := Color("7fd8ff")
const DIAMOND_DARK := Color("2f7fd0")

var currency := "coins"


func _init(kind := "coins", icon_size := 14.0) -> void:
	currency = kind
	custom_minimum_size = Vector2(icon_size, icon_size)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	if currency == "diamonds":
		_diamond(c, s)
	else:
		_coin(c, s)


func _coin(c: Vector2, s: float) -> void:
	var r := s * 0.47
	draw_circle(c + Vector2(0, s * 0.04), r, COIN_DARK, true, -1.0, true)
	draw_circle(c, r, COIN, true, -1.0, true)
	draw_arc(c, r * 0.78, 0.0, TAU, 28, COIN_DARK, maxf(1.0, s * 0.07), true)
	# A tiny three-pointed jester's hat.
	var w := r * 0.62
	var hat := PackedVector2Array([
		c + Vector2(-w, w * 0.45), c + Vector2(-w * 0.75, -w * 0.55), c + Vector2(-w * 0.3, w * 0.05),
		c + Vector2(0, -w * 0.8), c + Vector2(w * 0.3, w * 0.05), c + Vector2(w * 0.75, -w * 0.55), c + Vector2(w, w * 0.45),
	])
	draw_colored_polygon(hat, COIN_DARK)
	draw_circle(c + Vector2(-r * 0.25, -r * 0.35), r * 0.16, Color(1, 1, 1, 0.55), true, -1.0, true)


func _diamond(c: Vector2, s: float) -> void:
	var w := s * 0.48
	var top := c.y - s * 0.3
	var mid := c.y - s * 0.08
	var tip := c.y + s * 0.44
	var outline := PackedVector2Array([
		Vector2(c.x - w * 0.55, top), Vector2(c.x + w * 0.55, top), Vector2(c.x + w, mid), Vector2(c.x, tip), Vector2(c.x - w, mid),
	])
	draw_colored_polygon(outline, DIAMOND_DARK)
	# Facets: a light crown and a lighter left half of the pavilion.
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.55, top), Vector2(c.x + w * 0.55, top), Vector2(c.x + w, mid), Vector2(c.x - w, mid)]), DIAMOND)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - w, mid), Vector2(c.x, mid), Vector2(c.x, tip)]), DIAMOND.lightened(0.25))
	draw_line(Vector2(c.x - w * 0.2, top), Vector2(c.x - w * 0.45, mid), Color(1, 1, 1, 0.6), maxf(1.0, s * 0.06), true)
