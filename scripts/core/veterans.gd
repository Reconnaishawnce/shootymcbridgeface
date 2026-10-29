class_name Veterans
extends RefCounted
## Named soldiers. Every boss you beat makes one survivor a veteran with
## a name, a beret and a trait the whole squad feels. A heavy bite can
## take one, and the loss is named. Up to MAX a run; they do not carry
## over. Pure: the roster and the maths, no nodes.

const MAX := 3
## Chance a heavy bite (brute, tank, boss chew, spit, strike, saw, horde)
## takes a veteran with it.
const RISK := 0.2
const TRAITS := {
	"deadeye": {"title": "DEADEYE", "desc": "+8% damage for the whole squad", "color": Color(0.9, 0.25, 0.2)},
	"tough": {"title": "TOUGH", "desc": "Every heavy bite takes 8% less", "color": Color(0.3, 0.5, 0.9)},
	"medic": {"title": "FIELD MEDIC", "desc": "A soldier comes back every 8 seconds", "color": Color(0.95, 0.95, 0.95)},
	"lucky": {"title": "LUCKY", "desc": "+15% bounty at the end of the run", "color": Color(0.98, 0.78, 0.2)},
}
const DAMAGE_PER := 0.08
const BITE_PER := 0.08
const MEDIC_SECONDS := 8.0
const COIN_PER := 0.15
const NAMES := ["ADA", "BO", "CAL", "DEV", "EZRA", "FINN", "GUS", "HOLT", "IKE", "JO", "KIT", "LEV", "MAE", "NICO", "OZ", "PIP", "QUINN", "REX", "SAM", "TESS", "UMA", "VIC", "WREN", "ZED", "RUBY", "MOSS", "JUNO", "BRAM", "LUX", "NELL"]

var roster: Array = []


func count() -> int:
	return roster.size()


func is_full() -> bool:
	return roster.size() >= MAX


## A survivor steps up: a fresh name and a trait, or {} when full.
func promote(rng: RandomNumberGenerator) -> Dictionary:
	if is_full():
		return {}
	var used := {}
	for v in roster:
		used[v.name] = true
	var name: String = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	while used.has(name):
		name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	var keys := TRAITS.keys()
	var v := {"name": name, "trait": keys[rng.randi_range(0, keys.size() - 1)]}
	roster.append(v)
	return v


## A heavy bite rolls for a veteran; returns the one lost, or {}.
func roll_loss(rng: RandomNumberGenerator) -> Dictionary:
	if roster.is_empty() or rng.randf() >= RISK:
		return {}
	return roster.pop_at(rng.randi_range(0, roster.size() - 1))


func _with(trait_id: String) -> int:
	var n := 0
	for v in roster:
		if v.trait == trait_id:
			n += 1
	return n


func damage_mult() -> float:
	return 1.0 + DAMAGE_PER * _with("deadeye")


func bite_mult() -> float:
	return 1.0 - BITE_PER * _with("tough")


func coin_mult() -> float:
	return 1.0 + COIN_PER * _with("lucky")


func medics() -> int:
	return _with("medic")


static func title(trait_id: String) -> String:
	return str(TRAITS[trait_id]["title"])


static func description(trait_id: String) -> String:
	return str(TRAITS[trait_id]["desc"])


static func color(trait_id: String) -> Color:
	return TRAITS[trait_id]["color"]


## "ADA the DEADEYE", for banners and tags.
static func label(v: Dictionary) -> String:
	return "%s the %s" % [str(v.name), title(str(v.trait))]


func summary() -> String:
	var parts := []
	for v in roster:
		parts.append(label(v))
	return "   ·   ".join(parts)
