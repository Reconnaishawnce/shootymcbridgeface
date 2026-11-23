class_name Progression
extends RefCounted
## What the game turns on at which level, and the one line it says when it
## does. Level 1 is steer and pick. Every level after that adds one tool or
## one threat, so the player learns by playing, not by reading.
##
## THE LADDER (0.63). By 0.62 everything arrived by level 4 and a new
## player met thirty-three mechanics in ten minutes: "overwhelming", "no
## one knows what the things mean". Now level 1 is two gates of plain
## numbers and zombies one bullet kills; one new thing arrives a level,
## with one line of six words or so; and the gates that needed a
## paragraph to read are gone from the road.

## A thing that is not in the game: its code is still here, nothing
## makes it.
const NEVER := 9999

## Gates.
const MUL_LEVEL := 2
const POWER_PANEL_LEVEL := 3
const DILEMMA_LEVEL := 6
const VEHICLE_LEVEL := 12
## Hidden "?" panels, panels that flash, sums ("+3 x2"), deals (BET,
## SCOUT, TRADE), coin panels, the three-word perk gate and the fork in
## the road all needed reading at a run. Gone.
const HIDDEN_LEVEL := NEVER
const HOT_LEVEL := NEVER
const EXPR_LEVEL := NEVER
const EXPR_THREE_TERMS_LEVEL := NEVER
const DEAL_LEVEL := NEVER
const SUPPLY_LEVEL := NEVER
const PERK_GATE_LEVEL := NEVER
const FORK_LEVEL := NEVER

## Things on the road.
const CRATE_LEVEL := 2
const PIT_LEVEL := 4
const SAW_LEVEL := 5
const BARRICADE_LEVEL := 7
## A build card after the boss. Not after the first one: the first level
## ends on the win, not on three things to read.
const DRAFT_LEVEL := 2

## Zombies. Walkers only on level 1.
const BRUTE_LEVEL := 2
## Walkers that reach the squad cling on from here, the same level the
## dash and the shake arrive, so there is always a way to throw them.
const CLING_LEVEL := 3
const DASH_LEVEL := 3
const RUNNER_LEVEL := 4
## Sturdy purple latchers.
const LATCHER_LEVEL := 6
const THIEF_LEVEL := 8
const TANK_LEVEL := 9
const SPLITTER_LEVEL := 10
const FLANKER_LEVEL := 11

## The first boss only walks at you. From here they throw things.
const BOSS_ATTACK_LEVEL := 2
## Level themes change the rules (a fast road, lightning) from here; the
## looks change from level 2.
const THEME_RULE_LEVEL := 5

const LANE_W := 3.3
const MAX_LANES := 5


## How many lanes the road has on [param level]. Two for three levels,
## then one more every few: more lanes is more to read at every gate.
static func lanes_for(level: int, _index: int = 0) -> int:
	if level <= 3:
		return 2
	if level <= 8:
		return 3
	if level <= 14:
		return 4
	return MAX_LANES


static func road_half(lanes: int) -> float:
	return float(lanes) * LANE_W * 0.5


## The coach: the one line a level says when it brings something new.
## Two short lines at most. This is all the teaching there is on the
## road; HOW TO PLAY on the home screen has the rest for who wants it.
const LEVEL_HINTS := {
	1: "DRAG TO MOVE\nWALK THROUGH THE BIGGER NUMBER",
	2: "x2 DOUBLES YOUR SQUAD\nBOXES ON THE ROAD ARE POWER-UPS",
	3: "A ZOMBIE ON YOU?\nTAP IT, OR SHAKE YOUR PHONE",
	4: "PIT STOP AHEAD\nSTEER RIGHT TO SHOP",
	5: "SAW BLADES: STEP ASIDE",
	6: "PURPLE ONES GRAB ON\nSHOOT THEM FIRST",
	7: "A WALL: SHOOT IT DOWN\nOR GO ROUND",
	8: "THIEVES SHRINK THE NEXT GATE\nSHOOT THEM",
	9: "THE BIG ONE SOAKS BULLETS\nSTEP ROUND IT",
	10: "YELLOW ONES BURST\nKILL THEM FAR AWAY",
	12: "OLIVE GATE:\nTRADE SOLDIERS FOR A JEEP",
}
## The second line a run's first level says, once the player has moved:
## aiming is the one thing nobody finds on their own.
const AIM_HINT := "HOLD A FINGER ON THE ROAD\nTO AIM EVERY GUN THERE"
## How many runs the level 1 lines keep showing for.
const BASICS_RUNS := 3


## Whether the coach speaks at the start of [param level]: only while
## the level is new to this player. [param best] is the furthest level
## they have reached, [param runs] how many runs they have played.
static func coach_due(level: int, best: int, runs: int) -> bool:
	if not LEVEL_HINTS.has(level):
		return false
	if level == 1:
		return runs < BASICS_RUNS
	return level >= best

## Unfocused fire sprays: each bullet drifts sideways by up to this much
## (m/s). At range that means misses. Focus fire has no spray and hits
## harder. Aiming is the skill.
const SPRAY := 1.6
const FOCUS_DAMAGE_MULT := 1.5
## Holding focus on a clinging zombie pours this fraction of squad DPS into
## it per second, since bullets cannot reach your own flank.
const FOCUS_LATCH_DPS_FRACTION := 0.7
const FOCUS_LATCH_RADIUS := 1.8
## A touch that lands within this many pixels (at 720 wide) of a clinging
## zombie aims at it, wherever on the screen it is. Clingers ride beside
## the squad, deep in the steering zone, so the usual aim zone cannot
## reach them.
const CLING_TAP_PX := 110.0
## How many zombies can cling at once; the rest bite once and are spent.
const MAX_LATCHED := 6
## A dash throws off this many clingers.
const DASH_SHAKES_OFF := 2


static func dash_enabled(level: int) -> bool:
	return level >= DASH_LEVEL


static func clinging(level: int) -> bool:
	return level >= CLING_LEVEL


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

## Firepower grows one for one up to this many soldiers. Past it, extra
## soldiers still add fire, but at DPS_TAIL_EXPONENT: a squad of 100
## shoots like 50, 200 like 56, 500 like 69. A big squad is mostly
## something to protect, and the road scales its crowds to the same
## curve (Difficulty.fire_scale), so it never outgrows the game.
const DPS_CAP_SOLDIERS := 40
const DPS_TAIL_EXPONENT := 0.55


static func firing_count(count: int) -> int:
	if count <= DPS_CAP_SOLDIERS:
		return maxi(count, 0)
	return DPS_CAP_SOLDIERS + int(pow(float(count - DPS_CAP_SOLDIERS), DPS_TAIL_EXPONENT))
