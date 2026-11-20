class_name Flight
extends RefCounted
## The flight recorder. Once a second the game writes one row of numbers
## to a file on the phone: frame times, what is on screen, where the
## game is. The file survives a crash, so the next launch can say what
## the last seconds looked like. With LOGGING on, the rows also go to
## the server as the session runs, in chunks, and the tail of a session
## that died goes up when the game is next opened.
##
## Pure: the row and file formats, parsing, chunking, the upload rules.
## Diag does the sampling and the file, Game does the sending. Nothing
## here names the player.

## One row a second.
const SAMPLE_EVERY := 1.0
## The columns of a row, in order. "max" is the worst single frame in
## the second: an average hides a hitch, this does not.
const COLS := ["t", "ms", "max", "fps", "proc", "phys", "nodes", "draw", "prims", "vram", "mem", "zombies", "squad", "level", "fx", "state", "crumb"]
## With logging on: a chunk every this many seconds...
const UPLOAD_EVERY := 120.0
## ...or at once when something goes wrong, but not more often than this.
const TROUBLE_GAP := 30.0
## A second with a frame this long, or this slow on average, is trouble.
const TROUBLE_MAX_MS := 400.0
const TROUBLE_AVG_MS := 45.0
## Rows a chunk carries at most, and chunks a session may send.
const CHUNK_ROWS := 240
const MAX_SEQ := 200
## Rows kept in memory waiting for an upload, and kept for reports.
const PENDING_ROWS := 600
const REPORT_ROWS := 90
## The file is cut back to its last TAIL_ROWS when it passes FILE_ROWS.
const FILE_ROWS := 7200
const TAIL_ROWS := 300
const MAX_BYTES := 48000
## After a crash, logging turns itself on for this many launches.
const AUTO_SESSIONS := 5
const EVENTS_PER_CHUNK := 60

const PATH := "user://flight.log"
const PREV_PATH := "user://flight_prev.log"


## One row. [param avg_ms] and [param max_ms] are the second's frames;
## [param gauges] is what the game put in Diag.set_gauge.
static func row(t: float, avg_ms: float, max_ms: float, frames: int, proc_ms: float, phys_ms: float, counts: Dictionary, mem_mb: int, gauges: Dictionary, state: String, crumb: String) -> Array:
	return [
		snappedf(t, 0.1), snappedf(avg_ms, 0.1), snappedf(max_ms, 0.1), frames,
		snappedf(proc_ms, 0.1), snappedf(phys_ms, 0.1),
		int(counts.get("nodes", 0)), int(counts.get("draw", 0)), int(counts.get("prims", 0)), int(counts.get("vram", 0)), mem_mb,
		int(gauges.get("zombies", 0)), int(gauges.get("squad", 0)), int(gauges.get("level", 0)), int(gauges.get("fx", 0)),
		state, crumb.substr(0, 24),
	]


static func value(r: Array, col: String):
	var i := COLS.find(col)
	return r[i] if i >= 0 and i < r.size() else null


## Whether a row shows trouble worth an early upload.
static func is_trouble(r: Array) -> bool:
	return float(value(r, "max")) >= TROUBLE_MAX_MS or float(value(r, "ms")) >= TROUBLE_AVG_MS


# --- the file --------------------------------------------------------------
# One JSON value a line: a header object first, then rows (arrays),
# events ({"e": ...}) and upload marks ({"u": seq, "t": t}).

static func header(session: String, started: int, info: Dictionary, logging: bool) -> Dictionary:
	var h := {"h": 1, "session": session, "started": started, "log": logging}
	for k in ["version", "device", "os", "gpu", "screen", "renderer"]:
		h[k] = str(info.get(k, "?"))
	return h


static func event_line(t: float, name: String, data: Dictionary) -> Dictionary:
	return {"e": name, "t": snappedf(t, 0.1), "d": data}


static func mark_line(seq: int, t: float) -> Dictionary:
	return {"u": seq, "t": snappedf(t, 0.1)}


## A file's text as {header, rows, events, seq, sent_t}: seq is the last
## chunk the server has, sent_t the time of the last row it has. Broken
## lines (a write cut short by the crash) are skipped.
static func parse(text: String) -> Dictionary:
	var out := {"header": {}, "rows": [], "events": [], "seq": -1, "sent_t": -1.0}
	var json := JSON.new()
	for line in text.split("\n", false):
		# The instance parser returns an error; parse_string would also
		# print one for the line a crash cut short.
		if json.parse(line) != OK:
			continue
		var v = json.data
		if v is Array:
			if v.size() == COLS.size():
				out.rows.append(v)
		elif v is Dictionary:
			if v.has("h"):
				out.header = v
			elif v.has("e"):
				out.events.append(v)
			elif v.has("u"):
				out.seq = maxi(int(out.seq), int(v.u))
				out.sent_t = maxf(float(out.sent_t), float(v.get("t", -1.0)))
	return out


