class_name Events
extends RefCounted
## Events: a weekend modifier that changes the road for everyone two
## days a week, and the weekly challenge, a twist the whole week's
## shared run carries so the weekly board is a different contest every
## week. Pure: which event is on, and the knobs it turns. The world and
## the game read the knobs.

## The knobs an event can turn, with their resting values.
const DEFAULT_MODS := {
	"bounty_mult": 1.0, "fog": false, "reveal_penalty": 0.0,
	"saws_extra": 0, "saw_speed": 0.0, "elite_all": false, "speed_bonus": 0.0,
}
const CATALOG := {
	"double_bounty": {"title": "DOUBLE BOUNTY", "body": "Every kill pays twice. Spend it at the pit.", "mods": {"bounty_mult": 2.0}},
	"fog": {"title": "FOG ON THE BRIDGE", "body": "Panels show late and the far road is grey. Read fast.", "mods": {"fog": true, "reveal_penalty": 9.0}},
	"saw_storm": {"title": "SAW STORM", "body": "Two more saws a level, and faster. Keep moving.", "mods": {"saws_extra": 2, "saw_speed": 2.0}},
	"elite_waves": {"title": "ELITE WAVES", "body": "Every wave brings brutes and a tank.", "mods": {"elite_all": true}},
	"fast_road": {"title": "FAST ROAD", "body": "The road runs faster all the way.", "mods": {"speed_bonus": 2.0}},
}
## Weekend events rotate week by week; the weekly challenge has its own
## rotation, so a weekend and a weekly never line up for long.
const WEEKEND := ["double_bounty", "saw_storm", "fog"]
const WEEKLY := ["fog", "saw_storm", "elite_waves", "fast_road"]
## Days of the week that count as the weekend (0 is Sunday).
const WEEKEND_DAYS := [0, 6]


static func title(id: String) -> String:
	return str(CATALOG.get(id, {}).get("title", ""))


static func body(id: String) -> String:
	return str(CATALOG.get(id, {}).get("body", ""))


static func is_weekend(unix_time: int) -> bool:
	return int(Time.get_datetime_dict_from_unix_time(unix_time).weekday) in WEEKEND_DAYS


## The weekend event on at [param unix_time], or "" on a weekday.
static func weekend_event(unix_time: int) -> String:
	if not is_weekend(unix_time):
		return ""
	return WEEKEND[posmod(Daily.week_number(unix_time), WEEKEND.size())]


## The twist every weekly run of [param week] carries.
static func weekly_challenge(week: int) -> String:
	return WEEKLY[posmod(week, WEEKLY.size())]


## The knobs for a set of events, merged over the defaults: multipliers
## multiply, counts add, flags or together, bonuses take the larger.
static func mods(ids: Array) -> Dictionary:
	var out := DEFAULT_MODS.duplicate()
	for id in ids:
		if not CATALOG.has(id):
			continue
		var m: Dictionary = CATALOG[id]["mods"]
		for k in m:
			match k:
				"bounty_mult":
					out[k] = float(out[k]) * float(m[k])
				"saws_extra":
					out[k] = int(out[k]) + int(m[k])
				"fog", "elite_all":
					out[k] = bool(out[k]) or bool(m[k])
				_:
					out[k] = maxf(float(out[k]), float(m[k]))
	return out


## Which events a run of [param mode] at [param unix_time] carries: the
## weekly challenge for a weekly run, the weekend event for every other
## mode (the daily included: everyone plays the same day).
static func for_run(mode: String, unix_time: int) -> Array:
	if mode == "weekly":
		return [weekly_challenge(Daily.week_number(unix_time))]
	var w := weekend_event(unix_time)
	return [w] if w != "" else []


## One line for the home screen, or "".
static func banner(unix_time: int) -> String:
	var w := weekend_event(unix_time)
	if w == "":
		return ""
	return "WEEKEND EVENT: %s  ·  %s" % [title(w), body(w)]


## The weekly's line: what this week's run carries.
static func weekly_line(week: int) -> String:
	var c := weekly_challenge(week)
	return "WEEK %d CHALLENGE: %s  ·  %s" % [week, title(c), body(c)]
