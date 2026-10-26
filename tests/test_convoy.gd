extends TestCase


func test_specs_and_offer() -> void:
	for id in Convoy.ORDER:
		check(Convoy.SPECS.has(id), "spec for %s" % id)
		check(Convoy.cost(id) > 0 and float(Convoy.spec(id).hp) > 0.0, "cost and health")
		check(Convoy.damage_per_shot(id) > 0.0, "damage per shot")
	check_eq(Convoy.offer(10, {}, 1), "", "too small for anything")
	check_eq(Convoy.offer(32, {}, 1), "jeep", "a jeep at 32")
	check_eq(Convoy.offer(32, {"jeep": 2}, 1), "", "no room for a third jeep")
	check_eq(Convoy.offer(100, {}, 1), "jeep", "no tank on level 1")
	check_eq(Convoy.offer(100, {}, 2), "tank", "the biggest affordable first")
	check_eq(Convoy.offer(100, {"tank": 1}, 2), "jeep", "then a jeep")
	check(not Convoy.can_offer("jeep", 31, 0, 1), "margin: 31 is not 1.6 x 20")
	check(Convoy.spec("jeep").dps >= 20 * Progression.DPS_CAP_SOLDIERS / 40.0 * 2.5 * 0.99, "a jeep is worth its soldiers in fire")


func test_vehicle_panel() -> void:
	var p := GateMath.vehicle("jeep")
	check_eq(GateMath.label(p), "JEEP -20", "label")
	check_eq(GateMath.apply(40, p), 20, "costs soldiers")
	check(GateMath.is_vehicle(p) and not GateMath.is_deal(p) and not GateMath.is_good(p), "flags")
	check_eq(GateMath.register_hit(p, 3.0, 3.0), 0, "cannot be shot cheaper")
	check_eq(GateMath.best_index([GateMath.add(3), p], 40), 0, "plain ranking ignores the convoy")


func test_gates_offer_vehicles() -> void:
	var gen := Difficulty.new(11)
	var offers := 0
	var openers := 0
	for level in range(1, 6):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var panels := gen.make_gate(level, i, 50, Progression.lanes_for(level, i), {})
			var n := 0
			for q in panels:
				if GateMath.is_vehicle(q):
					n += 1
			check(n <= 1, "at most one vehicle panel per gate")
			offers += n
			if i == 0:
				openers += n
	check(offers > 5, "vehicles get offered (%d)" % offers)
	check_eq(openers, 0, "never on the opener")
	var none := 0
	for i in range(1, Difficulty.GATES_PER_LEVEL):
		for q in gen.make_gate(3, i, 12, 3, {}):
			if GateMath.is_vehicle(q):
				none += 1
	check_eq(none, 0, "a small squad is never offered one")
	check_eq(Difficulty.level_bonus(2, 10, 2), 300 + 50 + 2 * Convoy.LEVEL_BONUS_PER_VEHICLE, "vehicles pay at the boss")


func test_ranks_and_flying() -> void:
	check_eq(Convoy.rank_for(0), 0, "no kills, no rank")
	check_eq(Convoy.rank_for(25), 1, "first rank")
	check_eq(Convoy.rank_for(149), 2, "second")
	check_eq(Convoy.rank_for(150), 3, "third")
	check_eq(Convoy.rank_for(9999), Convoy.RANK_KILLS.size(), "capped")
	check_near(Convoy.rank_dps_mult(2), 1.3, 0.0001, "rank fire")
	check_near(Convoy.rank_hp_mult(1), 1.2, 0.0001, "rank health")
	check(Convoy.flies("heli") and not Convoy.flies("tank"), "only the helicopter flies")
	check_eq(Convoy.offer(200, {}, 3), "heli", "a helicopter at 200 on level 3")
	check_eq(Convoy.offer(200, {}, 2), "tank", "not before level 3")
	check_eq(Convoy.offer(400, {}, 4), "mech", "a mech at 400 on level 4")
	check_eq(Convoy.offer(400, {"mech": 1, "heli": 1, "tank": 1}, 4), "jeep", "what is left")


func test_vehicle_perks() -> void:
	var perks := Perks.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen_vehicle := false
	for i in range(30):
		for id in perks.offer(rng, false):
			if bool(Perks.CATALOG[id].get("vehicle", false)):
				seen_vehicle = true
	check(not seen_vehicle, "no convoy perks without a convoy")
	for i in range(30):
		for id in perks.offer(rng, true):
			if bool(Perks.CATALOG[id].get("vehicle", false)):
				seen_vehicle = true
	check(seen_vehicle, "convoy perks show up once you have one")
	check_near(perks.vehicle_fire_mult(), 1.0, 0.0001, "no overdrive yet")
	perks.take("overdrive")
	perks.take("plating")
	check_near(perks.vehicle_fire_mult(), 1.3, 0.0001, "overdrive")
	check_near(perks.vehicle_damage_mult(), 0.6, 0.0001, "plating")
