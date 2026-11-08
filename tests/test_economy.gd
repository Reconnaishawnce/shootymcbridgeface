extends TestCase


func test_conversion_and_caps() -> void:
	check_eq(Economy.coins_for_bounty(300), 300, "small bounty converts one to one")
	check_eq(Economy.coins_for_bounty(500), 500, "up to the knee")
	var big := Economy.coins_for_bounty(84000)
	check(big > 4000 and big < 7000, "a monster run pays well, not without limit (%d)" % big)
	check(Economy.coins_for_bounty(1000) > Economy.coins_for_bounty(900), "always worth more")
	check_eq(Economy.coins_for_bounty(-5), 0, "never negative")
	check_eq(Economy.cap_squad(34616), Economy.SQUAD_CAP, "the bridge holds five hundred")
	check_eq(Economy.cap_squad(-3), 0, "floor")
	check_eq(Economy.mul_cap_for(10), 5.0, "a small squad can push a panel to x5")
	check_eq(Economy.mul_cap_for(200), 2.0, "a mid squad to x2")
	check_eq(Economy.mul_cap_for(400), 1.5, "a big squad to x1.5")
	check(Economy.mul_cap_for(400) * 0.5 < 1.0, "a big squad taking panels at random shrinks")
	var p := GateMath.mul(0.5)
	GateMath.register_hit(p, 1000.0, 1.0, 2.0)
	check_near(p.value, 2.0, 0.001, "shooting stops at the cap handed in")
