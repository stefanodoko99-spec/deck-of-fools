class_name InboxSheet
extends Sheet
## The inbox: letters from the server with something to claim (coins, a message).
## Placeholder until wave 1 fills it in (docs/ROADMAP.md).


func _init() -> void:
	title_text = "Inbox"
	panel_size = Vector2(520, 300)


func _build() -> void:
	body.add_child(words("No letters yet.", 10, UiTheme.MUTED))


## Letters with something still to claim (for the badge on the home screen).
static func unclaimed_count() -> int:
	return 0
