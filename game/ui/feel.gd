extends Node







const CUES := {
	"select": [["select", "select2"], -6.0], "deselect": [["deselect", "deselect2"], -7.0],
	"deal": [["deal1", "deal2", "deal3"], -6.0], "play": [["play"], -3.0],
	"points": [["points", "points2", "points3"], -5.0], "mult": [["mult", "mult2"], -7.0],
	"xmult": [["xmult"], -3.0], "slam": [["slam"], -2.0], "jackpot": [["jackpot"], -1.0],
	"win": [["win"], -3.0], "applause": [["applause"], -7.0], "lose": [["lose"], -5.0],
	"buy": [["buy", "buy2"], -8.0], "sell": [["sell"], -8.0], "cash": [["cash"], -9.0],
	"pack": [["pack"], -5.0], "reroll": [["reroll"], -4.0], "show": [["show"], -9.0],
	"click": [["click", "click2"], -8.0], "tick": [["tick"], -12.0], "discard": [["discard"], -4.0],
	"error": [["error"], -8.0],
}
const WOBBLE := ["select", "deselect", "deal", "points", "tick", "click"]


const TRACKS := { "menu": "theme", "show": "show", "patron": "patron", "shop": "shop" }
const TRACK_VOLUME := { "theme": -13.0, "show": -21.0, "patron": -15.0, "shop": -16.0 }


const DRIVES := { "show": ["show_drive", -1.0], "patron": ["patron_drive", -4.0] }
const VOICES := 8


const MOODS := {
	"menu": [Color("100719"), Color("321449"), Color("6e2264"), Color("c0457c"), Color("3aa6ba")],
	"patron": [Color("170408"), Color("480e18"), Color("8a2027"), Color("d05a34"), Color("e0b456")],
	"shop": [Color("07140b"), Color("163f24"), Color("2f7436"), Color("80b84e"), Color("5a9ad6")],
}

const TOWN_MOODS := [
	[Color("06141f"), Color("0d3442"), Color("17595f"), Color("2f8f84"), Color("d8708f")],
	[Color("071027"), Color("132a5a"), Color("1f4c8a"), Color("3f7ad8"), Color("f0c860")],
	[Color("061a17"), Color("0f3b33"), Color("1e6b57"), Color("3fa080"), Color("f08a6a")],
	[Color("1a0e07"), Color("3d2210"), Color("6e3d1c"), Color("b0703a"), Color("7fb0d0")],
	[Color("1a0812"), Color("3d1230"), Color("6e2050"), Color("b03a6a"), Color("f0b84a")],
	[Color("0d1608"), Color("24350f"), Color("466018"), Color("8aa83a"), Color("46c2d8")],
	[Color("100a1f"), Color("2a1650"), Color("4a2a8a"), Color("8060d0"), Color("f0d860")],
	[Color("1a0610"), Color("40122a"), Color("701e48"), Color("b04a78"), Color("9ad05a")],
]

const SWIRL_SPEED := 0.12
const MAX_KICK := 2.2


const BACKDROP_SCALE := [0.2, 0.32, 0.5]

const PARTICLES := [0.4, 0.75, 1.0]


signal settings_changed


var shake_target: Control
var effects: Node
var crt_rect: ColorRect

var crt: ShaderMaterial
var _crt_light: ShaderMaterial

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

var _music: Array[AudioStreamPlayer] = []
var _track := ""
var _music_tweens: Array[Tween] = [null, null]


var _drives: Array[AudioStreamPlayer] = []
var _intensity := 0.0
var _intensity_target := 0.0


var _backdrop: ShaderMaterial
var _backdrop_view: SubViewport
var _mood := "menu"
var _colours: Array = MOODS["menu"]
var _mood_tween: Tween
var _flash_tween: Tween
var _phase := 0.0
var _kick := 0.0


func _ready() -> void:
	Settings.load_saved()

	if DisplayServer.get_name() == "headless":
		return
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
		var d := AudioStreamPlayer.new()
		d.volume_db = -80.0
		add_child(d)
		_drives.append(d)
	_switch_music(TRACKS[_mood])



