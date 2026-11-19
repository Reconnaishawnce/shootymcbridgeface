extends TestCase


func test_cycle() -> void:
	check_eq(Themes.for_level(1), "day", "level 1 is plain")
	check_eq(Themes.for_level(0), "day", "nonsense is plain")
	var seen := {}
	for level in range(2, 9):
		seen[Themes.for_level(level)] = true
	check_eq(seen.size(), Themes.ORDER.size(), "levels 2 to 8 visit every theme once")
	check_eq(Themes.for_level(2), "gold", "level 2")
	check_eq(Themes.for_level(3), "night", "level 3")
	check_eq(Themes.for_level(4), "storm", "level 4")
	check_eq(Themes.for_level(8), "day", "a breather every seventh")
	check_eq(Themes.for_level(11), Themes.for_level(4), "and round again")
	for level in range(1, 40):
		var id := Themes.for_level(level)
		check(level >= int(Themes.CATALOG[id]["min_level"]), "level %d is not too early for %s" % [level, id])
	check(int(Themes.CATALOG["works"]["min_level"]) >= Difficulty.BARRICADE_LEVEL, "roadworks needs walls to exist")
	check(int(Themes.CATALOG["saws"]["min_level"]) >= Difficulty.SAW_LEVEL, "the saw mill needs saws to exist")


func test_catalog() -> void:
	for id in Themes.ORDER:
		check(Themes.CATALOG.has(id) and Themes.LOOKS.has(id), "theme %s has a rule and a look" % id)
		check(Themes.title(id) != "", "a name: %s" % id)
		for k in Themes.mods(id):
			check(Events.DEFAULT_MODS.has(k), "%s turns a real knob: %s" % [id, k])
		for k in Themes.LOOKS["day"]:
			check(Themes.look(id).has(k), "%s's look has %s" % [id, k])
		if id != "day":
			check(Themes.rule(id).length() > 15, "a rule a player can read: %s" % id)
	check_eq(Themes.rule("day"), "", "daybreak has no rule")
	check_eq(Themes.title("nonsense"), "DAYBREAK", "an unknown theme is daybreak")
	check_eq(Themes.banner(1, "day"), "LEVEL 1", "a plain banner")
	check(Themes.banner(3, "night").begins_with("LEVEL 3  ·  NIGHT SHIFT\n"), "a themed banner names the place and the rule")


func test_looks_read() -> void:
	# The road has to stay readable everywhere: no theme goes black.
	for id in Themes.ORDER:
		var l := Themes.look(id)
		check(float(l.sun_energy) * Palette.luma(l.sun) + float(l.ambient) * 0.5 > 0.6, "%s is lit enough to read" % id)
		check(float(l.fog_density) <= 0.03, "%s's fog leaves the near road clear" % id)
	check(Themes.look("night").headlight and Themes.look("storm").rain and not Themes.look("day").rain, "the extras are where they belong")
	check(Palette.luma(Themes.look("night").sky_top) < 0.05 and Palette.luma(Themes.look("day").sky_top) > 0.15, "night is dark and day is not")


func test_blend() -> void:
	var a := Themes.look("day")
	var b := Themes.look("night")
	var half := Themes.blend(a, b, 0.5)
	check_near(float(half.sun_energy), (float(a.sun_energy) + float(b.sun_energy)) * 0.5, 0.0001, "numbers blend")
	check_near((half.sky_top as Color).b, ((a.sky_top as Color).b + (b.sky_top as Color).b) * 0.5, 0.0001, "colours blend")
	check(half.headlight == true, "flags take the destination's")
	var done := Themes.blend(a, b, 1.0)
	check_near(float(done.ambient), float(b.ambient), 0.0001, "all the way is the destination")


func test_mods_merge() -> void:
	var plain := Events.merge(Events.DEFAULT_MODS.duplicate(), Themes.mods("day"))
	check_eq(plain, Events.DEFAULT_MODS, "daybreak changes nothing")
	var night := Events.merge(Events.DEFAULT_MODS.duplicate(), Themes.mods("night"))
	check_near(float(night.pace_mult), 1.2, 0.0001, "night is faster")
	check_near(float(night.bounty_mult), 1.5, 0.0001, "and pays")
	var both := Events.merge(Events.mods(["double_bounty", "saw_storm"]), Themes.mods("saws"))
	check_eq(int(both.saws_extra), 4, "a weekend saw storm in the saw mill stacks")
	check_near(float(both.bounty_mult), 2.0, 0.0001, "and the weekend bounty holds")
	var storm := Events.merge(Events.DEFAULT_MODS.duplicate(), Themes.mods("storm"))
	check(bool(storm.strikes) and not bool(plain.strikes), "the storm strikes")
	check_eq(int(Events.merge(Events.DEFAULT_MODS.duplicate(), Themes.mods("works")).barricades_extra), 2, "roadworks adds walls")
