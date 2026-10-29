extends TestCase


func test_bounty_by_kind() -> void:
	check_eq(Bounty.for_kind("normal"), 1, "walker")
	check_eq(Bounty.for_kind("brute"), 3, "brute")
	check_eq(Bounty.for_kind("tank"), 5, "tank")
	check_eq(Bounty.for_kind("mystery"), 1, "unknown pays the floor")
	check(Bounty.for_kind("thief") > Bounty.for_kind("runner"), "a thief is worth the chase")
	check_eq(Bounty.coins_for_run(120, 2, 10), 120 + 50 + 20, "payout")
	check_eq(Bounty.coins_for_run(-5, 0, 0), 0, "never negative")
	check(Bounty.STRAIGHT_DAMAGE_MULT > 1.0 and Bounty.STRAIGHT_PIERCE >= 1, "straight fire drills")


func test_supply_panels() -> void:
	var p := GateMath.supply(42, "shield")
	check(GateMath.is_supply(p) and not GateMath.is_deal(p), "its own kind, its own colour")
	check_eq(GateMath.supply_cost(p), 42, "cost")
	check_eq(GateMath.label(p), "SHIELD\n42c", "label says the price in coins")
	check_eq(GateMath.apply(20, p), 20, "walking through alone changes nothing; the world pays")
	var sp := GateMath.supply(56, "soldiers", 8)
	check_eq(GateMath.label(sp), "+8 SOLDIERS\n56c", "soldiers say how many")
	var d := Difficulty.new(3)
	for i in range(20):
		var panel := d.make_supply(40)
		check(GateMath.supply_cost(panel) > 0, "always priced")
		if panel.power == "soldiers":
			check(panel.amount >= 6 and panel.amount <= Difficulty.SUPPLY_SOLDIERS_MAX, "a sane number of soldiers")
			check_eq(GateMath.supply_cost(panel), panel.amount * Difficulty.SUPPLY_SOLDIER_COST, "flat price each")
		else:
			check(Difficulty.SUPPLY_POWER_COST.has(panel.power), "a listed power-up")
