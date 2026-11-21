extends RefCounted
## Development gallery. Exported only by the "Web Preview" preset (custom feature
## "preview"), never by the release preset. Pick a screen with the page URL:
##   ?screen=cards              every playing card, enhancement and edition, plus the backs
##   ?screen=jesters&page=1     the Jesters, a page at a time
##   ?screen=items              Tarocchi, Signs, Omens, Warrants, Patrons, Favors, packs
##   ?screen=big                a few faces at large size, to judge detail
##   ?screen=menu | run         the real screens
##   ?screen=sky                the backdrop alone
## Add &mood=patron|shop|menu|show&town=3 to set the backdrop, and
## &energy=0..1 &confetti=0..1 &pulse=1 &gloom=1 to see how it reacts to play.

const PAGE_SIZE := 40


static func requested_screen() -> Dictionary:
	var query := ""
	if OS.has_feature("web"):
		query = str(JavaScriptBridge.eval("window.location.search", true))
	var out := { "screen": "cards", "page": "1", "mood": "menu", "town": "1" }
	for pair in query.trim_prefix("?").split("&", false):
		var kv := pair.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1].uri_decode()
	return out


static func open(main: Control, request: Dictionary) -> void:
	var screen := str(request["screen"])
	Feel.mood(str(request["mood"]), int(request["town"]))
	Feel.intensity(float(request.get("energy", "0")))
	Feel.danger(request.get("pulse", "0") == "1")
	Feel.gloom(request.get("gloom", "0") == "1")
	var burst := float(request.get("confetti", "0"))
	if burst > 0.0:
		var again := Timer.new()
		again.wait_time = 0.4
		again.autostart = true
		again.timeout.connect(Feel.celebrate.bind(burst))
		main.add_child(again)
	match screen:
		"menu":
			return
		"sky":
			main.call("_clear")
			return
		"run":
			Game.new_run("d_bergamo", 1, "", "PREVIEW")
			main.call("_show_run")
			return
	main.call("_clear")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_child(host)
	var stage := UiTheme.stage(host)
	var title := UiTheme.title("Gallery: %s" % screen, 12, UiTheme.GOLD)
	title.position = Vector2(8, 2)
	stage.add_child(title)
	var views: Array[CardView] = []
	match screen:
		"cards":
			var id := 0
			for suit in 4:
				for rank in range(2, 15):
					views.append(_playing(id, rank, suit, "", ""))
					id += 1
			for enh in ContentDB.pool("enhancement"):
				views.append(_playing(id, 12, id % 4, enh.id, ""))
				id += 1
			for ed in ["ed_silvered", "ed_opaline", "ed_prismatic", "ed_shadow"]:
				views.append(_playing(id, 14, id % 4, "", ed))
				id += 1
			for back in Settings.CARD_BACKS.size():
				var v := CardView.new(Vector2(52, 72))
				v.face_down = true
				v.back_style = back
				views.append(v)
		"jesters":
			for d in ContentDB.pool("zanni"):
				views.append(_item("zanni", d.id))
		"items":
			for kind in ["tarocchi", "sign", "omen", "warrant", "patron", "favor", "pack"]:
				var defs := ContentDB.pool(kind)
				for i in mini(8, defs.size()):
					views.append(_item(kind, defs[i].id))
		"big":
			var big := Vector2(110, 154)
			for rank in [11, 12, 13, 14]:
				views.append(_playing(rank, rank, rank % 4, "", "", big))
			var jesters := ContentDB.pool("zanni")
			for i in [0, 7, 21, 40, 63]:
				if i < jesters.size():
					views.append(_item("zanni", jesters[i].id, big))
	if views.size() > PAGE_SIZE and screen != "big":
		var page := clampi(int(request["page"]), 1, ceili(views.size() / float(PAGE_SIZE)))
		title.text = "Gallery: %s, page %d of %d" % [screen, page, ceili(views.size() / float(PAGE_SIZE))]
		views = views.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
	var x := 8.0
	var y := 22.0
	var row_h := 0.0
	for v in views:
		if x + v.size.x > 632.0:
			x = 8.0
			y += row_h + 6.0
			row_h = 0.0
		v.position = Vector2(x, y)
		stage.add_child(v)
		x += v.size.x + 6.0
		row_h = maxf(row_h, v.size.y)


static func _playing(id: int, rank: int, suit: int, enhancement: String, edition: String, view_size := Vector2(52, 72)) -> CardView:
	var card := PlayingCard.make(id, rank, suit)
	card.enhancement = enhancement
	card.edition = edition
	var v := CardView.new(view_size)
	v.kind = "card"
	v.card = card
	v.edition = edition
	return v


static func _item(kind: String, def_id: String, view_size := Vector2(52, 72)) -> CardView:
	var v := CardView.new(view_size)
	v.kind = kind
	v.def_id = def_id
	return v
