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
	check_near(Difficulty.world_speed(1), 9.5, 0.001, "base speed")
	check(Difficulty.world_speed(100) <= 14.0, "speed capped")
	check(Difficulty.runner_release_z(1) < -8.0 and Difficulty.runner_release_z(1) > -30.0, "runners released a second out")
	check(Difficulty.runner_release_z(9) < Difficulty.runner_release_z(1), "faster roads release farther")
	check(Difficulty.boss_world_speed() < Difficulty.world_speed(1), "boss fight slows the road")
	check(Difficulty.step_cost(5) > Difficulty.step_cost(1), "step cost grows")
	check_near(Difficulty.effective_step_cost(1, 1.0), 3.0, 0.001, "floor applies to a tiny squad")
	check_near(Difficulty.effective_step_cost(1, 100.0), 70.0, 0.001, "big squad pays most of its dps")
	check(Difficulty.wave_for(3, 2).count > Difficulty.wave_for(1, 0).count, "waves grow")
	check(Difficulty.wave_for(3, 2).hp > Difficulty.wave_for(1, 0).hp, "hp grows")
	check(Difficulty.wave_for(1, 7).count > Difficulty.wave_for(1, 0).count, "waves grow inside a level")
	check(Difficulty.wave_for(6, 0).count <= 12, "a late level still opens gently (got %d)" % Difficulty.wave_for(6, 0).count)
	check_eq(Difficulty.wave_for(1, 0).brutes, 0, "no brutes at the very start")
	check_eq(Difficulty.wave_for(5, 0).brutes, 0, "no brutes on any level's opener")
	check(Difficulty.wave_for(1, 3).brutes >= 1, "brutes from the fourth gate of level 1")
	check(Difficulty.wave_for(1, 0).runners >= 1, "runners from the first gate")
	check(Difficulty.wave_for(1, 6).runners > Difficulty.wave_for(1, 0).runners, "more runners deeper in")
	check_eq(Difficulty.wave_for(6, 0).runners, 1, "one runner on any opener")
	check(Difficulty.wave_for(6, 0).hp < Difficulty.wave_for(6, 1).hp, "opener zombies are softer")
	check(Difficulty.wave_for(1, 0).runner_hp < Difficulty.wave_for(1, 0).hp, "runners are thin")
	check(Difficulty.wave_clear_bonus(2) > Difficulty.wave_clear_bonus(1), "wave bonus grows")
	check_eq(Difficulty.wave_for(1, 3).thieves, 0, "no thieves on level 1")
	check(Difficulty.wave_for(2, 1).thieves >= 1, "thieves from level 2 on odd gates")
	check_eq(Difficulty.wave_for(2, 0).thieves, 0, "no thieves on the opener")
	check_eq(Difficulty.wave_for(2, 2).tanks, 0, "no tanks on level 2")
	check_eq(Difficulty.wave_for(3, 2).tanks, 1, "a tank on level 3 gate 3")
	check(Difficulty.wave_for(3, 2, 300).tank_hp > Difficulty.wave_for(3, 2, 1).tank_hp * 5.0, "tanks soak a big squad")
	check(Difficulty.wave_for(1, 2, 200).count > Difficulty.wave_for(1, 2, 1).count, "big squads draw crowds")
	check(Difficulty.wave_for(1, 2, 100000).count <= Difficulty.MAX_WAVE, "wave capped")
	check(Difficulty.wave_for(1, 2, 500).brute_hp > Difficulty.wave_for(1, 2, 1).brute_hp * 10.0, "brutes soak a big squad")
	check_eq(Difficulty.brute_bite(10), 2, "brute bite floor")
	check_eq(Difficulty.brute_bite(1000), 80, "brute bite scales")


func test_boss_curve() -> void:
	# Three kinds cycle by level; each kind's health grows with the level.
	for kind in [Boss.Kind.WALKER, Boss.Kind.SPITTER, Boss.Kind.STORM]:
		var last := 0.0
		for level in range(1, 20):
			if Difficulty.boss_kind(level) != kind:
				continue
			var hp := Difficulty.boss_hp(level)
			check(hp > last, "boss kind %d hp grows at level %d" % [kind, level])
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
	check_near(Difficulty.boss_hp(1), 70.0 * 2.5 * 7.0, 0.001, "level 1 boss is 7 s of a 70 squad")
	check_eq(Difficulty.boss_bite(10), 2, "boss bite floor")
	check_eq(Difficulty.boss_bite(100), 12, "boss bite scales")
	check(Difficulty.level_bonus(2, 10) > Difficulty.level_bonus(1, 10), "bonus grows with level")
	check_eq(Difficulty.carry_over(100, 1), 25, "a quarter carries over")
	check_eq(Difficulty.carry_over(3, 2), 2, "never below the starting squad")


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
				check(p.value >= -2.0, "opener never bites hard (seed %d level %d)" % [s, level])
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


