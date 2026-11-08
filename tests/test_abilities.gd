extends TestCase


func test_rules() -> void:
	check_eq(Abilities.for_type("rifle"), "volley", "rifles volley")
	check_eq(Abilities.for_type("shotgun"), "shockwave", "shotguns shock")
	check_eq(Abilities.for_type("medic"), "heal", "medics heal")
	check_eq(Abilities.for_type("nonsense"), "volley", "unknown squads volley")
	check_near(Abilities.cooldown(0), Abilities.COOLDOWN_BASE, 0.001, "base cooldown")
	check(Abilities.cooldown(3) < Abilities.cooldown(0), "the shop shortens the wait")
	check(Abilities.cooldown(99) >= 8.0, "never faster than eight seconds")
	check(Abilities.ready(100.0, 100.0 - Abilities.COOLDOWN_BASE, 0), "ready after the cooldown")
	check(not Abilities.ready(100.0, 95.0, 0), "not before")
	check_near(Abilities.charge(100.0, 90.0, 0), 0.5, 0.001, "half charged halfway")
	check_near(Abilities.charge(100.0, 0.0, 0), 1.0, 0.001, "charge caps at one")
	check_eq(Abilities.volley_shots(500), Abilities.VOLLEY_MAX_SHOTS, "a volley is capped")
	check_eq(Abilities.volley_shots(0), 1, "and never nothing")
	check(Abilities.shockwave_damage(100.0, 2) > Abilities.shockwave_damage(100.0, 0), "power scales the shockwave")
	check_eq(Abilities.heal_amount(10, 0), Abilities.HEAL_MIN, "heal floor")
	check_eq(Abilities.heal_amount(200, 0), 24, "twelve percent of the squad")
	check(Abilities.heal_amount(200, 3) > Abilities.heal_amount(200, 0), "power heals more")
	check(Abilities.is_hero_tap(50.0, 0.1, 5.0) and not Abilities.is_hero_tap(300.0, 0.1, 5.0), "a tap must be on the squad")
	check(not Abilities.is_hero_tap(50.0, 0.1, 60.0), "a drag is not a tap")
	check(not Abilities.is_hero_tap(50.0, 0.6, 5.0), "a hold is not a tap")
	for id in Abilities.CATALOG:
		check(Abilities.title(id) != "" and Abilities.description(id) != "", "%s has a name and a line" % id)
