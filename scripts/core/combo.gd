class_name Combo
extends RefCounted
## Kill streaks. Kills inside WINDOW seconds of each other chain; the chain
## pays a score multiplier that steps up every STEP kills. Pure and
## testable: the caller supplies the clock.

const WINDOW := 1.4
const STEP := 5
const MULT_PER_STEP := 0.5
const MAX_MULT := 4.0

var count := 0
var best := 0
var _last_time := -1000.0


## Register a kill at [param now]. Returns the chain length.
func kill(now: float) -> int:
	if now - _last_time > WINDOW:
		count = 0
	count += 1
	best = maxi(best, count)
	_last_time = now
	return count


## True while the chain is still alive at [param now].
func alive(now: float) -> bool:
	return count > 0 and now - _last_time <= WINDOW


## 0..1, how much of the window is left.
func remaining(now: float) -> float:
	if count == 0:
		return 0.0
	return clampf(1.0 - (now - _last_time) / WINDOW, 0.0, 1.0)


func multiplier() -> float:
	return minf(1.0 + float(count / STEP) * MULT_PER_STEP, MAX_MULT)


func reset() -> void:
	count = 0
	_last_time = -1000.0
