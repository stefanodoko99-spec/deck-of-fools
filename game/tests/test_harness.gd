extends "res://tests/suite.gd"
## The test harness itself: the deep comparison the save/load checks rely on, and the
## promise that tests run with Online inert and pointed away from the real server.

const Suite := preload("res://tests/suite.gd")


func differences(a: Variant, b: Variant, tolerance := 0.0) -> Array[String]:
	var out: Array[String] = []
	Suite.diff(a, b, "", out, tolerance)
	return out


func test_diff_finds_what_differs() -> void:
	eq(differences({ "a": 1, "b": [1, "x"] }, { "a": 1.0, "b": [1, "x"] }), [] as Array[String], "an int equals the same float")
	eq(differences({ "a": [1, 2] }, { "a": [1, 3] }), [".a[1]: 2, expected 3"] as Array[String], "array item")
	eq(differences({ "a": 1 }, { "b": 1 }).size(), 2, "a key missing on each side")
	eq(differences([1, 2], [1, 2, 3]).size(), 1, "different lengths")
	eq(differences("1", 1).size(), 1, "a string is not a number")
	eq(differences(1.0, 1.0 + 1e-12, 1e-9), [] as Array[String], "within tolerance")
	eq(differences(1.0, 1.001, 1e-9).size(), 1, "outside tolerance")
	eq(differences(&"name", "name"), [] as Array[String], "StringName equals String")


func test_failed_checks_are_recorded() -> void:
	var inner := Suite.new()
	check(not inner.eq(1, 2, "sum"), "eq() returns false on a difference")
	check(inner.check(true, "fine"), "check() returns its condition")
	inner.fail("by hand")
	eq(inner.failures.size(), 2, "failures recorded")
	eq(inner.checks, 3, "checks counted")


func test_online_is_inert_and_offline() -> void:
	check(Online.inert, "Online is inert in a headless run")
	check(not Online.signed_in(), "no account is loaded in tests")
	check(Online.api_url.begins_with("http://127.0.0.1"), "Online points at this machine, not %s" % Online.api_url)
