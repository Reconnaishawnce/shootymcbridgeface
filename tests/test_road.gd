extends TestCase


func test_trophies() -> void:
	check_eq(Road.trophies_for_run(1, [], "normal", false), Road.PER_LEVEL, "a level-one wipe still moves the road")
	check_eq(Road.trophies_for_run(4, ["S", "A", "B"], "normal", false), 40 + 15 + 10 + 5, "levels and grades")
	check_eq(Road.trophies_for_run(4, ["S", "A", "B"], "hard", false), 140, "double on hard")
	check_eq(Road.trophies_for_run(4, ["S", "A", "B"], "nightmare", false), 210, "triple on nightmare")
	check_eq(Road.trophies_for_run(9, [], "normal", true), 45, "endless pays half by level")
	check(Road.trophies_for_run(2, ["D"], "normal", false) >= 0, "never negative")


func test_milestones_and_unlocks() -> void:
	check_eq(Road.milestone_count(0), 0, "start")
	check_eq(Road.milestone_count(250), 2, "two milestones")
	check_eq(Road.next_milestone(250), 300, "next")
	check_eq(Road.checkpoint(1240), 1000, "checkpoint floor")
	check(not Road.is_unlocked("hard", 599) and Road.is_unlocked("hard", 600), "hard at 600")
	check(Road.is_unlocked("endless", 300) and not Road.is_unlocked("nightmare", 1499), "endless at 300, nightmare at 1500")
	for feature in Road.UNLOCKS:
		var k := int(Road.UNLOCKS[feature]) / Road.MILESTONE
		check_eq(Road.reward(k).kind, "unlock", "the unlock sits on its milestone: %s" % feature)
		check_eq(Road.reward(k).id, feature, "and names the feature")
	var kinds := {}
	for k in range(1, Road.LENGTH / Road.MILESTONE + 1):
		var r := Road.reward(k)
		kinds[r.kind] = true
		if r.kind == "item":
			check(Wardrobe.CATALOG.has(r.id), "road item exists: %s" % r.id)
		check(Road.reward_text(r) != "", "text")
	check(kinds.has("coins") and kinds.has("stars") and kinds.has("item") and kinds.has("unlock"), "all reward kinds appear")


func test_advance() -> void:
	var out := Road.advance(0, 150)
	check_eq(int(out.trophies), 150, "total")
	check_eq(out.rewards.size(), 1, "one milestone")
	out = Road.advance(int(out.trophies), 500)
	check_eq(out.rewards.size(), 5, "five more (200 to 600)")
	check_eq(int(out.checkpoint), 500, "checkpoint")
	var capped := Road.advance(Road.LENGTH - 50, 1000)
	check_eq(int(capped.trophies), Road.LENGTH, "capped at the end")
	check(Road.rows(250).size() >= 8, "rows around you")
	check(Road.rows(250)[0].done, "rows start with done ones")


func test_revive() -> void:
	check_eq(Revive.price(0), 3, "first rally")
	check_eq(Revive.price(2), 8, "third")
	check_eq(Revive.price(9), 8, "stays at the top")
	check(Revive.allowed("levels") and Revive.allowed("endless"), "allowed in free modes")
	check(not Revive.allowed("daily") and not Revive.allowed("weekly"), "never on a shared road")
	var saved := {}
	check_eq(Revive.uses_today(saved, 5), 0, "fresh")
	saved = Revive.note_use(saved, 5)
	saved = Revive.note_use(saved, 5)
	check_eq(Revive.uses_today(saved, 5), 2, "counted")
	check_eq(Revive.uses_today(saved, 6), 0, "a new day resets")
