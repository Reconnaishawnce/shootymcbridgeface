extends TestCase


func test_chain_and_window() -> void:
	var c := Combo.new()
	check_eq(c.kill(0.0), 1, "first kill")
	check_eq(c.kill(1.0), 2, "inside window")
	check_eq(c.kill(3.0), 1, "window expired resets")
	check(c.alive(3.5), "alive inside window")
	check(not c.alive(5.0), "dead after window")
	check_eq(c.best, 2, "best kept")


func test_multiplier_steps_and_caps() -> void:
	var c := Combo.new()
	check_near(c.multiplier(), 1.0, 0.001, "base")
	for i in range(Combo.STEP):
		c.kill(0.1 * i)
	check_near(c.multiplier(), 1.5, 0.001, "first step")
	for i in range(100):
		c.kill(0.5 + 0.01 * i)
	check_near(c.multiplier(), Combo.MAX_MULT, 0.001, "capped")
	c.reset()
	check_eq(c.count, 0, "reset")
	check_near(c.remaining(0.0), 0.0, 0.001, "nothing remaining after reset")
