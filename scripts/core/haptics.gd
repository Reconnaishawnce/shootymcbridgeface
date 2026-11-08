class_name Haptics
extends RefCounted
## What the phone's buzz says, in milliseconds per moment. Short for
## the things that happen all the time, long for the ones that should
## be felt in the hand. Pure; the game asks and the OS vibrates.

const TABLE := {
	"bite": 22, "heavy": 55, "wall": 70, "saw": 70,
	"gate_good": 16, "gate_bad": 30, "perfect": 40,
	"ability": 35, "buy": 14, "level_clear": 65, "boss_down": 120,
	"wipe": 160, "rally": 30,
}
## Never more often than this (seconds), so a crowd does not turn the
## phone into a motor.
const MIN_GAP := 0.08


static func duration(event: String, on: bool) -> int:
	if not on:
		return 0
	return int(TABLE.get(event, 0))


## Whether a buzz may fire now: the setting is on, the event is known,
## and the last buzz was MIN_GAP ago (longer ones may always follow a
## shorter one).
static func allowed(event: String, on: bool, now: float, last: float, last_ms: int) -> bool:
	var ms := duration(event, on)
	if ms <= 0:
		return false
	return now - last >= MIN_GAP or ms > last_ms
