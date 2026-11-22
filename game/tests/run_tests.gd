extends Node
## Headless test runner (the scene run_tests.tscn). Use ./test.sh, or directly:
##   godot --headless --path game res://tests/run_tests.tscn -- [options]
## Options after "--":
##   --only=<text>       run only the suites or tests whose name contains <text>
##   --bot-runs=<n>      complete runs the play bot plays (default 48; test_bot.gd)
##   --stats-out=<path>  also write the bot's numbers as JSON to this file
##   --verbose           list every test, its notes and every bot run
##   --api=<url>         read by the Online autoload; ./test.sh points it at a closed local port
## Every file named test_*.gd here is a suite (see suite.gd). The exit code is 0 only when
## every test passed; known bugs (XFAIL) don't fail the run, a fixed known bug (XPASS) does.
##
## The autoloads run as in the game: Game registers the content, Feel and CardArt stay idle,
## and Online is inert because the display is headless (the runner refuses to run if not).
## Tests never call Game's save functions, so the player's user:// files are only read.

const SUITE_DIR := "res://tests"
## Where Online's API address points during the tests: a closed port on this machine.
const NO_NETWORK := "http://127.0.0.1:9"


## Collects every error and script error logged while a test runs.
class ErrorLog extends Logger:
	var _mutex := Mutex.new()
	var _entries: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var text := rationale if rationale != "" else code
		# Point at the GDScript line that raised it rather than the engine's C++ source.
		for trace in script_backtraces:
			if trace != null and trace.get_frame_count() > 0:
				file = trace.get_frame_file(0)
				line = trace.get_frame_line(0)
				function = trace.get_frame_function(0)
				break
		_mutex.lock()
		_entries.append("%s (%s:%d %s)" % [text, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var out: Array[String] = _entries.duplicate()
		_entries.clear()
		_mutex.unlock()
		return out


var options := { "only": "", "bot_runs": 48, "stats_out": "", "verbose": false }
var _log := ErrorLog.new()


func _ready() -> void:
	OS.add_logger(_log)
	var result: Variant = _run()
	OS.remove_logger(_log)
	get_tree().quit(result if result is int else 1)


func _run() -> int:
	_read_options()
	var started := Time.get_ticks_msec()
	print("Deck of Fools tests - Godot %s, display '%s'" % [Engine.get_version_info()["string"], DisplayServer.get_name()])
	if not Online.inert:
		print("TESTS FAILED: the Online autoload is live (not headless, or --online given); refusing to run")
		return 1
	Online.api_url = NO_NETWORK
	var requests_before := _http_requests()
	if ContentDB.pool("zanni").is_empty():
		print("TESTS FAILED: no content registered (the Game autoload did not run)")
		return 1
	_log.take()

	var totals := { "pass": 0, "fail": 0, "xfail": 0, "xpass": 0, "checks": 0, "tests": 0 }
	var problems: Array[String] = []
	for path in _suites():
		_run_suite(path, totals, problems)

	if _http_requests() > requests_before:
		totals["fail"] += 1
		problems.append("FAIL network guard: a test started an HTTP request through Online")
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("")
	for line in problems:
		print(line)
	var summary := "%d passed, %d failed, %d known bugs (xfail), %d fixed known bugs (xpass); %d tests, %d checks, %.1f s" % [
		totals["pass"], totals["fail"], totals["xfail"], totals["xpass"], totals["tests"], totals["checks"], seconds]
	if totals["tests"] == 0:
		print("TESTS FAILED: no tests matched")
		return 1
	if totals["fail"] > 0 or totals["xpass"] > 0:
		print("TESTS FAILED: " + summary)
		return 1
	print("TESTS PASSED: " + summary)
	return 0


func _read_options() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			options["only"] = arg.get_slice("=", 1)
		elif arg.begins_with("--bot-runs="):
			options["bot_runs"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--stats-out="):
			options["stats_out"] = arg.substr(arg.find("=") + 1)
		elif arg == "--verbose" or arg == "-v":
			options["verbose"] = true


func _suites() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(SUITE_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(SUITE_DIR.path_join(file))
	out.sort()
	return out


func _run_suite(path: String, totals: Dictionary, problems: Array[String]) -> void:
	var suite_name := path.get_file().get_basename().trim_prefix("test_")
	var script: Variant = load(path)
	var load_errors := _log.take()
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		totals["fail"] += 1
		totals["tests"] += 1
		problems.append("FAIL %s: the suite does not load. %s" % [suite_name, " | ".join(load_errors)])
		print("  %-16s does not load" % suite_name)
		return
	var tests: Array[String] = []
	for m in (script as GDScript).get_script_method_list():
		var method: String = m["name"]
		if method.begins_with("test_") and not tests.has(method):
			if options["only"] == "" or suite_name.contains(options["only"]) or method.contains(options["only"]):
				tests.append(method)
	if tests.is_empty():
		return
	var suite: Object = (script as GDScript).new()
	suite.set("options", options)
	var counts := { "pass": 0, "fail": 0, "xfail": 0, "xpass": 0 }
	var started := Time.get_ticks_msec()
	for test in tests:
		suite.call("reset")
		_log.take()
		var t0 := Time.get_ticks_msec()
		suite.call(test)
		var ms := Time.get_ticks_msec() - t0
		var failures: Array[String] = []
		failures.assign(suite.get("failures"))
		for e in _log.take():
			failures.append("error logged: " + e)
		var notes: Array = suite.get("notes")
		var bug := str(suite.get("bug_id"))
		totals["checks"] += int(suite.get("checks"))
		totals["tests"] += 1
		var verdict := "pass"
		if bug != "":
			verdict = "xfail" if not failures.is_empty() else "xpass"
		elif not failures.is_empty():
			verdict = "fail"
		counts[verdict] += 1
		totals[verdict] += 1
		var label := "%s::%s" % [suite_name, test]
		match verdict:
			"fail":
				problems.append("FAIL %s (%d ms)" % [label, ms])
				for f in failures:
					problems.append("    - " + f)
				for n in notes:
					problems.append("      " + str(n))
			"xfail":
				problems.append("XFAIL %s [known bug %s] %s" % [label, bug, str(suite.get("bug_text"))])
				for f in failures.slice(0, 3):
					problems.append("    - " + f)
				if options["verbose"]:
					for n in notes:
						problems.append("      " + str(n))
			"xpass":
				problems.append("XPASS %s: known bug '%s' no longer shows up; drop the known_bug() call" % [label, bug])
		if options["verbose"]:
			print("    %-5s %s (%d ms)" % [verdict, label, ms])
			if verdict == "pass":
				for n in notes:
					print("          " + str(n))
	var parts: Array[String] = ["%d passed" % counts["pass"]]
	for key in ["fail", "xfail", "xpass"]:
		if counts[key] > 0:
			parts.append("%d %s" % [counts[key], key])
	print("  %-16s %s (%.1f s)" % [suite_name, ", ".join(parts), (Time.get_ticks_msec() - started) / 1000.0])


func _http_requests() -> int:
	var count := 0
	for child in Online.get_children():
		if child is HTTPRequest:
			count += 1
	return count
