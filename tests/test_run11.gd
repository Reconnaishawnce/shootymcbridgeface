extends TestCase


func test_modifiers() -> void:
	check_eq(Modifiers.title("hard"), "HARD", "title")
	check(float(Modifiers.get_value("nightmare", "wave")) > float(Modifiers.get_value("hard", "wave")), "nightmare throws more")
	check(float(Modifiers.get_value("hard", "score")) > 1.0, "hard pays more")
	check_eq(float(Modifiers.get_value("bogus", "score")), 1.0, "unknown falls back to normal")
	check(Modifiers.unlocked("normal", 0, 0), "normal always open")
	check(not Modifiers.unlocked("hard", 2, 0) and Modifiers.unlocked("hard", 3, 0), "hard opens at level 3")
	check(not Modifiers.unlocked("nightmare", 9, 3) and Modifiers.unlocked("nightmare", 0, 4), "nightmare needs hard level 4")
	check_eq(Modifiers.next("normal", 0, 0), "normal", "nothing else open: stays")
	check_eq(Modifiers.next("normal", 3, 0), "hard", "cycles to hard")
	check_eq(Modifiers.next("hard", 3, 0), "normal", "wraps past a locked nightmare")
	check_eq(Modifiers.next("hard", 3, 4), "nightmare", "then nightmare")
	check_eq(Modifiers.key_suffix("normal"), "", "normal keeps the old keys")
	check(Modifiers.ramp(1) < 0.5 and Modifiers.ramp(3) == 1.0 and Modifiers.ramp(9) == 1.0, "threat ramps in by level 3")
	check_eq(Modifiers.key_suffix("hard"), "_hard", "suffix")


func test_grades() -> void:
	check_eq(Grades.grade(8, 8, 100, 100, 5.0), "S", "perfect level")
	check_eq(Grades.grade(0, 8, 100, 10, 25.0), "D", "a mess")
	check_eq(Grades.grade(4, 8, 100, 70, 10.0), "B", "middling")
	check(Grades.bonus("S") > Grades.bonus("A") and Grades.bonus("D") == 0, "bonus order")
	check(Grades.LETTERS.has(Grades.grade(0, 0, 0, 0, 0.0)), "no gates, no squad: survives division")


func test_trade_and_bet() -> void:
	var t := GateMath.trade(12, "shield")
	check_eq(GateMath.label(t), "SHIELD -12", "trade label")
	check_eq(GateMath.apply(40, t), 28, "trade costs soldiers")
	check(GateMath.is_deal(t) and GateMath.is_trade(t) and not GateMath.is_good(t), "trade flags")
	GateMath.register_hit(t, 3.0, 3.0)
	check_eq(GateMath.label(t), "SHIELD -11", "shooting a trade makes it cheaper")
	var b := GateMath.bet()
	check_eq(GateMath.label(b), "BET x2", "bet label")
	check_eq(GateMath.apply(40, b), 40, "a bet changes nothing at the gate")
	check_eq(GateMath.register_hit(b, 3.0, 3.0), 0, "bets cannot be shot")
	check(GateMath.is_deal(b) and GateMath.is_bet(b), "bet flags")
	var panels := [GateMath.add(3), b, t]
	check_eq(GateMath.best_index(panels, 40), 0, "the bot takes the sure thing")


func test_deals_in_lanes() -> void:
	var gen := Difficulty.new(9)
	var trades := 0
	var bets := 0
	for level in range(1, 10):
		for i in range(Difficulty.GATES_PER_LEVEL):
			var lanes := Progression.lanes_for(level, i)
			var panels := gen.make_gate(level, i, 30, lanes)
			var deals := 0
			for p in panels:
				if GateMath.is_trade(p):
					trades += 1
					deals += 1
					check(level >= Difficulty.TRADE_LEVEL, "no trades before level %d" % Difficulty.TRADE_LEVEL)
					check(p.value <= -3.0, "a trade costs at least three")
				if GateMath.is_bet(p):
					bets += 1
					deals += 1
					check(level >= Difficulty.BET_LEVEL, "no bets before level %d" % Difficulty.BET_LEVEL)
			check(deals <= 1, "one deal per gate")
			if lanes <= 3:
				check_eq(deals, 0, "deals need a fourth lane")
	check(trades > 2 and bets > 1, "deals appear (%d trades, %d bets)" % [trades, bets])
	check_eq(int(Difficulty.wave_for(3, 4).flankers), 0, "no flankers early")
	check(int(Difficulty.wave_for(4, 4).flankers) >= 1, "flankers from level 4")
	check_eq(int(Difficulty.wave_for(8, 0).flankers), 0, "never on the opener")
	check(Difficulty.horde_bite(10) >= 2 and Difficulty.horde_bite(200) == 10, "horde bite")


func test_modifier_records() -> void:
	SaveData.wipe()
	SaveData.record_run(500, 4, false, "hard")
	check_eq(SaveData.load_best("hard"), 500, "hard best kept apart")
	check_eq(SaveData.load_best(), 0, "normal untouched")
	check_eq(SaveData.load_best_level("hard"), 4, "hard level")
	SaveData.record_run(300, 2)
	check_eq(SaveData.load_best(), 300, "normal best")
	check_eq(SaveData.load_best("hard"), 500, "hard still 500")
	SaveData.save_modifier("nightmare")
	check_eq(SaveData.load_modifier(), "nightmare", "modifier persists")
	SaveData.wipe()
