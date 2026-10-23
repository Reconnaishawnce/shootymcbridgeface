extends TestCase


func test_weekly() -> void:
	var day1 := (Daily.EPOCH_DAY) * Daily.SECONDS_PER_DAY
	check_eq(Daily.day_number(day1), 1, "epoch day is day one")
	check_eq(Daily.week_number(day1), 1, "day one is week one")
	check_eq(Daily.week_number(day1 + 6 * Daily.SECONDS_PER_DAY), 1, "day seven still week one")
	check_eq(Daily.week_number(day1 + 7 * Daily.SECONDS_PER_DAY), 2, "day eight is week two")
	check(Daily.seed_for_week(1) != Daily.seed_for_week(2), "weeks differ")
	check(Daily.seed_for_week(3) != Daily.seed_for_day(3), "weekly seed is not the daily's")
	check(Daily.week_label(4).contains("4"), "label")
	var r := Daily.prune_weeks({1: {}, 2: {}, 5: {}, 9: {}}, 5)
	check(r.has(2) and r.has(5) and not r.has(1) and not r.has(9), "keeps the last four weeks, nothing future")
	check(Daily.week_share_text(2, 10, 3, 4, 5).contains("weekly #2"), "share text")
	check_eq(Daily.WEEKLY_MODIFIER, "hard", "the weekly is hard")


func test_scout() -> void:
	var p := GateMath.scout(4)
	check_eq(GateMath.label(p), "SCOUT -4", "label")
	check_eq(GateMath.apply(20, p), 16, "scouts cost soldiers")
	check(GateMath.is_deal(p) and GateMath.is_scout(p) and not GateMath.is_trade(p), "flags")
	GateMath.register_hit(p, 3.0, 3.0)
	check_eq(GateMath.label(p), "SCOUT -3", "cheaper when shot")
	for i in range(5):
		GateMath.register_hit(p, 3.0, 3.0)
	check_eq(GateMath.label(p), "SCOUT 0", "never pays you")
	var gen := Difficulty.new(4)
	var scouts := 0
	for level in range(1, 8):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var lanes := Progression.lanes_for(level, i)
			for q in gen.make_gate(level, i, 30, lanes):
				if GateMath.is_scout(q):
					scouts += 1
					check(level >= Difficulty.SCOUT_LEVEL and lanes >= 3, "scouts need hidden panels and a third lane")
	check(scouts > 2, "scouts appear (%d)" % scouts)


func test_cheer_lines() -> void:
	check(Wardrobe.cheer_line("LUNA", "S", 0).begins_with("LUNA: "), "named")
	check(Wardrobe.cheer_line("LUNA", "S", 0) != Wardrobe.cheer_line("LUNA", "S", 1), "varies")
	check(Wardrobe.cheer_line("MAX", "Z", 7).length() > 5, "unknown grade still speaks")
