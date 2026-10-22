extends TestCase


func test_round_trip_and_best_tracking() -> void:
	SaveData.wipe()
	check_eq(SaveData.load_best(), 0, "empty best")
	check_eq(SaveData.load_runs(), 0, "empty runs")
	check(SaveData.record_run(120), "first run is a best")
	check(not SaveData.record_run(80), "lower run is not a best")
	check(SaveData.record_run(121), "higher run is a best")
	check_eq(SaveData.load_best(), 121, "best persisted")
	check_eq(SaveData.load_runs(), 3, "runs counted")
	SaveData.wipe()
