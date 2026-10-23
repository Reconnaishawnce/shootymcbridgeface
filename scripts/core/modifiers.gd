class_name Modifiers
extends RefCounted
## Difficulty modifiers: NORMAL, HARD, NIGHTMARE. Each scales what the
## road throws at you and what it pays. Pure data and curves. The daily
## is always normal so everyone plays the same game.

const ORDER := ["normal", "hard", "nightmare"]

const TABLE := {
	"normal": {
		"name": "NORMAL", "wave": 1.0, "hp": 1.0, "boss": 1.0, "bite": 1.0,
		"strikes": 0, "score": 1.0, "coins": 1.0, "stars": 0,
		"horde_level": 4, "horde_speed": 1.0, "blurb": "The road as it comes.",
	},
	"hard": {
		"name": "HARD", "wave": 1.35, "hp": 1.25, "boss": 1.4, "bite": 1.3,
		"strikes": 1, "score": 1.5, "coins": 1.5, "stars": 1,
		"horde_level": 2, "horde_speed": 1.3, "blurb": "Bigger waves, meaner bosses. 1.5x score and coins.",
	},
	"nightmare": {
		"name": "NIGHTMARE", "wave": 1.6, "hp": 1.35, "boss": 1.8, "bite": 1.45,
		"strikes": 1, "score": 2.5, "coins": 2.5, "stars": 2,
		"horde_level": 1, "horde_speed": 1.6, "blurb": "Everything, all at once. 2.5x score and coins.",
	},
}

## Threat multipliers reach full strength at this level; before it they
## scale in, so level 1 on nightmare is harder, not hopeless.
const RAMP_LEVEL := 3


static func ramp(level: int) -> float:
	return clampf(float(level) / float(RAMP_LEVEL), 0.34, 1.0)


## Normal best level needed to open HARD; hard best level to open NIGHTMARE.
const HARD_UNLOCK_LEVEL := 3
const NIGHTMARE_UNLOCK_LEVEL := 4


static func get_value(id: String, key: String):
	var row: Dictionary = TABLE.get(id, TABLE["normal"])
	return row.get(key, TABLE["normal"][key])


static func title(id: String) -> String:
	return str(get_value(id, "name"))


static func blurb(id: String) -> String:
	return str(get_value(id, "blurb"))


static func unlocked(id: String, normal_best_level: int, hard_best_level: int) -> bool:
	match id:
		"hard":
			return normal_best_level >= HARD_UNLOCK_LEVEL
		"nightmare":
			return hard_best_level >= NIGHTMARE_UNLOCK_LEVEL
	return true


## What it takes to open [param id], for the title button.
static func unlock_text(id: String) -> String:
	match id:
		"hard":
			return "reach level %d" % HARD_UNLOCK_LEVEL
		"nightmare":
			return "reach level %d on hard" % NIGHTMARE_UNLOCK_LEVEL
	return ""


## The next modifier in the cycle that is open, wrapping to normal.
static func next(id: String, normal_best_level: int, hard_best_level: int) -> String:
	var i := ORDER.find(id)
	for k in range(1, ORDER.size() + 1):
		var cand: String = ORDER[(i + k) % ORDER.size()]
		if unlocked(cand, normal_best_level, hard_best_level):
			return cand
	return "normal"


## Save-file key suffix: normal keeps the old keys so nothing is lost.
static func key_suffix(id: String) -> String:
	return "" if id == "normal" or not TABLE.has(id) else "_" + id
