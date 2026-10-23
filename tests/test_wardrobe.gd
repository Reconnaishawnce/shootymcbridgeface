extends TestCase


func test_catalog() -> void:
	var seen := {}
	for id in Wardrobe.CATALOG.keys():
		var item: Dictionary = Wardrobe.CATALOG[id]
		check(Wardrobe.CATEGORIES.has(item.cat), "known category: %s" % id)
		check(not seen.has(id), "unique id: %s" % id)
		seen[id] = true
		check(item.cost >= 0, "cost not negative: %s" % id)
	for cat in Wardrobe.CATEGORIES:
		var ids := Wardrobe.items_in(cat)
		check(ids.size() >= 5, "%s has choices (%d)" % [cat, ids.size()])
		check_eq(Wardrobe.cost(ids[0]), 0, "%s starts free" % cat)
		check(Wardrobe.CATALOG.has(Wardrobe.DEFAULTS[cat]), "default exists: %s" % cat)
		check_eq(Wardrobe.category(Wardrobe.DEFAULTS[cat]), cat, "default in its category")


func test_buy_and_equip() -> void:
	var w := Wardrobe.new()
	check(w.is_owned("max") and w.is_owned("zuri"), "two heroes free")
	check(w.is_equipped("max") and w.is_equipped("helmet"), "defaults equipped")
	check_eq(w.tap("zuri"), "equipped", "owned items equip on tap")
	check_eq(w.hero_name(), "ZURI", "hero name follows")
	check_eq(w.tap("crown"), "", "cannot afford a crown")
	w.stars = 9
	check_eq(w.tap("crown"), "bought", "bought with stars")
	check_eq(w.stars, 1, "stars spent")
	check(w.is_equipped("crown"), "bought items equip")
	check_eq(w.tap("cap"), "bought", "a one-star cap")
	check_eq(w.stars, 0, "down to zero")
	check(w.is_equipped("cap") and not w.is_equipped("crown"), "one hat at a time")
	check(w.is_owned("crown"), "the crown stays owned")
	check(not w.equip("gold"), "cannot equip what you do not own")


func test_stars() -> void:
	check_eq(Wardrobe.stars_for_run(0, 0, 2, false), 0, "a two-gate run pays nothing")
	check_eq(Wardrobe.stars_for_run(0, 0, 3, false), 1, "showing up pays one")
	check_eq(Wardrobe.stars_for_run(3, 8, 30, false), 6, "bosses and perfect gates")
	check_eq(Wardrobe.stars_for_run(0, 4, 40, true), 7, "endless pays by distance")


func test_look() -> void:
	var w := Wardrobe.new()
	w.stars = 50
	w.tap("luna")
	w.tap("sunny")
	w.tap("cat")
	w.tap("neon")
	w.tap("cape_red")
	var l := w.look()
	for key in ["hero", "name", "skin", "hair", "hair_style", "top", "pants", "hat", "weapon", "back"]:
		check(l.has(key), "look has %s" % key)
	check_eq(l.name, "LUNA", "hero name")
	check_eq(l.hat, "cat", "hat id")
	check_eq(l.back, "cape_red", "back id")
	check(l.hero, "hero flag")
	var c := w.crew_look()
	check(not c.hero and not c.has("skin") and c.hat == "cat", "crew share the hat, not the face")
	w.tap("none_hat")
	w.tap("none_back")
	check_eq(w.look().hat, "none", "no hat maps to none")
	check_eq(w.look().back, "none", "no back maps to none")
	var classic := Wardrobe.classic_look()
	check(classic.hat == "helmet" and not classic.hero, "classic look")


func test_round_trip() -> void:
	var w := Wardrobe.new()
	w.stars = 20
	w.tap("pip")
	w.tap("berry")
	var d := w.to_dict()
	var w2 := Wardrobe.new()
	w2.from_dict(d)
	check_eq(w2.stars, w.stars, "stars persist")
	check(w2.is_owned("pip") and w2.is_equipped("pip"), "hero persists")
	check(w2.is_equipped("berry"), "outfit persists")
	var w3 := Wardrobe.new()
	w3.from_dict({"stars": 3, "owned": ["gold", "bogus"], "equipped": {"weapon": "gold", "hat": "crown", "hero": "zuri"}})
	check(w3.is_equipped("gold"), "owned and equipped from save")
	check(w3.is_equipped("helmet"), "an unowned equip falls back to the default")
	check(not w3.owned.has("bogus"), "unknown ids dropped")
	check(w3.is_equipped("zuri"), "a free hero equips from a save")
