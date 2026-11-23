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
	check(sections.size() >= 12 and sections.size() <= 18, "a page, not a manual: %d sections" % sections.size())
	var all := ""
	for sec in sections:
		check(str(sec.title) != "" and str(sec.body).length() > 40, "section has a title and a body")
		# Short sections, plain words: the page had grown to thirty-eight
		# sections nobody read.
		check(Notices.words(str(sec.body)) <= HelpText.MAX_SECTION_WORDS, "%s is short enough to read: %d words" % [sec.title, Notices.words(str(sec.body))])
		all += str(sec.body) + "\n"
	# Every panel colour that is on the road, and none that is not.
	for word in ["BLUE", "RED", "PURPLE", "OLIVE"]:
		check(all.contains(word), "help explains %s panels" % word)
	for word in ["TEAL", "AMBER", "GREY panels", "GOLD panels", "PERK gate", "forks"]:
		check(not all.contains(word), "help does not explain %s: it is not in the game" % word)
	for word in ["PERFECT", "coins", "Stars", "LOCKER", "SHOP", "HARD", "NIGHTMARE", "ENDLESS", "DAILY", "WEEKLY", "BOSS RUSH", "RALLY", "ENLIST", "MAXED", "one whole soldier", "Nobody is unbeatable", "PIT STOP", "DRAG", "HOLD", "TAP", "SHAKE", "FLICK", "core", "BRUTES", "TANKS", "Thieves", "splitters", "QUEST CHEST", "ROAD CHEST", "GOLD CHEST", "FLIGHT RECORDER", "LOGGING in SETTINGS", "REPORT A PROBLEM", "SAFE GRAPHICS", "GREEN", "ORANGE BOMBS", "SAW BLADES", "LIGHTNING", "cannot walk past"]:
		check(all.contains(word), "help mentions %s" % word)
	for id in Powerups.ORDER:
		check(all.contains(Powerups.title(id)), "help mentions power-up %s" % id)
	for id in Cards.ORDER:
		check(all.contains(Cards.title(id)) and all.contains(Cards.description(id)), "help says what the card %s does" % id)
	for id in Cards.COMBO_ORDER:
		check(all.contains(Cards.combo_title(id)), "help mentions combo %s" % id)
	check(all.contains("COMMON") and all.contains("RARE") and all.contains("EPIC"), "help explains the draft")
	for id in Heroes.ORDER:
		check(all.contains(Wardrobe.title(id)) and all.contains(Heroes.short(id)), "help says what %s does" % id)
	for id in PitStop.ORDER:
		check(all.contains(PitStop.title(id).to_lower()), "help lists the pit stop's %s" % id)
	for id in Themes.ORDER:
		if Themes.rule(id) != "":
			check(all.contains(Themes.title(id)) and all.contains(Themes.rule(id)), "help says the rule of %s" % id)
	# The ladder is on the page, with the numbers the game uses.
	for level in [Progression.MUL_LEVEL, Progression.CLING_LEVEL, Progression.PIT_LEVEL, Progression.SAW_LEVEL, Progression.LATCHER_LEVEL, Progression.BARRICADE_LEVEL, Progression.THIEF_LEVEL, Progression.TANK_LEVEL, Progression.SPLITTER_LEVEL, Progression.VEHICLE_LEVEL]:
		check(all.contains("Level %d:" % level), "the ladder lists level %d" % level)
	check(all.contains("level %d" % Progression.DASH_LEVEL), "dash level comes from the constant")
	check(all.contains("%d gates and a boss" % Difficulty.GATES_PER_LEVEL), "gates per level from the constant")
	check(all.contains("every bullet kills a zombie"), "and it says what level 1 is")


func test_storm() -> void:
	check_eq(Difficulty.boss_kind(Difficulty.STORM_BOSS_LEVEL), Boss.Kind.STORM, "the storm arrives at STORM_BOSS_LEVEL")
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
