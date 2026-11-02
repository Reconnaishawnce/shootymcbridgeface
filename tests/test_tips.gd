extends TestCase


func test_tips_fit_the_death() -> void:
	check(Tips.for_wipe({"in_boss": true, "boss_kind": "storm"}).contains("gap"), "the storm tip is about the gap")
	check(Tips.for_wipe({"in_boss": true, "boss_kind": "foreman"}).contains("saws"), "the foreman tip is about saws")
	check(Tips.for_wipe({"in_boss": true, "boss_kind": "walker", "count_at_boss": 5}).contains("small squad"), "a small squad at the boss")
	check(Tips.for_wipe({"bombs_left": 2}).contains("bomb"), "an unthrown bomb")
	check(Tips.for_wipe({"peak": 120, "kills": 40}).contains("WIDE"), "a big squad that did not kill")
	check(Tips.for_wipe({}).length() > 30, "always a tip")
