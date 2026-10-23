class_name Progression
extends RefCounted
## What the game turns on at which level, and the one line it says when it
## does. Level 1 is steer and pick. Every level after that adds one tool or
## one threat, so the player learns by playing, not by reading.

const DASH_LEVEL := 2
const HOT_LEVEL := 3
## Sturdy purple latchers join the waves from here; ordinary walkers and
## runners that reach the squad latch on from level 1.
const LATCHER_LEVEL := 3
const HIDDEN_LEVEL := 2
const DILEMMA_LEVEL := 2

## Hints shown at the start of a level, keyed by level.
## Sum gates (short equations, applied left to right) appear from here.
const EXPR_LEVEL := 2
const EXPR_THREE_TERMS_LEVEL := 5
const LANE_W := 3.3
const MAX_LANES := 5


## How many lanes the road has at gate [param index] of [param level].
## Two to start; it widens partway through levels 2, 4 and 7 and stays.
static func lanes_for(level: int, index: int) -> int:
	var late := index >= 4
	if level <= 1:
		return 2
	if level == 2:
		return 3 if late else 2
	if level == 3:
		return 3
	if level == 4:
		return 4 if late else 3
	if level <= 6:
		return 4
	if level == 7:
		return 5 if late else 4
	return MAX_LANES


static func road_half(lanes: int) -> float:
	return float(lanes) * LANE_W * 0.5


const LEVEL_HINTS := {
	1: "DRAG LOW TO STEER. HOLD THE ROAD TO AIM.\nZOMBIES THAT REACH YOU CLING ON: HOLD ON THEM",
	2: "FLICK LOW TO DASH. TEAL GATES ARE SUMS:\n+3 x2 IS NOT x2 +3. WORK IT OUT, LEFT TO RIGHT",
	3: "PANELS FLASH: HIT THEM THEN FOR x3\nPURPLE LATCHERS ARE TOUGHER: AIM EARLY",
	4: "RED ON BOTH SIDES NOW\nPICK THE ONE YOU CAN SHOOT UP",
	5: "THREE-TERM SUMS FROM HERE\nTHE ROAD KEEPS WIDENING",
}

## Unfocused fire sprays: each bullet drifts sideways by up to this much
## (m/s). At range that means misses. Focus fire has no spray and hits
## harder. Aiming is the skill.
const SPRAY := 1.6
const FOCUS_DAMAGE_MULT := 1.5
## Holding focus on a clinging zombie pours this fraction of squad DPS into
## it per second, since bullets cannot reach your own flank.
const FOCUS_LATCH_DPS_FRACTION := 0.7
const FOCUS_LATCH_RADIUS := 1.4
## How many zombies can cling at once; the rest bite once and are spent.
const MAX_LATCHED := 6
## A dash throws off this many clingers.
const DASH_SHAKES_OFF := 2


static func dash_enabled(level: int) -> bool:
	return level >= DASH_LEVEL


static func hot_panels(level: int) -> bool:
	return level >= HOT_LEVEL


static func latchers(level: int) -> bool:
	return level >= LATCHER_LEVEL


static func hint_for(level: int) -> String:
	return str(LEVEL_HINTS.get(level, ""))


## Hot panels: a panel is hot for HOT_ON seconds out of every HOT_PERIOD,
## offset by its own phase so the two sides of a gate flash at different
## times. [param t] is run time in seconds.
const HOT_PERIOD := 2.2
const HOT_ON := 0.45
const HOT_MULT := 3.0


static func is_hot(t: float, phase: float) -> bool:
	return fmod(t + phase, HOT_PERIOD) < HOT_ON


## Dash: a flick in the steer zone moves the squad DASH_DISTANCE in
## DASH_SECONDS with DASH_IFRAMES of invulnerability, then a cooldown.
const DASH_DISTANCE := 2.2
const DASH_SECONDS := 0.14
const DASH_IFRAMES := 0.4
const DASH_COOLDOWN := 1.1
## Flick speed, in canvas pixels per second, that counts as a dash.
const DASH_FLICK_SPEED := 2200.0
const DODGE_BONUS := 40

## Firepower stops growing past this many soldiers: beyond it, soldiers are
## health, not damage, and a big squad is something to protect.
const DPS_CAP_SOLDIERS := 40
