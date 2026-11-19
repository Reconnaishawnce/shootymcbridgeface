class_name Cards
extends RefCounted
## Build cards: after a boss falls the road pauses and offers three.
## Unlike perks (numbers that go up), a card changes what a bullet or a
## bite does, and some pairs make a combo. Pure: the catalog, the bag,
## the counters, the numbers the game reads. Nothing here touches a node.

const CATALOG := {
	"ricochet": {"name": "RICOCHET", "rarity": "common", "max": 3, "icon": "ricochet"},
	"burn": {"name": "BURNING ROUNDS", "rarity": "common", "max": 3, "icon": "burn"},
	"frost": {"name": "COLD ROUNDS", "rarity": "common", "max": 2, "icon": "frost"},
	"medic": {"name": "FIELD MEDIC", "rarity": "common", "max": 3, "icon": "medic"},
	"charge": {"name": "OVERCHARGE", "rarity": "common", "max": 2, "icon": "charge"},
	"blast": {"name": "BLAST ROUNDS", "rarity": "rare", "max": 3, "icon": "bomb"},
	"martyr": {"name": "LAST STAND", "rarity": "rare", "max": 2, "icon": "martyr"},
	"crit": {"name": "DEAD EYE", "rarity": "rare", "max": 2, "icon": "crit"},
	"sentry": {"name": "SENTRY GUN", "rarity": "epic", "max": 2, "icon": "turret"},
	"execute": {"name": "EXECUTIONER", "rarity": "epic", "max": 1, "icon": "slayer"},
}
const ORDER := ["ricochet", "burn", "frost", "medic", "charge", "blast", "martyr", "crit", "sentry", "execute"]
const RARITIES := ["common", "rare", "epic"]
const RARITY_WEIGHT := {"common": 60, "rare": 30, "epic": 10}
## A card that would complete a combo with what you hold shows up more.
const COMBO_PULL := 1.6
const CARDS := 3

## Two cards that make a third thing.
const COMBOS := {
	"firestorm": {"name": "FIRESTORM", "needs": ["burn", "blast"], "desc": "Explosions set everything they touch on fire"},
	"shatter": {"name": "SHATTER", "needs": ["frost", "crit"], "desc": "Slowed zombies take half again as much from bullets"},
	"wildfire": {"name": "WILDFIRE", "needs": ["ricochet", "burn"], "desc": "Every bounce carries the fire"},
	"chain": {"name": "CHAIN REACTION", "needs": ["blast", "martyr"], "desc": "Every explosion is half again as wide"},
}
const COMBO_ORDER := ["firestorm", "shatter", "wildfire", "chain"]

const RICOCHET_MULT := 0.6
const RICOCHET_RANGE := 5.0
const BURN_FRACTION := 0.4
const BURN_SECONDS := 3.0
const SLOW := [1.0, 0.75, 0.55]
const SLOW_SECONDS := 2.0
const MEDIC_EVERY := [0, 15, 11, 8]
const CHARGE_MULT := 0.7
const BLAST_EVERY := [0, 8, 6, 4]
const BLAST_RADIUS := 2.6
const BLAST_DAMAGE_MULT := 3.0
const MARTYR_RADIUS := [0.0, 2.6, 3.6]
const MARTYR_DAMAGE_MULT := 4.0
const CRIT_EVERY := [0, 8, 5]
const CRIT_MULT := 3.0
const EXECUTE_FRACTION := 0.25
const SHATTER_MULT := 1.5
const CHAIN_RADIUS_MULT := 1.5

var stacks: Dictionary = {}
var _bullet_kills := 0
var _kills := 0
var _shots := 0


func stack(id: String) -> int:
	return int(stacks.get(id, 0))


func total() -> int:
	var n := 0
	for id in stacks:
		n += int(stacks[id])
	return n


func can_offer(id: String) -> bool:
	return CATALOG.has(id) and stack(id) < int(CATALOG[id]["max"])


func take(id: String) -> void:
	assert(CATALOG.has(id))
	stacks[id] = stack(id) + 1


static func title(id: String) -> String:
	return str(CATALOG[id]["name"])


static func rarity(id: String) -> String:
	return str(CATALOG[id]["rarity"])


static func icon(id: String) -> String:
	return str(CATALOG[id]["icon"])


static func max_stack(id: String) -> int:
	return int(CATALOG[id]["max"])


## What the card does at [param n] stacks, with the real numbers.
static func description(id: String, n: int = 1) -> String:
	n = clampi(n, 1, max_stack(id))
	match id:
		"ricochet":
			return "A kill bounces to the next zombie for %d%% damage%s" % [int(RICOCHET_MULT * 100.0), "" if n == 1 else ", %d times" % n]
		"burn":
			return "Hits burn for %d%% of the shot every second, for %d seconds" % [int(BURN_FRACTION * 100.0) * n, int(BURN_SECONDS)]
		"frost":
			return "Hits slow zombies by %d%% for %d seconds" % [int(round((1.0 - float(SLOW[n])) * 100.0)), int(SLOW_SECONDS)]
		"medic":
			return "One soldier back for every %d kills" % int(MEDIC_EVERY[n])
		"charge":
			return "The hero move recharges %d%% faster" % int(round((1.0 - pow(CHARGE_MULT, n)) * 100.0))
		"blast":
			return "Every %dth bullet kill explodes" % int(BLAST_EVERY[n])
		"martyr":
			return "A soldier lost to a bite goes out with a %s bang" % ("big" if n == 1 else "huge")
		"crit":
			return "Every %dth bullet hits for triple" % int(CRIT_EVERY[n])
		"sentry":
			return "A gold turret rides beside you for the rest of the run"
		"execute":
			return "Bullets finish any zombie under a quarter health"
	return ""


