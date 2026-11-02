extends TestCase


func test_prices_and_effects() -> void:
	var pit := PitStop.new()
	check_eq(pit.cost("rounds"), 60, "base price")
	check(not pit.can_buy("rounds", 59) and pit.can_buy("rounds", 60), "exact funds buy")
	var left := pit.buy("rounds", 200)
	check_eq(left, 140, "the price comes off the bounty")
	check_eq(pit.cost("rounds"), 90, "the next one costs more")
	check_near(pit.damage_mult(), 1.12, 0.001, "one stack of rounds")
	for i in range(10):
		left = pit.buy("rounds", 100000)
	check(pit.is_maxed("rounds") and pit.stack("rounds") == 5, "five at most")
	check_eq(pit.buy("rounds", 100000), 100000, "maxed: nothing spent")
	check_eq(pit.cost("bomb"), 25, "bombs stay cheap")
	pit.buy("bomb", 100)
	check_eq(pit.cost("bomb"), 25, "and do not climb")
	check_eq(PitStop.dressing_for(10), 4, "a dressing has a floor")
	check_eq(PitStop.dressing_for(200), 20, "a tenth of a big squad")
	check(PitStop.effect_text("armor", 2, 0).contains("20%"), "effect text adds up")
	check(PitStop.bay_distance(2) > Difficulty.gate_distance(PitStop.BAY_GATE_INDEX) and PitStop.bay_distance(2) < Difficulty.wave_distance(PitStop.BAY_GATE_INDEX), "the bay sits between a gate and its wave")
	check(not PitStop.has_bay(1) and PitStop.has_bay(2), "from level two")
	for id in PitStop.ORDER:
		check(PitStop.title(id) != "" and PitStop.description(id) != "", "every item explains itself: %s" % id)
