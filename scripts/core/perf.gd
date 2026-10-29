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


## What the player is told when it happens.
static func notice() -> String:
	return "Graphics lowered for this phone.\nChange it in SETTINGS."
