extends TestCase


func test_log_lines_and_trim() -> void:
	var l := Report.line(12.5, "running", "bite", {"left": 3})
	check(l.contains("running") and l.contains("bite") and l.contains("\"left\":3"), "a line names the state, the event and the data")
	var lines := []
	for i in range(Report.LOG_LINES + 50):
		lines.append(str(i))
	var t := Report.trim(lines)
	check_eq(t.size(), Report.LOG_LINES, "the ring keeps the limit")
	check_eq(t[-1], str(Report.LOG_LINES + 49), "and the newest line")


func test_stalls_and_verdicts() -> void:
	check(not Report.is_stall(0.03) and Report.is_stall(0.8), "half a second is a stall")
	check_eq(Report.verdict({}), "none", "no previous session")
	check_eq(Report.verdict({"clean": true}), "clean", "clean exit")
	check(Report.verdict({"clean": false, "state": "game_over", "crumb": "end_run:stats"}).contains("end_run:stats"), "a death names the crumb")
	check(Report.bad_exit({"clean": false}) and not Report.bad_exit({"clean": true}) and not Report.bad_exit({}), "bad exit only when it was not clean")


func test_error_lines() -> void:
	var text := "Godot Engine v4.4\nfine\nSCRIPT ERROR: Invalid call\n   at: _process (res://scripts/game.gd:10)\nERROR: Condition failed\nmore\n"
	var out := Report.error_lines(text)
	check_eq(out.size(), 3, "errors and their locations")
	check(out[0].begins_with("SCRIPT ERROR"), "script errors first")
	var many := ""
	for i in range(100):
		many += "ERROR: %d\n" % i
	check_eq(Report.error_lines(many, 10).size(), 10, "capped at the newest")
	check_eq(Report.error_lines(many, 10)[-1], "ERROR: 99", "newest last")


func test_build_and_mailto() -> void:
	var ctx := {
		"version": "0.29.1", "device": "Pixel 10 Pro (Android)", "os": "15", "gpu": "PowerVR / Imagination",
		"previous": {"clean": false, "state": "game_over", "crumb": "end_run:save", "version": "0.29.0", "ran": 120, "age": 3, "events": ["a", "b"]},
		"stalls": [{"t": 1.0, "seconds": 2.5, "state": "game_over", "crumb": "show_game_over"}],
		"events": ["  1.00  title     boot"], "previous_errors": ["SCRIPT ERROR: x"], "current_errors": [],
		"save": {"runs": 12, "coins": 300}, "note": "It froze after I died.",
	}
	var r := Report.build(ctx)
	for word in ["0.29.1", "Pixel 10 Pro", "PowerVR", "end_run:save", "show_game_over", "SCRIPT ERROR: x", "runs: 12", "It froze after I died.", "ENGINE ERRORS, THIS SESSION: 0"]:
		check(r.contains(word), "report mentions %s" % word)
	var m := Report.mailto("Bug", r)
	check(m.begins_with("mailto:" + Report.BUG_EMAIL + "?subject=Bug&body="), "a mailto link to the bug address")
	check(not m.contains("\n") and not m.contains(" "), "encoded")
	var long := ""
	for i in range(2000):
		long += "line %d\n" % i
	var cut := Report.mailto("Bug", long, 500)
	check(cut.length() < 1200, "a long body is cut")
	check(cut.contains("line%201999".replace("%20", "%20")) or cut.contains("1999"), "the newest lines survive the cut")
	check(cut.contains("clipboard".uri_encode()), "and the cut is said")
