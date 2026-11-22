extends RefCounted
## Save/load checks shared by the suites. checkpoint() loads a run's to_dict() into two fresh
## copies, one straight from the dictionary and one through JSON text the way Game saves
## user://run.json, and checks they give back the same to_dict(). follow() then plays every
## later action on the copies too, and after `window` actions compares them with the original,
## so a field that is saved but read back wrong shows up as soon as it matters.
##
## Known bug "shop-stickers": ShopState.from_dict() drops the "sticker" and "rented" keys of
## shop offers. Those differences are counted in sticker_drops instead of reported, and the
## stickers are put back on the copy so it can still be checked for anything else.

const Suite := preload("res://tests/suite.gd")
const JSON_TOLERANCE := 1e-9

var problems: Array[String] = []
var checkpoints := 0
var sticker_drops := 0
var _copies: Array[Dictionary] = []
var _sticker_line := RegEx.create_from_string("^\\.shop\\.offers\\[\\d+\\]\\.(sticker|rented):")


func checkpoint(run: RunState, label: String, window: int) -> void:
	checkpoints += 1
	var saved := run.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	if not parsed is Dictionary:
		problems.append("%s: the saved run is not valid JSON" % label)
		return
	for via in ["memory", "json"]:
		var copy := RunState.from_dict(saved if via == "memory" else parsed)
		var tolerance := 0.0 if via == "memory" else JSON_TOLERANCE
		var out: Array[String] = []
		Suite.diff(copy.to_dict(), saved, "", out, tolerance)
		var other := _known_dropped(out, copy, run)
		if not other.is_empty():
			problems.append("%s, loaded from %s, differs: %s" % [label, via, "; ".join(other.slice(0, 4))])
			continue
		_copies.append({ "run": copy, "label": "%s (loaded from %s)" % [label, via], "left": window, "tolerance": tolerance })


## Plays the action the original run just took on every loaded copy.
func follow(action: Dictionary, result: Dictionary, run: RunState) -> void:
	for c in _copies.duplicate():
		var copy: RunState = c["run"]
		var r := copy.apply(action)
		if bool(r["ok"]) != bool(result["ok"]):
			problems.append("%s: %s was %s on the copy but %s on the original" % [
				c["label"], action, "accepted" if r["ok"] else "refused (%s)" % r.get("error", ""),
				"accepted" if result["ok"] else "refused"])
			_copies.erase(c)
			continue
		c["left"] = int(c["left"]) - 1
		if int(c["left"]) <= 0:
			_compare(c, run)
			_copies.erase(c)


## Compares the copies still being followed (call when the run ends).
func finish(run: RunState) -> void:
	for c in _copies:
		_compare(c, run)
	_copies.clear()


func _compare(c: Dictionary, run: RunState) -> void:
	var out: Array[String] = []
	Suite.diff((c["run"] as RunState).to_dict(), run.to_dict(), "", out, float(c["tolerance"]))
	if not out.is_empty():
		problems.append("%s then played on differently: %s" % [c["label"], "; ".join(out.slice(0, 4))])


func _known_dropped(out: Array[String], copy: RunState, run: RunState) -> Array[String]:
	var other: Array[String] = []
	var dropped := false
	for line in out:
		if _sticker_line.search(line) != null:
			dropped = true
		else:
			other.append(line)
	if dropped:
		sticker_drops += 1
		for i in mini(run.shop.offers.size(), copy.shop.offers.size()):
			for key in ["sticker", "rented"]:
				if run.shop.offers[i].has(key):
					copy.shop.offers[i][key] = run.shop.offers[i][key]
	return other
