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
