class_name UiIcon
extends Control
## Line icons drawn in code, so they stay sharp at any size: rounded strokes in
## the style of the system icons on iPhone. Names: settings, profile, trophy,
## help, info, pause, close, back, forward.

var icon := ""
var colour := Color.WHITE


func _init(icon_name := "", icon_colour := Color.WHITE) -> void:
	icon = icon_name
	colour = icon_colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var w := maxf(1.2, s * 0.09)
	var at := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var line := func(points: PackedVector2Array) -> void:
		draw_polyline(points, colour, w, true)
		draw_circle(points[0], w / 2.0, colour, true, -1.0, true)
		draw_circle(points[points.size() - 1], w / 2.0, colour, true, -1.0, true)
	match icon:
		"settings":
			var gear := PackedVector2Array()
			var teeth := 8
			for i in teeth * 4 + 1:
				var k := i % 4
				var a: float = (floori(i / 4.0) + [0.0, 0.18, 0.5, 0.68][k]) * TAU / teeth
				var r := 0.44 if k == 1 or k == 2 else 0.33
				gear.append(at.call(0.5, 0.5) + Vector2(cos(a), sin(a)) * r * s)
			draw_polyline(gear, colour, w, true)
			draw_arc(at.call(0.5, 0.5), s * 0.13, 0.0, TAU, 24, colour, w, true)
		"profile":
			draw_arc(at.call(0.5, 0.34), s * 0.17, 0.0, TAU, 24, colour, w, true)
			draw_arc(at.call(0.5, 0.98), s * 0.36, PI * 1.12, PI * 1.88, 20, colour, w, true)
		"trophy":
			line.call(PackedVector2Array([at.call(0.28, 0.16), at.call(0.72, 0.16), at.call(0.7, 0.42)]))
			draw_arc(at.call(0.5, 0.4), s * 0.2, 0.0, PI, 16, colour, w, true)
			line.call(PackedVector2Array([at.call(0.28, 0.16), at.call(0.3, 0.42)]))
			draw_arc(at.call(0.25, 0.3), s * 0.1, PI * 0.5, PI * 1.5, 10, colour, w, true)
			draw_arc(at.call(0.75, 0.3), s * 0.1, -PI * 0.5, PI * 0.5, 10, colour, w, true)
			line.call(PackedVector2Array([at.call(0.5, 0.6), at.call(0.5, 0.76)]))
			line.call(PackedVector2Array([at.call(0.32, 0.84), at.call(0.68, 0.84)]))
		"help", "info":
			draw_arc(at.call(0.5, 0.5), s * 0.42, 0.0, TAU, 32, colour, w, true)
			var glyph := "?" if icon == "help" else "i"
			var font_size := int(round(s * 0.56))
			var width := UiTheme.bold.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(UiTheme.bold, at.call(0.5, 0.5) + Vector2(-width / 2.0, font_size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
		"pause":
			for x in [0.36, 0.64]:
				draw_line(at.call(x, 0.26), at.call(x, 0.74), colour, w * 1.4, true)
				draw_circle(at.call(x, 0.26), w * 0.7, colour, true, -1.0, true)
				draw_circle(at.call(x, 0.74), w * 0.7, colour, true, -1.0, true)
		"close":
			line.call(PackedVector2Array([at.call(0.28, 0.28), at.call(0.72, 0.72)]))
			line.call(PackedVector2Array([at.call(0.72, 0.28), at.call(0.28, 0.72)]))
		"back":
			line.call(PackedVector2Array([at.call(0.62, 0.22), at.call(0.34, 0.5), at.call(0.62, 0.78)]))
		"forward":
			line.call(PackedVector2Array([at.call(0.38, 0.22), at.call(0.66, 0.5), at.call(0.38, 0.78)]))
