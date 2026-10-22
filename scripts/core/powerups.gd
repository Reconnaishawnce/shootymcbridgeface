class_name Powerups
extends RefCounted
## Power-ups: granted by a gate panel or a road crate, specific or mystery.
## Pure catalog and timers; the game and world read the state each frame.

const CATALOG := {
	"bomb": {"name": "BOMB", "desc": "Throw it. Clears the road ahead.", "seconds": 0.0},
	"slow": {"name": "SLOW-MO", "desc": "The road crawls for six seconds.", "seconds": 6.0},
	"shield": {"name": "SHIELD", "desc": "Nothing bites for six seconds.", "seconds": 6.0},
	"frenzy": {"name": "FRENZY", "desc": "Double fire rate for six seconds.", "seconds": 6.0},
}
const ORDER := ["bomb", "slow", "shield", "frenzy"]
const MYSTERY := "mystery"
const MAX_BOMBS := 3
const SLOW_FACTOR := 0.45
const FRENZY_MULT := 2.0

var bombs := 0
## id -> time (run seconds) the effect ends.
var _until: Dictionary = {}


static func title(id: String) -> String:
	if id == MYSTERY:
		return "?"
	return CATALOG[id]["name"]


static func description(id: String) -> String:
	if id == MYSTERY:
		return "Could be anything."
	return CATALOG[id]["desc"]


static func is_valid(id: String) -> bool:
	return id == MYSTERY or CATALOG.has(id)


## A mystery resolves to a real power-up through the run's RNG.
static func resolve(id: String, rng: RandomNumberGenerator) -> String:
	if id != MYSTERY:
		return id
	return ORDER[rng.randi_range(0, ORDER.size() - 1)]


## Grant a resolved power-up at [param now]. Returns true if anything
## changed (a fourth bomb is wasted).
func grant(id: String, now: float) -> bool:
	assert(CATALOG.has(id))
	if id == "bomb":
		if bombs >= MAX_BOMBS:
			return false
		bombs += 1
		return true
	var seconds := float(CATALOG[id]["seconds"])
	_until[id] = maxf(float(_until.get(id, 0.0)), now) + seconds
	return true


func active(id: String, now: float) -> bool:
	return float(_until.get(id, -1.0)) > now


func remaining(id: String, now: float) -> float:
	return maxf(0.0, float(_until.get(id, 0.0)) - now)


func take_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	return true


func world_speed_mult(now: float) -> float:
	return SLOW_FACTOR if active("slow", now) else 1.0


func fire_rate_mult(now: float) -> float:
	return FRENZY_MULT if active("frenzy", now) else 1.0


func shielded(now: float) -> bool:
	return active("shield", now)


func reset() -> void:
	bombs = 0
	_until.clear()
