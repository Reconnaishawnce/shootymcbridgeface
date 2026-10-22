extends TestCase


func test_steal() -> void:
	var p := GateMath.add(3, true)
	GateMath.steal(p)
	check(p.revealed, "stealing reveals")
	check_eq(GateMath.label(p), "+1", "add loses two")
	var m := GateMath.mul(2.0)
	GateMath.steal(m)
	check_eq(GateMath.label(m), "x1.5", "mul loses a half")
	GateMath.steal(m)
	GateMath.steal(m)
	check_eq(GateMath.label(m), "x1", "never below x1")


func test_power_panels() -> void:
	var p := GateMath.power("bomb")
	check(GateMath.is_power(p), "is power")
	check(GateMath.is_good(p), "reads as good")
	check_eq(GateMath.apply(7, p), 7, "count unchanged")
	check_eq(GateMath.label(p), "BOMB", "label")
	check_eq(GateMath.register_hit(p, 100.0, 1.0), 0, "cannot be shot up")
	GateMath.steal(p)
	check_eq(GateMath.label(p), "?", "a thief turns it into a mystery")
	check_eq(GateMath.better_index(GateMath.add(3), GateMath.power("slow"), 10), 1, "a power-up beats a small add")
	check_eq(GateMath.better_index(GateMath.add(6), GateMath.power("slow"), 10), 0, "a big add beats a power-up")
