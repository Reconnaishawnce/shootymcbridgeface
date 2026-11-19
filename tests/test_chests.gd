extends TestCase


func test_make_and_totals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := Chests.make("silver", "ROAD 1300", {"kind": "coins", "amount": 275, "at": 1300}, rng)
	check_eq(str(c.tier), "silver", "the tier is kept")
	check_eq(int(c.base.amount), 275, "the reward it was earned for is inside")
	check(not c.base.has("at"), "and nothing else rides along into the save")
	c.bonus = {"kind": "none"}
	check_eq(Chests.totals(c), {"coins": 275, "stars": 0, "item": ""}, "no bonus pays the base")
	c.bonus = {"kind": "stars", "amount": 3}
	check_eq(Chests.totals(c), {"coins": 275, "stars": 3, "item": ""}, "a star bonus adds stars")
	c.bonus = {"kind": "jackpot", "coins": 1000, "stars": 5}
	check_eq(Chests.totals(c), {"coins": 1275, "stars": 5, "item": ""}, "a jackpot adds both")
	check(Chests.is_jackpot(c), "and says so")
	var item := Chests.make("gold", "SEASON TIER 5", {"kind": "item", "id": "crown"}, rng)
	item.bonus = {"kind": "none"}
	check_eq(str(Chests.totals(item).item), "crown", "an item chest hands the item over")
	check_eq(Chests.totals(item, true, 8), {"coins": 0, "stars": 8, "item": ""}, "an owned item pays its price in stars")
	check_eq(int(Chests.totals(item, true, 0).stars), 1, "never nothing")
	check_eq(str(Chests.make("nonsense", "x", {"kind": "coins", "amount": 1}, rng).tier), "wood", "an unknown tier is a wooden chest")


func test_bonus_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for tier in Chests.TIERS:
		var counts := {"none": 0, "coins": 0, "stars": 0, "jackpot": 0}
		for i in range(4000):
			var b := Chests.roll_bonus(tier, rng)
			counts[str(b.kind)] += 1
			if b.kind == "coins":
				check(int(b.amount) >= int(Chests.BONUS[tier].coins_range[0]) and int(b.amount) <= int(Chests.BONUS[tier].coins_range[1]), "coins in range")
		var any := float(4000 - int(counts.none)) / 4000.0
		check_near(any, Chests.bonus_chance(tier), 0.04, "%s chests hold a bonus about as often as the table says" % tier)
		check(int(counts.jackpot) > 0 and int(counts.jackpot) < int(counts.coins), "%s jackpots are rare but real (%d)" % [tier, counts.jackpot])
	check(Chests.bonus_chance("gold") > Chests.bonus_chance("silver") and Chests.bonus_chance("silver") > Chests.bonus_chance("wood"), "better chests are luckier")
	var a := RandomNumberGenerator.new()
	var b2 := RandomNumberGenerator.new()
	a.seed = 9
	b2.seed = 9
	check_eq(Chests.roll_bonus("gold", a), Chests.roll_bonus("gold", b2), "a seed replays")


func test_reveal_and_clean() -> void:
	var c := {"tier": "wood", "label": "QUEST", "base": {"kind": "coins", "amount": 90}, "bonus": {"kind": "coins", "amount": 55}}
	var r := Chests.reveal(c)
	check_eq(str(r.main), "90 COINS", "the big line")
	check_eq(str(r.bonus), "BONUS: +55 COINS", "the bonus line")
	check(not r.jackpot, "no jackpot")
	c.bonus = {"kind": "jackpot", "coins": 600, "stars": 3}
	check(Chests.reveal(c).jackpot and str(Chests.reveal(c).bonus).begins_with("JACKPOT!"), "a jackpot shouts")
	var item := {"tier": "gold", "label": "SEASON", "base": {"kind": "item", "id": "crown"}, "bonus": {"kind": "none"}}
	check_eq(str(Chests.reveal(item, "CROWN").main), "CROWN FOR THE LOCKER", "an item names itself")
	check_eq(str(Chests.reveal(item, "CROWN", true, 8).main), "CROWN, OWNED: 8 STARS", "an owned item says what it pays")
	check_eq(str(Chests.reveal({"tier": "wood", "base": {"kind": "stars", "amount": 1}, "bonus": {"kind": "none"}}).main), "1 STAR", "one star is singular")
	var dirty := [c, "junk", {"tier": "plastic", "base": {"kind": "coins", "amount": 1}}, {"tier": "wood", "base": {"kind": "gems", "amount": 1}}, {"tier": "wood", "base": {"kind": "coins", "amount": 4}}]
	var kept := Chests.clean(dirty)
	check_eq(kept.size(), 2, "a save keeps only real chests")
	check_eq(str(kept[1].bonus.kind), "none", "a chest with no roll opens plain")
	check(Chests.clean("nonsense").is_empty(), "nonsense is no chests")
	for tier in Chests.TIERS:
		check(Chests.title(tier) != "", "a title for %s" % tier)


func test_economy_curve() -> void:
	# The lower curve: the same early game, a flatter late one.
	check_eq(Economy.coins_for_bounty(250), 250, "small runs are untouched")
	check(Economy.coins_for_bounty(1000) < 420, "a good run pays less than it did (%d)" % Economy.coins_for_bounty(1000))
	check(Economy.coins_for_bounty(5000) < 520, "a great run flattens (%d)" % Economy.coins_for_bounty(5000))
	check(Economy.coins_for_bounty(5000) > Economy.coins_for_bounty(1000), "but more is still more")
