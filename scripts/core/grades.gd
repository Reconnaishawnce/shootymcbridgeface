class_name Grades
extends RefCounted
## A letter for each level cleared: how many gates you shot perfect, how
## much of the squad you kept, how fast the boss went down. S to D.

const LETTERS := ["S", "A", "B", "C", "D"]
const BONUS := {"S": 600, "A": 350, "B": 150, "C": 50, "D": 0}
## Boss seconds for full marks, and where the speed score hits zero.
const FAST_BOSS := 6.0
const SLOW_BOSS := 20.0


static func score(perfect: int, gates: int, peak: int, left: int, boss_seconds: float) -> float:
	var p := float(perfect) / float(maxi(gates, 1))
	var s := clampf(float(left) / float(maxi(peak, 1)), 0.0, 1.0)
	var v := 1.0 - clampf((boss_seconds - FAST_BOSS) / (SLOW_BOSS - FAST_BOSS), 0.0, 1.0)
	return 0.35 * p + 0.4 * s + 0.25 * v


static func grade(perfect: int, gates: int, peak: int, left: int, boss_seconds: float) -> String:
	var x := score(perfect, gates, peak, left, boss_seconds)
	if x >= 0.8:
		return "S"
	if x >= 0.65:
		return "A"
	if x >= 0.5:
		return "B"
	if x >= 0.35:
		return "C"
	return "D"


static func bonus(letter: String) -> int:
	return int(BONUS.get(letter, 0))
