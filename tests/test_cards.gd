extends TestCase


func test_catalog() -> void:
	check_eq(Cards.ORDER.size(), Cards.CATALOG.size(), "order lists every card")
	for id in Cards.ORDER:
		check(Cards.CATALOG.has(id), "a real card: %s" % id)
		check(Cards.RARITIES.has(Cards.rarity(id)), "a known rarity: %s" % id)
		check(Cards.title(id) != "" and Cards.icon(id) != "", "name and icon: %s" % id)
		for n in range(1, Cards.max_stack(id) + 1):
			check(Cards.description(id, n).length() > 10, "description for %s x%d" % [id, n])
	check(Cards.description("blast", 1).contains("8th") and Cards.description("blast", 3).contains("4th"), "the description reads the real number")
	for combo in Cards.COMBO_ORDER:
		var needs: Array = Cards.COMBOS[combo]["needs"]
		check(needs.size() == 2 and Cards.CATALOG.has(needs[0]) and Cards.CATALOG.has(needs[1]), "combo %s names two cards" % combo)
		check(Cards.combo_title(combo) != "" and Cards.combo_description(combo) != "", "combo text: %s" % combo)


func test_offer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c := Cards.new()
	var epics := 0
	var commons := 0
	for i in range(400):
		var offer := c.offer(rng)
		check_eq(offer.size(), Cards.CARDS, "three cards")
		check(offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "all different")
		for id in offer:
			if Cards.rarity(id) == "epic":
				epics += 1
			elif Cards.rarity(id) == "common":
				commons += 1
	check(epics > 20 and epics * 3 < commons, "epics are rare but real (%d epic, %d common)" % [epics, commons])
	c.take("execute")
	for i in range(50):
		check(not c.offer(rng).has("execute"), "a maxed card is not offered again")
	for i in range(50):
		check(not c.offer(rng, ["sentry"]).has("sentry"), "a blocked card is not offered")
	var full := Cards.new()
	for id in Cards.ORDER:
		for n in range(Cards.max_stack(id)):
			full.take(id)
	check(full.offer(rng).is_empty(), "nothing left to offer")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	check_eq(Cards.new().offer(a), Cards.new().offer(b), "the same seed deals the same hand")


func test_combos() -> void:
	var c := Cards.new()
	check(c.combos().is_empty(), "no cards, no combos")
	check_eq(c.combo_hint("burn"), "Pairs with BLAST ROUNDS for FIRESTORM", "a hint for what it could become")
	c.take("burn")
	check_eq(c.combo_hint("blast"), "COMBO: FIRESTORM with your BURNING ROUNDS", "completing a combo says so")
	check_eq(c.combo_hint("burn"), "", "a second stack makes no new combo")
	c.take("blast")
	check(c.has_combo("firestorm") and not c.has_combo("chain"), "burn and blast are a firestorm")
	check(c.summary().contains("FIRESTORM!") and c.summary().contains("BURNING ROUNDS"), "the summary names cards and combos")
	check_near(c.blast_radius(), Cards.BLAST_RADIUS, 0.0001, "no chain yet")
	c.take("martyr")
	check_near(c.blast_radius(), Cards.BLAST_RADIUS * Cards.CHAIN_RADIUS_MULT, 0.0001, "chain reaction widens blasts")
	check_near(c.shatter_mult(), 1.0, 0.0001, "no shatter")
	c.take("frost")
	c.take("crit")
	check_near(c.shatter_mult(), Cards.SHATTER_MULT, 0.0001, "frost and dead eye shatter")
	check_eq(Cards.partner("wildfire", "burn"), "ricochet", "partners")
	# The pull: holding one half, the other half turns up more.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var plain := 0
	var pulled := 0
	var held := Cards.new()
	held.take("frost")
	for i in range(600):
		if Cards.new().offer(rng).has("crit"):
			plain += 1
		if held.offer(rng).has("crit"):
			pulled += 1
	check(pulled > plain, "a combo half is offered more (%d > %d)" % [pulled, plain])


func test_effects_and_counters() -> void:
	var c := Cards.new()
	check(not c.note_shot() and not c.note_bullet_kill() and not c.note_kill(), "no cards, nothing fires")
	check_eq(c.ricochets(), 0, "no bounce")
	check_near(c.slow_mult(), 1.0, 0.0001, "no slow")
	check_near(c.cooldown_mult(), 1.0, 0.0001, "no charge")
	c.take("crit")
	var crits := 0
	for i in range(80):
		if c.note_shot():
			crits += 1
	check_eq(crits, 10, "every eighth shot")
	c.take("blast")
	c.take("blast")
	var blasts := 0
	for i in range(60):
		if c.note_bullet_kill():
			blasts += 1
	check_eq(blasts, 10, "two stacks: every sixth kill")
	c.take("medic")
	var back := 0
	for i in range(45):
		if c.note_kill():
			back += 1
	check_eq(back, 3, "a soldier every fifteen kills")
	c.take("burn")
	c.take("burn")
	check_near(c.burn_fraction(), 0.8, 0.0001, "burn stacks")
	c.take("frost")
	c.take("frost")
	check_near(c.slow_mult(), 0.55, 0.0001, "two frost stacks")
	c.take("charge")
	check_near(c.cooldown_mult(), 0.7, 0.0001, "overcharge")
	check(not c.executes(), "no executioner")
	c.take("execute")
	check(c.executes(), "executioner")
	check_eq(c.total(), 10, "the count the boss scales with")
	check(c.martyr_radius() == 0.0, "no last stand, no radius")


func test_draft_schedule() -> void:
	check(not Cards.drafts_after_boss("levels", 0), "no boss, no draft")
	check(Cards.drafts_after_boss("levels", 1) and Cards.drafts_after_boss("endless", 2) and Cards.drafts_after_boss("daily", 3), "every boss pays a draft")
	check(Cards.drafts_after_boss("rush", 1) and not Cards.drafts_after_boss("rush", 2) and Cards.drafts_after_boss("rush", 3), "every other boss in the rush")


func test_near_miss() -> void:
	check_eq(NearMiss.line(500, 0, false), "", "a first run has nothing to miss")
	check_eq(NearMiss.line(1200, 1000, true), "", "a new best says so elsewhere")
	check_eq(NearMiss.line(950, 1000, false), "SO CLOSE: 50 short of your best", "within a tenth is close")
	check_eq(NearMiss.line(400, 1000, false), "600 short of your best", "otherwise the gap")
	check(NearMiss.is_close(950, 1000) and not NearMiss.is_close(400, 1000) and not NearMiss.is_close(1000, 1000), "close is close")
