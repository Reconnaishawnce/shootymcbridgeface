class_name Streak
extends RefCounted
## Playing on consecutive days builds a streak, and the streak pays:
## BONUS_PER_DAY more coins at the end of every run, up to BONUS_CAP.
## Miss a day and it starts over. Pure; the game hands in the day.

const BONUS_PER_DAY := 0.05
const BONUS_CAP := 0.5


static func blank() -> Dictionary:
	return {"days": 0, "last_day": -1, "best": 0}


## A run finished on [param day]: the streak grows, holds, or resets.
static func advance(state: Dictionary, day: int) -> Dictionary:
	var st := state.duplicate()
	var last := int(st.get("last_day", -1))
	var days := int(st.get("days", 0))
	if last == day:
		return st
	days = days + 1 if last == day - 1 else 1
	st.days = days
	st.last_day = day
	st.best = maxi(int(st.get("best", 0)), days)
	return st


## Whether a streak is still alive on [param day]: played today or
## yesterday.
static func alive(state: Dictionary, day: int) -> bool:
	var last := int(state.get("last_day", -1))
	return int(state.get("days", 0)) > 0 and (last == day or last == day - 1)


## Days to show: the streak, or 0 once it has lapsed.
static func days(state: Dictionary, day: int) -> int:
	return int(state.get("days", 0)) if alive(state, day) else 0


## The coin multiplier for a streak of [param p_days].
static func bonus_mult(p_days: int) -> float:
	return 1.0 + minf(BONUS_CAP, BONUS_PER_DAY * float(maxi(p_days - 1, 0)))


static func bonus_percent(p_days: int) -> int:
	return int(round((bonus_mult(p_days) - 1.0) * 100.0))


## One line for the home screen; empty when there is no streak.
static func line(state: Dictionary, day: int) -> String:
	var d := days(state, day)
	if d <= 1:
		return "" if d == 0 else "DAY 1  ·  play tomorrow for +%d%% coins" % bonus_percent(2)
	var pct := bonus_percent(d)
	if int(state.get("last_day", -1)) == day:
		return "DAY %d STREAK  ·  +%d%% coins" % [d, pct]
	return "DAY %d STREAK  ·  +%d%% coins  ·  play today to keep it" % [d, pct]
