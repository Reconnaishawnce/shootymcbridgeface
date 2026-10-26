class_name Perks
extends RefCounted
## Run-scoped perks, offered as three cards every third gate. Pure: a
## catalog plus a bag of stacks, with getters the game reads when it needs
## them. No nodes, fully unit-testable.

const CATALOG := {
	"rapid": {"name": "RAPID FIRE", "desc": "+25% fire rate", "max": 4},
	"big": {"name": "BIG BULLETS", "desc": "+40% bullet size", "max": 2},
	"pierce": {"name": "PIERCING", "desc": "Bullets pass through a kill", "max": 2},
	"whisper": {"name": "GATE WHISPERER", "desc": "Gates step up 25% faster", "max": 3},
	"recruit": {"name": "RECRUITER", "desc": "+1 soldier at every gate", "max": 2},
	"skin": {"name": "THICK SKIN", "desc": "Brutes eat a third less", "max": 2},
	"sight": {"name": "LONG SIGHT", "desc": "Hidden gates show from farther", "max": 2},
	"core": {"name": "CORE SIGHT", "desc": "Boss core takes +1x damage", "max": 3},
	"greed": {"name": "GREED", "desc": "+30% coins", "max": 3},
	# Convoy perks: only offered once you have a vehicle.
	"plating": {"name": "PLATING", "desc": "Vehicles take 40% less", "max": 1, "vehicle": true},
	"overdrive": {"name": "OVERDRIVE", "desc": "Vehicles fire 30% faster", "max": 2, "vehicle": true},
}
## A pick is offered after every PICK_EVERY-th gate of a level.
const PICK_EVERY := 3
const CARDS := 3

var stacks: Dictionary = {}


func stack(id: String) -> int:
	return int(stacks.get(id, 0))


func total() -> int:
	var n := 0
	for id in stacks:
		n += int(stacks[id])
	return n


func can_offer(id: String) -> bool:
	return stack(id) < int(CATALOG[id]["max"])


## Up to CARDS distinct perk ids, shuffled with [param rng] so runs replay.
func offer(rng: RandomNumberGenerator, has_vehicles: bool = false) -> Array:
	var pool: Array = []
	for id in CATALOG:
		if can_offer(id) and (has_vehicles or not bool(CATALOG[id].get("vehicle", false))):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(CARDS, pool.size()))


func take(id: String) -> void:
	assert(CATALOG.has(id))
	stacks[id] = stack(id) + 1


## True for gate indices (0-based, within a level) that trigger an offer.
## With eight gates and PICK_EVERY 3 that is the third and sixth gate.
static func is_pick_gate(gate_index: int) -> bool:
	var n := gate_index + 1
	return n % PICK_EVERY == 0 and n < Difficulty.GATES_PER_LEVEL


static func title(id: String) -> String:
	return CATALOG[id]["name"]


static func description(id: String) -> String:
	return CATALOG[id]["desc"]


# --- effects ---------------------------------------------------------------

func vehicle_fire_mult() -> float:
	return 1.0 + 0.3 * float(stacks.get("overdrive", 0))


func vehicle_damage_mult() -> float:
	return 0.6 if int(stacks.get("plating", 0)) > 0 else 1.0


func fire_rate_mult() -> float:
	return 1.0 + 0.25 * stack("rapid")


func bullet_radius_mult() -> float:
	return 1.0 + 0.4 * stack("big")


func pierce() -> int:
	return stack("pierce")


func step_cost_mult() -> float:
	return pow(0.75, stack("whisper"))


func recruit_per_gate() -> int:
	return stack("recruit")


func brute_bite_mult() -> float:
	return pow(0.67, stack("skin"))


## Extra metres of reveal range for hidden panels.
func reveal_bonus() -> float:
	return 15.0 * stack("sight")


func core_mult_bonus() -> float:
	return 1.0 * stack("core")


func coin_mult() -> float:
	return 1.0 + 0.3 * stack("greed")
