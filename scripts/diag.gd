extends Node
## Diagnostics. An autoload: an event log the game writes to, a
## heartbeat file that says what the game was doing if it dies, stall
## detection on the wall clock, and the bug report built from all of it
## plus the engine's own log of the previous session. Nothing here is
## on the hot path: the heartbeat is a tiny file every few seconds.

const HEARTBEAT_PATH := "user://heartbeat.json"
const LOG_DIR := "user://logs"
const HEARTBEAT_EVERY := 3.0
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs (tests, the smoke bot, CI) must not leave files behind.
	_enabled = DisplayServer.get_name() != "headless"
	started = Time.get_unix_time_from_system()
	_last_wall = Time.get_ticks_msec() * 0.001
	_last_beat = _last_wall
	if _enabled:
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
	# A long gap between frames while in the foreground is a stall worth
	# knowing about: which state, which breadcrumb, how long.
	if Report.is_stall(wall) and _clean == false and _frames > 2:
		if stalls.size() < MAX_STALLS:
			stalls.append({"t": snappedf(now, 0.01), "seconds": snappedf(wall, 0.01), "state": state_name, "crumb": crumb})
		note("STALL", {"seconds": snappedf(wall, 0.01), "crumb": crumb})
	if now - _last_beat >= HEARTBEAT_EVERY:
		_beat(false)


func _notification(what: int) -> void:
	# Backgrounded or closing: a death from here on is the system's doing.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clean = true
		_beat(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_clean = false
		_beat(true)


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


## The whole report: device, app, the previous session, stalls, engine
## errors from both logs, a save summary and the event log.
func report(save: Dictionary, note: String = "") -> String:
	var ctx := {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"time": Time.get_datetime_string_from_system(true, true),
		"device": "%s (%s)" % [OS.get_model_name(), OS.get_name()],
		"os": OS.get_version(),
		"gpu": "%s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
		"screen": "%s @ %sHz" % [str(DisplayServer.screen_get_size()), str(snappedf(DisplayServer.screen_get_refresh_rate(), 0.1))],
		"fps": str(Engine.get_frames_per_second()),
		"memory_mb": str(snappedf(float(OS.get_static_memory_usage()) / 1048576.0, 0.1)),
		"locale": OS.get_locale(),
		"safe_graphics": SaveData.load_safe_graphics(),
		"shadows": SaveData.load_shadows_on(),
		"previous": previous,
		"stalls": stalls,
		"events": events,
		"previous_errors": Report.error_lines(_previous_log()),
		"current_errors": Report.error_lines(_current_log()),
		"save": save,
		"note": note,
	}
	return Report.build(ctx)


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
