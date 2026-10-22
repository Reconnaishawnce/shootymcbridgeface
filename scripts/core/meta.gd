class_name Meta
extends RefCounted
## Permanent upgrades bought with coins between runs. Pure catalog and math;
## the levels dictionary is loaded from and saved to SaveData by the game.

const CATALOG := {
	"start": {"name": "RECRUITS", "desc": "Start every level with +1 soldier", "max": 5, "base": 40},
	"power": {"name": "FIREPOWER", "desc": "+8% damage", "max": 5, "base": 50},
	"gate": {"name": "GATE BONUS", "desc": "+1 on every positive gate", "max": 3, "base": 80},
	"armor": {"name": "ARMOR", "desc": "Brutes eat 1% less of the squad", "max": 4, "base": 60},
	"slayer": {"name": "BOSS SLAYER", "desc": "Boss core takes +0.5x damage", "max": 4, "base": 70},
	"magnet": {"name": "COIN MAGNET", "desc": "+15% coins", "max": 4, "base": 45},
	"scout": {"name": "SCOUT", "desc": "Hidden gates show 8 m sooner", "max": 3, "base": 55},
	"shotgun": {"name": "SHOTGUNNERS", "desc": "Unlock the shotgun squad", "max": 1, "base": 200},
	"medic": {"name": "MEDICS", "desc": "Unlock the medic squad", "max": 1, "base": 250},
}
const ORDER := ["start", "power", "gate", "armor", "slayer", "magnet", "scout", "shotgun", "medic"]
const SQUAD_TYPES := ["rifle", "shotgun", "medic"]
const COST_GROWTH := 1.7
## Clearing this level unlocks Endless mode.
const ENDLESS_UNLOCK_LEVEL := 3

var levels: Dictionary = {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


func is_maxed(id: String) -> bool:
	return level(id) >= int(CATALOG[id]["max"])


static func cost_at(id: String, current_level: int) -> int:
	return int(round(float(CATALOG[id]["base"]) * pow(COST_GROWTH, current_level)))


func cost(id: String) -> int:
	return cost_at(id, level(id))


func can_buy(id: String, coins: int) -> bool:
	return not is_maxed(id) and coins >= cost(id)


## Buys one level. Returns the coins left, or [param coins] unchanged if the
## purchase was not possible.
func buy(id: String, coins: int) -> int:
	if not can_buy(id, coins):
		return coins
	var c := cost(id)
	levels[id] = level(id) + 1
	return coins - c


static func title(id: String) -> String:
	return CATALOG[id]["name"]


static func description(id: String) -> String:
	return CATALOG[id]["desc"]


static func max_level(id: String) -> int:
	return int(CATALOG[id]["max"])


## Coins a run pays out before multipliers.
static func coins_for_run(kills: int, bosses: int, gates: int) -> int:
	return kills / 4 + bosses * 25 + gates * 2


static func endless_unlocked(best_level: int) -> bool:
	return best_level > ENDLESS_UNLOCK_LEVEL


# --- effects ---------------------------------------------------------------

func start_squad() -> int:
	return 1 + level("start")


func damage_mult() -> float:
	return 1.0 + 0.08 * level("power")


func gate_bonus() -> int:
	return level("gate")


## Fraction of the squad a brute eats, after armor.
func brute_bite_fraction(base: float) -> float:
	return maxf(0.02, base - 0.01 * level("armor"))


func core_mult_bonus() -> float:
	return 0.5 * level("slayer")


func coin_mult() -> float:
	return 1.0 + 0.15 * level("magnet")


func reveal_bonus() -> float:
	return 8.0 * level("scout")


func shotgun_unlocked() -> bool:
	return level("shotgun") >= 1


func squad_unlocked(type: String) -> bool:
	match type:
		"rifle":
			return true
		"shotgun":
			return level("shotgun") >= 1
		"medic":
			return level("medic") >= 1
	return false


## The next unlocked squad type after [param current], wrapping round.
func next_squad(current: String) -> String:
	var i := SQUAD_TYPES.find(current)
	for step in range(1, SQUAD_TYPES.size() + 1):
		var t: String = SQUAD_TYPES[(i + step) % SQUAD_TYPES.size()]
		if squad_unlocked(t):
			return t
	return "rifle"
