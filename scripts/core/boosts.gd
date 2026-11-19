class_name Boosts
extends RefCounted
## Per-run boosts: bought with coins on the home screen, spent on the
## next run. A sink that never fills. Pure: what they cost, what is
## armed, what they do. Daily and weekly runs ignore them (fair seeds).

const CATALOG := {
	"bombs": {"name": "BOMB DROP", "desc": "Two extra bombs at the start of the next run", "cost": 300, "icon": "belt"},
	"sharp": {"name": "HOT ROUNDS", "desc": "+25% damage for the whole of the next run", "cost": 400, "icon": "power"},
	"pay": {"name": "DOUBLE PAY", "desc": "Twice the coins from the next run", "cost": 500, "icon": "magnet"},
	"wind": {"name": "SPARE WIND", "desc": "One more comeback in the next run, with or without SECOND WIND", "cost": 600, "icon": "wind"},
}
const ORDER := ["bombs", "sharp", "pay", "wind"]
const BOMBS := 2
const DAMAGE_MULT := 1.25
const COIN_MULT := 2.0
## Modes a boost is spent on. The daily and the weekly are everyone's
## same road with no upgrades, so no boosts either.
const MODES := ["levels", "endless", "rush"]

var armed: Dictionary = {}


static func title(id: String) -> String:
	return str(CATALOG[id]["name"])


static func description(id: String) -> String:
	return str(CATALOG[id]["desc"])


static func cost(id: String) -> int:
	return int(CATALOG[id]["cost"])


static func icon(id: String) -> String:
	return str(CATALOG[id]["icon"])


static func applies(mode: String) -> bool:
	return MODES.has(mode)


func is_armed(id: String) -> bool:
	return bool(armed.get(id, false))


func can_buy(id: String, coins: int) -> bool:
	return CATALOG.has(id) and not is_armed(id) and coins >= cost(id)


## Arms one boost. Returns the coins left, or [param coins] unchanged.
func buy(id: String, coins: int) -> int:
	if not can_buy(id, coins):
		return coins
	armed[id] = true
	return coins - cost(id)


## The boosts for a run of [param mode], as a dict for from_dict, and
## this set is spent. A mode they do not apply to leaves them armed for
## the next one. (A dict, not a Boosts: a script that builds its own
## class leaks at import.)
func take(mode: String) -> Dictionary:
	if not applies(mode):
		return {}
	var out := armed.duplicate()
	armed.clear()
	return out


func any_armed() -> bool:
	for id in ORDER:
		if is_armed(id):
			return true
	return false


## "Next run: BOMB DROP · DOUBLE PAY" for the home screen, or "".
func summary() -> String:
	var names := []
	for id in ORDER:
		if is_armed(id):
			names.append(title(id))
	return "Next run: %s" % " · ".join(names) if not names.is_empty() else ""


func bombs() -> int:
	return BOMBS if is_armed("bombs") else 0


func damage_mult() -> float:
	return DAMAGE_MULT if is_armed("sharp") else 1.0


func coin_mult() -> float:
	return COIN_MULT if is_armed("pay") else 1.0


func extra_winds() -> int:
	return 1 if is_armed("wind") else 0


func to_dict() -> Dictionary:
	return armed.duplicate()


func from_dict(d: Dictionary) -> void:
	armed.clear()
	for id in d.keys():
		if CATALOG.has(str(id)) and bool(d[id]):
			armed[str(id)] = true
