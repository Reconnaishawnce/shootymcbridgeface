class_name Stats
extends RefCounted
## Lifetime numbers, kept across runs. Pure: a dictionary with known keys
## and a merge. The game adds a run's numbers at the end of the run.

const KEYS := ["runs", "kills", "bosses", "gates", "perfect", "distance", "best_combo", "bets_won", "bets_lost", "dailies", "weeklies", "hard_bosses", "nightmare_bosses", "s_grades", "stars_earned", "coins_earned", "best_level", "endless_level", "escapes"]
## Keys that keep the larger value instead of adding.
const MAX_KEYS := ["best_combo", "best_level", "endless_level"]


static func blank() -> Dictionary:
	var d := {}
	for k in KEYS:
		d[k] = 0
	return d


## Fold [param run] into [param total]: sums, except the best-of keys.
static func merge(total: Dictionary, run: Dictionary) -> Dictionary:
	var out := blank()
	for k in KEYS:
		var a := int(total.get(k, 0))
		var b := int(run.get(k, 0))
		out[k] = maxi(a, b) if MAX_KEYS.has(k) else a + b
	return out


## Lines for the records page.
static func lines(d: Dictionary) -> Array:
	return [
		"Runs  %d" % int(d.get("runs", 0)),
		"Zombies killed  %d" % int(d.get("kills", 0)),
		"Bosses killed  %d" % int(d.get("bosses", 0)),
		"Gates passed  %d   ·   perfect  %d" % [int(d.get("gates", 0)), int(d.get("perfect", 0))],
		"Distance  %d m" % int(d.get("distance", 0)),
		"Best combo  %d" % int(d.get("best_combo", 0)),
		"Best level  %d   ·   endless  %d" % [int(d.get("best_level", 0)), int(d.get("endless_level", 0))],
		"S grades  %d" % int(d.get("s_grades", 0)),
		"Bets won  %d   ·   lost  %d" % [int(d.get("bets_won", 0)), int(d.get("bets_lost", 0))],
		"Dailies  %d   ·   weeklies  %d" % [int(d.get("dailies", 0)), int(d.get("weeklies", 0))],
		"Coins earned  %d   ·   stars earned  %d" % [int(d.get("coins_earned", 0)), int(d.get("stars_earned", 0))],
	]
