class_name WebStatus
extends RefCounted
## A one-line note for the web page's start screen (game/web/shell.html), saved in the
## browser's localStorage under "dof-status" so the page can offer "Continue the tour"
## before the engine has even loaded. Web builds only; a no-op elsewhere.


static func publish(run: RunState) -> void:
	if not OS.has_feature("web"):
		return
	var status := {}
	if run != null and run.phase != RunState.Phase.LOST:
		var show_name := str(RunScreen.SHOW_NAMES[clampi(run.show_index, 0, 2)])
		status["continue"] = "Town %d, %s" % [run.town, show_name]
	status["found"] = Game.profile.jesters_found()
	var text := JSON.stringify(JSON.stringify(status))
	JavaScriptBridge.eval("try { localStorage.setItem('dof-status', %s) } catch (e) {}" % text, true)
