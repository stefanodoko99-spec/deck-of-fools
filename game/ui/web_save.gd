class_name WebSave
extends RefCounted
## A small, synchronous safety copy of the important user:// files for web builds.
##
## Godot's primary web save lives in IndexedDB. Mobile Safari can suspend a Home
## Screen app before its filesystem sync finishes, so the same JSON is mirrored in
## localStorage after every save. On the next launch this class only restores files
## that are missing or contain invalid JSON; a healthy IndexedDB save always wins.


const STORAGE_KEY := "dof-save-backup-v1"
const VERSION := 1
const MAX_FILE_CHARS := 2 * 1024 * 1024
const FILES := {
	"profile": "user://profile.json",
	"run": "user://run.json",
	"run_meta": "user://run_meta.json",
	"settings": "user://settings.json",
}


## Restore any missing/corrupt core files before Game and Settings load them.
## Returns the number of files recovered (useful for diagnostics and tests).
static func restore_missing() -> int:
	if not OS.has_feature("web"):
		return 0
	var value: Variant = JavaScriptBridge.eval(
		"(function () { try { return localStorage.getItem('%s') || ''; } catch (e) { return ''; } })()" % STORAGE_KEY,
		true
	)
	var payload := decode(str(value) if value != null else "")
	if payload.is_empty():
		return 0
	var recovered := 0
	var saved_files: Dictionary = payload["files"]
	for key: String in FILES:
		var path: String = FILES[key]
		if _valid_file(path):
			continue
		var text := str(saved_files.get(key, ""))
		if not valid_json_file(text):
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_string(text)
		file.flush()
		file.close()
		recovered += 1
	return recovered


## Replace the safety copy with the current complete state. Missing files are left
## out deliberately, so a completed run is not resurrected on a later recovery.
static func backup() -> void:
	if not OS.has_feature("web"):
		return
	var saved_files := {}
	for key: String in FILES:
		var path: String = FILES[key]
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if valid_json_file(text):
			saved_files[key] = text
	if saved_files.is_empty():
		return
	var payload := JSON.stringify({
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"files": saved_files,
	})
	var literal := JSON.stringify(payload)
	JavaScriptBridge.eval(
		"try { localStorage.setItem('%s', %s) } catch (e) {}" % [STORAGE_KEY, literal],
		true
	)


## Parse and validate a backup without touching browser storage.
static func decode(text: String) -> Dictionary:
	if text.is_empty() or text.length() > MAX_FILE_CHARS * FILES.size():
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var value: Variant = parser.data
	if not value is Dictionary:
		return {}
	var payload: Dictionary = value
	if int(payload.get("version", 0)) != VERSION or not payload.get("files") is Dictionary:
		return {}
	var files: Dictionary = payload["files"]
	for key: Variant in files:
		if not FILES.has(str(key)) or not valid_json_file(str(files[key])):
			return {}
	return payload


static func valid_json_file(text: String) -> bool:
	if text.is_empty() or text.length() > MAX_FILE_CHARS:
		return false
	var parser := JSON.new()
	return parser.parse(text) == OK and parser.data is Dictionary


static func _valid_file(path: String) -> bool:
	return FileAccess.file_exists(path) and valid_json_file(FileAccess.get_file_as_string(path))
