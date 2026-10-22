extends TestCase


func test_costs_grow_and_purchases_apply() -> void:
	var m := Meta.new()
	check_eq(m.level("start"), 0, "fresh")
	check_eq(m.cost("start"), 40, "base cost")
	check(Meta.cost_at("start", 1) > Meta.cost_at("start", 0), "cost grows")
	check(not m.can_buy("start", 39), "too poor")
	check_eq(m.buy("start", 39), 39, "failed buy keeps coins")
	check_eq(m.buy("start", 100), 60, "buy deducts")
	check_eq(m.level("start"), 1, "level up")
	check_eq(m.start_squad(), 2, "effect applies")


func test_max_level_blocks_buying() -> void:
	var m := Meta.new()
	var coins := 100000
	for i in range(10):
		coins = m.buy("shotgun", coins)
	check_eq(m.level("shotgun"), 1, "one-shot unlock")
	check(m.is_maxed("shotgun"), "maxed")
	check(m.shotgun_unlocked(), "unlocked")
	check_eq(coins, 100000 - 200, "charged once")


func test_effects() -> void:
	var m := Meta.new()
	m.levels = {"power": 2, "gate": 1, "armor": 3, "slayer": 2, "magnet": 1, "scout": 2}
	check_near(m.damage_mult(), 1.16, 0.0001, "power")
	check_eq(m.gate_bonus(), 1, "gate")
	check_near(m.brute_bite_fraction(0.08), 0.05, 0.0001, "armor")
	check_near(m.core_mult_bonus(), 1.0, 0.0001, "slayer")
	check_near(m.coin_mult(), 1.15, 0.0001, "magnet")
	check_near(m.reveal_bonus(), 16.0, 0.0001, "scout")
	check_near(m.brute_bite_fraction(0.03), 0.02, 0.0001, "armor floors")


func test_squad_cycling() -> void:
	var m := Meta.new()
	check_eq(m.next_squad("rifle"), "rifle", "nothing unlocked wraps to rifle")
	m.levels = {"medic": 1}
	check_eq(m.next_squad("rifle"), "medic", "skips locked shotgun")
	check_eq(m.next_squad("medic"), "rifle", "wraps")
	m.levels = {"medic": 1, "shotgun": 1}
	check_eq(m.next_squad("rifle"), "shotgun", "in order")
	check(m.squad_unlocked("medic") and not Meta.new().squad_unlocked("medic"), "unlock check")


func test_coins_and_endless_unlock() -> void:
	check_eq(Meta.coins_for_run(40, 2, 10), 10 + 50 + 20, "payout")
	check(not Meta.endless_unlocked(3), "level 3 reached is not enough")
	check(Meta.endless_unlocked(4), "reaching level 4 means level 3 was cleared")
	for id in Meta.ORDER:
		check(Meta.CATALOG.has(id), "order lists a real upgrade: %s" % id)
	check_eq(Meta.ORDER.size(), Meta.CATALOG.size(), "every upgrade is listed")
