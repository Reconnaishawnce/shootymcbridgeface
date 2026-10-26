class_name Revive
extends RefCounted
## The rally: once a run, when the squad hits zero, a few stars buy a
## small squad back and the run goes on. The price climbs through the
## day so it is a safety net, not a habit. Never in the daily or the
## weekly, where everyone shares one road. Pure.

const PRICES := [3, 5, 8]
const SOLDIERS := 8
const OFFER_SECONDS := 5.0


static func price(uses_today: int) -> int:
	return int(PRICES[clampi(uses_today, 0, PRICES.size() - 1)])


static func allowed(mode: String) -> bool:
	return mode != "daily" and mode != "weekly"


## Uses so far today, from a saved {day, count}.
static func uses_today(saved: Dictionary, day: int) -> int:
	return int(saved.get("count", 0)) if int(saved.get("day", -1)) == day else 0


static func note_use(saved: Dictionary, day: int) -> Dictionary:
	return {"day": day, "count": uses_today(saved, day) + 1}
