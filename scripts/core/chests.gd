class_name Chests
extends RefCounted
## Chests: quest, road and season rewards arrive as a chest you tap
## open. Every chest holds the reward it was earned for, and rolls for
## a bonus on top, with a small chance of a jackpot. The roll is made
## when the chest is earned and kept with it, so closing the game does
## not buy another throw. Pure: making, rolling, totals and the text.

const TIERS := ["wood", "silver", "gold"]
const TITLES := {"wood": "QUEST CHEST", "silver": "ROAD CHEST", "gold": "GOLD CHEST"}
## Per tier, the chances of each bonus and the range it pays. What is
## left over is no bonus at all.
const BONUS := {
	"wood": {"coins": 0.24, "stars": 0.05, "jackpot": 0.01, "coins_range": [40, 90], "stars_range": [1, 2]},
	"silver": {"coins": 0.30, "stars": 0.10, "jackpot": 0.03, "coins_range": [80, 180], "stars_range": [2, 3]},
	"gold": {"coins": 0.38, "stars": 0.18, "jackpot": 0.06, "coins_range": [150, 300], "stars_range": [3, 5]},
}
## A jackpot pays this many coins and stars.
const JACKPOT := {"wood": [600, 3], "silver": [1000, 5], "gold": [1500, 8]}
## A locker item already owned pays its price in stars instead.
const OWNED_MIN_STARS := 1


static func title(tier: String) -> String:
	return str(TITLES.get(tier, TITLES["wood"]))


## The bonus for a chest of [param tier]: {"kind": "none"} or coins,
## stars or a jackpot with amounts.
static func roll_bonus(tier: String, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = BONUS.get(tier, BONUS["wood"])
	var roll := rng.randf()
	if roll < float(t.jackpot):
		var j: Array = JACKPOT.get(tier, JACKPOT["wood"])
		return {"kind": "jackpot", "coins": int(j[0]), "stars": int(j[1])}
	roll -= float(t.jackpot)
	if roll < float(t.stars):
		return {"kind": "stars", "amount": rng.randi_range(int(t.stars_range[0]), int(t.stars_range[1]))}
	roll -= float(t.stars)
	if roll < float(t.coins):
		return {"kind": "coins", "amount": rng.randi_range(int(t.coins_range[0]), int(t.coins_range[1]))}
	return {"kind": "none"}


## A chest: where it came from ([param label]), what it was earned for
## ([param base]: {"kind": "coins"|"stars"|"item", "amount"/"id"}), and
## the bonus rolled now.
static func make(tier: String, label: String, base: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := {"kind": str(base.get("kind", "coins"))}
	if b.kind == "item":
		b["id"] = str(base.get("id", ""))
	else:
		b["amount"] = int(base.get("amount", 0))
	return {"tier": tier if TIERS.has(tier) else "wood", "label": label, "base": b, "bonus": roll_bonus(tier, rng)}


static func is_jackpot(chest: Dictionary) -> bool:
	return str(chest.get("bonus", {}).get("kind", "")) == "jackpot"


## What opening pays: {"coins", "stars", "item"} where item is the id of
## a locker item to hand over, or "" (none, or [param item_owned] and so
## paid in stars at [param item_cost]).
static func totals(chest: Dictionary, item_owned: bool = false, item_cost: int = 0) -> Dictionary:
	var out := {"coins": 0, "stars": 0, "item": ""}
	var base: Dictionary = chest.get("base", {})
	match str(base.get("kind", "")):
		"coins":
			out.coins += int(base.get("amount", 0))
		"stars":
			out.stars += int(base.get("amount", 0))
		"item":
			if item_owned:
				out.stars += maxi(OWNED_MIN_STARS, item_cost)
			else:
				out.item = str(base.get("id", ""))
	var bonus: Dictionary = chest.get("bonus", {})
	match str(bonus.get("kind", "none")):
		"coins":
			out.coins += int(bonus.get("amount", 0))
		"stars":
			out.stars += int(bonus.get("amount", 0))
		"jackpot":
			out.coins += int(bonus.get("coins", 0))
			out.stars += int(bonus.get("stars", 0))
	return out


## The reveal: the big line for what the chest was earned for, and the
## bonus line under it ("" when there is none).
static func reveal(chest: Dictionary, item_name: String = "", item_owned: bool = false, item_cost: int = 0) -> Dictionary:
	var base: Dictionary = chest.get("base", {})
	var main := ""
	match str(base.get("kind", "")):
		"coins":
			main = "%d COINS" % int(base.get("amount", 0))
		"stars":
			var n := int(base.get("amount", 0))
			main = "%d %s" % [n, "STAR" if n == 1 else "STARS"]
		"item":
			main = "%s, OWNED: %d STARS" % [item_name, maxi(OWNED_MIN_STARS, item_cost)] if item_owned else "%s FOR THE LOCKER" % item_name
	var bonus: Dictionary = chest.get("bonus", {})
	var extra := ""
	match str(bonus.get("kind", "none")):
		"coins":
			extra = "BONUS: +%d COINS" % int(bonus.get("amount", 0))
		"stars":
			var s := int(bonus.get("amount", 0))
			extra = "BONUS: +%d %s" % [s, "STAR" if s == 1 else "STARS"]
		"jackpot":
			extra = "JACKPOT! +%d COINS AND %d STARS" % [int(bonus.get("coins", 0)), int(bonus.get("stars", 0))]
	return {"main": main, "bonus": extra, "jackpot": is_jackpot(chest)}


## Only well-formed chests, for a save that may hold anything.
static func clean(list) -> Array:
	var out := []
	if not (list is Array):
		return out
	for c in list:
		if not (c is Dictionary) or not TIERS.has(str(c.get("tier", ""))):
			continue
		var base = c.get("base", null)
		if not (base is Dictionary) or not ["coins", "stars", "item"].has(str(base.get("kind", ""))):
			continue
		var bonus = c.get("bonus", {"kind": "none"})
		out.append({"tier": str(c.tier), "label": str(c.get("label", "")), "base": base, "bonus": bonus if bonus is Dictionary else {"kind": "none"}})
	return out


## The chance a chest of [param tier] holds any bonus, for the help page.
static func bonus_chance(tier: String) -> float:
	var t: Dictionary = BONUS.get(tier, BONUS["wood"])
	return float(t.coins) + float(t.stars) + float(t.jackpot)
