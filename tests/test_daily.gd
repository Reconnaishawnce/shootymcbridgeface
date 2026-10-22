extends TestCase


func test_day_numbers_and_seeds() -> void:
	var t0 := Daily.EPOCH_DAY * Daily.SECONDS_PER_DAY
	check_eq(Daily.day_number(t0), 1, "first daily is #1")
	check_eq(Daily.day_number(t0 + Daily.SECONDS_PER_DAY - 1), 1, "same day until midnight UTC")
	check_eq(Daily.day_number(t0 + Daily.SECONDS_PER_DAY), 2, "next day")
	check(Daily.seed_for_day(1) != Daily.seed_for_day(2), "different seeds")
	check_eq(Daily.seed_for_day(5), Daily.seed_for_day(5), "stable seed")
	check(Daily.seed_for_day(3) >= 0, "seed non-negative")


func test_record_and_prune() -> void:
	var r := {}
	var out := Daily.record(r, 10, 500, 3, 40, 60)
	check(out.new_best, "first result is a best")
	out = Daily.record(out.results, 10, 400, 4, 50, 70)
	check(not out.new_best, "lower score is not a best")
	check_eq(int(out.results[10].score), 500, "best kept")
	out = Daily.record(out.results, 3, 100, 1, 2, 3)
	var pruned := Daily.prune(out.results, 10)
	check(pruned.has(10), "today kept")
	check(not pruned.has(3), "old day pruned")
	check_eq(Daily.prune({"9": {"score": 1}}, 10).size(), 1, "string keys survive")


func test_share_text() -> void:
	var t := Daily.share_text(12, 4312, 4, 182, 240)
	check(t.contains("#12"), "day")
	check(t.contains("4312"), "score")
	check(t.contains("level 4"), "level")
	check(t.contains("github.com"), "link")
	check_eq(Daily.label(7), "DAILY #7", "label")
