class_name Shake
extends RefCounted
## Shake to report. The phone's accelerometer reads gravity plus motion;
## a jolt is a reading far from gravity, and a shake is several jolts
## close together. Pure: feed it readings and times, it says when.

## Metres per second squared past gravity that count as a jolt.
const JOLT := 11.0
## Jolts needed inside WINDOW seconds.
const JOLTS := 4
const WINDOW := 0.9
## A jolt is counted at most this often, so one swing is one jolt.
const JOLT_GAP := 0.08
## After a shake, nothing counts for this long.
const COOLDOWN := 4.0
const GRAVITY := 9.81

## This detector's own numbers: the report shake by default.
var jolts_needed := JOLTS
var window := WINDOW
var cooldown := COOLDOWN

## Shaking a clinger off in a run is a quicker, lighter thing than
## asking for the report card: two jolts, and ready again in a second.
const QUICK_JOLTS := 2
const QUICK_WINDOW := 0.6
const QUICK_COOLDOWN := 1.0


static func quick() -> Shake:
	var s := Shake.new()
	s.jolts_needed = QUICK_JOLTS
	s.window = QUICK_WINDOW
	s.cooldown = QUICK_COOLDOWN
	return s


var _jolts: Array = []
var _last_jolt := -10.0
var _last_shake := -100.0


## Feed one accelerometer reading at [param now]. True on a shake.
func feed(accel: Vector3, now: float) -> bool:
	if now - _last_shake < cooldown:
		return false
	var excess := absf(accel.length() - GRAVITY)
	if excess >= JOLT and now - _last_jolt >= JOLT_GAP:
		_last_jolt = now
		_jolts.append(now)
	while not _jolts.is_empty() and now - float(_jolts[0]) > window:
		_jolts.pop_front()
	if _jolts.size() >= jolts_needed:
		_jolts.clear()
		_last_shake = now
		return true
	return false


## Whether a reading looks like a real sensor (a desktop reports zero).
static func has_sensor(accel: Vector3) -> bool:
	return accel.length() > 0.5
