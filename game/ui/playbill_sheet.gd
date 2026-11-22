class_name PlaybillSheet
extends Sheet
## The Playbill: news and What's new, sent from the server (GET /v1/news).
## Placeholder until wave 1 fills it in (docs/ROADMAP.md).


func _init() -> void:
	title_text = "Playbill"
	panel_size = Vector2(520, 300)


func _build() -> void:
	body.add_child(words("News will appear here.", 10, UiTheme.MUTED))


## News items not read yet (for the dot on the home screen).
static func unread_count() -> int:
	return 0


## Up to three event banners for the home screen, each { id, title, text, colour, ends_at, action }.
static func banners() -> Array:
	return []
