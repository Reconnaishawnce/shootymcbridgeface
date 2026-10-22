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
