class_name WebStart
extends RefCounted
## The web page's start screen (game/web/shell.html) stays over the running game until the
## player chooses Play or Continue; then it sets window.dofStartChoice, dispatches the
## "dofstart" event and gets out of the way. This is the game's side of that hand-off, so
## Continue can open the saved run directly instead of the home. A no-op off the web.


## The start screen's state: "loading", "ready", "closed" or "error"; "" when there is no
## start screen (not the web, or a page without one).
static func screen_state() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.dofStartScreen ? window.dofStartScreen() : ''", true))


## What the player chose on the start screen: "play", "continue", or "" (not yet, or none).
static func choice() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.dofStartChoice || ''", true))


static var _callback: JavaScriptObject
static var _waiting: Array[Callable] = []


## Calls `on_choice` with "play" or "continue" once the player has chosen: straight away if
## they already have (the tap can come before the game asks), else when "dofstart" fires.
## Off the web, or with no start screen up, it never calls.
static func when_chosen(on_choice: Callable) -> void:
	var now := choice()
	if now != "":
		on_choice.call(now)
		return
	var state := screen_state()
	if state != "loading" and state != "ready":
		return
	_waiting.append(on_choice)
	if _callback == null:
		# Kept in a static so the bridge doesn't free it while the page still holds it.
		_callback = JavaScriptBridge.create_callback(_on_start)
		var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		window.addEventListener("dofstart", _callback)


static func _on_start(_args: Array) -> void:
	var chosen := choice()
	if chosen == "":
		chosen = "play"
	var calls := _waiting.duplicate()
	_waiting.clear()
	for call: Callable in calls:
		if call.is_valid():
			call.call(chosen)
