class_name Paint
extends RefCounted
## Shared painting tools for the Venetian carnival look of cards and Jesters:
## shapes lit from the top left so they read as rounded, warm sepia ink lines,
## gold leaf, soft candle glows, vignettes and the pointed Venetian arch.

const INK := Color("2b1b12")
const GOLD_HI := Color("fff2c0")
const GOLD := Color("e2aa3e")
const GOLD_LO := Color("8a5a14")
const PARCHMENT := Color("f6ecd4")
const PARCHMENT_EDGE := Color("c9a46a")
## Carnival jewel tones for card bodies and backdrops.
const LAGOON := Color("0f5a6b")
const CARMINE := Color("a3122c")
const MIDNIGHT := Color("1b2152")
const EMERALD := Color("13704e")
const AMETHYST := Color("5b2a86")


## Fill with light falling from the top left: the top-left edge is lighter, the
## bottom-right darker, so a flat shape reads as rounded paint.
static func lit(canvas: CanvasItem, points: PackedVector2Array, colour: Color, strength := 1.0) -> void:
	if points.size() < 3:
		return
	var box := bounds(points)
	var colours := PackedColorArray()
	for p in points:
		var t := (p.y - box.position.y) / maxf(0.001, box.size.y)
		var u := (p.x - box.position.x) / maxf(0.001, box.size.x)
		var shade := (0.34 * (0.5 - t) + 0.12 * (0.5 - u)) * strength
		colours.append(colour.lightened(shade) if shade > 0.0 else colour.darkened(-shade))
	canvas.draw_polygon(points, colours)


## A warm ink line around a shape, darker than its fill.
static func ink(canvas: CanvasItem, points: PackedVector2Array, colour: Color, width := 0.7) -> void:
	if points.size() < 2:
		return
	var line := colour.darkened(0.55).lerp(INK, 0.45)
	line.a = 0.85 * colour.a
	canvas.draw_polyline(closed(points), line, width, true)


## Painted shape: lit fill plus ink line.
static func shape(canvas: CanvasItem, points: PackedVector2Array, colour: Color, width := 0.7, strength := 1.0) -> void:
	lit(canvas, points, colour, strength)
	ink(canvas, points, colour, width)


## Gold leaf: bright at the top, deep at the bottom, with a dark rim.
static func gold(canvas: CanvasItem, points: PackedVector2Array, width := 0.6) -> void:
	if points.size() < 3:
		return
	var box := bounds(points)
	var colours := PackedColorArray()
	for p in points:
		var t := (p.y - box.position.y) / maxf(0.001, box.size.y)
		colours.append(GOLD_HI.lerp(GOLD, t / 0.4) if t < 0.4 else GOLD.lerp(GOLD_LO, (t - 0.4) / 0.6))
	canvas.draw_polygon(points, colours)
	canvas.draw_polyline(closed(points), GOLD_LO.darkened(0.35), width, true)


## A gilded line: a dark bed, the gold stroke and a fine highlight on top.
static func gold_line(canvas: CanvasItem, points: PackedVector2Array, width: float, loop := true) -> void:
	var path := closed(points) if loop else points
	canvas.draw_polyline(path, GOLD_LO.darkened(0.3), width + maxf(0.5, width * 0.6), true)
	canvas.draw_polyline(path, GOLD, width, true)
	canvas.draw_polyline(path, Color(GOLD_HI, 0.55), maxf(0.35, width * 0.35), true)


## Soft round light, built from stacked transparent discs.
static func glow(canvas: CanvasItem, at: Vector2, radius: float, colour: Color, rings := 7) -> void:
	for i in rings:
		var f := 1.0 - float(i) / rings
		canvas.draw_circle(at, radius * f, Color(colour, colour.a / rings), true, -1.0, true)


## Darken the edges of a rectangle towards `colour`, like an old painting.
static func vignette(canvas: CanvasItem, r: Rect2, colour: Color, depth: float) -> void:
	var inner := r.grow(-depth)
	var edge := Color(colour, colour.a)
	var clear := Color(colour, 0.0)
	var o := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var i := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for k in 4:
		var n := (k + 1) % 4
		canvas.draw_polygon(PackedVector2Array([o[k], o[n], i[n], i[k]]), PackedColorArray([edge, edge, clear, clear]))


## A pointed Venetian arch filling a rectangle, apex at its top edge. `pointed`
## is each arc's radius as a share of the width: 0.5 is a round arch, 1.0 the
## sharp equilateral Gothic arch; Venetian windows sit around 0.55-0.65.
static func arch(r: Rect2, pointed := 0.58, steps := 10) -> PackedVector2Array:
	var w := r.size.x
	var radius := w * clampf(pointed, 0.5, 1.0)
	var apex_cos := (w * 0.5 - radius) / radius
	var apex_angle := acos(clampf(apex_cos, -1.0, 1.0))
	var spring := r.position.y + radius * sin(apex_angle)
	var left_arc_centre := Vector2(r.position.x + radius, spring)
	var right_arc_centre := Vector2(r.end.x - radius, spring)
	var points := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x, spring)])
	for k in range(1, steps + 1):
		var a := lerpf(PI, apex_angle, float(k) / steps)
		points.append(left_arc_centre + Vector2(cos(a), -sin(a)) * radius)
	for k in range(1, steps + 1):
		var a := lerpf(PI - apex_angle, 0.0, float(k) / steps)
		points.append(right_arc_centre + Vector2(cos(a), -sin(a)) * radius)
	points.append(Vector2(r.end.x, r.end.y))
	return points


static func round_rect(r: Rect2, radius: float, steps := 4) -> PackedVector2Array:
	var points := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) / 2.0)
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI / 2.0],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2.0],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	for corner in corners:
		for k in steps + 1:
			var a: float = corner[1] + float(k) / steps * PI / 2.0
			points.append(corner[0] + Vector2(cos(a), sin(a)) * radius)
	return points


static func diamond(c: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -half_h), c + Vector2(half_w, 0), c + Vector2(0, half_h), c + Vector2(-half_w, 0)])


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


static func bounds(points: PackedVector2Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


## Paper grain: a sprinkle of faint warm specks, the same on every card of a size.
static func grain(canvas: CanvasItem, r: Rect2, colour: Color, count := 40) -> void:
	for i in count:
		var p := r.position + r.size * Vector2(fposmod(0.37 + i * 0.7548777, 1.0), fposmod(0.11 + i * 0.5698403, 1.0))
		canvas.draw_circle(p, maxf(0.25, r.size.x * (0.004 + 0.003 * (i % 3))), Color(colour, 0.08 + 0.04 * (i % 2)), true, -1.0, true)
