extends TestCase


func test_round_trip_and_best_tracking() -> void:
	SaveData.wipe()
	check_eq(SaveData.load_best(), 0, "empty best")
	check_eq(SaveData.load_best_level(), 0, "empty best level")
	check_eq(SaveData.load_runs(), 0, "empty runs")
	var r := SaveData.record_run(120, 2)
	check(r.new_best_score and r.new_best_level, "first run sets both records")
	r = SaveData.record_run(80, 3)
	check(not r.new_best_score, "lower score is not a best")
	check(r.new_best_level, "higher level is a best")
	r = SaveData.record_run(121, 1)
	check(r.new_best_score and not r.new_best_level, "score only")
	check_eq(SaveData.load_best(), 121, "best score persisted")
	check_eq(SaveData.load_best_level(), 3, "best level persisted")
	check_eq(SaveData.load_runs(), 3, "runs counted")
	SaveData.wipe()


func test_sound_setting() -> void:
	SaveData.wipe()
	check(SaveData.load_sound_on(), "sound defaults on")
	SaveData.save_sound_on(false)
	check(not SaveData.load_sound_on(), "sound off persists")
	SaveData.wipe()
