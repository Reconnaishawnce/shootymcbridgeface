class_name Perf
extends RefCounted
## Frame-rate watchdog logic. Pure: the game samples, this decides. A
## phone that cannot hold the frame rate gets the safe renderer once,
## automatically, and is told so; the player can turn it back in SETTINGS.

## Below this average the extras are not worth it.
const SLOW_FPS := 22.0
## How long a sample has to run before it counts.
const SAMPLE_SECONDS := 5.0
## Frames at the very start (shader compiles, warm-up) are not a sample.
const SETTLE_SECONDS := 3.0


static func average_fps(frames: int, seconds: float) -> float:
	return float(frames) / seconds if seconds > 0.0 else 0.0


static func should_degrade(avg_fps: float, seconds: float, safe_on: bool, already_done: bool) -> bool:
	if safe_on or already_done:
		return false
	return seconds >= SAMPLE_SECONDS and avg_fps < SLOW_FPS


## A sample only counts if the game ran through all of it. A pit stop, a
## draft, the pause menu or a trip to the home screen in the middle is
## time with no frames in it, and used to read as "3 fps": a report sent
## for nothing, and the safe renderer switched on for phones that were
## holding sixty. [param resumed_at] is when the app last came back to
## the front, [param since] when the sample began.
static func sample_valid(paused: bool, since: float, resumed_at: float) -> bool:
	return not paused and resumed_at <= since


## Below this the sun's shadows go first: they draw every body twice,
## and are the one extra a slow stretch can do without.
const SHADOW_FPS := 45.0
## Slow samples in a row, in a run, before they do.
const SHADOW_SAMPLES := 2


static func should_drop_shadows(low_streak: int, shadows_on: bool, safe_on: bool, already_done: bool) -> bool:
	if not shadows_on or safe_on or already_done:
		return false
	return low_streak >= SHADOW_SAMPLES


## Counts slow samples in a run; any good one, or any outside a run,
## starts the count again.
static func low_streak(streak: int, avg_fps: float, in_run: bool) -> int:
	return streak + 1 if in_run and avg_fps < SHADOW_FPS else 0


static func shadows_notice() -> String:
	return "Shadows off to keep the game smooth.\nSETTINGS turns them back on."


## Saves from before the watchdog could tell a pause from a slow phone:
## if it switched the safe renderer on, that verdict is thrown out and
## the phone is judged again, fairly.
const WATCHDOG_VERSION := 2


static func should_retry(version: int, safe_on: bool, auto_done: bool) -> bool:
	return version < WATCHDOG_VERSION and safe_on and auto_done


static func retry_notice() -> String:
	return "Full graphics are back on: the game runs lighter now.\nSETTINGS has SAFE GRAPHICS if you want it."


## What the player is told when it happens.
static func notice() -> String:
	return "Graphics lowered for this phone.\nChange it in SETTINGS."
