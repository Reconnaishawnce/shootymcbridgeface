extends TestCase


func test_watchdog() -> void:
	check_near(Perf.average_fps(300, 5.0), 60.0, 0.01, "average")
	check_eq(Perf.average_fps(10, 0.0), 0.0, "no time, no rate")
	check(not Perf.should_degrade(15.0, 2.0, false, false), "too early to judge")
	check(Perf.should_degrade(15.0, 5.0, false, false), "slow for long enough")
	check(not Perf.should_degrade(40.0, 5.0, false, false), "fast enough")
	check(not Perf.should_degrade(15.0, 5.0, true, false), "already safe")
	check(not Perf.should_degrade(15.0, 5.0, false, true), "only ever once")
	check(Perf.notice().contains("SETTINGS"), "the notice says where to change it")
