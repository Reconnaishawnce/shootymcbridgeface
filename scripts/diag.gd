extends Node
## Diagnostics. An autoload: an event log the game writes to, a
## heartbeat file that says what the game was doing if it dies, stall
## detection on the wall clock, and the bug report built from all of it
## plus the engine's own log of the previous session. Nothing here is
## on the hot path: the heartbeat is a tiny file every few seconds.

const HEARTBEAT_PATH := "user://heartbeat.json"
const LOG_DIR := "user://logs"
## Once a second: a death between two beats is pinned to the second.
const HEARTBEAT_EVERY := 1.0
const MAX_STALLS := 30

var events: Array = []
var stalls: Array = []
var previous: Dictionary = {}
var state_name := "boot"
var crumb := ""
var started := 0.0
var _last_wall := 0.0
var _last_beat := 0.0
var _clean := false
var _frames := 0
var _enabled := true
## Frame times this session: a histogram by Telemetry.HIST_EDGES and
## the worst few frames with where the game was.
var frame_hist: Array = [0, 0, 0, 0, 0]
var worst_frames: Array = []
## The performance trace (Telemetry.trace_sample every TRACE_EVERY) and
## the game's gauges folded into each sample (set_gauge).
var trace: Array = []
var gauges: Dictionary = {}
var _trace_at := 0.0
var _trace_frames := 0
## The bot samples by frame instead of wall time: a fast runner plays
## 900 fixed frames in a second, which is one wall-clock sample.
var trace_every_frames := 0
var _trace_ms := 0.0
## The flight recorder (Flight): one row a second, in memory and in a
## file that survives a crash. `session` names this launch;
## `previous_flight` is the last launch's file, parsed.
var session := ""
var flight_rows: Array = []
var flight_events: Array = []
var flight_sent_t := -1.0
var flight_seq := 0
var flight_trouble := false
var flight_logging := false
var previous_flight: Dictionary = {}
## The bot samples by frame, like the trace.
var flight_every_frames := 0
var _flight_file: FileAccess
var _flight_lines := 0
var _flight_at := 0.0
var _flight_frames := 0
var _flight_ms := 0.0
var _flight_max := 0.0
var _flight_head_written := false
## Lines from before the first row: they wait, so the header is written
## once the game has said whether logging is on.
var _flight_early: Array = []
## A single frame of Telemetry.LONG_FRAME_SECONDS or more, in the
## foreground: a freeze the game should report.
signal long_frame(seconds: float, crumb: String)
## When the app last came back to the front, in seconds since launch:
## a frame-rate sample that began before then has a hole in it.
var resumed_at := 0.0
var _skip_gap := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs (tests, the smoke bot, CI) must not leave files behind.
	_enabled = DisplayServer.get_name() != "headless"
	started = Time.get_unix_time_from_system()
	_last_wall = Time.get_ticks_msec() * 0.001
	_last_beat = _last_wall
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	session = Flight.new_session(rng)
	if _enabled:
		_flight_rotate()
		previous = _read_heartbeat()
		if not previous.is_empty():
			previous.age = int(started - float(previous.get("last", started)))
			previous.ran = int(float(previous.get("last", started)) - float(previous.get("started", started)))
	note("boot", {"previous": Report.verdict(previous)})
	_beat(true)


