class_name Convoy
extends RefCounted
## The convoy: soldiers turned into vehicles. A vehicle costs soldiers at
## a gate, carries health, fires in its own way, and stays with you from
## level to level while the soldiers reset. Pure data and the offer rule;
## the Vehicle node does the shooting.

const SPECS := {
	"jeep": {
		"name": "JEEP", "cost": 20, "hp": 90.0, "max": 2, "level": 1,
		"dps": 50.0, "shots": 8.0, "pierce": 2,
		"blurb": "A mounted gun: fast, straight, through two zombies at a time.",
	},
	"tank": {
		"name": "TANK", "cost": 60, "hp": 220.0, "max": 1, "level": 2,
		"dps": 90.0, "shots": 0.8, "splash": 2.0,
		"blurb": "Shells that burst. Slow, heavy, hits a crowd at once.",
	},
	"heli": {
		"name": "HELICOPTER", "cost": 120, "hp": 160.0, "max": 1, "level": 3,
		"dps": 110.0, "shots": 10.0, "pierce": 1, "flies": true, "cling_dps": 40.0,
		"blurb": "Hovers above the ground. Hunts thieves, runners and clingers. Nothing on the ground can touch it.",
	},
	"mech": {
		"name": "MECH", "cost": 250, "hp": 400.0, "max": 1, "level": 4,
		"dps": 220.0, "shots": 10.0, "pierce": 3, "beam": true,
		"blurb": "A walking laser. Burns straight through a column of zombies.",
	},
}
const ORDER := ["jeep", "tank", "heli", "mech"]
## Veteran ranks: kills a vehicle needs for each rank, and what a rank
## adds to its fire and its health.
const RANK_KILLS := [25, 75, 150]
const RANK_DPS := 0.15
const RANK_HP := 0.2
## A vehicle is offered once the squad has this many times its cost, so
## forming one never leaves you bare.
const OFFER_MARGIN := 1.6
## Points a vehicle still rolling is worth at the end of a level.
const LEVEL_BONUS_PER_VEHICLE := 100


static func title(id: String) -> String:
	return str(SPECS.get(id, {}).get("name", id.to_upper()))


static func cost(id: String) -> int:
	return int(SPECS.get(id, {}).get("cost", 0))


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, SPECS["jeep"])


static func can_offer(id: String, count: int, owned: int, level: int) -> bool:
	var s: Dictionary = SPECS[id]
	return level >= int(s.level) and owned < int(s.max) and float(count) >= float(s.cost) * OFFER_MARGIN


## The vehicle to offer a squad of [param count] that already owns
## [param owned] (id -> count), or "". The biggest affordable one first.
static func offer(count: int, owned: Dictionary, level: int) -> String:
	for i in range(ORDER.size() - 1, -1, -1):
		var id: String = ORDER[i]
		if can_offer(id, count, int(owned.get(id, 0)), level):
			return id
	return ""


static func flies(id: String) -> bool:
	return bool(spec(id).get("flies", false))


## Rank reached with [param kills]: 0 to RANK_KILLS.size().
static func rank_for(kills: int) -> int:
	var r := 0
	for need in RANK_KILLS:
		if kills >= int(need):
			r += 1
	return r


static func rank_dps_mult(rank: int) -> float:
	return 1.0 + RANK_DPS * float(rank)


static func rank_hp_mult(rank: int) -> float:
	return 1.0 + RANK_HP * float(rank)


## Damage per shot from the spec's DPS and rate.
static func damage_per_shot(id: String) -> float:
	var s := spec(id)
	return float(s.dps) / maxf(float(s.shots), 0.1)
