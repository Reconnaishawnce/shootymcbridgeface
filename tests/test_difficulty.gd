extends TestCase


func test_tiers_are_monotonic_in_level() -> void:
	var last := -1
	for level in range(1, 30):
		var t := Difficulty.tier_for_level(level)
		check(t >= last, "tier never drops at level %d" % level)
		last = t
	check_eq(Difficulty.tier_for_level(1), 0, "level 1 is tier 0")
	check_eq(Difficulty.tier_for_level(7), 3, "level 7 is top tier")


func test_level_layout() -> void:
	check_eq(Difficulty.gate_distance(0), Difficulty.FIRST_GATE_AT, "first gate")
	check(Difficulty.wave_distance(0) > Difficulty.gate_distance(0), "wave after its gate")
	check(Difficulty.wave_distance(0) < Difficulty.gate_distance(1), "wave before next gate")
	check(Difficulty.boss_distance() > Difficulty.gate_distance(Difficulty.GATES_PER_LEVEL - 1), "boss after last gate")


func test_curves_are_bounded_and_increasing() -> void:
	check_near(Difficulty.world_speed(1), 8.0, 0.001, "base speed")
	check(Difficulty.world_speed(100) <= 12.0, "speed capped")
	check(Difficulty.boss_world_speed() < Difficulty.world_speed(1), "boss fight slows the road")
	check(Difficulty.step_cost(5) > Difficulty.step_cost(1), "step cost grows")
	check_near(Difficulty.effective_step_cost(1, 1.0), 3.0, 0.001, "floor applies to a tiny squad")
	check_near(Difficulty.effective_step_cost(1, 100.0), 90.0, 0.001, "big squad pays its own dps")
	check(Difficulty.wave_for(3, 2).count > Difficulty.wave_for(1, 0).count, "waves grow")
	check(Difficulty.wave_for(3, 2).hp > Difficulty.wave_for(1, 0).hp, "hp grows")
	check(Difficulty.wave_for(1, 7).count > Difficulty.wave_for(1, 0).count, "waves grow inside a level")
	check(Difficulty.wave_for(6, 0).count <= 8, "a late level still opens gently (got %d)" % Difficulty.wave_for(6, 0).count)
	check_eq(Difficulty.wave_for(1, 0).brutes, 0, "no brutes at the very start")
	check_eq(Difficulty.wave_for(5, 0).brutes, 0, "no brutes on any level's opener")
	check(Difficulty.wave_for(2, 2).brutes >= 1, "brutes from level 2")
	check(Difficulty.wave_for(1, 4).brutes >= 1, "brutes late in level 1")
	check_eq(Difficulty.wave_for(1, 3).thieves, 0, "no thieves on level 1")
	check(Difficulty.wave_for(2, 1).thieves >= 1, "thieves from level 2 on odd gates")
	check_eq(Difficulty.wave_for(2, 0).thieves, 0, "no thieves on the opener")
	check_eq(Difficulty.wave_for(2, 2).tanks, 0, "no tanks on level 2")
	check_eq(Difficulty.wave_for(3, 2).tanks, 1, "a tank on level 3 gate 3")
	check(Difficulty.wave_for(3, 2, 300).tank_hp > Difficulty.wave_for(3, 2, 1).tank_hp * 5.0, "tanks soak a big squad")
	check(Difficulty.wave_for(1, 2, 200).count > Difficulty.wave_for(1, 2, 1).count, "big squads draw crowds")
	check(Difficulty.wave_for(1, 2, 100000).count <= Difficulty.MAX_WAVE, "wave capped")
	check(Difficulty.wave_for(1, 2, 500).brute_hp > Difficulty.wave_for(1, 2, 1).brute_hp * 10.0, "brutes soak a big squad")
	check_eq(Difficulty.brute_bite(10), 3, "brute bite floor")
	check_eq(Difficulty.brute_bite(1000), 80, "brute bite scales")


