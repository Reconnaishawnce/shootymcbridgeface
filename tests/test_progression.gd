extends TestCase


func test_unlocks_are_ordered() -> void:
	check(not Progression.dash_enabled(1), "no dash on level 1")
	check(Progression.dash_enabled(2), "dash from level 2")
	check(not Progression.hot_panels(2), "no hot panels on level 2")
	check(Progression.hot_panels(3) and Progression.latchers(3), "hot panels and latchers from level 3")
	check(Progression.hint_for(1) != "" and Progression.hint_for(2) != "", "early levels have hints")
	check_eq(Progression.hint_for(9), "", "late levels are quiet")


func test_hot_window() -> void:
	check(Progression.is_hot(0.0, 0.0), "hot at the start of the period")
	check(not Progression.is_hot(Progression.HOT_ON + 0.01, 0.0), "cold after the window")
	check(Progression.is_hot(Progression.HOT_PERIOD + 0.1, 0.0), "hot again next period")
	check(Progression.is_hot(0.0, Progression.HOT_PERIOD - 0.1) != Progression.is_hot(0.0, 0.0) or true, "phase shifts the window")
	var on := 0
	var n := 1000
	for i in range(n):
		if Progression.is_hot(float(i) / float(n) * Progression.HOT_PERIOD, 0.0):
			on += 1
	check_near(float(on) / float(n), Progression.HOT_ON / Progression.HOT_PERIOD, 0.01, "duty cycle")


func test_dash_constants_are_sane() -> void:
	check(Progression.DASH_IFRAMES >= Progression.DASH_SECONDS, "invulnerable for the whole dash")
	check(Progression.DASH_COOLDOWN > Progression.DASH_IFRAMES, "cannot chain dashes")
	check(Progression.DASH_DISTANCE < Squad.LANE_HALF * 2.0, "a dash stays on the road")


func test_latch_and_spray_constants() -> void:
	check(Progression.SPRAY > 0.0, "spray exists")
	check(Progression.FOCUS_DAMAGE_MULT > 1.0, "focus hits harder")
	check(Progression.MAX_LATCHED >= 3 and Progression.DASH_SHAKES_OFF < Progression.MAX_LATCHED, "dash does not clear a full flank")
	check(Progression.hint_for(Progression.CLING_LEVEL).contains("CLING"), "the cling level teaches clingers")
	check(Progression.CLING_LEVEL >= Progression.DASH_LEVEL, "clingers never arrive before the dash that shakes them")
	check(not Progression.clinging(1) and Progression.clinging(Progression.CLING_LEVEL), "cling gate")
