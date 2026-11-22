class_name CollectionSheet
extends Sheet
## The Jester collection: every Jester in the game, 30 to a page. The ones you've met
## (in a shop, a pack or your lineup) show their face, with a gold medal for the best
## stake you've won a tour with them; the rest are blank tiles, and a lock marks the
## ones a feat still has to unlock. Tap a tile to see it up close (JesterInspect).
## Swipe, scroll or use the arrows to turn pages.

const COLUMNS := 10
const ROWS := 3
const TILE := Vector2(52, 72)
const FILTERS := ["All", "Common", "Uncommon", "Rare", "Legendary"]

## What unlocks each Jester in Unlocks.RARE_FEATS, in words.
const FEAT_WORDS := {
	"jesters_5": "Have 5 Jesters at once",
	"jesters_6": "Have 6 Jesters at once",
	"ducats_50": "Hold 50 ducats",
	"won_run": "Win a run",
	"patrons_8": "Beat 8 Patrons in one run",
	"signs_20": "Use 20 Signs in one run",
	"level_5": "Raise a poker hand to level 5",
	"all_hands": "Play every poker hand in one run",
	"enhanced_10": "Have 10 enhanced cards in your deck",
	"editions_3": "Have 3 cards with an edition in your deck",
	"lost_to_patron": "Lose to a Patron",
	"points_1000": "Score over 1,000 Points in one hand",
	"played_flush": "Play a Flush",
	"played_straight_flush": "Play a Straight Flush",
	"identical_cards": "Play two identical cards in one hand",
	"patron_first_hand": "Beat a Patron with your first hand",
	"won_on_last_hand": "Win a show on your last hand",
	"won_with_one_jester": "Win a show with only one Jester",
	"won_with_burattinaio": "Win a show with Il Burattinaio",
	"interest_10": "Earn 10 ducats of interest at once",
	"lifetime:runs_lost>=5": "Lose 5 runs",
	"lifetime:signs_used>=50": "Use 50 Signs in all",
}

var filter := 0
var page := 0
var _grid: GridContainer
var _inspect: JesterInspect
var _press_at := Vector2.ZERO
var _pressing := false
var _last_turn := 0


func _init() -> void:
	title_text = "Jesters"
	panel_size = Vector2(612, 348)


## Every Jester in collection order, with its number (#1 to #150).
static func numbered() -> Array[String]:
	var out: Array[String] = []
	for d: ContentDef in ContentDB.pool("zanni"):
		out.append(d.id)
	return out


static func found_count() -> int:
	return numbered().filter(func(id: String) -> bool: return Game.profile.discovered.has(id)).size()


## How to unlock a Jester that is still locked, or "" when it isn't.
static func lock_words(id: String) -> String:
	if Game.profile.is_unlocked(id):
		return ""
	return str(FEAT_WORDS.get(Unlocks.RARE_FEATS[id], "Keep playing"))


func entries() -> Array[String]:
	var out: Array[String] = []
	for d: ContentDef in ContentDB.pool("zanni"):
		if filter == 0 or d.rarity == filter - 1:
			out.append(d.id)
	return out


func _per_page() -> int:
	return COLUMNS * ROWS


func _pages() -> int:
	return maxi(1, ceili(entries().size() / float(_per_page())))


