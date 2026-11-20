extends TestCase


func _row(t: float, ms: float = 16.7, mx: float = 20.0) -> Array:
	return Flight.row(t, ms, mx, 60, 8.0, 1.0, {"nodes": 2000, "draw": 300, "prims": 40000, "vram": 80}, 900, {"zombies": 30, "squad": 40, "level": 2, "fx": 3}, "running", "gate:4")


func test_rows() -> void:
	var r := _row(12.34)
	check_eq(r.size(), Flight.COLS.size(), "a row has a value for every column")
	check_near(float(Flight.value(r, "t")), 12.3, 0.0001, "time, to a tenth")
	check_eq(int(Flight.value(r, "zombies")), 30, "the game's gauges ride along")
	check_eq(str(Flight.value(r, "crumb")), "gate:4", "and where the game was")
	check_eq(Flight.value(r, "nonsense"), null, "an unknown column is nothing")
	check(not Flight.is_trouble(r), "a smooth second is no trouble")
	check(Flight.is_trouble(_row(1.0, 16.0, 900.0)), "a second with a long frame is")
	check(Flight.is_trouble(_row(1.0, 60.0, 70.0)), "a slow second is")
	var long := Flight.row(1.0, 1.0, 1.0, 1, 1.0, 1.0, {}, 1, {}, "s", "x".repeat(100))
	check(str(Flight.value(long, "crumb")).length() <= 24, "a crumb is kept short")


func test_file_round_trip() -> void:
	var head := Flight.header("abcd1234abcd1234", 1798000000, {"version": "0.60.61", "device": "Pixel (Android)"}, true)
	var lines := [JSON.stringify(head)]
	for i in range(10):
		lines.append(JSON.stringify(_row(float(i + 1))))
	lines.append(JSON.stringify(Flight.event_line(4.2, "state", {"to": "running"})))
	lines.append(JSON.stringify(Flight.mark_line(0, 6.0)))
	lines.append(JSON.stringify(_row(11.0)))
	# A crash can cut the last write short.
	lines.append("[12.0, 16.7, 20.0, 60, 8.0")
	var p := Flight.parse("\n".join(lines))
	check_eq(str(p.header.session), "abcd1234abcd1234", "the header comes back")
	check(bool(p.header.log), "with whether logging was on")
	check_eq((p.rows as Array).size(), 11, "every whole row, and not the broken one")
	check_eq((p.events as Array).size(), 1, "events too")
	check_eq(int(p.seq), 0, "the last chunk the server has")
	check_near(float(p.sent_t), 6.0, 0.0001, "and up to when")
	var u := Flight.unsent(p.rows, p.events, float(p.sent_t))
	check_eq((u.rows as Array).size(), 5, "only the rows after the mark are owed")
	check((u.events as Array).is_empty(), "an event before them is not")
	check_eq((Flight.unsent(p.rows, p.events, -1.0, 4).rows as Array).size(), 4, "the newest rows win when there are too many")
	check_eq(Flight.parse("").rows.size(), 0, "an empty file is an empty log")
	check_eq(int(Flight.parse("nonsense\n{}\n[1,2]").seq), -1, "junk is skipped")


func test_was_logging() -> void:
	check(not Flight.was_logging({}), "no file, no logging")
	check(not Flight.was_logging({"header": {"log": false}, "seq": -1, "events": []}), "off is off")
	check(Flight.was_logging({"header": {"log": true}, "seq": -1, "events": []}), "the header says it was on")
	check(Flight.was_logging({"header": {"log": false}, "seq": 2, "events": []}), "a chunk that reached the server says so too")
	check(Flight.was_logging({"header": {}, "seq": -1, "events": [Flight.event_line(3.0, "logging", {"on": true})]}), "and so does switching it on mid-session")
	check(not Flight.was_logging({"header": {}, "seq": -1, "events": [Flight.event_line(3.0, "logging", {"on": false})]}), "switching it off does not")


