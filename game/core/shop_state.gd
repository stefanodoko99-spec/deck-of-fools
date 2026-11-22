class_name ShopState
extends RefCounted





var offers: Array[Dictionary] = []
var packs: Array[Dictionary] = []
var rerolls := 0
var reroll_cost := 5
var extra_warrant := ""
var extra_bought := false


func to_dict() -> Dictionary:
	return {
		"offers": offers.duplicate(true), "packs": packs.duplicate(true),
		"rerolls": rerolls, "reroll_cost": reroll_cost,
		"extra_warrant": extra_warrant, "extra_bought": extra_bought,
	}


static func from_dict(d: Dictionary) -> ShopState:
	var shop := ShopState.new()
	for o in d["offers"]:
		var offer := {
			"kind": str(o["kind"]), "id": str(o["id"]), "cost": int(o["cost"]),
			"edition": str(o["edition"]), "sold": bool(o["sold"]),
		}
		if o.has("card"):
			offer["card"] = (o["card"] as Dictionary).duplicate()
		if o.has("free"):
			offer["free"] = bool(o["free"])
		# Stake stickers (Eternal, Perishable, Rented) must survive a save and load.
		if o.has("sticker"):
			offer["sticker"] = str(o["sticker"])
		if o.has("rented"):
			offer["rented"] = bool(o["rented"])
		shop.offers.append(offer)
	for p in d.get("packs", []):
		var pack := { "id": str(p["id"]), "cost": int(p["cost"]), "sold": bool(p["sold"]) }
		if p.has("free"):
			pack["free"] = bool(p["free"])
		shop.packs.append(pack)
	shop.rerolls = int(d["rerolls"])
	shop.reroll_cost = int(d["reroll_cost"])
	shop.extra_warrant = str(d.get("extra_warrant", ""))
	shop.extra_bought = bool(d.get("extra_bought", false))
	return shop