# --- combos ----------------------------------------------------------------

func has_combo(id: String) -> bool:
	for need in COMBOS[id]["needs"]:
		if stack(str(need)) < 1:
			return false
	return true


## Ids of the combos held, in COMBO_ORDER.
func combos() -> Array:
	var out := []
	for id in COMBO_ORDER:
		if has_combo(id):
			out.append(id)
	return out


static func combo_title(id: String) -> String:
	return str(COMBOS[id]["name"])


static func combo_description(id: String) -> String:
	return str(COMBOS[id]["desc"])


## The other half of [param combo] given one half, or "".
static func partner(combo: String, id: String) -> String:
	var needs: Array = COMBOS[combo]["needs"]
	if not needs.has(id):
		return ""
	return str(needs[1]) if str(needs[0]) == id else str(needs[0])


## What taking [param id] would do for combos: the line under the card.
## Completing one beats starting one; nothing new says nothing.
func combo_hint(id: String) -> String:
	if stack(id) > 0:
		return ""
	for combo in COMBO_ORDER:
		var other := partner(combo, id)
		if other != "" and stack(other) > 0:
			return "COMBO: %s with your %s" % [combo_title(combo), title(other)]
	for combo in COMBO_ORDER:
		var other := partner(combo, id)
		if other != "":
			return "Pairs with %s for %s" % [title(other), combo_title(combo)]
	return ""


func _completes_combo(id: String) -> bool:
	if stack(id) > 0:
		return false
	for combo in COMBO_ORDER:
		var other := partner(combo, id)
		if other != "" and stack(other) > 0:
			return true
	return false


# --- the draft -------------------------------------------------------------

## Up to CARDS distinct ids, drawn by rarity weight with [param rng] so a
## seed replays. [param blocked] are ids that cannot be used right now.
func offer(rng: RandomNumberGenerator, blocked: Array = []) -> Array:
	var pool: Array = []
	var weights: Array = []
	for id in ORDER:
		if not can_offer(id) or blocked.has(id):
			continue
		pool.append(id)
		weights.append(float(RARITY_WEIGHT[rarity(id)]) * (COMBO_PULL if _completes_combo(id) else 1.0))
	var out := []
	while out.size() < CARDS and not pool.is_empty():
		var sum := 0.0
		for w in weights:
			sum += float(w)
		var roll := rng.randf() * sum
		var pick := pool.size() - 1
		for i in range(pool.size()):
			roll -= float(weights[i])
			if roll < 0.0:
				pick = i
				break
		out.append(pool[pick])
		pool.remove_at(pick)
		weights.remove_at(pick)
	return out


## Whether the boss that just fell (the [param bosses_killed]-th of the
## run) pays a draft. Boss rush has a boss every gate, so every other.
static func drafts_after_boss(mode: String, bosses_killed: int) -> bool:
	if bosses_killed <= 0:
		return false
	return bosses_killed % 2 == 1 if mode == "rush" else true


## The line on the pause menu and the results card.
func summary() -> String:
	var parts := []
	for id in ORDER:
		var n := stack(id)
		if n > 0:
			parts.append(title(id) + ("  x%d" % n if n > 1 else ""))
	for id in combos():
		parts.append(combo_title(id) + "!")
	return "   ·   ".join(parts)


# --- effects ---------------------------------------------------------------

func ricochets() -> int:
	return stack("ricochet")


func burn_fraction() -> float:
	return BURN_FRACTION * float(stack("burn"))


func slow_mult() -> float:
	return float(SLOW[clampi(stack("frost"), 0, SLOW.size() - 1)])


func cooldown_mult() -> float:
	return pow(CHARGE_MULT, stack("charge"))


func blast_radius() -> float:
	return BLAST_RADIUS * (CHAIN_RADIUS_MULT if has_combo("chain") else 1.0)


func martyr_radius() -> float:
	return float(MARTYR_RADIUS[clampi(stack("martyr"), 0, MARTYR_RADIUS.size() - 1)]) * (CHAIN_RADIUS_MULT if has_combo("chain") else 1.0)


func executes() -> bool:
	return stack("execute") > 0


func shatter_mult() -> float:
	return SHATTER_MULT if has_combo("shatter") else 1.0


## A bullet left the barrel: true when it is a DEAD EYE shot.
func note_shot() -> bool:
	var every := int(CRIT_EVERY[clampi(stack("crit"), 0, CRIT_EVERY.size() - 1)])
	if every <= 0:
		return false
	_shots += 1
	if _shots >= every:
		_shots = 0
		return true
	return false


## A bullet killed something: true when BLAST ROUNDS goes off.
func note_bullet_kill() -> bool:
	var every := int(BLAST_EVERY[clampi(stack("blast"), 0, BLAST_EVERY.size() - 1)])
	if every <= 0:
		return false
	_bullet_kills += 1
	if _bullet_kills >= every:
		_bullet_kills = 0
		return true
	return false


## Anything died: true when the FIELD MEDIC brings a soldier back.
func note_kill() -> bool:
	var every := int(MEDIC_EVERY[clampi(stack("medic"), 0, MEDIC_EVERY.size() - 1)])
	if every <= 0:
		return false
	_kills += 1
	if _kills >= every:
		_kills = 0
		return true
	return false
