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


func test_sum_panels() -> void:
	var e := GateMath.expr([[GateMath.Kind.ADD, 3], [GateMath.Kind.MUL, 2.0]])
	check_eq(GateMath.label(e), "+3 x2", "label reads left to right")
	check_eq(GateMath.apply(10, e), 26, "(10 + 3) x 2")
	var f := GateMath.expr([[GateMath.Kind.MUL, 2.0], [GateMath.Kind.ADD, 3]])
	check_eq(GateMath.apply(10, f), 23, "10 x 2 + 3: order matters")
	var h := GateMath.expr([[GateMath.Kind.MUL, 0.5], [GateMath.Kind.ADD, -4]])
	check_eq(GateMath.label(h), "÷2 -4", "halving label")
	check_eq(GateMath.apply(9, h), 0, "floors at zero")
	check(GateMath.is_expr(e) and not GateMath.is_expr(GateMath.add(1)), "kind check")
	check(GateMath.is_good(e), "+3 x2 is a gain at the reference count")
	check(not GateMath.is_good(h), "÷2 -4 is not")
	check_eq(GateMath.register_hit(e, 3.0, 3.0), 1, "shooting steps the first add")
	check_eq(GateMath.label(e), "+4 x2", "first add stepped")
	var m := GateMath.expr([[GateMath.Kind.MUL, 2.0]])
	GateMath.register_hit(m, 3.0, 3.0)
	check_eq(GateMath.label(m), "x2 +1", "a sum with no add grows one")
	GateMath.steal(e)
	check_eq(GateMath.label(e), "+2 x2", "theft takes two off the first add")


func test_best_index() -> void:
	var panels := [GateMath.add(3), GateMath.mul(2.0), GateMath.expr([[GateMath.Kind.ADD, 10], [GateMath.Kind.MUL, 0.5]])]
	check_eq(GateMath.best_index(panels, 1), 2, "(1+10)/2 = 5 beats +3 and x2 at one soldier")
	check_eq(GateMath.best_index(panels, 20), 1, "x2 wins at twenty")
	check_eq(GateMath.best_index(panels, 2), 2, "(2+10)/2 = 6 beats 5 and 4")
