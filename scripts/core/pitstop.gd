class_name PitStop
extends RefCounted
## The pit stop: a bay on the right side of the road, once a level from
## PIT_LEVEL. Steer into it and the road waits while you spend this
## run's bounty on this run's gear. Nothing here outlives the run; the
## shop on the title is where coins buy what lasts. Pure.

const ITEMS := {
	"rounds": {"name": "SHARPER ROUNDS", "desc": "Every bullet hits harder", "base": 60, "growth": 1.5, "max": 5, "unit": "damage"},
	"rifles": {"name": "FASTER RIFLES", "desc": "The whole squad fires faster", "base": 60, "growth": 1.5, "max": 5, "unit": "fire rate"},
	"armor": {"name": "FLAK JACKETS", "desc": "Every heavy bite takes less", "base": 80, "growth": 1.5, "max": 3, "unit": "bites"},
	"bomb": {"name": "BOMB", "desc": "One more in the belt", "base": 25, "growth": 1.0, "max": 99, "unit": "bomb"},
	"dressing": {"name": "FIELD DRESSING", "desc": "Soldiers back on their feet, now", "base": 45, "growth": 1.3, "max": 99, "unit": "soldiers"},
}
const ORDER := ["rounds", "rifles", "armor", "bomb", "dressing"]
const PIT_LEVEL := 2
## The bay sits this far past the gate at BAY_GATE_INDEX.
const BAY_GATE_INDEX := 5
const BAY_OFFSET := 16.0
const DAMAGE_PER := 0.12
const FIRE_PER := 0.12
const BITE_PER := 0.1
## Field dressing: this fraction of the squad, at least DRESSING_MIN.
const DRESSING_FRACTION := 0.1
const DRESSING_MIN := 4

var stacks: Dictionary = {}


func stack(id: String) -> int:
	return int(stacks.get(id, 0))


func is_maxed(id: String) -> bool:
	return stack(id) >= int(ITEMS[id]["max"])


func cost(id: String) -> int:
	return int(round(float(ITEMS[id]["base"]) * pow(float(ITEMS[id]["growth"]), stack(id))))


func can_buy(id: String, funds: int) -> bool:
	return not is_maxed(id) and funds >= cost(id)


## Spend; returns the funds left (unchanged when it could not).
func buy(id: String, funds: int) -> int:
	if not can_buy(id, funds):
		return funds
	var left := funds - cost(id)
	stacks[id] = stack(id) + 1
	return left


func damage_mult() -> float:
	return 1.0 + DAMAGE_PER * stack("rounds")


func fire_mult() -> float:
	return 1.0 + FIRE_PER * stack("rifles")


func bite_mult() -> float:
	return 1.0 - BITE_PER * stack("armor")


static func dressing_for(count: int) -> int:
	return maxi(DRESSING_MIN, int(float(count) * DRESSING_FRACTION))


static func title(id: String) -> String:
	return str(ITEMS[id]["name"])


static func description(id: String) -> String:
	return str(ITEMS[id]["desc"])


## What a stack is worth, as the card prints it.
static func effect_text(id: String, n: int, count: int = 0) -> String:
	match id:
		"rounds":
			return "+%d%% damage" % int(round(DAMAGE_PER * 100.0 * n))
		"rifles":
			return "+%d%% fire rate" % int(round(FIRE_PER * 100.0 * n))
		"armor":
			return "-%d%% on heavy bites" % int(round(BITE_PER * 100.0 * n))
		"bomb":
			return "+1 bomb"
		"dressing":
			return "+%d soldiers" % dressing_for(count)
	return ""


static func bay_distance(level: int) -> float:
	return Difficulty.gate_distance(BAY_GATE_INDEX) + BAY_OFFSET


static func has_bay(level: int) -> bool:
	return level >= PIT_LEVEL