func _exit_tree() -> void:
	for tween in _music_tweens:
		if tween != null:
			tween.kill()
	for p in _players + _music + _drives:
		p.stop()
		p.stream = null
	_sounds.clear()
	_backdrop = null
	crt = null
	_crt_light = null



func apply_settings() -> void:
	Engine.max_fps = Settings.fps
	if crt_rect != null:
		if crt == null:
			crt = ShaderMaterial.new()
			crt.shader = load("res://shaders/crt.gdshader")
			_crt_light = ShaderMaterial.new()
			_crt_light.shader = load("res://shaders/crt_light.gdshader")
		crt_rect.visible = Settings.crt > 0
		crt_rect.material = crt if Settings.crt == 2 else _crt_light
		crt.set_shader_parameter("curvature", 0.0 if Settings.reduce_motion else 0.03)
	if _backdrop != null:
		_backdrop.set_shader_parameter("sparkle", 0.4 if Settings.reduce_motion else 1.0)
	_resize_backdrop()
	_switch_music(_track, true)




func _process(scaled_delta: float) -> void:
	var delta := scaled_delta / maxf(Engine.time_scale, 0.01)
	_follow_drives(delta)
	if _backdrop == null or Settings.reduce_motion:
		return
	_kick = move_toward(_kick, 0.0, delta * 1.6)
	_phase += delta * (SWIRL_SPEED + _kick)
	_backdrop.set_shader_parameter("phase", _phase)




func intensity(level: float) -> void:
	_intensity_target = clampf(level, 0.0, 1.0)




func _follow_drives(delta: float) -> void:
	if _drives.is_empty():
		return
	_intensity = move_toward(_intensity, _intensity_target, delta * 0.4)
	for i in _music.size():
		var drive := _drives[i]
		if not drive.playing:
			continue
		if not _music[i].playing:
			drive.stop()
			continue
		drive.volume_db = _music[i].volume_db + float(drive.get_meta("offset", 0.0)) + linear_to_db(maxf(_intensity, 0.0005))



func kick(amount: float) -> void:
	_kick = minf(MAX_KICK, _kick + amount)



func setup_backdrop(host: Control) -> void:
	_backdrop = ShaderMaterial.new()
	_backdrop.shader = load("res://shaders/swirl.gdshader")
	_backdrop_view = SubViewport.new()
	_backdrop_view.disable_3d = true
	_backdrop_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var paint := ColorRect.new()
	paint.set_anchors_preset(Control.PRESET_FULL_RECT)
	paint.material = _backdrop
	_backdrop_view.add_child(paint)
	host.add_child(_backdrop_view)
	var shown := TextureRect.new()
	shown.texture = _backdrop_view.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(shown)
	host.move_child(shown, 0)
	get_tree().root.size_changed.connect(_resize_backdrop)
	_set_colours(_colours)
	apply_settings()


func _resize_backdrop() -> void:
	if _backdrop_view == null:
		return
	var screen := Vector2(get_tree().root.size)
	var share: float = BACKDROP_SCALE[Settings.quality]
	_backdrop_view.size = Vector2i(maxi(96, int(screen.x * share)), maxi(54, int(screen.y * share)))



func backdrop(rect: ColorRect) -> void:
	rect.color = Color.TRANSPARENT
	rect.material = null



func flash(colour: Color, strength := 0.35) -> void:
	if _backdrop == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	var peak := strength * (0.5 if Settings.reduce_motion else 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(a: float) -> void: _backdrop.set_shader_parameter("flash", Color(colour, a)), peak, 0.0, 0.5)




func mood(name: String, town := 1) -> void:
	var key := name if name != "show" else "show%d" % ((town - 1) % TOWN_MOODS.size())
	if key == _mood or not (MOODS.has(name) or name == "show"):
		return
	_mood = key
	_switch_music(TRACKS.get(name, "theme"))
	if _mood_tween != null:
		_mood_tween.kill()
	var from := _colours.duplicate()
	var to: Array = MOODS[name] if name != "show" else TOWN_MOODS[(town - 1) % TOWN_MOODS.size()]
	if Settings.reduce_motion:
		_set_colours(to)
		return
	_mood_tween = create_tween()
	_mood_tween.tween_method(func(k: float) -> void:
		var mixed := []
		for i in to.size():
			mixed.append((from[i] as Color).lerp(to[i], k))
		_set_colours(mixed), 0.0, 1.0, 0.8)


