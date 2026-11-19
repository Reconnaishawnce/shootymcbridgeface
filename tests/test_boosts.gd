extends TestCase


func test_boosts() -> void:
	var b := Boosts.new()
	check_eq(b.summary(), "", "nothing armed says nothing")
	check(not b.can_buy("pay", 499) and b.can_buy("pay", 500), "a boost costs what the catalog says")
	check_eq(b.buy("pay", 499), 499, "too poor keeps the coins")
	check_eq(b.buy("pay", 700), 200, "buying arms and charges")
	check(b.is_armed("pay") and not b.can_buy("pay", 9999), "one of each")
	check_eq(b.buy("bombs", 300), 0, "exact change")
	check_eq(b.summary(), "Next run: BOMB DROP · DOUBLE PAY", "the home screen line lists them in order")
	check_near(b.coin_mult(), 2.0, 0.0001, "double pay doubles")
	check_eq(b.bombs(), 2, "two bombs")
	check_near(b.damage_mult(), 1.0, 0.0001, "hot rounds not armed")
	check(b.take("daily").is_empty() and b.any_armed(), "the daily spends nothing and keeps them for later")
	var run := Boosts.new()
	run.from_dict(b.take("levels"))
	check(run.is_armed("pay") and run.bombs() == 2 and not b.any_armed(), "a normal run takes them all")
	var saved := Boosts.new()
	saved.from_dict({"wind": true, "bogus": true, "sharp": false})
	check(saved.is_armed("wind") and not saved.is_armed("sharp") and saved.armed.size() == 1, "the save round-trips and drops junk")
	check_eq(saved.extra_winds(), 1, "spare wind")
	for id in Boosts.ORDER:
		check(Boosts.title(id) != "" and Boosts.description(id) != "" and Boosts.cost(id) > 0 and Boosts.icon(id) != "", "catalog entry %s" % id)
	check(Boosts.applies("endless") and Boosts.applies("rush") and not Boosts.applies("weekly"), "modes")
