class_name AdSheet
extends Control
## The test stand-in for an ad (Ads in "test" mode). It looks like the theatre's
## intermission curtain: a placeholder card where the real ad will play, a countdown,
## and a close button. A rewarded ad pays only if it runs to the end; closing early
## says so. Real ads replace this through Ads._play_live.

signal done(completed: bool)

const SECONDS := 5.0
const TITLES := {
	"encore": "An Encore, sponsored",
	"double_coins": "Double your coins",
	"daily_gift": "Double your gift",
	"town_break": "Intermission",
	"run_end": "Intermission",
}

var placement := ""
var rewarded := false
var _left := SECONDS
var _button: Button
var _count: Label
var _bar: Control
var _finished := false


func _init(where: String, gives_reward: bool) -> void:
	placement = where
	rewarded = gives_reward


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	var curtain := ColorRect.new()
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color(0.16, 0.02, 0.06, 0.97)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	var stage := UiTheme.stage(self)
	# Curtain folds down both sides.
	var folds := Control.new()
	folds.size = UiTheme.STAGE
	folds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folds.draw.connect(func() -> void:
		for side in 2:
			for i in 6:
				var x := (i * 18.0) if side == 0 else UiTheme.STAGE.x - 18.0 - i * 18.0
				folds.draw_rect(Rect2(x, 0, 12, UiTheme.STAGE.y), Color(0.45, 0.05, 0.12, 0.35 - i * 0.04)))
	stage.add_child(folds)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.position = Vector2(150, 30)
	col.size = Vector2(340, 300)
	stage.add_child(col)
	var tag := UiTheme.label("TEST AD", 9, UiTheme.INK)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 99))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_child(tag)
	col.add_child(pill)
	var title := UiTheme.title(str(TITLES.get(placement, "Advertisement")), 24, UiTheme.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var screen := PanelContainer.new()
	screen.custom_minimum_size = Vector2(320, 120)
	screen.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.18), 14))
	var words := UiTheme.label("A real ad plays here once ads are connected. Nothing is tracked and nothing is charged in this test.", 10, UiTheme.MUTED)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen.add_child(words)
	col.add_child(screen)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(320, 6)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _bar.size)
		_bar.draw_style_box(UiTheme.box(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 99), r)
		r.size.x = maxf(r.size.y, r.size.x * (1.0 - _left / SECONDS))
		_bar.draw_style_box(UiTheme.box(UiTheme.GOLD, Color(0, 0, 0, 0), 99), r))
	col.add_child(_bar)
	_count = UiTheme.label("", 10, UiTheme.TEXT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_count)
	_button = UiTheme.button("", _close, 11, UiTheme.PANEL_LIGHT)
	_button.custom_minimum_size = Vector2(170, 28)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_button)
	_refresh()


func _process(delta: float) -> void:
	if _finished:
		return
	_left = maxf(0.0, _left - delta)
	_refresh()


func _refresh() -> void:
	var ended := _left <= 0.0
	if rewarded:
		_count.text = "Reward ready" if ended else "Reward in %d" % ceili(_left)
		_button.text = "Collect" if ended else "Close (no reward)"
		_button.disabled = false
	else:
		_count.text = "" if ended else "The show resumes in %d" % ceili(_left)
		_button.text = "Back to the show"
		_button.disabled = not ended
	_bar.queue_redraw()


func _close() -> void:
	if _finished:
		return
	_finished = true
	var completed := _left <= 0.0
	Feel.play("cash" if completed and rewarded else "click")
	done.emit(completed)
	queue_free()
