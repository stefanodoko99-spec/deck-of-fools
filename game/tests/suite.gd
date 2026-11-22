extends RefCounted
## Base for the test suites in this folder: every file named test_*.gd extends this script
## and every method named test_* in it is a test (run by run_tests.gd, see ./test.sh).
## Assertions record a failure and carry on, so one test can report several problems.
## Script errors and push_error() calls during a test fail it too.
##
## A test that pins down a known bug calls known_bug() first. It is then expected to fail
## (reported as XFAIL, which doesn't fail the run); if it starts passing (XPASS) the run
## fails, so whoever fixed the bug turns it into a plain test.

## Command-line options from run_tests.gd: "bot_runs", "verbose", "stats_out", "only".
var options: Dictionary = {}

var failures: Array[String] = []
var notes: Array[String] = []
var checks := 0
var bug_id := ""
var bug_text := ""


func reset() -> void:
	failures.clear()
	notes.clear()
	checks = 0
	bug_id = ""
	bug_text = ""


## Marks the running test as the record of a known bug: it should fail until the bug is fixed.
func known_bug(id: String, text: String) -> void:
	bug_id = id
	bug_text = text


## A line printed under the test's result (always for failures, otherwise with --verbose).
func note(text: String) -> void:
	notes.append(text)


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func fail(message: String) -> void:
	checks += 1
	failures.append(message)


## Deep equality for dictionaries, arrays and numbers (an int equals the same float; a
## tolerance > 0 also accepts floats that differ by that fraction). Lists the first differences.
func eq(actual: Variant, expected: Variant, message := "", tolerance := 0.0) -> bool:
	checks += 1
	var out: Array[String] = []
	diff(actual, expected, "", out, tolerance)
	if out.is_empty():
		return true
	var shown := "; ".join(out.slice(0, 6))
	if out.size() > 6:
		shown += "; ... %d more" % (out.size() - 6)
	failures.append((message + ": " if message != "" else "") + shown)
	return false


## Appends "path: what differs" for every difference between a (actual) and b (expected).
static func diff(a: Variant, b: Variant, path: String, out: Array[String], tolerance := 0.0, limit := 40) -> void:
	if out.size() >= limit:
		return
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		var fa := float(a)
		var fb := float(b)
		if fa == fb:
			return
		if tolerance > 0.0 and absf(fa - fb) <= tolerance * maxf(1.0, maxf(absf(fa), absf(fb))):
			return
		out.append("%s: %s, expected %s" % [_where(path), _short(a), _short(b)])
		return
	if ta == TYPE_STRING_NAME:
		a = str(a)
		ta = TYPE_STRING
	if tb == TYPE_STRING_NAME:
		b = str(b)
		tb = TYPE_STRING
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		for k in da:
			if not db.has(k):
				out.append("%s: %s, expected no such key" % [_where(path + "." + str(k)), _short(da[k])])
			else:
				diff(da[k], db[k], path + "." + str(k), out, tolerance, limit)
		for k in db:
			if not da.has(k):
				out.append("%s: missing, expected %s" % [_where(path + "." + str(k)), _short(db[k])])
		return
	if _is_list(ta) and _is_list(tb):
		var size_a: int = a.size()
		var size_b: int = b.size()
		if size_a != size_b:
			out.append("%s: %d items, expected %d (%s vs %s)" % [_where(path), size_a, size_b, _short(a), _short(b)])
			return
		for i in size_a:
			diff(a[i], b[i], "%s[%d]" % [path, i], out, tolerance, limit)
		return
	if ta != tb:
		out.append("%s: %s (%s), expected %s (%s)" % [_where(path), _short(a), type_string(ta), _short(b), type_string(tb)])
		return
	if a != b:
		out.append("%s: %s, expected %s" % [_where(path), _short(a), _short(b)])


static func _is_list(t: int) -> bool:
	return t == TYPE_ARRAY or (t >= TYPE_PACKED_BYTE_ARRAY and t <= TYPE_PACKED_VECTOR4_ARRAY)


static func _where(path: String) -> String:
	return path if path != "" else "value"


static func _short(v: Variant) -> String:
	var text := str(v)
	return text if text.length() <= 70 else text.substr(0, 67) + "..."
