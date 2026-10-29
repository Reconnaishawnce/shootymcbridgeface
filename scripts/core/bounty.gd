class_name Bounty
extends RefCounted
## Coins per kill. Every zombie pays a bounty by kind, so a wide
## formation that mows a crowd earns more than a narrow one that drills
## what is in front of it. Pure.

const BY_KIND := {"normal": 1, "runner": 1, "thief": 2, "latcher": 2, "brute": 3, "tank": 5}
const BOSS := 25
const GATE := 2
## Extra on straight fire: the drill pays in damage, not coins.
const STRAIGHT_DAMAGE_MULT := 1.25
const STRAIGHT_PIERCE := 1


static func for_kind(kind_name: String) -> int:
	return int(BY_KIND.get(kind_name, 1))


## The run's coins: the bounty plus the bosses and gates.
static func coins_for_run(bounty: int, bosses: int, gates: int) -> int:
	return maxi(0, bounty) + bosses * BOSS + gates * GATE
