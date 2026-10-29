extends TestCase


func test_catalog_and_order() -> void:
	check_eq(Lessons.ORDER.size(), Lessons.CATALOG.size(), "every lesson is listed once")
	for id in Lessons.ORDER:
		check(Lessons.CATALOG.has(id), "ordered id exists: %s" % id)
		check(Lessons.title(id) != "" and Lessons.body(id).length() > 40, "a real lesson: %s" % id)
		check(Lessons.body(id).length() < 420, "short enough to read on a phone: %s" % id)
	check(Lessons.perk_body(["rapid", "skin"]).contains("THICK SKIN: Every heavy bite takes a third less."), "the perk lesson names the perks on offer")
	check_eq(Lessons.boss_lesson("storm"), "boss_storm", "boss lesson by kind")
	check_eq(Lessons.for_level(1), [], "level one teaches by playing")
	check(Lessons.for_level(Progression.DASH_LEVEL).has("dash"), "dash arrives with its level")
	check(Lessons.for_level(Progression.HOT_LEVEL).has("hot"), "hot panels too")


func test_due_and_seen() -> void:
	check(Lessons.due("fork", [], true, false, 99.0), "unseen and on: due")
	check(not Lessons.due("fork", ["fork"], true, false, 99.0), "seen: not due")
	check(Lessons.due("fork", ["fork"], true, true, 99.0), "a learning round shows everything again")
	check(not Lessons.due("fork", [], false, true, 99.0), "lessons off: never")
	check(not Lessons.due("fork", [], true, false, 1.0), "too soon after the last one")
	check(not Lessons.due("nope", [], true, false, 99.0), "unknown lesson never pops")
	var seen := Lessons.mark_seen([], "fork")
	seen = Lessons.mark_seen(seen, "fork")
	check_eq(seen, ["fork"], "seen once, kept once")
