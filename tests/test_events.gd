extends TestCase


func test_events() -> void:
	# 2026-11-07 is a Saturday (day 20764 since 1970), 2026-11-09 a Monday.
	var sat := 20764 * 86400
	var mon := sat + 2 * 86400
	check(Events.is_weekend(sat) and not Events.is_weekend(mon), "saturday is, monday is not")
	check(Events.weekend_event(sat) != "" and Events.weekend_event(mon) == "", "an event on the weekend only")
	check(Events.CATALOG.has(Events.weekend_event(sat)), "the weekend event is a real one")
	check_eq(Events.weekend_event(sat), Events.weekend_event(sat + 86400), "the same event all weekend")
	check(Events.weekend_event(sat) != Events.weekend_event(sat + 7 * 86400) or Events.WEEKEND.size() == 1, "it rotates week to week")
	for id in Events.CATALOG:
		check(Events.title(id) != "" and Events.body(id) != "", "%s has a title and a body" % id)
	var m := Events.mods(["double_bounty", "saw_storm"])
	check_near(float(m.bounty_mult), 2.0, 0.001, "double bounty doubles")
	check_eq(int(m.saws_extra), 2, "the storm adds saws")
	check_near(float(m.saw_speed), 2.0, 0.001, "and speeds them")
	check(not bool(m.fog), "no fog unless asked")
	var two := Events.mods(["saw_storm", "saw_storm"])
	check_eq(int(two.saws_extra), 4, "counts add")
	check_eq(Events.mods([]), Events.DEFAULT_MODS, "no events, resting knobs")
	check_eq(Events.mods(["nonsense"]), Events.DEFAULT_MODS, "unknown ids change nothing")
	check(Events.for_run("weekly", mon).size() == 1 and Events.WEEKLY.has(Events.for_run("weekly", mon)[0]), "a weekly run carries its challenge")
	check_eq(Events.for_run("levels", mon).size(), 0, "a weekday run carries nothing")
	check_eq(Events.for_run("levels", sat).size(), 1, "a weekend run carries the event")
	check(Events.weekly_challenge(5) != Events.weekly_challenge(6), "the challenge changes weekly")
	check(Events.banner(mon) == "" and Events.banner(sat).begins_with("WEEKEND EVENT"), "the banner only on the weekend")
	check(Events.weekly_line(3).contains("WEEK 3"), "the weekly line names the week")
