class_name Report
extends RefCounted
## Bug reports. Pure: the game hands in what it knows (device, app, the
## event log, stalls, the last session's heartbeat, error lines from the
## previous engine log) and gets back the text that goes in the email,
## plus the mailto: link that opens the mail app with it filled in.
## Everything here runs in tests; nothing touches the OS.

## Where reports go. One constant, easy to change.
const BUG_EMAIL := "shawn.abelson@gmail.com"
## The mail app gets a body of at most this many characters; the whole
## report also goes to the clipboard so nothing is lost to a short limit.
const BODY_LIMIT := 6000
const LOG_LINES := 200
## A frame this long (seconds of wall clock) counts as a stall.
const STALL_SECONDS := 0.5
## A heartbeat older than this at the time the app died means the system
## most likely killed a backgrounded app, not a crash in the foreground.
const HEARTBEAT_FRESH := 8


## One line of the event log.
static func line(t: float, state: String, event: String, data: Dictionary = {}) -> String:
	var s := "%7.2f  %-9s %s" % [t, state, event]
	if not data.is_empty():
		s += "  " + JSON.stringify(data)
	return s


## Keep the log a ring: the newest LOG_LINES lines.
static func trim(lines: Array, limit: int = LOG_LINES) -> Array:
	if lines.size() <= limit:
		return lines
	return lines.slice(lines.size() - limit)


static func is_stall(wall_delta: float) -> bool:
	return wall_delta >= STALL_SECONDS


## What the previous session's heartbeat says about how it ended.
## [param hb] keys: clean (bool), last (unix), state, crumb, version.
static func verdict(hb: Dictionary) -> String:
	if hb.is_empty():
		return "none"
	if bool(hb.get("clean", true)):
		return "clean"
	return "died in %s at %s" % [str(hb.get("state", "?")), str(hb.get("crumb", "?"))]


static func bad_exit(hb: Dictionary) -> bool:
	return not hb.is_empty() and not bool(hb.get("clean", true))


## Error lines worth sending from an engine log: the lines that name an
## error and the line after each (Godot prints the location there).
static func error_lines(log_text: String, limit: int = 40) -> Array:
	var out := []
	var lines := log_text.split("\n")
	var i := 0
	while i < lines.size():
		var l: String = lines[i]
		if l.begins_with("ERROR") or l.begins_with("SCRIPT ERROR") or l.begins_with("USER ERROR") or l.contains("Parse Error") or l.contains("at: "):
			out.append(l.strip_edges())
		i += 1
	if out.size() > limit:
		out = out.slice(out.size() - limit)
	return out


## The report text. [param c] keys: version, device, os, gpu, renderer,
## screen, memory_mb, fps, locale, safe_graphics, shadows, previous
## (heartbeat dict), stalls (Array of dicts), events (Array of lines),
## previous_errors (Array), current_errors (Array), save (Dictionary),
## note (String the player typed, optional).
static func build(c: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("SHOOTY McBRIDGEFACE BUG REPORT")
	parts.append("version %s   %s" % [str(c.get("version", "dev")), str(c.get("time", ""))])
	if str(c.get("note", "")) != "":
		parts.append("\nWHAT HAPPENED\n" + str(c.note))
	parts.append("\nDEVICE")
	parts.append("model: %s" % str(c.get("device", "?")))
	parts.append("os: %s" % str(c.get("os", "?")))
	parts.append("gpu: %s" % str(c.get("gpu", "?")))
	parts.append("renderer: %s   screen: %s   fps now: %s" % [str(c.get("renderer", "?")), str(c.get("screen", "?")), str(c.get("fps", "?"))])
	parts.append("memory: %s MB   locale: %s" % [str(c.get("memory_mb", "?")), str(c.get("locale", "?"))])
	parts.append("safe graphics: %s   shadows: %s" % [str(c.get("safe_graphics", false)), str(c.get("shadows", true))])
	var prev: Dictionary = c.get("previous", {})
	parts.append("\nPREVIOUS SESSION: " + verdict(prev))
	if not prev.is_empty():
		parts.append("version %s, ran %s s, last heartbeat %s s before now" % [str(prev.get("version", "?")), str(prev.get("ran", "?")), str(prev.get("age", "?"))])
		var prev_events: Array = prev.get("events", [])
		if not prev_events.is_empty():
			parts.append("its last events:")
			for l in prev_events:
				parts.append("  " + str(l))
	var stalls: Array = c.get("stalls", [])
	parts.append("\nSTALLS THIS SESSION: %d" % stalls.size())
	for st in stalls:
		parts.append("  %s" % JSON.stringify(st))
	var prev_err: Array = c.get("previous_errors", [])
	parts.append("\nENGINE ERRORS, PREVIOUS SESSION: %d" % prev_err.size())
	for l in prev_err:
		parts.append("  " + str(l))
	var cur_err: Array = c.get("current_errors", [])
	parts.append("\nENGINE ERRORS, THIS SESSION: %d" % cur_err.size())
	for l in cur_err:
		parts.append("  " + str(l))
	parts.append("\nSAVE")
	var save: Dictionary = c.get("save", {})
	for k in save:
		parts.append("%s: %s" % [str(k), str(save[k])])
	parts.append("\nEVENTS (newest last)")
	for l in c.get("events", []):
		parts.append(str(l))
	return "\n".join(parts)


## The mailto: link. The body is cut from the front, so the newest
## events survive, and the cut is said out loud.
static func mailto(subject: String, body: String, limit: int = BODY_LIMIT) -> String:
	var b := body
	if b.length() > limit:
		b = "[cut: full report is on the clipboard]\n" + b.substr(b.length() - limit)
	return "mailto:%s?subject=%s&body=%s" % [BUG_EMAIL, subject.uri_encode(), b.uri_encode()]
