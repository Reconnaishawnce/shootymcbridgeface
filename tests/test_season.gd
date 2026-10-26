extends TestCase


func test_quests_for_day() -> void:
	var a := Quests.for_day(12)
	var b := Quests.for_day(12)
	check_eq(a.size(), Quests.PER_DAY, "three a day")
	check_eq(a[0].title, b[0].title, "same for everyone")
	var ids := {}
	for q in a:
		ids[q.id] = true
		check(q.target > 0 and q.points > 0, "a target and a payout")
		check(not q.title.contains("%"), "title formatted")
	check_eq(ids.size(), Quests.PER_DAY, "distinct")
	check(Quests.for_day(13)[0].title != a[0].title or Quests.for_day(13)[1].title != a[1].title, "days differ")


func test_quest_progress() -> void:
	var day := 1
	var st := Quests.blank(day)
	var qs := Quests.for_day(day)
	var big := {}
	for q in qs:
		big[q.key] = q.target
	var out := Quests.advance(st, day, big)
	check_eq(out.completed.size(), Quests.PER_DAY, "a big enough run completes them all")
	check_eq(Quests.points_for(out.completed), int(qs[0].points) + int(qs[1].points) + int(qs[2].points), "points add")
	var again := Quests.advance(out.state, day, big)
	check(again.completed.is_empty(), "paid once")
	var reset := Quests.advance(out.state, day + 1, {})
	check_eq(int(reset.state.day), day + 1, "a new day resets")
	check(reset.state.done.is_empty(), "fresh quests")
	# Adding vs max.
	var k := {"id": "x", "key": "kills", "target": 100, "points": 1, "title": "", "max": false}
	var rows := Quests.rows(Quests.advance(Quests.blank(day), day, {"kills": 40, "best_combo": 10, "gates": 5}).state, day)
	check_eq(rows.size(), Quests.PER_DAY, "rows")


func test_season() -> void:
	check_eq(Season.number(1), 1, "season one")
	check_eq(Season.number(30), 1, "day thirty is season one")
	check_eq(Season.number(31), 2, "day thirty-one is season two")
	check_eq(Season.day_in_season(31), 1, "first day of season two")
	check_eq(Season.tier_for(0), 0, "no points, no tier")
	check_eq(Season.tier_for(250), 2, "two tiers")
	check_eq(Season.tier_for(99999), Season.TIERS, "capped")
	check_eq(Season.reward(1, 5).kind, "item", "fifth tier is an item")
	check_eq(Season.reward(1, 3).kind, "stars", "third tier is stars")
	check_eq(Season.reward(1, 1).kind, "coins", "first tier is coins")
	check(Season.reward(1, 5).id != Season.reward(2, 5).id, "seasons rotate the items")
	for t in range(1, Season.TIERS + 1):
		var r := Season.reward(1, t)
		if r.kind == "item":
			check(Wardrobe.CATALOG.has(r.id), "item exists: %s" % r.id)
		check(Season.reward_text(r) != "", "text")
	var st := Season.blank(1)
	var out := Season.advance(st, 1, 130)
	check_eq(int(out.state.points), 130, "points kept")
	check_eq(out.rewards.size(), 1, "tier one reached")
	check_eq(int(out.rewards[0].tier), 1, "tier number carried")
	out = Season.advance(out.state, 1, 400)
	check_eq(out.rewards.size(), 4, "tiers two to five")
	check_eq(int(out.state.claimed), 5, "claimed up to five")
	var fresh := Season.advance(out.state, 2, 0)
	check_eq(int(fresh.state.points), 0, "a new season starts over")