func _build() -> void:
	var all := numbered()
	var found := found_count()
	# Progress on the left, the rarity filter on the right.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var progress := VBoxContainer.new()
	progress.add_theme_constant_override("separation", 3)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(UiTheme.label("%d of %d found" % [found, all.size()], 10, UiTheme.TEXT))
	progress.add_child(_bar(float(found) / maxf(1.0, all.size())))
	top.add_child(progress)
	top.add_child(UiTheme.segmented(FILTERS, filter, _pick_filter, 9))
	body.add_child(top)

	var list := entries()
	page = clampi(page, 0, _pages() - 1)
	var centre := CenterContainer.new()
	centre.custom_minimum_size = Vector2(0, ROWS * TILE.y + (ROWS - 1) * 6.0)
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(centre)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	centre.add_child(_grid)
	for i in range(page * _per_page(), mini(list.size(), (page + 1) * _per_page())):
		_grid.add_child(_tile(list[i], i, all.find(list[i]) + 1))
	# Keep the grid's height when the last page is short, so the footer doesn't jump.
	for i in _per_page() - _grid.get_child_count():
		var gap := Control.new()
		gap.custom_minimum_size = TILE
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(gap)
	if not Settings.reduce_motion:
		_grid.modulate.a = 0.0
		_grid.create_tween().tween_property(_grid, "modulate:a", 1.0, 0.16)

	# Page control: arrows either side of iPhone-style dots.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 10)
	var back := UiTheme.icon_button("back", _turn.bind(-1), 22.0)
	back.modulate.a = 1.0 if page > 0 else 0.25
	foot.add_child(back)
	var dots := Control.new()
	dots.custom_minimum_size = Vector2(_pages() * 12.0 + 8.0, 22)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(_draw_dots.bind(dots))
	foot.add_child(dots)
	var next := UiTheme.icon_button("forward", _turn.bind(1), 22.0)
	next.modulate.a = 1.0 if page < _pages() - 1 else 0.25
	foot.add_child(next)
	body.add_child(foot)


func _tile(id: String, index: int, number: int) -> Control:
	if Game.profile.discovered.has(id):
		var v := CardView.new(TILE)
		v.kind = "zanni"
		v.def_id = id
		v.tapped.connect(func(_v: CardView) -> void: _open(index))
		var best := int(Game.profile.badges.get(id, 0))
		if best > 0:
			var medal := Control.new()
			medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			medal.position = TILE - Vector2(9, 9)
			medal.size = Vector2(12, 12)
			medal.draw.connect(_draw_medal.bind(medal, best))
			v.add_child(medal)
			# The card adds its face when it enters the tree; keep the medal above it.
			v.ready.connect(func() -> void: v.move_child(medal, -1))
		return v
	var blank := BlankTile.new(id, number)
	blank.pressed.connect(_open.bind(index))
	return blank


func _bar(share: float) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(150, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_style_box(UiTheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 99), r)
		if share > 0.0:
			var fill := r
			fill.size.x = maxf(r.size.y, r.size.x * share)
			bar.draw_style_box(UiTheme.box(UiTheme.GOLD, Color(0, 0, 0, 0), 99), fill))
	return bar


func _draw_dots(dots: Control) -> void:
	var n := _pages()
	var x := 4.0
	var y := dots.size.y / 2.0
	for i in n:
		if i == page:
			dots.draw_style_box(UiTheme.box(UiTheme.TEXT, Color(0, 0, 0, 0), 99), Rect2(x - 1.0, y - 3.0, 14.0, 6.0))
			x += 18.0
		else:
			dots.draw_circle(Vector2(x + 3.0, y), 3.0, Color(1, 1, 1, 0.3), true, -1.0, true)
			x += 12.0


