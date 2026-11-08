class_name Economy
extends RefCounted
## The two currencies and the brakes that keep them sane. The bounty is
## the run's money: every kill pays it, supply and pit stops spend it.
## Coins are the save's money: what is left of the bounty at the end,
## converted with diminishing returns so a monster run pays well but
## not without limit. The bridge holds SQUAD_CAP soldiers, and the
## harder you shoot a multiplier panel the less a big squad can push
## it, so the squad stops compounding past the point where the game is
## still a game. Pure.

## Bounty up to this converts one to one.
const GOLD_LINEAR := 500
## Beyond it, the extra converts at this power.
const GOLD_EXPONENT := 0.75
## The bridge holds this many soldiers.
const SQUAD_CAP := 500
## How far a shot multiplier panel can be pushed, by squad size.
const MUL_CAP_SMALL := 5.0
## A mid squad doubles at most, a big one gets half as much again: with
## the bad panel's x0.5 that makes a squad left to take random panels
## shrink instead of holding, which is what kept idle endless runs alive.
const MUL_CAP_MID := 2.0
const MUL_CAP_BIG := 1.5
const MUL_MID_SQUAD := 150
const MUL_BIG_SQUAD := 300


## Coins the save gets for a run's remaining bounty.
static func coins_for_bounty(bounty: int) -> int:
	if bounty <= GOLD_LINEAR:
		return maxi(0, bounty)
	return GOLD_LINEAR + int(round(pow(float(bounty - GOLD_LINEAR), GOLD_EXPONENT)))


static func cap_squad(n: int) -> int:
	return clampi(n, 0, SQUAD_CAP)


static func mul_cap_for(count: int) -> float:
	if count >= MUL_BIG_SQUAD:
		return MUL_CAP_BIG
	if count >= MUL_MID_SQUAD:
		return MUL_CAP_MID
	return MUL_CAP_SMALL