## What the server has not seen: rows and events after [param sent_t],
## the newest [param max_rows] of them.
static func unsent(rows: Array, events: Array, sent_t: float, max_rows: int = CHUNK_ROWS) -> Dictionary:
	var r := []
	for x in rows:
		if float(x[0]) > sent_t:
			r.append(x)
	if r.size() > max_rows:
		r = r.slice(r.size() - max_rows)
	var from_t := float(r[0][0]) if not r.is_empty() else sent_t
	var e := []
	for x in events:
		if float(x.get("t", 0.0)) >= from_t:
			e.append(x)
	if e.size() > EVENTS_PER_CHUNK:
		e = e.slice(e.size() - EVENTS_PER_CHUNK)
	return {"rows": r, "events": e}


## Whether a parsed file's session had logging on: the header says so,
## or a chunk reached the server, or it was switched on along the way.
static func was_logging(parsed: Dictionary) -> bool:
	if bool((parsed.get("header", {}) as Dictionary).get("log", false)) or int(parsed.get("seq", -1)) >= 0:
		return true
	for e in parsed.get("events", []):
		if str(e.get("e", "")) == "logging" and bool((e.get("d", {}) as Dictionary).get("on", false)):
			return true
	return false


## The last [param n] rows, with the columns, for a crash or bug report.
static func tail(rows: Array, n: int = REPORT_ROWS) -> Dictionary:
	if rows.is_empty():
		return {}
	return {"cols": COLS, "rows": rows.slice(maxi(0, rows.size() - n))}


## The worst of a set of rows: {seconds, worst_ms, slow_seconds}.
static func summary(rows: Array) -> Dictionary:
	var worst := 0.0
	var slow := 0
	for r in rows:
		worst = maxf(worst, float(value(r, "max")))
		if is_trouble(r):
			slow += 1
	return {"seconds": rows.size(), "worst_ms": snappedf(worst, 0.1), "slow_seconds": slow}


# --- chunks for the server -------------------------------------------------

## One upload. [param head] is the session's header; [param ended] is
## "" while it runs, "clean" or "crash" for the tail sent afterwards.
static func chunk(head: Dictionary, install: String, seq: int, rows: Array, events: Array, ended: String = "", reported: bool = false, note: String = "") -> Dictionary:
	var c := {"v": 1, "install": install, "seq": seq, "cols": COLS, "rows": rows, "events": events, "ended": ended, "reported": reported, "note": note.substr(0, 600)}
	for k in ["session", "started", "version", "device", "os", "gpu", "screen", "renderer"]:
		c[k] = head.get(k, "?")
	return c


## The chunk as the text that is signed and sent. Too big, and the
## oldest rows go, then the events.
static func text(c: Dictionary, limit: int = MAX_BYTES) -> String:
	var q := c.duplicate(true)
	var s := JSON.stringify(q)
	var step := 0
	while s.to_utf8_buffer().size() > limit and step < 16:
		step += 1
		var rows: Array = q.rows
		if rows.size() > 8:
			q.rows = rows.slice(rows.size() / 2)
		elif not (q.events as Array).is_empty():
			q.events = []
		else:
			q.rows = []
		s = JSON.stringify(q)
	return s


static func canonical(p_text: String) -> String:
	return "log|" + p_text


static func body(p_text: String, secret: String) -> Dictionary:
	return {"text": p_text, "sig": Leaderboard.hmac_hex(secret, canonical(p_text))}


static func url(base: String) -> String:
	return base.trim_suffix("/") + "/log"


## Whether a chunk should go now. [param since_upload] seconds since the
## last one, [param pending] rows waiting, [param trouble] whether any
## of them shows trouble, [param seq] the next chunk's number.
static func should_upload(since_upload: float, pending: int, trouble: bool, seq: int) -> bool:
	if pending <= 0 or seq > MAX_SEQ:
		return false
	if since_upload >= UPLOAD_EVERY:
		return true
	return trouble and since_upload >= TROUBLE_GAP


# --- the setting -----------------------------------------------------------

## Whether logging is live this launch: the switch, or the launches left
## after a crash turned it on by itself.
static func active(setting: bool, auto_left: int) -> bool:
	return setting or auto_left > 0


## The SETTINGS button.
static func label(setting: bool, auto_left: int) -> String:
	if setting:
		return "LOGGING: ON"
	if auto_left > 0:
		return "LOGGING: AUTO x%d" % auto_left
	return "LOGGING: OFF"


## A new session id: sixteen hex digits from [param rng].
static func new_session(rng: RandomNumberGenerator) -> String:
	return "%08x%08x" % [rng.randi(), rng.randi()]
