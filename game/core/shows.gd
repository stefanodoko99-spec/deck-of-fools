class_name Shows
extends RefCounted



const MATINEE := 0
const EVENING := 1
const PATRON := 2
const FINAL_TOWN := 8

const SIZE := [1.0, 1.5, 2.0]


const TARGETS := [
	[300, 800, 2000, 5000, 11000, 20000, 35000, 50000],
	[300, 900, 2600, 8000, 20000, 36000, 60000, 100000],
	[300, 1000, 3200, 9000, 25000, 60000, 110000, 200000],
]


static func base_target(town: int, scaling: int) -> float:
	var row: Array = TARGETS[clampi(scaling, 1, TARGETS.size()) - 1]
	if town <= FINAL_TOWN:
		return float(row[maxi(town, 1) - 1])

	var extra := town - FINAL_TOWN
	return floorf(float(row[FINAL_TOWN - 1]) * pow(2.0, extra) * (1.0 + 0.15 * extra * extra))
