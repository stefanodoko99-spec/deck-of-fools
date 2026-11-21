class_name UiSwitch
extends Button
## An iOS-style on/off switch: a pill track that turns green, with a white knob
## that slides across.

const ON := Color("34c759")
const OFF := Color(1, 1, 1, 0.18)

var _t := 0.0


func _init(on := false) -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_NONE
	button_pressed = on
	_t = 1.0 if on else 0.0
	custom_minimum_size = Vector2(36, 21)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggled.connect(func(now: bool) -> void:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(v: float) -> void:
			_t = v
			queue_redraw(), _t, 1.0 if now else 0.0, 0.0 if Settings.reduce_motion else 0.22))


func _draw() -> void:
	var track := Rect2(Vector2.ZERO, custom_minimum_size)
	track.position.y = (size.y - track.size.y) / 2.0
	var radius := track.size.y / 2.0
	draw_style_box(_pill(OFF.lerp(ON, _t)), track)
	var knob := track.position + Vector2(radius + (track.size.x - radius * 2.0) * _t, radius)
	draw_circle(knob + Vector2(0, 1.2), radius - 1.6, Color(0, 0, 0, 0.25), true, -1.0, true)
	draw_circle(knob, radius - 2.0, Color.WHITE, true, -1.0, true)


static func _pill(colour: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	s.set_corner_radius_all(99)
	s.anti_aliasing = true
	return s
