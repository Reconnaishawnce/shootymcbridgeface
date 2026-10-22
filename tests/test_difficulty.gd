extends TestCase


func test_tiers_are_monotonic() -> void:
	var last := -1
	for d in range(0, 2000, 10):
		var t := Difficulty.tier_for(float(d))
		check(t >= last, "tier never drops at %d" % d)
		last = t
	check_eq(Difficulty.tier_for(0.0), 0, "starts at tier 0")
	check_eq(Difficulty.tier_for(10000.0), Difficulty.TIER_EDGES.size(), "top tier")


func test_curves_are_bounded_and_increasing() -> void:
	check_near(Difficulty.world_speed(0.0), 8.0, 0.001, "base speed")
	check(Difficulty.world_speed(100000.0) <= 12.0, "speed capped")
	check(Difficulty.step_cost(500.0) > Difficulty.step_cost(0.0), "step cost grows")
	check_near(Difficulty.effective_step_cost(0.0, 1.0), 3.0, 0.001, "floor applies to a tiny squad")
	check_near(Difficulty.effective_step_cost(0.0, 100.0), 90.0, 0.001, "big squad pays its own dps")
	check(Difficulty.wave_for(400.0).count > Difficulty.wave_for(0.0).count, "waves grow")
	check(Difficulty.wave_for(400.0).hp > Difficulty.wave_for(0.0).hp, "hp grows")
	check_eq(Difficulty.wave_for(0.0).brutes, 0, "no brutes at start")
	check(Difficulty.wave_for(200.0).brutes >= 1, "brutes later")
	check(Difficulty.wave_for(100.0, 200).count > Difficulty.wave_for(100.0, 1).count, "big squads draw crowds")
	check(Difficulty.wave_for(100.0, 100000).count <= Difficulty.MAX_WAVE, "wave capped")
	check(Difficulty.wave_for(100.0, 500).brute_hp > Difficulty.wave_for(100.0, 1).brute_hp * 10.0, "brutes soak a big squad")
	check_eq(Difficulty.brute_bite(10), 3, "brute bite floor")
	check_eq(Difficulty.brute_bite(1000), 80, "brute bite scales")


func test_first_gate_is_a_clear_positive_choice() -> void:
	for s in range(200):
		var gen := Difficulty.new(s)
		var pair := gen.make_gate_pair(Difficulty.FIRST_GATE_AT)
		check_eq(pair.size(), 2, "pair size")
		var any_good := false
		for p in pair:
			check(p.revealed, "first gate never hidden (seed %d)" % s)
			check_eq(p.kind, GateMath.Kind.ADD, "first gate is additive (seed %d)" % s)
			if GateMath.is_good(p):
				any_good = true
		check(any_good, "first gate offers a gain (seed %d)" % s)


func test_generation_is_deterministic() -> void:
	var a := Difficulty.new(99)
	var b := Difficulty.new(99)
	for i in range(50):
		var d := Difficulty.FIRST_GATE_AT + i * Difficulty.GATE_SPACING
		var pa := a.make_gate_pair(d)
		var pb := b.make_gate_pair(d)
		for j in range(2):
			check_eq(pa[j].kind, pb[j].kind, "kind matches at gate %d" % i)
			check_near(pa[j].value, pb[j].value, 0.0001, "value matches at gate %d" % i)
			check_eq(pa[j].revealed, pb[j].revealed, "hidden matches at gate %d" % i)


func test_multipliers_are_rare() -> void:
	var gen := Difficulty.new(3)
	var muls := 0
	var total := 0
	for i in range(400):
		var d := Difficulty.FIRST_GATE_AT + i * Difficulty.GATE_SPACING
		for p in gen.make_gate_pair(d):
			total += 1
			if p.kind == GateMath.Kind.MUL and p.value > 1.0:
				muls += 1
	check(muls > 0, "some multipliers")
	check(float(muls) / float(total) < 0.2, "fewer than a fifth of panels multiply (got %d of %d)" % [muls, total])


func test_big_squads_get_no_multipliers() -> void:
	var gen := Difficulty.new(11)
	for i in range(200):
		var d := Difficulty.FIRST_GATE_AT + i * Difficulty.GATE_SPACING
		for p in gen.make_gate_pair(d, Difficulty.BIG_SQUAD):
			check(not (p.kind == GateMath.Kind.MUL and p.value > 1.0), "no x2/x3 for a big squad at gate %d" % i)


func test_values_stay_in_sane_ranges() -> void:
	var gen := Difficulty.new(7)
	var hidden_seen := false
	for i in range(300):
		var d := Difficulty.FIRST_GATE_AT + i * Difficulty.GATE_SPACING
		for p in gen.make_gate_pair(d):
			if p.kind == GateMath.Kind.MUL:
				check(p.value == 0.5 or p.value == 2.0 or p.value == 3.0, "mul is 0.5, 2 or 3 at %d" % i)
			else:
				check(p.value >= -25.0 and p.value <= 12.0, "add in range at %d" % i)
			if not p.revealed:
				hidden_seen = true
	check(hidden_seen, "hidden panels appear over a long run")