func _set_colours(colours: Array) -> void:
	_colours = colours
	if _backdrop == null:
		return
	for i in colours.size():
		_backdrop.set_shader_parameter("c%d" % i, colours[i])


func shake(strength: float) -> void:
	if Settings.reduce_motion or shake_target == null:
		return
	var t := shake_target.create_tween()
	for i in 5:
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 5.0)
		t.tween_property(shake_target, "position", offset, 0.03)
	t.tween_property(shake_target, "position", Vector2.ZERO, 0.03)


func burst(at: Vector2, colour: Color, amount := 12) -> void:
	if effects == null:
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(2, int(amount * PARTICLES[Settings.quality] * (0.5 if Settings.reduce_motion else 1.0)))
	p.lifetime = 0.45
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = colour
	effects.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)



func float_text(text: String, at: Vector2, colour: Color, size := 13) -> void:
	if effects == null:
		return
	var l := UiTheme.title(text, size, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(140, size + 10)
	l.position = at - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	effects.add_child(l)
	var t := l.create_tween().set_parallel()
	if Settings.reduce_motion:
		t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	else:
		l.scale = Vector2(0.3, 0.3)
		t.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "position:y", l.position.y - 24.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.55)
	t.chain().tween_callback(l.queue_free)



func buzz(ms: int) -> void:
	if Settings.vibration_level > 0:
		Input.vibrate_handheld(ms * Settings.vibration_level, 0.45 if Settings.vibration_level == 1 else 1.0)



func play(cue: String, pitch := 1.0) -> void:
	if not Settings.sound or not CUES.has(cue) or _players.is_empty():
		return
	var takes: Array = CUES[cue][0]
	var take: String = takes[randi() % takes.size()]
	if not _sounds.has(take):
		_sounds[take] = load("res://audio/sfx/%s.wav" % take)
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % VOICES
	p.stream = _sounds[take]
	p.volume_db = CUES[cue][1] + linear_to_db(maxf(Settings.sfx_volume, 0.001))
	p.pitch_scale = pitch * (randf_range(0.96, 1.04) if cue in WOBBLE else 1.0)
	p.play()





func _switch_music(track: String, force := false) -> void:
	if _music.is_empty() or (track == _track and not force):
		return
	_track = track
	var audible := Settings.music and Settings.music_volume > 0.0 and track != ""
	var current: AudioStreamPlayer = null
	for m in _music:
		if m.playing and str(m.get_meta("track", "")) == track and m.volume_db > -70.0:
			current = m
	if not audible:
		for m in _music:
			_fade(m, -80.0, 0.6)
		return
	var target_db: float = TRACK_VOLUME.get(track, -14.0) + linear_to_db(Settings.music_volume)
	if current == null:
		current = _music[0] if not _music[0].playing or _music[0].volume_db < _music[1].volume_db else _music[1]
		current.stream = _load_track(track)
		current.set_meta("track", track)
		current.volume_db = -60.0
		current.play()
		var drive := _drives[_music.find(current)]
		drive.stop()
		if DRIVES.has(track):
			drive.stream = _load_track(DRIVES[track][0])
			drive.set_meta("offset", DRIVES[track][1])
			drive.volume_db = -80.0
			drive.play()
	_fade(current, target_db, 1.2 if not force else 0.15)
	for m in _music:
		if m != current:
			_fade(m, -80.0, 1.2)


func _load_track(track: String) -> AudioStream:
	var stream: AudioStreamWAV = load("res://audio/music/%s.wav" % track)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _fade(player: AudioStreamPlayer, to_db: float, seconds := 1.2) -> void:
	var slot := _music.find(player)
	if _music_tweens[slot] != null:
		_music_tweens[slot].kill()
	var t := create_tween()
	t.tween_property(player, "volume_db", to_db, seconds)
	if to_db <= -79.0:
		t.tween_callback(player.stop)
	_music_tweens[slot] = t
