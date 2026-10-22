extends TestCase


func test_timers_stack_and_expire() -> void:
	var p := Powerups.new()
	check(not p.active("slow", 0.0), "nothing at start")
	check(p.grant("slow", 10.0), "granted")
	check(p.active("slow", 15.9), "active inside window")
	check(not p.active("slow", 16.1), "expired")
	p.grant("slow", 12.0)
	check_near(p.remaining("slow", 12.0), 10.0, 0.001, "second grant extends from the end")
	check_near(p.world_speed_mult(13.0), Powerups.SLOW_FACTOR, 0.001, "slow factor")
	check_near(p.world_speed_mult(30.0), 1.0, 0.001, "back to normal")
	p.grant("frenzy", 0.0)
	check_near(p.fire_rate_mult(1.0), Powerups.FRENZY_MULT, 0.001, "frenzy")
	p.grant("shield", 0.0)
	check(p.shielded(5.9) and not p.shielded(6.1), "shield window")


func test_bombs_cap() -> void:
	var p := Powerups.new()
	for i in range(5):
		p.grant("bomb", 0.0)
	check_eq(p.bombs, Powerups.MAX_BOMBS, "capped")
	check(p.take_bomb(), "throw one")
	check_eq(p.bombs, Powerups.MAX_BOMBS - 1, "one fewer")
	p.reset()
	check(not p.take_bomb(), "nothing to throw after reset")


func test_mystery_resolves_through_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen := {}
	for i in range(100):
		var id := Powerups.resolve(Powerups.MYSTERY, rng)
		check(Powerups.CATALOG.has(id), "resolves to a real power-up")
		seen[id] = true
	check_eq(seen.size(), Powerups.ORDER.size(), "every power-up can come out of a mystery")
	check_eq(Powerups.resolve("bomb", rng), "bomb", "specific stays specific")
	check_eq(Powerups.title(Powerups.MYSTERY), "?", "mystery label")
	check(Powerups.is_valid("slow") and not Powerups.is_valid("nope"), "validity")