func _process(_delta: float) -> void:
	_frames += 1
	var now := Time.get_ticks_msec() * 0.001
	var wall := now - _last_wall
	_last_wall = now
	# The first frame back from the home screen (or a locked phone) is as
	# long as the player was away. That is not a frame: it used to be
	# filed as a half-hour freeze.
	if _skip_gap or (_clean and Report.is_stall(wall)):
		_skip_gap = false
		return
	# A long gap between frames while in the foreground is a stall worth
	# knowing about: which state, which breadcrumb, how long.
	if _frames > 2:
		var ms := wall * 1000.0
		frame_hist[Telemetry.hist_bucket(ms)] += 1
		_trace_frames += 1
		_trace_ms += ms
		var due := (_trace_frames >= trace_every_frames) if trace_every_frames > 0 else (now - _trace_at >= Telemetry.TRACE_EVERY)
		if due:
			var counts := {
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
				"vram": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
			}
			trace = Telemetry.push_trace(trace, Telemetry.trace_sample(now, _trace_ms / float(maxi(_trace_frames, 1)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, counts, gauges, state_name))
			_trace_at = now
			_trace_frames = 0
			_trace_ms = 0.0
		if ms > 50.0:
			worst_frames = Telemetry.note_worst(worst_frames, {"ms": snappedf(ms, 0.1), "t": snappedf(now, 0.01), "state": state_name, "crumb": crumb})
		# The flight recorder: the second's average and its worst frame.
		_flight_frames += 1
		_flight_ms += ms
		_flight_max = maxf(_flight_max, ms)
		var flight_due := (_flight_frames >= flight_every_frames) if flight_every_frames > 0 else (now - _flight_at >= Flight.SAMPLE_EVERY)
		if flight_due:
			_flight_sample(now)
	if Report.is_stall(wall) and _clean == false and _frames > 2:
		if stalls.size() < MAX_STALLS:
			stalls.append({"t": snappedf(now, 0.01), "seconds": snappedf(wall, 0.01), "state": state_name, "crumb": crumb})
		note("STALL", {"seconds": snappedf(wall, 0.01), "crumb": crumb})
		if wall >= Telemetry.LONG_FRAME_SECONDS:
			long_frame.emit(wall, crumb)
	if now - _last_beat >= HEARTBEAT_EVERY:
		_beat(false)


func _notification(what: int) -> void:
	# Backgrounded or closing: a death from here on is the system's doing.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clean = true
		_beat(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_clean = false
		_skip_gap = true
		resumed_at = Time.get_ticks_msec() * 0.001
		_beat(true)


## A number the game wants in every trace sample: zombies on screen,
## bullets, the squad, the level.
func set_gauge(key: String, value: Variant) -> void:
	gauges[key] = value


## Game state changed (title, running, game over, ...).
func set_state(name: String) -> void:
	if name == state_name:
		return
	state_name = name
	crumb = ""
	note("state", {"to": name})
	_beat(true)


## A step inside a state: the heartbeat names it, so a death says where.
func mark(where: String) -> void:
	crumb = where
	if _enabled:
		_beat(true)


func note(event: String, data: Dictionary = {}) -> void:
	var t := Time.get_ticks_msec() * 0.001
	events.append(Report.line(t, state_name, event, data))
	events = Report.trim(events)
	var line := Flight.event_line(t, event, data)
	flight_events.append(line)
	if flight_events.size() > 200:
		flight_events = flight_events.slice(flight_events.size() - 200)
	_flight_write(line)


# --- the flight recorder ---------------------------------------------------

func _counts() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"vram": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
	}


## Megabytes in use on the device, as a number.
func _mem_used_mb() -> int:
	var info := OS.get_memory_info()
	var physical := float(info.get("physical", 0))
	return int((physical - float(info.get("free", 0))) / 1048576.0) if physical > 0.0 else 0


## What the device is, for the file's header and every chunk.
func _device_info() -> Dictionary:
	return {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"device": "%s (%s)" % [OS.get_model_name(), OS.get_name()],
		"os": OS.get_version() if OS.get_version() != "" else OS.get_version_alias(),
		"gpu": "%s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"screen": "%s @ %sHz" % [str(DisplayServer.screen_get_size()), str(snappedf(DisplayServer.screen_get_refresh_rate(), 0.1))],
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
	}


func flight_head() -> Dictionary:
	return Flight.header(session, int(started), _device_info(), flight_logging)


## One row: into memory for reports and uploads, and onto the disk.
func _flight_sample(now: float) -> void:
	var n := maxi(_flight_frames, 1)
	var r := Flight.row(now, _flight_ms / float(n), _flight_max, _flight_frames, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, _counts(), _mem_used_mb(), gauges, state_name, crumb)
	_flight_at = now
	_flight_frames = 0
	_flight_ms = 0.0
	_flight_max = 0.0
	flight_rows.append(r)
	if flight_rows.size() > Flight.PENDING_ROWS:
		flight_rows = flight_rows.slice(flight_rows.size() - Flight.PENDING_ROWS)
	if Flight.is_trouble(r):
		flight_trouble = true
	_flight_write(r)


## The game says whether logging is live. Written into the header, so
## the next launch knows whether this session's tail is owed.
func set_logging(on: bool) -> void:
	if on == flight_logging:
		return
	flight_logging = on
	note("logging", {"on": on})


## Rows and events the server has not had yet.
func flight_unsent() -> Dictionary:
	return Flight.unsent(flight_rows, flight_events, flight_sent_t)


func flight_unsent_count() -> int:
	var n := 0
	for r in flight_rows:
		if float(r[0]) > flight_sent_t:
			n += 1
	return n


## Chunk [param seq] reached the server with rows up to [param t].
func flight_uploaded(seq: int, t: float) -> void:
	flight_seq = seq + 1
	flight_sent_t = maxf(flight_sent_t, t)
	flight_trouble = false
	_flight_write(Flight.mark_line(seq, flight_sent_t))


## The last launch's file becomes the previous one, and is read: the
## header from its first line, everything else from its last 64 KB.
func _flight_rotate() -> void:
	if FileAccess.file_exists(Flight.PATH):
		if FileAccess.file_exists(Flight.PREV_PATH):
			DirAccess.remove_absolute(Flight.PREV_PATH)
		DirAccess.rename_absolute(Flight.PATH, Flight.PREV_PATH)
	if FileAccess.file_exists(Flight.PREV_PATH):
		previous_flight = Flight.parse(_tail(Flight.PREV_PATH))
		var f := FileAccess.open(Flight.PREV_PATH, FileAccess.READ)
		if f != null:
			var first := Flight.parse(f.get_line())
			f.close()
			if not (first.header as Dictionary).is_empty():
				previous_flight.header = first.header
	_flight_file = FileAccess.open(Flight.PATH, FileAccess.WRITE)


## One line to the file, flushed at once so a crash cannot take it.
func _flight_write(v: Variant) -> void:
	if _flight_file == null:
		return
	if not _flight_head_written:
		# The header waits for the first row (a second in), by when the
		# game has loaded its settings and said whether logging is on.
		if not (v is Array) and _flight_early.size() < 40:
			_flight_early.append(v)
			return
		_flight_head_written = true
		_flight_file.store_line(JSON.stringify(flight_head()))
		for early in _flight_early:
			_flight_file.store_line(JSON.stringify(early))
		_flight_early = []
	_flight_file.store_line(JSON.stringify(v))
	_flight_file.flush()
	_flight_lines += 1
	if _flight_lines > Flight.FILE_ROWS:
		_flight_cut()


## The file has grown past its limit: start it again from its tail.
func _flight_cut() -> void:
	_flight_file.close()
	_flight_file = FileAccess.open(Flight.PATH, FileAccess.WRITE)
	if _flight_file == null:
		return
	_flight_file.store_line(JSON.stringify(flight_head()))
	var keep := flight_rows.slice(maxi(0, flight_rows.size() - Flight.TAIL_ROWS))
	for r in keep:
		_flight_file.store_line(JSON.stringify(r))
	if flight_seq > 0:
		_flight_file.store_line(JSON.stringify(Flight.mark_line(flight_seq - 1, flight_sent_t)))
	_flight_file.flush()
	_flight_lines = keep.size() + 2


## Memory in use, in megabytes, as the OS sees it: the static counter is
## zero in release builds, so this reads the process's physical use.
func memory_mb() -> String:
	var info := OS.get_memory_info()
	var physical := float(info.get("physical", 0))
	var free := float(info.get("free", 0))
	if physical > 0.0:
		return "%s used of %s" % [snappedf((physical - free) / 1048576.0, 1.0), snappedf(physical / 1048576.0, 1.0)]
	return str(snappedf(float(OS.get_static_memory_usage()) / 1048576.0, 0.1))


## Counters a report carries: frame times, scene size, memory.
func perf() -> Dictionary:
	return {
		"hist": frame_hist.duplicate(),
		"worst": worst_frames.duplicate(true),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"fps": Engine.get_frames_per_second(),
		"memory_mb": memory_mb(),
		"max_fps": Engine.max_fps,
		"uptime": snappedf(Time.get_ticks_msec() * 0.001, 0.1),
	}


## Everything a report is made from: device, app, the previous session,
## stalls, engine errors from both logs, a save summary, the event log.
func context(save: Dictionary, p_note: String = "") -> Dictionary:
	return {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"time": Time.get_datetime_string_from_system(true, true),
		"device": "%s (%s)" % [OS.get_model_name(), OS.get_name()],
		"os": OS.get_version() if OS.get_version() != "" else OS.get_version_alias(),
		"gpu": "%s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
		"screen": "%s @ %sHz" % [str(DisplayServer.screen_get_size()), str(snappedf(DisplayServer.screen_get_refresh_rate(), 0.1))],
		"fps": str(Engine.get_frames_per_second()),
		"memory_mb": memory_mb(),
		"locale": OS.get_locale(),
		"safe_graphics": SaveData.load_safe_graphics(),
		"shadows": SaveData.load_shadows_on(),
		"previous": previous,
		"stalls": stalls,
		"events": events,
		"previous_errors": Report.error_lines(_previous_log()),
		"current_errors": Report.error_lines(_current_log()),
		"save": save,
		"note": p_note,
		"state": state_name,
		"crumb": crumb,
		"uptime": snappedf(Time.get_ticks_msec() * 0.001, 0.1),
		"perf": perf(),
		"trace": trace.duplicate(true),
		"session": session,
		"flight": Flight.tail(flight_rows),
		"previous_flight": Flight.tail(previous_flight.get("rows", [])),
		"previous_session": str(previous_flight.get("header", {}).get("session", "")),
	}


## The report as text, for the mail app and the clipboard.
func report(save: Dictionary, p_note: String = "") -> String:
	return Report.build(context(save, p_note))


## The report as a payload for the server (Telemetry).
func bundle(save: Dictionary, kind: String, p_note: String = "") -> Dictionary:
	var c := context(save, p_note)
	c.kind = kind
	# The last launch's final seconds belong in its crash report only.
	if kind != "crash":
		c.previous_flight = {}
	return Telemetry.payload(c)


## Open the mail app with the report, and put it on the clipboard too.
func send(save: Dictionary, note: String = "") -> bool:
	var text := report(save, note)
	DisplayServer.clipboard_set(text)
	var subject := "Shooty McBridgeface bug report (%s)" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	var err := OS.shell_open(Report.mailto(subject, text))
	note("report_sent", {"ok": err == OK, "chars": text.length()})
	return err == OK


func had_bad_exit() -> bool:
	return Report.bad_exit(previous)


# --- files -----------------------------------------------------------------

func _beat(force: bool) -> void:
	if not _enabled:
		return
	var now := Time.get_ticks_msec() * 0.001
	if not force and now - _last_beat < HEARTBEAT_EVERY:
		return
	_last_beat = now
	var hb := {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"started": started,
		"last": Time.get_unix_time_from_system(),
		"state": state_name,
		"crumb": crumb,
		"clean": _clean,
		"frames": _frames,
		"session": session,
		"events": Report.trim(events, 12),
	}
	var f := FileAccess.open(HEARTBEAT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(hb))
		f.close()


func _read_heartbeat() -> Dictionary:
	if not FileAccess.file_exists(HEARTBEAT_PATH):
		return {}
	var f := FileAccess.open(HEARTBEAT_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


## Godot rotates user://logs/godot.log on start: the newest dated file is
## the previous session.
func _previous_log() -> String:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return ""
	var newest := ""
	for name in dir.get_files():
		if name.begins_with("godot_") and name.ends_with(".log") and name > newest:
			newest = name
	if newest == "":
		return ""
	return _tail(LOG_DIR + "/" + newest)


func _current_log() -> String:
	return _tail(LOG_DIR + "/godot.log")


func _tail(path: String, max_bytes: int = 65536) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var size := f.get_length()
	if size > max_bytes:
		f.seek(size - max_bytes)
	var text := f.get_as_text()
	f.close()
	return text
