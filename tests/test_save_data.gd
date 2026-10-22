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


func test_endless_records_are_separate() -> void:
	SaveData.wipe()
	var r := SaveData.record_run(500, 9, true)
	check(r.new_best_endless, "endless best")
	check_eq(SaveData.load_best_endless(), 500, "endless persisted")
	check_eq(SaveData.load_best(), 0, "levels best untouched")
	check_eq(SaveData.load_best_level(), 0, "best level untouched")
	SaveData.wipe()


func test_wallet_upgrades_and_settings() -> void:
	SaveData.wipe()
	check_eq(SaveData.load_coins(), 0, "empty wallet")
	check_eq(SaveData.add_coins(30), 30, "add returns total")
	SaveData.save_coins(-5)
	check_eq(SaveData.load_coins(), 0, "wallet never negative")
	SaveData.save_upgrades({"start": 2})
	check_eq(SaveData.load_upgrades().get("start", 0), 2, "upgrades persist")
	check(SaveData.load_sound_on(), "sound defaults on")
	SaveData.save_sound_on(false)
	check(not SaveData.load_sound_on(), "sound off persists")
	check_eq(SaveData.load_squad_type(), "rifle", "default squad")
	SaveData.save_squad_type("shotgun")
	check_eq(SaveData.load_squad_type(), "shotgun", "squad persists")
	SaveData.wipe()
