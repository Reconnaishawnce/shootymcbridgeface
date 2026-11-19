class_name NearMiss
extends RefCounted
## The line on the results card that says how close that was. Pure.

## Within this fraction of the best score it is "SO CLOSE".
const CLOSE := 0.1


## "" for a first run or a new best; otherwise how far short the run fell.
static func line(score: int, best: int, is_best: bool) -> String:
	if is_best or best <= 0 or score >= best:
		return ""
	var gap := best - score
	if float(gap) <= float(best) * CLOSE:
		return "SO CLOSE: %d short of your best" % gap
	return "%d short of your best" % gap


static func is_close(score: int, best: int) -> bool:
	return best > 0 and score < best and float(best - score) <= float(best) * CLOSE