func _draw_medal(medal: Control, stake: int) -> void:
	var c := medal.size / 2.0
	medal.draw_circle(c + Vector2(0, 1), 6.5, Color(0, 0, 0, 0.35), true, -1.0, true)
	medal.draw_circle(c, 6.5, UiTheme.GOLD, true, -1.0, true)
	medal.draw_arc(c, 6.5, 0.0, TAU, 20, UiTheme.GOLD.lightened(0.4), 1.0, true)
	var text := str(stake)
	var size_px := 8
	var w := UiTheme.bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	medal.draw_string(UiTheme.bold, c + Vector2(-w / 2.0, size_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UiTheme.INK)


func _pick_filter(i: int) -> void:
	if i == filter:
		return
	Feel.play("click")
	filter = i
	page = 0
	rebuild()


func _turn(step: int) -> void:
	var to := clampi(page + step, 0, _pages() - 1)
	if to == page:
		return
	Feel.play("click")
	Feel.buzz(6)
	page = to
	_last_turn = Time.get_ticks_msec()
	rebuild()


func _open(index: int) -> void:
	if _inspect != null:
		return
	Feel.play("select")
	Feel.buzz(12)
	_inspect = JesterInspect.new(entries(), index)
	_inspect.finished.connect(func(at: int) -> void:
		_inspect = null
		# Come back to the page of the Jester you ended on.
		var at_page := floori(at / float(_per_page()))
		if at_page != page:
			page = at_page
			rebuild())
	add_child(_inspect)


## Swipes and scrolls turn pages. This looks at input before the cards do, without
## taking it from them, so a tap still opens a card and a sideways drag turns the page.
func _input(event: InputEvent) -> void:
	if _inspect != null or _grid == null or not is_inside_tree():
		return
	if event is InputEventMouseButton:
		var button: int = event.button_index
		if event.pressed and button in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			# Trackpads send a stream of wheel events; turn once per flick.
			if Time.get_ticks_msec() - _last_turn > 380:
				_turn(1 if button in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] else -1)
		elif button == MOUSE_BUTTON_LEFT:
			var at := get_global_mouse_position()
			if event.pressed:
				_press_at = at
				_pressing = _grid.get_global_rect().grow(10.0).has_point(at)
			elif _pressing:
				_pressing = false
				var moved := at - _press_at
				if absf(moved.x) > 40.0 and absf(moved.x) > absf(moved.y) * 1.4:
					_turn(1 if moved.x < 0.0 else -1)


func _unhandled_input(event: InputEvent) -> void:
	if _inspect == null and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_turn(1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_LEFT:
			_turn(-1)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


## A Jester you haven't met yet: a blank tile with its rarity on the edge and its
## number, or a lock when a feat still has to unlock it.
class BlankTile extends Control:
	signal pressed

	var id := ""
	var number := 0
	var locked := false
	var _down := Vector2.ZERO

	func _init(jester_id: String, jester_number: int) -> void:
		id = jester_id
		number = jester_number
		locked = not Game.profile.is_unlocked(id)
		custom_minimum_size = CollectionSheet.TILE
		size = CollectionSheet.TILE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = event.global_position
			elif (event.global_position - _down).length() < 9.0:
				pressed.emit()
			accept_event()

	func _draw() -> void:
		var def := ContentDB.get_def(id)
		var rarity: Color = CardView.RARITY_COLOURS[clampi(def.rarity, 0, 3)]
		var r := Rect2(Vector2.ZERO, size)
		var face := UiTheme.box(Color(1, 1, 1, 0.045), Color(rarity, 0.45), 6)
		face.set_border_width_all(1)
		draw_style_box(face, r)
		var c := r.get_center() - Vector2(0, 4)
		if locked:
			# A padlock: shackle over a rounded body.
			var ink := Color(1, 1, 1, 0.38)
			draw_arc(c + Vector2(0, -3), 5.0, PI, TAU, 16, ink, 2.0, true)
			draw_line(c + Vector2(-5, -3), c + Vector2(-5, 0), ink, 2.0, true)
			draw_line(c + Vector2(5, -3), c + Vector2(5, 0), ink, 2.0, true)
			draw_style_box(UiTheme.box(ink, Color(0, 0, 0, 0), 3), Rect2(c + Vector2(-8, 0), Vector2(16, 11)))
		else:
			var mark := "?"
			var size_px := 22
			var w := UiTheme.display.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			draw_string(UiTheme.display, c + Vector2(-w / 2.0, size_px * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 1, 1, 0.22))
		var tag := "#%d" % number
		var w2 := UiTheme.font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(UiTheme.font, Vector2(size.x / 2.0 - w2 / 2.0, size.y - 6.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.35))