func test_boss_curve() -> void:
	var last := 0.0
	for level in range(1, 20, 2):
		var hp := Difficulty.boss_hp(level)
		check(hp > last, "walker hp grows at level %d" % level)
		last = hp
	last = 0.0
	for level in range(2, 20, 2):
		var hp := Difficulty.boss_hp(level)
		check(hp > last, "spitter hp grows at level %d" % level)
		last = hp
	check(Difficulty.boss_hp(2) < Difficulty.boss_hp(3), "spitters carry less than the next walker")
	check(Difficulty.boss_hp(3, 5) > Difficulty.boss_hp(3, 0), "perks make bosses tougher")
	check_near(Difficulty.boss_hp(3, 5) / Difficulty.boss_hp(3, 0), 1.3, 0.001, "6% per perk")
	check_eq(Difficulty.spit_bite(10), 2, "spit bite floor")
	check_eq(Difficulty.spit_bite(100), 8, "spit bite scales")
	check_eq(Difficulty.boss_kind(1), Boss.Kind.WALKER, "odd levels walk")
	check_eq(Difficulty.boss_kind(2), Boss.Kind.SPITTER, "even levels spit")
	check_eq(Difficulty.tank_bite(10), 5, "tank bite floor")
	check_eq(Difficulty.tank_bite(200), 30, "tank bite scales")
	check_near(Difficulty.boss_hp(1), 100.0 * 2.5 * 7.0, 0.001, "level 1 boss is 7 s of a 100 squad")
	check_eq(Difficulty.boss_bite(10), 2, "boss bite floor")
	check_eq(Difficulty.boss_bite(100), 12, "boss bite scales")
	check(Difficulty.level_bonus(2, 10) > Difficulty.level_bonus(1, 10), "bonus grows with level")


func test_first_gate_of_every_level_is_a_clear_positive_choice() -> void:
	for s in range(120):
		var gen := Difficulty.new(s)
		for level in [1, 2, 5, 9]:
			var pair := gen.make_gate_pair(level, 0)
			check_eq(pair.size(), 2, "pair size")
			var any_good := false
			for p in pair:
				check(p.revealed, "opener never hidden (seed %d level %d)" % [s, level])
				check_eq(p.kind, GateMath.Kind.ADD, "opener is additive (seed %d level %d)" % [s, level])
				if GateMath.is_good(p):
					any_good = true
			check(any_good, "opener offers a gain (seed %d level %d)" % [s, level])


func test_generation_is_deterministic() -> void:
	var a := Difficulty.new(99)
	var b := Difficulty.new(99)
	for level in range(1, 6):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var pa := a.make_gate_pair(level, i)
			var pb := b.make_gate_pair(level, i)
			for j in range(2):
				check_eq(pa[j].kind, pb[j].kind, "kind matches at %d/%d" % [level, i])
				check_near(pa[j].value, pb[j].value, 0.0001, "value matches at %d/%d" % [level, i])
				check_eq(pa[j].revealed, pb[j].revealed, "hidden matches at %d/%d" % [level, i])


func test_multipliers_are_rare() -> void:
	var gen := Difficulty.new(3)
	var muls := 0
	var total := 0
	for level in range(1, 40):
		for i in range(Difficulty.GATES_PER_LEVEL):
			for p in gen.make_gate_pair(level, i):
				total += 1
				if p.kind == GateMath.Kind.MUL and p.value > 1.0:
					muls += 1
	check(muls > 0, "some multipliers")
	check(float(muls) / float(total) < 0.2, "fewer than a fifth of panels multiply (got %d of %d)" % [muls, total])


func test_big_squads_get_no_multipliers() -> void:
	var gen := Difficulty.new(11)
	for level in range(1, 20):
		for i in range(Difficulty.GATES_PER_LEVEL):
			for p in gen.make_gate_pair(level, i, Difficulty.BIG_SQUAD):
				check(not (p.kind == GateMath.Kind.MUL and p.value > 1.0), "no x2/x3 for a big squad at %d/%d" % [level, i])


func test_values_stay_in_sane_ranges() -> void:
	var gen := Difficulty.new(7)
	var hidden_seen := false
	for level in range(1, 40):
		for i in range(Difficulty.GATES_PER_LEVEL):
			for p in gen.make_gate_pair(level, i):
				if p.kind == GateMath.Kind.MUL:
					check(p.value == 0.5 or p.value == 2.0 or p.value == 3.0, "mul is 0.5, 2 or 3 at %d/%d" % [level, i])
				else:
					check(p.value >= -25.0 and p.value <= 12.0, "add in range at %d/%d" % [level, i])
				if not p.revealed:
					hidden_seen = true
	check(hidden_seen, "hidden panels appear over a long run")
