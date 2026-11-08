extends TestCase


func test_haptics() -> void:
	check_eq(Haptics.duration("bite", true), 22, "a bite is a tap")
	check(Haptics.duration("boss_down", true) > Haptics.duration("bite", true), "a boss kill is felt")
	check_eq(Haptics.duration("bite", false), 0, "off means nothing")
	check_eq(Haptics.duration("nonsense", true), 0, "unknown moments buzz nothing")
	check(Haptics.allowed("bite", true, 10.0, 9.0, 22), "spaced out: allowed")
	check(not Haptics.allowed("bite", true, 10.0, 9.95, 22), "too soon after a bite: not")
	check(Haptics.allowed("boss_down", true, 10.0, 9.95, 22), "a longer buzz may follow at once")
	check(not Haptics.allowed("bite", false, 10.0, 0.0, 0), "the setting wins")
