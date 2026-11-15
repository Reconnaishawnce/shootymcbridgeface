extends TestCase


func test_payload_and_text() -> void:
	var events := []
	for i in range(300):
		events.append(Report.line(float(i), "running", "event number %d with some padding text" % i, {"i": i}))
	var p := Telemetry.payload({"kind": "freeze", "version": "0.43.1", "device": "Pixel", "events": events, "note": "x".repeat(2000), "previous": {"clean": false, "events": events}})
	check_eq(p.kind, "freeze", "kind kept")
	check_eq(p.events.size(), Telemetry.EVENTS_KEPT, "events trimmed to the ring")
	check_eq((p.previous as Dictionary).events.size(), Telemetry.PREVIOUS_EVENTS_KEPT, "the previous session keeps a dozen")
	check_eq(str(p.note).length(), 600, "the note is cut")
	check_eq(p.install, "", "unknown keys default")
	check_eq(Telemetry.payload({"kind": "nonsense"}).kind, "manual", "an unknown kind is manual")
	var t := Telemetry.text(p)
	check(t.begins_with("{") and JSON.parse_string(t) is Dictionary, "text is JSON")
	var small := Telemetry.text(p, 2000)
	check(small.to_utf8_buffer().size() <= 2000, "trimmed under the limit (%d)" % small.to_utf8_buffer().size())
	var parsed: Dictionary = JSON.parse_string(small)
	check_eq(parsed.kind, "freeze", "the kind survives the cut")
	check_eq(parsed.device, "Pixel", "and the device")


func test_signature_and_rules() -> void:
	var b := Telemetry.body("{\"kind\":\"crash\"}", "secret")
	check_eq(b.text, "{\"kind\":\"crash\"}", "the text goes as is")
	check_eq(b.sig, Leaderboard.hmac_hex("secret", "report|{\"kind\":\"crash\"}"), "signed over report| and the text")
	check_eq(Telemetry.url("https://x.workers.dev/"), "https://x.workers.dev/report", "the route")
	check(not Telemetry.allowed(true, false, "crash", 0, 0), "an unconfigured build sends nothing")
	check(Telemetry.allowed(false, true, "manual", 99, 99), "the player's own report always goes")
	check(not Telemetry.allowed(false, true, "crash", 0, 0), "the toggle stops automatic ones")
	check(Telemetry.allowed(true, true, "freeze", 0, 0) and not Telemetry.allowed(true, true, "freeze", 0, 1), "one freeze a run")
	check(Telemetry.allowed(true, true, "slow", 0, 0) and not Telemetry.allowed(true, true, "slow", 0, 1), "one slowdown a run")
	check(not Telemetry.allowed(true, true, "crash", Telemetry.PER_SESSION, 0), "a session cap")
	check_eq(Telemetry.crash_marker({}), "", "no previous session, no marker")
	check_eq(Telemetry.crash_marker({"version": "0.43.1", "last": 1700000000}), "0.43.1@1700000000", "the marker names the session")
	check(Telemetry.summary({"kind": "crash", "version": "1", "device": "P", "state": "running", "crumb": "end_run"}).contains("running/end_run"), "summary line")


func test_trace() -> void:
	var tr := []
	for i in range(Telemetry.TRACE_KEPT + 20):
		tr = Telemetry.push_trace(tr, Telemetry.trace_sample(float(i) * 0.5, 16.7, 8.0, 1.0, {"nodes": 1000 + i}, {"zombies": i}, "running"))
	check_eq(tr.size(), Telemetry.TRACE_KEPT, "the trace is a ring")
	check_eq(int(tr[-1].zombies), Telemetry.TRACE_KEPT + 19, "newest last")
	check(tr[0].has("proc") and tr[0].has("ms") and tr[0].has("nodes"), "a sample splits the frame and counts the scene")
	var p := Telemetry.payload({"kind": "slow", "trace": tr})
	var small := Telemetry.text(p, 1500)
	var parsed: Dictionary = JSON.parse_string(small)
	check(small.to_utf8_buffer().size() <= 1500 and (parsed.trace as Array).size() < tr.size(), "a tight limit cuts the trace from the front")


func test_frame_buckets() -> void:
	check_eq(Telemetry.hist_bucket(10.0), 0, "a good frame")
	check_eq(Telemetry.hist_bucket(40.0), 2, "a dropped frame")
	check_eq(Telemetry.hist_bucket(500.0), 4, "a stall")
	var worst := []
	for ms in [20.0, 300.0, 50.0, 80.0, 900.0, 60.0, 70.0]:
		worst = Telemetry.note_worst(worst, {"ms": ms})
	check_eq(worst.size(), 5, "five kept")
	check_eq(float(worst[0].ms), 900.0, "worst first")
	check_eq(float(worst[4].ms), 60.0, "the smallest kept is the fifth worst")
