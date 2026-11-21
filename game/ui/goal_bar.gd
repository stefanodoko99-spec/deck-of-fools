class_name GoalBar
extends Control
## The goal of the current show, always in view while you play: which show it is,
## the score to beat, a bar filling as you score (green once it is won) and how
## many hands are left to do it.

var title := ""
var score := 0.0
var target := 1.0
var hands := 0
var colour := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 30)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.06, 0.03, 0.12, 0.78)
	pill.border_color = Color(1, 1, 1, 0.14)
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(99)
	pill.anti_aliasing = true
	draw_style_box(pill, r)
	# Progress fill inside the pill.
	var share := clampf(score / maxf(1.0, target), 0.0, 1.0)
	var won := score >= target
	if share > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiTheme.GOOD if won else colour
		fill.set_corner_radius_all(99)
		fill.anti_aliasing = true
		var inner := r.grow(-3.0)
		inner.size.x = maxf(inner.size.y, inner.size.x * share)
		draw_style_box(fill, inner)
	var font := UiTheme.bold
	var size_px := UiTheme.px(10)
	var mid := r.size.y / 2.0 + size_px * 0.36
	draw_string_outline(font, Vector2(14, mid), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.45, size_px, 3, Color(0, 0, 0, 0.35))
	draw_string(font, Vector2(14, mid), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.45, size_px, Color.WHITE)
	var right := "%s / %s" % [UiTheme.number(score), UiTheme.number(target)]
	var hands_text := ("Won!" if won else "%d %s left" % [hands, "hand" if hands == 1 else "hands"])
	var right_text := right + "   ·   " + hands_text
	var width := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := r.size.x - 14.0 - width
	draw_string_outline(font, Vector2(x, mid), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 3, Color(0, 0, 0, 0.35))
	draw_string(font, Vector2(x, mid), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE if not won else Color.WHITE)
