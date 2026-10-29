extends TestCase


func test_promote_and_traits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var vets := Veterans.new()
	check_eq(vets.count(), 0, "nobody yet")
	var a := vets.promote(rng)
	check(a.has("name") and Veterans.TRAITS.has(a.trait), "a named veteran with a real trait")
	var b := vets.promote(rng)
	var c := vets.promote(rng)
	check(a.name != b.name and b.name != c.name and a.name != c.name, "no two share a name")
	check(vets.is_full() and vets.promote(rng).is_empty(), "three at most")
	check(vets.summary().contains(str(a.name)), "the summary names them")
	for id in Veterans.TRAITS:
		check(Veterans.title(id) != "" and Veterans.description(id) != "", "every trait explains itself: %s" % id)
	var forced := Veterans.new()
	forced.roster = [{"name": "ADA", "trait": "deadeye"}, {"name": "BO", "trait": "deadeye"}, {"name": "CAL", "trait": "tough"}]
	check_near(forced.damage_mult(), 1.16, 0.001, "two deadeyes")
	check_near(forced.bite_mult(), 0.92, 0.001, "one tough")
	check_near(forced.coin_mult(), 1.0, 0.001, "no lucky")
	check_eq(forced.medics(), 0, "no medic")
	check_eq(Veterans.label(forced.roster[0]), "ADA the DEADEYE", "label")


func test_losses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var vets := Veterans.new()
	check(vets.roll_loss(rng).is_empty(), "nothing to lose")
	vets.promote(rng)
	vets.promote(rng)
	var lost := 0
	for i in range(400):
		if not vets.roll_loss(rng).is_empty():
			lost += 1
			vets.promote(rng)
	check(lost > 40 and lost < 140, "a heavy bite takes a veteran about a fifth of the time (%d of 400)" % lost)
