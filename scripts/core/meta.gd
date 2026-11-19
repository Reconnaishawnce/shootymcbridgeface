class_name Meta
extends RefCounted
## Permanent upgrades bought with coins between runs. Pure catalog and math;
## the levels dictionary is loaded from and saved to SaveData by the game.

const CATALOG := {
	"start": {"name": "RECRUITS", "desc": "Start every level with more soldiers", "max": 5, "base": 400, "unit": "soldiers"},
	"power": {"name": "FIREPOWER", "desc": "Every bullet hits harder", "max": 5, "base": 500, "unit": "damage"},
	"gate": {"name": "GATE BONUS", "desc": "Extra soldiers on every blue gate", "max": 3, "base": 800, "unit": "per gate"},
	"armor": {"name": "ARMOR", "desc": "Brutes, bosses and lightning take less", "max": 4, "base": 600, "unit": "bites"},
	"slayer": {"name": "BOSS SLAYER", "desc": "Boss core takes more damage", "max": 4, "base": 700, "unit": "core"},
	"magnet": {"name": "COIN MAGNET", "desc": "More coins from every run", "max": 4, "base": 450, "unit": "coins"},
	"scout": {"name": "SCOUT", "desc": "Hidden panels show sooner", "max": 3, "base": 550, "unit": "reveal"},
	"belt": {"name": "BOMB BELT", "desc": "Start every run with bombs", "max": 2, "base": 750, "unit": "bombs"},
	"wind": {"name": "SECOND WIND", "desc": "Once a run, a wipe becomes a comeback", "max": 1, "base": 1500, "unit": "comeback"},
	"shotgun": {"name": "SHOTGUNNERS", "desc": "Unlock the shotgun squad", "max": 1, "base": 1250, "unit": "squad"},
	"medic": {"name": "MEDICS", "desc": "Unlock the medic squad", "max": 1, "base": 1600, "unit": "squad"},
	"hero": {"name": "HERO POWER", "desc": "A shorter wait and a bigger hit for the hero move", "max": 3, "base": 900, "unit": "move"},
	"sniper": {"name": "SNIPERS", "desc": "Unlock the sniper squad (free at 2000 trophies)", "max": 1, "base": 2200, "unit": "squad"},
}
const ORDER := ["start", "power", "gate", "armor", "belt", "wind", "hero", "slayer", "magnet", "scout", "shotgun", "medic", "sniper"]
const SQUAD_TYPES := ["rifle", "shotgun", "medic", "sniper"]
const COST_GROWTH := 1.6
## ENLIST: past max, an upgrade keeps growing a tier at a time, one
## percent (or a fraction of a soldier) each, with no end but the cost.
const ENLIST := ["start", "power", "gate", "armor", "slayer", "magnet", "scout", "hero"]
const ENLIST_COST_MULT := 2.5
const ENLIST_GROWTH := 1.12
## Fractions of a soldier per tier for the whole-number upgrades.
const ENLIST_START_PER := 4
const ENLIST_GATE_PER := 5
## Soldiers a second wind brings back.
const SECOND_WIND_SOLDIERS := 8
## Clearing this level unlocks Endless mode.
const ENDLESS_UNLOCK_LEVEL := 3

var levels: Dictionary = {}
var enlist: Dictionary = {}


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


# --- enlist ----------------------------------------------------------------

func tiers(id: String) -> int:
	return int(enlist.get(id, 0))


static func enlistable(id: String) -> bool:
	return ENLIST.has(id)


static func enlist_cost_at(id: String, tier: int) -> int:
	return int(round(float(CATALOG[id]["base"]) * ENLIST_COST_MULT * pow(ENLIST_GROWTH, tier)))


func enlist_cost(id: String) -> int:
	return enlist_cost_at(id, tiers(id))


func can_enlist(id: String, coins: int) -> bool:
	return enlistable(id) and is_maxed(id) and coins >= enlist_cost(id)


## Buys one tier. Returns the coins left, or [param coins] unchanged.
func enlist_tier(id: String, coins: int) -> int:
	if not can_enlist(id, coins):
		return coins
	var c := enlist_cost(id)
	enlist[id] = tiers(id) + 1
	return coins - c


