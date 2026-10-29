extends TestCase


func test_next_goal_order() -> void:
	check(Goals.next({"runs": 0}).contains("Play"), "first: play")
	check(Goals.next({"runs": 3, "best_level": 2}).contains("level %d" % Modifiers.HARD_UNLOCK_LEVEL), "old saves: reach the unlock level")
	check(Goals.next({"runs": 3, "trophies": 120, "hard_open": false}).contains("300 trophies open ENDLESS"), "with a road: endless first")
	check(Goals.next({"runs": 3, "trophies": 420, "hard_open": false}).contains("600 trophies open HARD"), "then hard")
	check(not Goals.next({"runs": 3, "trophies": 420, "hard_open": true, "coins": 0}).contains("trophies open"), "open: move on")
	var ctx := {"runs": 5, "best_level": 4, "coins": 500, "cheapest": "RECRUITS", "cheapest_cost": 400, "vehicles": 0}
	check(Goals.next(ctx).contains("RECRUITS"), "then: an affordable upgrade")
	ctx.coins = 10
	check(Goals.next(ctx).contains("JEEP"), "then: form a jeep")
	ctx.vehicles = 2
	ctx.modifier = "normal"
	ctx.hard_best_level = 0
	check(Goals.next(ctx).contains("HARD"), "then: try hard")
	ctx.hard_best_level = 9
	ctx.daily_played = false
	check(Goals.next(ctx).contains("DAILY"), "then: the daily")
	ctx.daily_played = true
	check(Goals.next(ctx).contains("Save for RECRUITS"), "then: save up")
	ctx.cheapest = ""
	ctx.best_score = 1234
	check(Goals.next(ctx).contains("1234"), "finally: beat the best")


func test_title_buttons() -> void:
	var fresh := Goals.title_buttons(0, false, false)
	check(not fresh.shop and not fresh.daily and not fresh.records and not fresh.mode and not fresh.locker, "a new player sees almost nothing")
	var one := Goals.title_buttons(1, false, false)
	check(one.shop and one.records and not one.daily, "after one run: shop and records")
	var later := Goals.title_buttons(2, true, true)
	check(later.daily and later.mode and later.locker, "everything in time")
