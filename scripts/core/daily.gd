class_name Daily
extends RefCounted
## The daily run: everyone gets the same seed for a given UTC day, plays
## with no shop upgrades and the rifle squad, and shares a one-line result.
## Pure helpers; the game supplies the clock.

const SECONDS_PER_DAY := 86400
## Day numbers count from this date so the first daily is #1, not #20000.
const EPOCH_DAY := 20748  # 2026-10-22 is day 20748 since 1970-01-01
const KEEP_DAYS := 7


static func day_number(unix_time: int) -> int:
	return unix_time / SECONDS_PER_DAY - EPOCH_DAY + 1


static func seed_for_day(day: int) -> int:
	# Spread consecutive days apart so neighbouring seeds do not feel alike.
	return int((day * 2654435761) % 2147483647)


static func label(day: int) -> String:
	return "DAILY #%d" % day


## The text a player pastes into a chat.
static func share_text(day: int, score: int, level: int, kills: int, peak: int) -> String:
	return "Shooty McBridgeface daily #%d\nScore %d · level %d · %d kills · peak squad %d\nhttps://github.com/Reconnaishawnce/shootymcbridgeface" % [day, score, level, kills, peak]


# --- the weekly ------------------------------------------------------------
## One seed per UTC week, played on hard with no upgrades. Weeks count
## from the same epoch as days, so week 1 holds day 1.

const KEEP_WEEKS := 4
const WEEKLY_MODIFIER := "hard"


static func week_number(unix_time: int) -> int:
	return (day_number(unix_time) - 1) / 7 + 1


static func seed_for_week(week: int) -> int:
	return int((week * 40503 + 7919) * 2654435761 % 2147483647)


static func week_label(week: int) -> String:
	return "WEEKLY #%d" % week


static func week_share_text(week: int, score: int, level: int, kills: int, peak: int) -> String:
	return "Shooty McBridgeface weekly #%d (hard)\nScore %d · level %d · %d kills · peak squad %d\nhttps://github.com/Reconnaishawnce/shootymcbridgeface" % [week, score, level, kills, peak]


## Keep only the newest KEEP_WEEKS results. [param results] maps week -> dict.
static func prune_weeks(results: Dictionary, this_week: int) -> Dictionary:
	var out := {}
	for k in results:
		var w := int(k)
		if w > this_week - KEEP_WEEKS and w <= this_week:
			out[w] = results[k]
	return out


## Keep only the newest KEEP_DAYS results. [param results] maps day -> dict.
static func prune(results: Dictionary, today: int) -> Dictionary:
	var out := {}
	for k in results:
		var d := int(k)
		if d > today - KEEP_DAYS and d <= today:
			out[d] = results[k]
	return out


## Fold a finished run into the results for [param day]. Returns the
## updated results and whether it was that day's new best.
static func record(results: Dictionary, day: int, score: int, level: int, kills: int, peak: int) -> Dictionary:
	var prev: Dictionary = results.get(day, {})
	var best := score > int(prev.get("score", -1))
	if best:
		results[day] = {"score": score, "level": level, "kills": kills, "peak": peak}
	return {"results": results, "new_best": best}