func test_tail_and_summary() -> void:
	var rows := []
	for i in range(200):
		rows.append(_row(float(i), 16.7, 900.0 if i == 150 else 20.0))
	var t := Flight.tail(rows)
	check_eq((t.rows as Array).size(), Flight.REPORT_ROWS, "a report carries the last minute and a half")
	check_eq(t.cols, Flight.COLS, "with the columns named")
	check(Flight.tail([]).is_empty(), "no rows, no tail")
	var s := Flight.summary(rows)
	check_eq(int(s.seconds), 200, "seconds recorded")
	check_near(float(s.worst_ms), 900.0, 0.0001, "the worst frame is found")
	check_eq(int(s.slow_seconds), 1, "and counted")


func test_chunks() -> void:
	var head := Flight.header("abcd1234abcd1234", 1798000000, {"version": "0.60.61", "device": "Pixel (Android)", "gpu": "Adreno"}, true)
	var rows := []
	for i in range(Flight.CHUNK_ROWS):
		rows.append(_row(float(i)))
	var c := Flight.chunk(head, "0123456789abcdef", 3, rows, [Flight.event_line(1.0, "boot", {})], "crash", true, "it froze at the boss")
	check_eq(str(c.session), "abcd1234abcd1234", "the session rides in every chunk")
	check_eq(int(c.seq), 3, "numbered")
	check_eq(str(c.ended), "crash", "and it says how the session ended")
	check(bool(c.reported), "and whether the player reported it")
	var text := Flight.text(c)
	check(text.to_utf8_buffer().size() <= Flight.MAX_BYTES, "a full chunk fits the server's limit (%d bytes)" % text.to_utf8_buffer().size())
	var small := Flight.text(c, 4000)
	var parsed: Dictionary = JSON.parse_string(small)
	check(small.to_utf8_buffer().size() <= 4000 and (parsed.rows as Array).size() < rows.size(), "a tight limit drops the oldest rows")
	check_near(float(parsed.rows[-1][0]), float(Flight.CHUNK_ROWS - 1), 0.0001, "and keeps the newest")
	var b := Flight.body(text, "secret")
	check_eq(str(b.sig).length(), 64, "signed")
	check(b.sig != Flight.body(text + " ", "secret").sig, "and the signature covers the text")
	check_eq(b.sig, Leaderboard.hmac_hex("secret", "log|" + text), "over log| and the text, which is what the Worker checks")
	check_eq(Flight.url("https://x.test/"), "https://x.test/log", "the route")
	check(not c.has("name"), "nothing names the player")


func test_upload_rules() -> void:
	check(not Flight.should_upload(500.0, 0, true, 0), "nothing to send, nothing sent")
	check(not Flight.should_upload(60.0, 50, false, 0), "a quiet minute waits")
	check(Flight.should_upload(Flight.UPLOAD_EVERY, 50, false, 0), "two minutes is a chunk")
	check(Flight.should_upload(Flight.TROUBLE_GAP, 50, true, 0), "trouble goes sooner")
	check(not Flight.should_upload(5.0, 50, true, 0), "but not in a flood")
	check(not Flight.should_upload(500.0, 50, true, Flight.MAX_SEQ + 1), "a session has a last chunk")


func test_setting() -> void:
	check(not Flight.active(false, 0), "off is off")
	check(Flight.active(true, 0), "on is on")
	check(Flight.active(false, 3), "and a crash turns it on for a few launches")
	check_eq(Flight.label(false, 0), "LOGGING: OFF", "the button says off")
	check_eq(Flight.label(true, 4), "LOGGING: ON", "on wins")
	check_eq(Flight.label(false, 4), "LOGGING: AUTO x4", "or how many launches are left")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var a := Flight.new_session(rng)
	check(a.length() == 16 and a.is_valid_hex_number() and a != Flight.new_session(rng), "a session id is sixteen hex digits, and the next is another")
