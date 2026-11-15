class_name Telemetry
extends RefCounted
## Crash, freeze and bug reports that reach the developer on their own.
## Pure: builds the report from what Diag knows, trims it to size, and
## signs it for the Worker (leaderboard/worker.js, POST /report). The
## game decides when to send one and does the sending. Nothing here
## names the player: a random install id, the phone, its graphics chip,
## frame times, the event log, engine errors and a save summary.

## What a report is about.
const KINDS := ["crash", "freeze", "slow", "manual"]
## The performance trace: one sample every TRACE_EVERY seconds, the last
## TRACE_KEPT of them, so a slowdown report shows the half minute before.
const TRACE_EVERY := 0.5
const TRACE_KEPT := 80
## The Worker refuses bigger bodies; events are dropped until it fits.
const MAX_BYTES := 48000
## A single frame this long (wall clock) is a freeze worth a report.
const LONG_FRAME_SECONDS := 1.0
## A five-second average under this, in a run, is a slowdown worth one.
const SLOW_FPS := 30.0
## Freeze or slowdown reports per run, and reports of any kind per session.
const PER_RUN_FREEZES := 1
const PER_SESSION := 6
## Reports kept in the save when the network is not there.
const PENDING_MAX := 3
const EVENTS_KEPT := 80
const PREVIOUS_EVENTS_KEPT := 12
const ERRORS_KEPT := 30
## Which keys a payload carries, and their defaults when Diag has none.
const FIELDS := {
	"kind": "manual", "version": "dev", "time": "", "install": "",
	"device": "?", "os": "?", "gpu": "?", "renderer": "?", "screen": "?",
	"memory_mb": "?", "fps": "?", "locale": "", "safe_graphics": false, "shadows": true,
	"state": "", "crumb": "", "uptime": 0.0, "note": "",
	"previous": {}, "stalls": [], "events": [], "previous_errors": [], "current_errors": [],
	"save": {}, "perf": {}, "trace": [],
}


## A payload from a Diag context: known keys only, lists trimmed.
static func payload(c: Dictionary) -> Dictionary:
	var p := {}
	for k in FIELDS:
		p[k] = c.get(k, FIELDS[k])
	if not p.kind in KINDS:
		p.kind = "manual"
	p.events = Report.trim(p.events, EVENTS_KEPT)
	p.previous_errors = Report.trim(p.previous_errors, ERRORS_KEPT)
	p.current_errors = Report.trim(p.current_errors, ERRORS_KEPT)
	var prev: Dictionary = p.previous
	if prev.has("events"):
		prev = prev.duplicate()
		prev.events = Report.trim(prev.events, PREVIOUS_EVENTS_KEPT)
		p.previous = prev
	p.note = str(p.note).substr(0, 600)
	return p


## The payload as the text that is signed and sent: compact JSON, cut
## down from the back of the event log until it fits [param limit].
static func text(p: Dictionary, limit: int = MAX_BYTES) -> String:
	var q := p.duplicate(true)
	var s := JSON.stringify(q)
	var step := 0
	while s.to_utf8_buffer().size() > limit and step < 12:
		step += 1
		var ev: Array = q.get("events", [])
		var tr: Array = q.get("trace", [])
		if tr.size() > 10:
			q.trace = tr.slice(tr.size() / 2)
		elif ev.size() > 8:
			q.events = ev.slice(ev.size() / 2)
		elif not (q.get("previous_errors", []) as Array).is_empty() or not (q.get("current_errors", []) as Array).is_empty():
			q.previous_errors = []
			q.current_errors = []
		elif not (q.get("stalls", []) as Array).is_empty():
			q.stalls = []
		else:
			q.events = []
			q.previous = {}
			q.save = {}
			q.perf = {}
			q.trace = []
		s = JSON.stringify(q)
	return s


## What the Worker checks: the text and its signature.
static func canonical(p_text: String) -> String:
	return "report|" + p_text


static func body(p_text: String, secret: String) -> Dictionary:
	return {"text": p_text, "sig": Leaderboard.hmac_hex(secret, canonical(p_text))}


static func url(base: String) -> String:
	return base.trim_suffix("/") + "/report"


## Whether a report of [param kind] may go now. Manual reports always
## may (the player asked); the rest respect the toggle and the caps.
## [param hitches_this_run] counts freeze and slowdown reports together.
static func allowed(on: bool, configured: bool, kind: String, sent_this_session: int, hitches_this_run: int) -> bool:
	if not configured:
		return false
	if kind == "manual":
		return true
	if not on or sent_this_session >= PER_SESSION:
		return false
	if (kind == "freeze" or kind == "slow") and hitches_this_run >= PER_RUN_FREEZES:
		return false
	return true


## One trace sample: the frame's cost split into script and render, the
## scene's size, and the game's own gauges.
static func trace_sample(t: float, frame_ms: float, process_ms: float, physics_ms: float, counts: Dictionary, gauges: Dictionary, state: String) -> Dictionary:
	var row := {"t": snappedf(t, 0.1), "ms": snappedf(frame_ms, 0.1), "proc": snappedf(process_ms, 0.1), "phys": snappedf(physics_ms, 0.1), "st": state}
	for k in counts:
		row[k] = counts[k]
	for k in gauges:
		row[k] = gauges[k]
	return row


## Keeps the trace a ring of TRACE_KEPT.
static func push_trace(trace: Array, row: Dictionary) -> Array:
	var out := trace.duplicate()
	out.append(row)
	if out.size() > TRACE_KEPT:
		out = out.slice(out.size() - TRACE_KEPT)
	return out


## One previous session is reported once: its heartbeat's last time is
## the marker the save keeps.
static func crash_marker(previous: Dictionary) -> String:
	if previous.is_empty():
		return ""
	return "%s@%s" % [str(previous.get("version", "")), str(previous.get("last", ""))]


## One line about a payload, for logs and the HUD.
static func summary(p: Dictionary) -> String:
	return "%s  v%s  %s  %s/%s" % [str(p.get("kind", "?")), str(p.get("version", "?")), str(p.get("device", "?")), str(p.get("state", "?")), str(p.get("crumb", ""))]


## Frame-time buckets, in milliseconds: under 17, 34, 67, 200, and over.
const HIST_EDGES := [17.0, 34.0, 67.0, 200.0]


static func hist_bucket(ms: float) -> int:
	for i in range(HIST_EDGES.size()):
		if ms < float(HIST_EDGES[i]):
			return i
	return HIST_EDGES.size()


## Keeps the [param keep] worst frames, worst first.
static func note_worst(worst: Array, entry: Dictionary, keep: int = 5) -> Array:
	var out := worst.duplicate()
	out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.ms) > float(b.ms))
	if out.size() > keep:
		out.resize(keep)
	return out
