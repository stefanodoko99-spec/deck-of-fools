class_name ContentDef
extends RefCounted
















































var id := ""
var kind := ""
var cost := 0
var rarity := 0
var data: Dictionary = {}
var hooks: Dictionary = {}


static func make(def_id: String, def_kind: String, def_cost := 0, def_rarity := 0,
		def_hooks := {}, def_data := {}) -> ContentDef:
	var d := ContentDef.new()
	d.id = def_id
	d.kind = def_kind
	d.cost = def_cost
	d.rarity = def_rarity
	d.hooks = def_hooks
	d.data = def_data
	return d


func has_hook(hook: String) -> bool:
	return hooks.has(hook)


func fire(hook: String, args: Array) -> Variant:
	var cb: Variant = hooks.get(hook)
	if cb is Callable and (cb as Callable).is_valid():
		return (cb as Callable).callv(args)
	return null
