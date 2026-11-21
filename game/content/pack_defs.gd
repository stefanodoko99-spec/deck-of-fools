class_name PackDefs
extends RefCounted



const KINDS := [

	["tarocchi", 4.0, [3, 5, 5]],
	["sign", 4.0, [3, 5, 5]],
	["card", 4.0, [3, 5, 5]],
	["zanni", 1.2, [2, 4, 4]],
	["omen", 0.6, [2, 4, 4]],
]
const SIZES := [

	["small", 4, 1, 4.0],
	["big", 6, 1, 2.0],
	["grand", 8, 2, 0.5],
]


static func register() -> void:
	for kind in KINDS:
		for s in SIZES.size():
			var size: Array = SIZES[s]
			ContentDB.register(ContentDef.make("pk_%s_%s" % [kind[0], size[0]], "pack", size[1], 0, {}, {
				"contents": kind[0],
				"size": size[0],
				"show": kind[2][s],
				"pick": size[2],
				"weight": kind[1] * size[3],
			}))
