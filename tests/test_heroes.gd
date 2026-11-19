extends TestCase


func test_catalog() -> void:
	check_eq(Heroes.ORDER.size(), Heroes.CATALOG.size(), "order lists every hero")
	for id in Heroes.ORDER:
		check(Wardrobe.CATALOG.has(id) and Wardrobe.category(id) == "hero", "a hero in the locker: %s" % id)
		check(Heroes.passive_title(id) != "" and Heroes.twist_title(id) != "", "names for %s" % id)
		check(Heroes.passive_text(id).length() > 12 and Heroes.twist_text(id).length() > 12, "text for %s" % id)
		check(Heroes.short(id) != "" and Heroes.short(id).length() <= 28, "a short line that fits a button: %s" % id)
	for id in Wardrobe.items_in("hero"):
		check(Heroes.known(id), "every locker hero has a power: %s" % id)
	check(Heroes.passive_text("pip").contains("30%") and Heroes.passive_text("pip").contains("12"), "text reads the constants")


func test_active() -> void:
	check_eq(Heroes.active("mei", true, "levels"), "mei", "characters on, a normal run")
	check_eq(Heroes.active("mei", false, "levels"), "", "characters off: the classic squad, no power")
	check_eq(Heroes.active("mei", true, "daily"), "", "the daily is plain for everyone")
	check_eq(Heroes.active("mei", true, "weekly"), "", "and the weekly")
	check_eq(Heroes.active("mei", true, "rush"), "mei", "the rush counts")
	check_eq(Heroes.active("nobody", true, "levels"), "", "an unknown hero is no hero")


func test_numbers() -> void:
	# No hero changes nothing.
	check_eq(Heroes.level_soldiers(""), 0, "no hero, no soldiers")
	check_near(Heroes.damage_mult("", 5), 1.0, 0.0001, "no hero, no damage")
	check_near(Heroes.cooldown_mult("") * Heroes.dash_cooldown_mult("") * Heroes.latch_interval_mult("") * Heroes.coin_mult("") * Heroes.bite_mult("") * Heroes.move_power("", 9), 1.0, 0.0001, "no hero, every multiplier is one")
	check(not Heroes.move_slows("") and not Heroes.move_shoves("") and not Heroes.perfect_refills(""), "no hero, no twist")
	# Each hero does its own thing and nobody else's.
	check_eq(Heroes.level_soldiers("max"), 3, "max")
	check_eq(Heroes.move_soldiers("max"), 2, "max's move")
	check_eq(Heroes.gate_soldiers("zuri"), 1, "zuri")
	check_near(Heroes.gate_seconds("zuri"), 2.0, 0.0001, "zuri's gates")
	check_near(Heroes.damage_mult("pip", 12), 1.3, 0.0001, "pip small")
	check_near(Heroes.damage_mult("pip", 13), 1.0, 0.0001, "pip big")
	check_near(Heroes.cooldown_mult("pip"), 0.75, 0.0001, "pip's move")
	check_near(Heroes.dash_cooldown_mult("luna"), 0.6, 0.0001, "luna")
	check_near(Heroes.ghost_seconds("luna"), 1.5, 0.0001, "luna's move")
	check_near(Heroes.latch_interval_mult("kofi"), 2.0, 0.0001, "kofi")
	check(Heroes.move_slows("kofi") and not Heroes.move_slows("rex"), "kofi's move")
	check_near(Heroes.coin_mult("ada"), 1.1, 0.0001, "ada")
	check_near(Heroes.move_power("ada", 5), 1.3, 0.0001, "ada's move")
	check_near(Heroes.bite_mult("rex"), 0.75, 0.0001, "rex")
	check(Heroes.move_shoves("rex"), "rex's move")
	check_eq(Heroes.perfect_soldiers("mei"), 2, "mei")
	check(Heroes.perfect_refills("mei"), "mei's move")
	check_eq(Heroes.level_soldiers("mei") + Heroes.gate_soldiers("max") + Heroes.perfect_soldiers("zuri"), 0, "nobody borrows")
