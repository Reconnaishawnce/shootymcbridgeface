class_name Rivals
extends RefCounted
## Someone to beat while you play. In the daily and the weekly the
## rivals are the names on the board; in every mode your own best is
## one of them. The HUD shows the next score above yours and the game
## says so when you pass it. Pure: the list, the next target, who was
## just passed.

const SELF_NAME := "YOUR BEST"

## {name, score, self} sorted by score, lowest first.
var targets: Array = []
## Names passed so far this run, in order.
var passed: Array = []


func _sort() -> void:
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) < int(b.score))


## Your own best in this mode: beaten, it is a new best.
func set_best(score: int) -> void:
	for t in targets.duplicate():
		if bool(t.get("self", false)):
			targets.erase(t)
	if score > 0:
		targets.append({"name": SELF_NAME, "score": score, "self": true})
	_sort()


## The board's rows ({rank, name, score}); [param your_rank] is your own
## row, left out because your best is already a target. Rivals already
## behind [param score_now] are not announced later.
func set_board(rows: Array, your_rank: int = 0, score_now: int = 0) -> void:
	for t in targets.duplicate():
		if not bool(t.get("self", false)):
			targets.erase(t)
	for r in rows:
		if not (r is Dictionary) or int(r.get("rank", 0)) == your_rank:
			continue
		var s := int(r.get("score", 0))
		if s > score_now and str(r.get("name", "")) != "":
			targets.append({"name": str(r.name), "score": s, "self": false})
	_sort()


## The lowest target still above [param score], or {} when none is left.
func next(score: int) -> Dictionary:
	for t in targets:
		if int(t.score) > score:
			return t
	return {}


## Call as the score climbs: the targets passed since the last call,
## lowest first. Each is reported once.
func advance(score: int) -> Array:
	var out := []
	for t in targets.duplicate():
		if int(t.score) < score:
			out.append(t)
			passed.append(str(t.name))
			targets.erase(t)
	return out


## The HUD's line: who is next and how far, or "" with nobody above.
func chip(score: int) -> String:
	var n := next(score)
	if n.is_empty():
		return ""
	return "%s  %d   ·   %d to go" % [str(n.name), int(n.score), int(n.score) - score]


## What to shout when [param t] is passed.
static func shout(t: Dictionary) -> String:
	return "NEW BEST!" if bool(t.get("self", false)) else "PASSED %s" % str(t.name)


## The results card's line: who this run got past.
func summary() -> String:
	var names := []
	for n in passed:
		if n != SELF_NAME:
			names.append(n)
	if names.is_empty():
		return ""
	if names.size() <= 3:
		return "PASSED  %s" % ", ".join(names)
	return "PASSED  %s and %d more" % [", ".join(names.slice(names.size() - 2)), names.size() - 2]
