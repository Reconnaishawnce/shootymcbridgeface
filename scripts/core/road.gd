class_name Road
extends RefCounted
## The trophy road: one long track every run adds to and nothing takes
## away. Trophies come from the level reached and the grades, more on
## hard and nightmare. A milestone every MILESTONE trophies pays coins,
## stars or a locker item; fixed points open features; a checkpoint
## every CHECKPOINT is a floor you never drop below (the road never goes
## down, so the floor is a marker of where you stand for good). Pure.

const MILESTONE := 100
const CHECKPOINT := 500
const LENGTH := 5000
const PER_LEVEL := 10
const GRADE_TROPHIES := {"S": 15, "A": 10, "B": 5, "C": 2, "D": 0}
const MODE_MULT := {"normal": 1.0, "hard": 2.0, "nightmare": 3.0}
## Features and where they open.
const UNLOCKS := {"endless": 300, "hard": 600, "weekly": 900, "nightmare": 1500}
const ITEM_POOL := ["beanie", "ocean", "wood", "cape_blue", "zuri", "headband", "lava", "ice", "jetpack", "ada", "party", "galaxy", "gold", "rex", "wizard", "snow", "mei", "halo"]


## Trophies a run pays. [param grades] are the letters earned this run.
static func trophies_for_run(level: int, grades: Array, modifier: String, endless: bool) -> int:
	var n := PER_LEVEL * maxi(level, 0)
	for g in grades:
		n += int(GRADE_TROPHIES.get(str(g), 0))
	if endless:
		n = PER_LEVEL * maxi(level, 0) / 2
	return int(round(float(n) * float(MODE_MULT.get(modifier, 1.0))))


static func milestone_count(trophies: int) -> int:
	return clampi(trophies / MILESTONE, 0, LENGTH / MILESTONE)


static func checkpoint(trophies: int) -> int:
	return (clampi(trophies, 0, LENGTH) / CHECKPOINT) * CHECKPOINT


static func next_milestone(trophies: int) -> int:
	return mini((trophies / MILESTONE + 1) * MILESTONE, LENGTH)


static func is_unlocked(feature: String, trophies: int) -> bool:
	return trophies >= int(UNLOCKS.get(feature, 0))


## What milestone [param k] (1-based, at k * MILESTONE) pays.
static func reward(k: int) -> Dictionary:
	var at := k * MILESTONE
	for feature in UNLOCKS:
		if int(UNLOCKS[feature]) == at:
			return {"kind": "unlock", "id": feature, "at": at}
	if k % 5 == 0:
		return {"kind": "item", "id": ITEM_POOL[(k / 5 - 1) % ITEM_POOL.size()], "at": at}
	if k % 2 == 0:
		return {"kind": "stars", "amount": 2 + k / 10, "at": at}
	return {"kind": "coins", "amount": 80 + k * 15, "at": at}


static func reward_text(r: Dictionary) -> String:
	match str(r.kind):
		"unlock":
			return {"endless": "ENDLESS opens", "hard": "HARD mode opens", "weekly": "the WEEKLY opens", "nightmare": "NIGHTMARE opens"}.get(str(r.id), str(r.id))
		"item":
			return "%s (locker)" % Wardrobe.title(str(r.id))
		"stars":
			return "%d stars" % int(r.amount)
	return "%d coins" % int(r.amount)


## Add trophies. Returns the new total and the milestones newly passed.
static func advance(trophies: int, earned: int) -> Dictionary:
	var before := milestone_count(trophies)
	var total := clampi(trophies + maxi(earned, 0), 0, LENGTH)
	var after := milestone_count(total)
	var rewards := []
	for k in range(before + 1, after + 1):
		rewards.append(reward(k))
	return {"trophies": total, "rewards": rewards, "checkpoint": checkpoint(total)}


## Rows for the road page: the milestones around where you stand.
static func rows(trophies: int, span: int = 12) -> Array:
	var out := []
	var here := milestone_count(trophies)
	var first := maxi(1, here - 3)
	for k in range(first, mini(first + span, LENGTH / MILESTONE) + 1):
		var r := reward(k)
		out.append({"at": k * MILESTONE, "text": reward_text(r), "done": k <= here, "kind": str(r.kind), "checkpoint": (k * MILESTONE) % CHECKPOINT == 0})
	return out
