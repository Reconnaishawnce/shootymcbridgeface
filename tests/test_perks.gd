extends TestCase


func test_pick_gates() -> void:
	var picks := []
	for i in range(Difficulty.GATES_PER_LEVEL):
		if Perks.is_pick_gate(i):
			picks.append(i)
	check_eq(picks, [2, 5], "third and sixth gate offer perks")


func test_offer_is_distinct_capped_and_seeded() -> void:
	var a := Perks.new()
	var b := Perks.new()
	var ra := RandomNumberGenerator.new()
	var rb := RandomNumberGenerator.new()
	ra.seed = 5
	rb.seed = 5
	var oa := a.offer(ra)
	var ob := b.offer(rb)
	check_eq(oa.size(), Perks.CARDS, "three cards")
	check_eq(oa, ob, "same seed, same offer")
	check(oa[0] != oa[1] and oa[1] != oa[2] and oa[0] != oa[2], "distinct cards")


func test_maxed_perks_leave_the_pool() -> void:
	var p := Perks.new()
	for i in range(Perks.CATALOG["pierce"]["max"]):
		p.take("pierce")
	check(not p.can_offer("pierce"), "pierce maxed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(30):
		check(not p.offer(rng).has("pierce"), "maxed perk never offered")
	check_eq(p.total(), 2, "total stacks")
	check_eq(int(Perks.CATALOG["recruit"]["max"]), 2, "recruiter capped at two")


func test_effects_scale_with_stacks() -> void:
	var p := Perks.new()
	check_near(p.fire_rate_mult(), 1.0, 0.0001, "base fire rate")
	check_near(p.step_cost_mult(), 1.0, 0.0001, "base step cost")
	check_eq(p.pierce(), 0, "no pierce")
	p.take("rapid")
	p.take("whisper")
	p.take("whisper")
	p.take("pierce")
	p.take("skin")
	p.take("greed")
	check_near(p.fire_rate_mult(), 1.25, 0.0001, "rapid")
	check_near(p.step_cost_mult(), 0.5625, 0.0001, "whisper stacks multiply")
	check_eq(p.pierce(), 1, "pierce")
	check_near(p.brute_bite_mult(), 0.67, 0.0001, "skin")
	check_near(p.coin_mult(), 1.3, 0.0001, "greed")
	check(p.reveal_bonus() == 0.0, "no sight")
