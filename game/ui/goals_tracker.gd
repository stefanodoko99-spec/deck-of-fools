extends Node
## Daily goals (autoload "Goals"): three daily goals and one weekly one, paid in coins,
## counted from Game.run_event. Placeholder until wave 1 fills it in (docs/ROADMAP.md).
## The home screen calls these:


## Today's goals and this week's goal, each { id, text, progress, target, coins, done, claimed }.
func current() -> Array:
	return []


## Goals finished but not yet claimed (for a badge on the home screen).
func ready_count() -> int:
	return 0


## Claim a finished goal; returns the coins paid (0 if it can't be claimed).
func claim(_id: String) -> int:
	return 0


## Open the goals sheet (the home screen's goals ring calls this).
func open() -> void:
	pass
