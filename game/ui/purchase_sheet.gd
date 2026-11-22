class_name PurchaseSheet
extends Sheet
## The test store's purchase sheet (Store in "test" mode): what the product contains,
## its reference price, and a clear note that nothing is charged. The App Store sheet
## or the web checkout replaces it when the store is connected.

signal done(confirmed: bool)

var product: Dictionary
var price := ""
var _answered := false


func _init(p: Dictionary, price_label: String) -> void:
	product = p
	price = price_label
	title_text = "Test purchase"
	panel_size = Vector2(360, 210)


func _build() -> void:
	body.add_child(UiTheme.title(str(product.get("name", "")), 16, UiTheme.TEXT))
	body.add_child(words(str(product.get("text", "")), 10, UiTheme.TEXT))
	body.add_child(words("This is the test store: no money is charged. At launch the App Store (or the web checkout) takes its place.", 9, UiTheme.MUTED))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UiTheme.button("Cancel", close, 11))
	var buy := UiTheme.button("Buy for %s (test)" % price, _confirm, 11, UiTheme.GOOD.darkened(0.2))
	row.add_child(buy)
	body.add_child(row)


func _confirm() -> void:
	if _answered:
		return
	_answered = true
	done.emit(true)
	closed.emit()
	queue_free()


func close() -> void:
	if not _answered:
		_answered = true
		done.emit(false)
	super.close()
