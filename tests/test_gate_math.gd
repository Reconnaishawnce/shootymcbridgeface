extends TestCase


func test_apply_add_and_floor_at_zero() -> void:
	check_eq(GateMath.apply(5, GateMath.add(3)), 8, "add")
	check_eq(GateMath.apply(5, GateMath.add(-3)), 2, "sub")
	check_eq(GateMath.apply(2, GateMath.add(-9)), 0, "never negative")
	check_eq(GateMath.apply(0, GateMath.add(4)), 4, "from zero")


func test_apply_mul_floors() -> void:
	check_eq(GateMath.apply(7, GateMath.mul(2.0)), 14, "x2")
	check_eq(GateMath.apply(7, GateMath.mul(2.5)), 17, "x2.5 floors")
	check_eq(GateMath.apply(1, GateMath.mul(2.0)), 2, "x2 from one")


func test_labels() -> void:
	check_eq(GateMath.label(GateMath.add(3)), "+3", "positive add")
	check_eq(GateMath.label(GateMath.add(0)), "+0", "zero shows plus")
	check_eq(GateMath.label(GateMath.add(-4)), "-4", "negative")
	check_eq(GateMath.label(GateMath.mul(2.0)), "x2", "integer mul")
	check_eq(GateMath.label(GateMath.mul(2.5)), "x2.5", "fractional mul")
	check_eq(GateMath.label(GateMath.mul(0.5)), "x0.5", "halving")
	check_eq(GateMath.label(GateMath.add(9, true)), "?", "hidden")


func test_is_good() -> void:
	check(GateMath.is_good(GateMath.add(1)), "+1 good")
	check(not GateMath.is_good(GateMath.add(0)), "+0 not good")
	check(not GateMath.is_good(GateMath.add(-1)), "-1 not good")
	check(GateMath.is_good(GateMath.mul(2.0)), "x2 good")
	check(not GateMath.is_good(GateMath.mul(1.0)), "x1 not good")
	check(not GateMath.is_good(GateMath.mul(0.5)), "x0.5 not good")
	check_eq(GateMath.apply(9, GateMath.mul(0.5)), 4, "halving floors")


func test_shooting_steps_additive_panel() -> void:
	var p := GateMath.add(-2)
	check_eq(GateMath.register_hit(p, 1.0, 3.0), 0, "first hit no step")
	check_eq(GateMath.register_hit(p, 1.0, 3.0), 0, "second hit no step")
	check_eq(GateMath.register_hit(p, 1.0, 3.0), 1, "third hit steps")
	check_eq(GateMath.label(p), "-1", "value climbed")
	check_eq(GateMath.register_hit(p, 6.0, 3.0), 2, "heavy hit climbs twice")
	check_eq(GateMath.label(p), "+1", "crossed into positive")


func test_shooting_reveals_hidden_panel() -> void:
	var p := GateMath.add(4, true)
	check_eq(GateMath.label(p), "?", "hidden at first")
	GateMath.register_hit(p, 0.5, 3.0)
	check(p.revealed, "a single hit reveals")
	check_eq(GateMath.label(p), "+4", "shows value after reveal")


func test_shooting_mul_panel_costs_more_and_is_capped() -> void:
	var p := GateMath.mul(2.0)
	check_eq(GateMath.register_hit(p, 3.0, 3.0), 0, "one additive-step of damage is not enough")
	check_eq(GateMath.register_hit(p, 6.0, 3.0), 1, "three times the cost steps once")
	check_eq(GateMath.label(p), "x2.5", "half step")
	for i in range(100):
		GateMath.register_hit(p, 9.0, 3.0)
	check_near(p.value, GateMath.MUL_CAP, 0.001, "capped")
	check_eq(GateMath.label(p), "x5", "cap label")


func test_zero_step_cost_is_safe() -> void:
	var p := GateMath.add(1)
	check_eq(GateMath.register_hit(p, 10.0, 0.0), 0, "no infinite loop")


func test_better_index_depends_on_count() -> void:
	var plus3 := GateMath.add(3)
	var times2 := GateMath.mul(2.0)
	check_eq(GateMath.better_index(plus3, times2, 1), 0, "+3 beats x2 at 1")
	check_eq(GateMath.better_index(plus3, times2, 10), 1, "x2 beats +3 at 10")
	check_eq(GateMath.better_index(plus3, times2, 3), 0, "tie goes left")
