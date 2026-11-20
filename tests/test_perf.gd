extends TestCase


func test_watchdog() -> void:
	check_near(Perf.average_fps(300, 5.0), 60.0, 0.01, "average")
	check_eq(Perf.average_fps(10, 0.0), 0.0, "no time, no rate")
	check(not Perf.should_degrade(15.0, 2.0, false, false), "too early to judge")
	check(Perf.should_degrade(15.0, 5.0, false, false), "slow for long enough")
	check(not Perf.should_degrade(40.0, 5.0, false, false), "fast enough")
	check(not Perf.should_degrade(15.0, 5.0, true, false), "already safe")
	check(not Perf.should_degrade(15.0, 5.0, false, true), "only ever once")


## The reports that started this: "3.6 fps over 18 s" straight after a
## sixteen-second pit stop, on a phone that was holding its frame rate.
func test_a_pause_is_not_a_slow_stretch() -> void:
	check(Perf.sample_valid(false, 10.0, 0.0), "an unbroken sample counts")
	check(not Perf.sample_valid(true, 10.0, 0.0), "a paused game is not sampled")
	check(not Perf.sample_valid(false, 10.0, 12.5), "nor one that was on the home screen halfway")
	check(Perf.sample_valid(false, 13.0, 12.5), "the next sample, begun after coming back, counts")
	# The pit stop itself: 54 frames in 18 seconds of wall clock, 16 of
	# them standing still. The old sum; the watchdog must never see it.
	check(Perf.average_fps(54, 18.0) < Telemetry.SLOW_FPS, "what the old watchdog computed")


func test_shadows_go_first() -> void:
	var streak := 0
	streak = Perf.low_streak(streak, 38.0, true)
	check(not Perf.should_drop_shadows(streak, true, false, false), "one slow sample is not a verdict")
	streak = Perf.low_streak(streak, 41.0, true)
	check(Perf.should_drop_shadows(streak, true, false, false), "two in a row is")
	check(not Perf.should_drop_shadows(streak, false, false, false), "nothing to drop")
	check(not Perf.should_drop_shadows(streak, true, true, false), "the safe renderer has none")
	check(not Perf.should_drop_shadows(streak, true, false, true), "once: after that the switch is the player's")
	check_eq(Perf.low_streak(streak, 58.0, true), 0, "a good sample starts the count again")
	check_eq(Perf.low_streak(streak, 20.0, false), 0, "the title screen does not count")
	check(Perf.SHADOW_FPS > Perf.SLOW_FPS, "shadows go before the safe renderer comes on")
	check(Perf.shadows_notice().contains("SETTINGS"), "and the player is told where the switch is")


func test_the_old_verdict_is_retried() -> void:
	check(Perf.should_retry(1, true, true), "safe graphics the old watchdog chose are undone")
	check(not Perf.should_retry(1, true, false), "the player's own choice is left alone")
	check(not Perf.should_retry(1, false, true), "nothing to undo")
	check(not Perf.should_retry(Perf.WATCHDOG_VERSION, true, true), "once")
	check(Perf.retry_notice().contains("SAFE GRAPHICS"), "said plainly")
	check(Perf.notice().contains("SETTINGS"), "the notice says where to change it")
