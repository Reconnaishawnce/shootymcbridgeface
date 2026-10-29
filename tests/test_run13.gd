extends TestCase


func test_stats_merge() -> void:
	var total := Stats.blank()
	check_eq(total.size(), Stats.KEYS.size(), "blank has every key")
	total = Stats.merge(total, {"kills": 10, "best_combo": 40, "runs": 1})
	total = Stats.merge(total, {"kills": 5, "best_combo": 20, "runs": 1, "bogus": 9})
	check_eq(int(total.kills), 15, "sums")
	check_eq(int(total.best_combo), 40, "keeps the best")
	check_eq(int(total.runs), 2, "runs")
	check(not total.has("bogus"), "unknown keys dropped")
	check(Stats.lines(total).size() >= 8, "records lines")


func test_achievements() -> void:
	var ids := {}
	for a in Achievements.CATALOG:
		check(not ids.has(a.id), "unique id %s" % a.id)
		ids[a.id] = true
		check(Stats.KEYS.has(a.key), "known stat key for %s" % a.id)
		check(int(a.stars) >= 1, "pays at least a star")
	var stats := Stats.merge(Stats.blank(), {"kills": 150, "bosses": 1})
	var fresh := Achievements.newly_done(stats, [])
	check(fresh.has("blood_100") and fresh.has("boss_1") and not fresh.has("blood_1k"), "thresholds")
	check_eq(Achievements.stars_for(fresh), 2, "two stars")
	var again := Achievements.newly_done(stats, fresh)
	check(again.is_empty(), "paid once")
	var rows := Achievements.rows(stats, fresh)
	check_eq(rows.size(), Achievements.CATALOG.size(), "a row each")
	check(rows[0].done and rows[0].progress == 100, "first row done and capped")


func test_help_text() -> void:
	var sections := HelpText.sections()
	check(sections.size() >= 12, "enough sections (%d)" % sections.size())
	var all := ""
	for sec in sections:
		check(str(sec.title) != "" and str(sec.body).length() > 40, "section has a title and a body")
		all += str(sec.body) + "\n"
	for word in ["BLUE", "RED", "TEAL", "PURPLE", "AMBER", "PERFECT", "coins", "Stars", "LOCKER", "HARD", "NIGHTMARE", "ENDLESS", "DAILY", "WEEKLY", "GRADE", "horde", "STORM", "dash", "OLIVE", "JEEP", "TANK", "HELICOPTER", "MECH", "RANK", "QUESTS", "SEASON", "ROAD", "RALLY", "trophies", "STRAIGHT", "bounty", "SAW", "THICK SKIN", "RECRUITER"]:
		check(all.contains(word), "help mentions %s" % word)
	for id in Powerups.ORDER:
		check(all.contains(Powerups.title(id)), "help mentions power-up %s" % id)
	check(all.contains("level %d" % Progression.DASH_LEVEL), "dash level comes from the constant")
	check(all.contains("%d gates and a boss" % Difficulty.GATES_PER_LEVEL), "gates per level from the constant")


func test_storm() -> void:
	check_eq(Difficulty.boss_kind(3), Boss.Kind.STORM, "level 3 is the storm")
	check_eq(Difficulty.boss_kind(1), Boss.Kind.WALKER, "level 1 walker")
	check_eq(Difficulty.boss_kind(2), Boss.Kind.SPITTER, "level 2 spitter")
	check_eq(Difficulty.boss_kind(6), Boss.Kind.STORM, "level 6 storm again")
	var line := Difficulty.storm_line(8.25, 0.0)
	check(line.size() >= 5, "a five-lane line has bolts (%d)" % line.size())
	for x in line:
		check(absf(x) > Difficulty.STORM_GAP * 0.5, "no bolt in the gap")
		check(absf(x) <= 8.25, "bolts stay on the road")
	var edge := Difficulty.storm_line(3.3, 2.5)
	check(edge.size() >= 1, "a narrow road still has a bolt beside the gap")
	check(Difficulty.boss_hp(3) < Difficulty.boss_hp(3) / Difficulty.STORM_HP_MULT, "storm carries less health")
