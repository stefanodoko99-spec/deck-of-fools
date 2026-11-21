class_name ShowTrack
extends Control
## The town as a game board instead of three forms: a path through three stops,
## the Matinee (a sun), the Evening show (a moon) and the Patron (a crowned boss).
## Finished stops show a tick, the current one glows and breathes, and under each
## stop is what it takes to win it and what skipping it would earn.

var run: RunState
var names: Array = []
var colours: Array = []
var _t := 0.0


func setup(r: RunState, show_names: Array, show_colours: Array, favor_text: Callable) -> void:
	run = r
	names = show_names
	colours = show_colours
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := size.x
	for i: int in _stops():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -1)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.position = Vector2(_node_x(i) - w / 6.0 + 4.0, 72.0)
		col.size = Vector2(w / 3.0 - 8.0, size.y - 76.0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)
		var done := i < r.show_index
		var title := UiTheme.label(str(names[i]), 11, (colours[i] as Color).lightened(0.35) if not done else UiTheme.MUTED)
		title.add_theme_font_override("font", UiTheme.bold)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(title)
		var goal := UiTheme.label("Won" if done else "Beat " + UiTheme.number(r.target_for_show(i)), 14, UiTheme.GOOD if done else UiTheme.GOLD)
		goal.add_theme_font_override("font", UiTheme.display)
		goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(goal)
		var detail := ""
		var detail_colour := UiTheme.MUTED
		if i < Shows.PATRON:
			if not done and r.town_favors[i] != "":
				detail = "Skip for %s: %s" % [UiTheme.name_of(r.town_favors[i]), favor_text.call(i)]
		else:
			detail = "%s: %s" % [UiTheme.name_of(r.town_patron), UiTheme.text_of(r.town_patron)]
			detail_colour = UiTheme.MULT.lightened(0.3)
		if detail != "":
			var d := UiTheme.label(detail, 9, detail_colour)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			d.max_lines_visible = 3
			d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			d.custom_minimum_size = Vector2(w / 3.0 - 10.0, 0)
			col.add_child(d)
	set_process(not Settings.reduce_motion)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The stops on this town's path: all three, or only the Patron in a boss rush.
func _stops() -> Array[int]:
	var stops: Array[int] = []
	if run == null or run.mode != "bosses":
		stops.append(Shows.MATINEE)
		stops.append(Shows.EVENING)
	stops.append(Shows.PATRON)
	return stops


func _node_x(i: int) -> float:
	if _stops().size() == 1:
		return size.x * 0.5
	return size.x * (0.17 + 0.33 * i)


func _draw() -> void:
	# A frosted panel under the board keeps its text readable over the bright backdrop.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.03, 0.12, 0.62)
	panel.border_color = Color(1, 1, 1, 0.1)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(16)
	panel.anti_aliasing = true
	draw_style_box(panel, Rect2(Vector2(0, -2), size + Vector2(0, 2)))
	var y := 36.0
	# The path: gold where you have been, faint ahead.
	for i in (2 if _stops().size() == 3 else 0):
		var a := Vector2(_node_x(i), y)
		var b := Vector2(_node_x(i + 1), y)
		var walked := i < run.show_index
		draw_line(a, b, Color(UiTheme.GOLD, 0.9) if walked else Color(1, 1, 1, 0.18), 3.0 if walked else 2.0, true)
		if not walked:
			for k in range(1, 8):
				draw_circle(a.lerp(b, k / 8.0), 1.4, Color(1, 1, 1, 0.35), true, -1.0, true)
	for i: int in _stops():
		var c := Vector2(_node_x(i), y)
		var radius := 28.0 if i == Shows.PATRON else 22.0
		var colour: Color = colours[i]
		var done := i < run.show_index
		var current := i == run.show_index and run.phase == RunState.Phase.CHOOSE_SHOW
		if current:
			var breathe := 0.5 + 0.5 * sin(_t * 3.0)
			Paint.glow(self, c, radius * (1.9 + 0.25 * breathe), Color(colour.lightened(0.3), 0.55), 6)
		var fill := UiTheme.GOOD if done else (colour if current else colour.darkened(0.55))
		draw_circle(c + Vector2(0, 2), radius, Color(0, 0, 0, 0.3), true, -1.0, true)
		draw_circle(c, radius, fill, true, -1.0, true)
		draw_arc(c, radius, 0.0, TAU, 40, UiTheme.GOLD if current else Color(1, 1, 1, 0.3), 2.0 if current else 1.0, true)
		var ink := Color.WHITE if (done or current) else Color(1, 1, 1, 0.55)
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 5), c + Vector2(8, -6)]), Color.WHITE, 3.0, true)
		else:
			_glyph(i, c, radius, ink, fill)


func _glyph(i: int, c: Vector2, radius: float, ink: Color, fill: Color) -> void:
	match i:
		Shows.MATINEE:
			draw_circle(c, radius * 0.3, ink, true, -1.0, true)
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * radius * 0.45, c + Vector2(cos(a), sin(a)) * radius * 0.65, ink, 2.0, true)
		Shows.EVENING:
			draw_circle(c, radius * 0.48, ink, true, -1.0, true)
			draw_circle(c + Vector2(radius * 0.24, -radius * 0.16), radius * 0.42, fill, true, -1.0, true)
		_:
			var s := radius * 0.55
			var crown := PackedVector2Array([
				c + Vector2(-s, s * 0.55), c + Vector2(-s, -s * 0.35), c + Vector2(-s * 0.45, s * 0.05),
				c + Vector2(0, -s * 0.7), c + Vector2(s * 0.45, s * 0.05), c + Vector2(s, -s * 0.35), c + Vector2(s, s * 0.55),
			])
			draw_colored_polygon(crown, ink)
			for p in [crown[1], crown[3], crown[5]]:
				draw_circle(p, 2.2, ink, true, -1.0, true)