func test_power_gates_and_crates() -> void:
	var gen := Difficulty.new(21)
	var powers := 0
	var total := 0
	for level in range(1, 30):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var pair := gen.make_gate_pair(level, i)
			var has_power := false
			for p in pair:
				total += 1
				if GateMath.is_power(p):
					has_power = true
					powers += 1
					check(Powerups.is_valid(p.power), "valid power id")
			if i == 0:
				check(not has_power, "opener never offers a power-up")
			if has_power:
				for p in pair:
					if not GateMath.is_power(p):
						check(GateMath.is_good(p) and p.revealed, "a power gate's other side is a visible gain")
	check(powers > 0 and float(powers) / float(total) < 0.15, "power panels are a minority (%d of %d)" % [powers, total])
	var crates := gen.crates_for_level(1)
	check_eq(crates.size(), Difficulty.CRATES_PER_LEVEL, "two crates")
	check(crates[0].index != crates[1].index, "distinct gates")
	for c in crates:
		check(Powerups.is_valid(c.id), "crate content valid")
		check(Difficulty.crate_distance(c.index) > Difficulty.gate_distance(c.index), "crate after its gate")
		check(Difficulty.crate_distance(c.index) < Difficulty.wave_distance(c.index), "crate before the wave")


func test_fork() -> void:
	check(Difficulty.is_fork_gate(Difficulty.FORK_INDEX), "fork starts at its index")
	check(Difficulty.is_fork_gate(Difficulty.FORK_INDEX + 1), "second route gate")
	check(not Difficulty.is_fork_gate(Difficulty.FORK_INDEX + 2), "fork is two gates")
	check(not Perks.is_pick_gate(Difficulty.FORK_INDEX) and not Perks.is_pick_gate(Difficulty.FORK_INDEX + 1), "fork never overlaps a perk gate")
	check(Difficulty.fork_distance() + Difficulty.fork_length() < Difficulty.gate_distance(Difficulty.FORK_INDEX + Difficulty.FORK_GATES), "merge before the next gate")
	check(Difficulty.fork_distance() < Difficulty.gate_distance(Difficulty.FORK_INDEX), "fork line before the first route gate")
	check(Difficulty.fork_distance() > Difficulty.gate_distance(Difficulty.FORK_INDEX - 1), "fork line after the previous gate")
	var heavy_left := 0
	var both_bite := 0
	for seed in range(60):
		var gen := Difficulty.new(seed)
		var f := gen.make_fork(2)
		var a: Dictionary = f.left
		var b: Dictionary = f.right
		check(a.threat != b.threat, "the two routes differ")
		if int(a.threat) > int(b.threat):
			heavy_left += 1
		for side in ["left", "right"]:
			var r: Dictionary = f[side]
			check_eq(r.panels.size(), Difficulty.FORK_GATES, "a panel per route gate")
			check(r.threat >= 1 and r.threat <= 4, "threat in range")
			check(int(r.needs) >= 3, "a route says what it needs")
			check(is_equal_approx(float(r.wave_mult), Difficulty.threat_wave_mult(int(r.threat))), "wave follows threat")
			if int(r.threat) == 1:
				for p in r.panels:
					check(p.revealed and GateMath.is_good(p), "quiet-route panels are visible gains")
		var heavy: Dictionary = a if int(a.threat) > int(b.threat) else b
		var light: Dictionary = b if heavy == a else a
		check(int(heavy.needs) > int(light.needs), "the heavy route needs more")
		var crates := gen.crates_for_level(2)
		for c in crates:
			check(not Difficulty.is_fork_gate(c.index), "no crate inside the fork")
	for seed in range(40):
		var f3 := Difficulty.new(seed + 100).make_fork(5)
		if int(f3.left.threat) >= 2 and int(f3.right.threat) >= 2:
			both_bite += 1
	check(both_bite > 2 and both_bite < 25, "sometimes both sides bite (%d of 40)" % both_bite)
	check(Difficulty.route_needs(2, 4) > Difficulty.route_needs(2, 1), "needs grow with threat")
	check(heavy_left > 10 and heavy_left < 50, "heavy side varies (%d of 60 left)" % heavy_left)


