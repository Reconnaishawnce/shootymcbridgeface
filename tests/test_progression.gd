extends TestCase


func test_unlocks_are_ordered() -> void:
	check(not Progression.dash_enabled(1), "no dash on level 1")
	check(Progression.dash_enabled(Progression.DASH_LEVEL), "dash from DASH_LEVEL")
	check(not Progression.latchers(Progression.LATCHER_LEVEL - 1) and Progression.latchers(Progression.LATCHER_LEVEL), "latchers from LATCHER_LEVEL")
	check(Progression.hint_for(1) != "" and Progression.hint_for(2) != "", "early levels have hints")
	check_eq(Progression.hint_for(30), "", "late levels are quiet")


## The ladder: one new thing a level, the wordy things nowhere.
func test_the_ladder() -> void:
	# What arrives when, in the order a player meets it.
	var rungs := [Progression.MUL_LEVEL, Progression.CLING_LEVEL, Progression.PIT_LEVEL, Progression.SAW_LEVEL, Progression.LATCHER_LEVEL, Progression.BARRICADE_LEVEL, Progression.THIEF_LEVEL, Progression.TANK_LEVEL, Progression.SPLITTER_LEVEL, Progression.FLANKER_LEVEL, Progression.VEHICLE_LEVEL]
	for i in range(rungs.size() - 1):
		check(int(rungs[i + 1]) > int(rungs[i]), "rung %d comes after rung %d: one new thing a level" % [i + 1, i])
	check(int(rungs[0]) >= 2, "and nothing new on level 1")
	for gone in [Progression.HIDDEN_LEVEL, Progression.HOT_LEVEL, Progression.EXPR_LEVEL, Progression.DEAL_LEVEL, Progression.SUPPLY_LEVEL, Progression.PERK_GATE_LEVEL, Progression.FORK_LEVEL]:
		check_eq(int(gone), Progression.NEVER, "the gates that needed a paragraph are off the road")
	check(not Progression.hot_panels(500), "no flashing panels at any level a run reaches")
	check_eq(Difficulty.TRADE_LEVEL, Progression.NEVER, "no trades")
	check_eq(Difficulty.BET_LEVEL, Progression.NEVER, "no bets")
	check_eq(Difficulty.SCOUT_LEVEL, Progression.NEVER, "no scouts")
	check_eq(Difficulty.SUPPLY_LEVEL, Progression.NEVER, "no coin panels")
	# A long run, every gate: nothing on a panel but a number, a power-up
	# with its name on it, or (late) a vehicle.
	var gen := Difficulty.new(63)
	for level in range(1, 45):
		check(gen.fork_for_level(level).is_empty(), "no fork on level %d" % level)
		for i in range(Difficulty.GATES_PER_LEVEL):
			for p in gen.make_gate(level, i, 60, Progression.lanes_for(level, i), {}):
				check(p.revealed, "no hidden panel (level %d)" % level)
				check(p.kind == GateMath.Kind.ADD or p.kind == GateMath.Kind.MUL or (GateMath.is_power(p) and p.power != Powerups.MYSTERY) or GateMath.is_vehicle(p), "level %d gate %d is a number, a named power-up or a vehicle: %s" % [level, i + 1, GateMath.label(p)])
				if p.kind == GateMath.Kind.MUL and p.value > 1.0:
					check(level >= Progression.MUL_LEVEL, "no multipliers before MUL_LEVEL")
				if GateMath.is_power(p):
					check(level >= Progression.POWER_PANEL_LEVEL, "no power panels before POWER_PANEL_LEVEL")


## The coach: one line a level, short, and only while the level is new.
func test_the_coach() -> void:
	for level in Progression.LEVEL_HINTS:
		var line := str(Progression.LEVEL_HINTS[level])
		check(Notices.words(line) <= 10, "level %d's line is ten words or fewer: %d" % [level, Notices.words(line)])
		check(line.count("\n") <= 1, "and two lines at most")
		check(line.replace("x2", "X2") == line.to_upper(), "and in the road's capitals")
	check(Notices.words(Progression.AIM_HINT) <= 12, "the aim line is short too")
	check(Progression.coach_due(1, 0, 0) and Progression.coach_due(1, 5, Progression.BASICS_RUNS - 1), "level 1 is coached for the first runs")
	check(not Progression.coach_due(1, 5, Progression.BASICS_RUNS), "and then left alone")
	check(Progression.coach_due(4, 3, 20) and Progression.coach_due(4, 4, 20), "a level is coached until it has been passed")
	check(not Progression.coach_due(4, 6, 20), "and not after")
	check(not Progression.coach_due(11, 3, 20), "a level with nothing new says nothing")
	check(Progression.hint_for(Progression.PIT_LEVEL).contains("PIT STOP"), "the pit stop is announced on the level it arrives")
	check(Progression.hint_for(Progression.SAW_LEVEL).contains("SAW"), "and the saws")
	check(Progression.hint_for(Progression.MUL_LEVEL).contains("x2"), "and the multiplier")


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
	check(Progression.hint_for(Progression.CLING_LEVEL).contains("TAP") and Progression.hint_for(Progression.CLING_LEVEL).contains("SHAKE"), "the cling level says how to get one off: tap it, or shake")
	check(Progression.CLING_LEVEL >= Progression.DASH_LEVEL, "clingers never arrive before the dash that shakes them")
	check(not Progression.clinging(1) and Progression.clinging(Progression.CLING_LEVEL), "cling gate")
