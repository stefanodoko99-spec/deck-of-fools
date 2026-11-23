extends "res://tests/suite.gd"


func test_decodes_a_valid_backup() -> void:
	var profile := JSON.stringify({ "runs_played": 3 })
	var text := JSON.stringify({
		"version": WebSave.VERSION,
		"saved_at": 123,
		"files": { "profile": profile },
	})
	var decoded := WebSave.decode(text)
	check(not decoded.is_empty(), "valid backup should decode")
	eq(decoded.get("files", {}).get("profile", ""), profile)


func test_rejects_unknown_or_malformed_files() -> void:
	var unknown := JSON.stringify({
		"version": WebSave.VERSION,
		"files": { "account": JSON.stringify({ "token": "secret" }) },
	})
	var malformed := JSON.stringify({
		"version": WebSave.VERSION,
		"files": { "profile": "not json" },
	})
	check(WebSave.decode(unknown).is_empty(), "backup must not accept unlisted files")
	check(WebSave.decode(malformed).is_empty(), "backup must not accept malformed JSON")


func test_core_file_validation_requires_a_json_object() -> void:
	check(WebSave.valid_json_file(JSON.stringify({ "ok": true })), "dictionary JSON is valid")
	check(not WebSave.valid_json_file("[]"), "an array is not a core save file")
	check(not WebSave.valid_json_file(""), "an empty file is invalid")