func test_level_one_is_simple() -> void:
	for seed in range(40):
		var gen := Difficulty.new(seed)
		for i in range(Difficulty.GATES_PER_LEVEL):
			var pair := gen.make_gate_pair(1, i)
			var any_good := false
			for p in pair:
				check(p.revealed, "level 1 never hides a panel (seed %d gate %d)" % [seed, i])
				if GateMath.is_good(p):
					any_good = true
			check(any_good, "level 1 always offers a gain (seed %d gate %d)" % [seed, i])
		var f := gen.make_fork(1)
		for side in ["left", "right"]:
			for p in f[side].panels:
				check(p.revealed, "level 1 fork is fully visible")
	check_eq(Difficulty.wave_for(2, 3).latchers, 0, "no latchers before level 3")
	check(Difficulty.wave_for(3, 3).latchers >= 1, "latchers from level 3")
	check(Difficulty.wave_for(3, 3).latcher_hp > Difficulty.wave_for(3, 3).hp, "latchers are sturdier than walkers")


func test_boss_attacks_scale() -> void:
	check_eq(Difficulty.strikes_per_volley(1), 1, "one ring on level 1")
	check(Difficulty.strikes_per_volley(7) >= 2, "more rings later")
	check(Difficulty.strikes_per_volley(40) <= 3, "rings capped")
	check_eq(Difficulty.strike_bite(10), 3, "strike floor")
	check_eq(Difficulty.strike_bite(100), 15, "strike scales")
	check(Difficulty.boss_adds(1) >= 1 and Difficulty.boss_adds(20) <= 4, "adds bounded")
	check(Difficulty.STRIKE_INTERVAL_ENRAGED < Difficulty.STRIKE_INTERVAL, "enrage is faster")


func test_lanes_progress() -> void:
	check_eq(Progression.lanes_for(1, 7), 2, "level 1 is two lanes")
	check_eq(Progression.lanes_for(2, 0), 2, "level 2 opens with two")
	check_eq(Progression.lanes_for(2, 4), 3, "level 2 widens to three")
	check_eq(Progression.lanes_for(4, 7), 4, "level 4 ends on four")
	check_eq(Progression.lanes_for(9, 0), Progression.MAX_LANES, "capped")
	var last := 0
	for level in range(1, 12):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var n := Progression.lanes_for(level, i)
			check(n >= last, "lanes never shrink (%d/%d)" % [level, i])
			last = n
	check_near(Progression.road_half(2), 3.3, 0.001, "two lanes is the old road")


func test_multi_lane_gates() -> void:
	var gen := Difficulty.new(5)
	var sums := 0
	var gates := 0
	var with_good := 0
	for level in range(1, 10):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var lanes := Progression.lanes_for(level, i)
			var panels := gen.make_gate(level, i, 20, lanes)
			gates += 1
			check_eq(panels.size(), lanes, "one panel per lane (%d/%d)" % [level, i])
			var any_good := false
			for p in panels:
				if GateMath.is_good(p) or GateMath.is_power(p):
					any_good = true
				if GateMath.is_expr(p):
					sums += 1
					check(level >= Progression.EXPR_LEVEL, "no sums before level %d" % Progression.EXPR_LEVEL)
					check(p.ops.size() == 2 or (p.ops.size() == 3 and level >= Progression.EXPR_THREE_TERMS_LEVEL), "term count by level")
			if any_good:
				with_good += 1
			if i == 0:
				check(any_good, "openers always offer a gain")
				for p in panels:
					check(not GateMath.is_expr(p) and p.revealed, "openers stay plain")
	check(sums > 10, "sums appear (%d)" % sums)
	# Dilemma gates (both sides hurt) are deliberate; everything else offers a gain.
	check(with_good * 10 >= gates * 8, "most gates offer something (%d of %d)" % [with_good, gates])
	var rival := GateMath.add(6)
	var e := gen.make_rival_expr(3, rival, 20)
	check(GateMath.is_expr(e), "rival is a sum")