## What the tiers add, for the shop tile: "+3% damage", "+1 soldier".
static func enlist_text(id: String, tier: int) -> String:
	match id:
		"start":
			return "+%d soldier%s (%d/%d)" % [tier / ENLIST_START_PER, "" if tier / ENLIST_START_PER == 1 else "s", tier % ENLIST_START_PER, ENLIST_START_PER]
		"gate":
			return "+%d per gate (%d/%d)" % [tier / ENLIST_GATE_PER, tier % ENLIST_GATE_PER, ENLIST_GATE_PER]
		"power":
			return "+%d%% damage" % tier
		"armor":
			return "-%.1f%% on bites" % (0.5 * tier)
		"slayer":
			return "core +%.2f" % (0.01 * tier)
		"magnet":
			return "+%d%% coins" % tier
		"scout":
			return "+%d m sooner" % tier
		"hero":
			return "+%d%% hero move" % tier
	return ""


func hero_power_bonus() -> float:
	return 0.01 * tiers("hero")


## Coins a run pays out before multipliers.
## The run's coins. The bounty is what the kills paid (see Bounty).
static func coins_for_run(bounty: int, bosses: int, gates: int) -> int:
	return Bounty.coins_for_run(bounty, bosses, gates)


static func endless_unlocked(best_level: int) -> bool:
	return best_level > ENDLESS_UNLOCK_LEVEL


# --- effects ---------------------------------------------------------------

func start_squad() -> int:
	return 1 + 2 * level("start") + tiers("start") / ENLIST_START_PER


func damage_mult() -> float:
	return 1.0 + 0.12 * level("power") + 0.01 * tiers("power")


func gate_bonus() -> int:
	return 2 * level("gate") + tiers("gate") / ENLIST_GATE_PER


## Fraction of the squad a brute eats, after armor.
func brute_bite_fraction(base: float) -> float:
	return base * bite_mult()


## What every heavy bite (brute, boss, spit, lightning) is scaled by.
func bite_mult() -> float:
	return maxf(0.25, 1.0 - 0.12 * level("armor") - 0.005 * tiers("armor"))


func core_mult_bonus() -> float:
	return 0.5 * level("slayer") + 0.01 * tiers("slayer")


func coin_mult() -> float:
	return 1.0 + 0.2 * level("magnet") + 0.01 * tiers("magnet")


func start_bombs() -> int:
	return level("belt")


func has_second_wind() -> bool:
	return level("wind") >= 1


## What an upgrade does at [param lvl], for the shop's now-and-next line.
static func effect_text(id: String, lvl: int) -> String:
	match id:
		"start":
			return "%d at level start" % (1 + 2 * lvl)
		"power":
			return "+%d%% damage" % (12 * lvl)
		"gate":
			return "+%d per blue gate" % (2 * lvl)
		"armor":
			return "-%d%% on bites" % (12 * lvl)
		"slayer":
			return "core x%.1f" % (3.0 + 0.5 * lvl)
		"magnet":
			return "+%d%% coins" % (20 * lvl)
		"scout":
			return "%d m sooner" % (8 * lvl)
		"belt":
			return "%d at start" % lvl
		"wind":
			return "one comeback" if lvl >= 1 else "none"
		"shotgun", "medic", "sniper":
			return "unlocked" if lvl >= 1 else "locked"
		"hero":
			return "%d s, x%.2f" % [int(Abilities.cooldown(lvl)), Abilities.power(lvl)]
	return ""


func reveal_bonus() -> float:
	return 8.0 * level("scout") + 1.0 * tiers("scout")


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
		"sniper":
			return level("sniper") >= 1
	return false


## The next unlocked squad type after [param current], wrapping round.
func next_squad(current: String) -> String:
	var i := SQUAD_TYPES.find(current)
	for step in range(1, SQUAD_TYPES.size() + 1):
		var t: String = SQUAD_TYPES[(i + step) % SQUAD_TYPES.size()]
		if squad_unlocked(t):
			return t
	return "rifle"
