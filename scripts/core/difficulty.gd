class_name Difficulty
extends RefCounted
## Deterministic content generation, keyed on level and gate index.
##
## A run is a sequence of levels. Each level is GATES_PER_LEVEL gates, a
## zombie wave after each gate, then a boss. The squad resets to one soldier
## at the start of every level, so growth is bounded per level and the boss
## is the bar you have to clear.
##
## Everything random flows through one seeded RNG, so a run can be replayed.
## Static functions are pure curves; instance functions consume the RNG.

const GATES_PER_LEVEL := 8
const FIRST_GATE_AT := 24.0
const GATE_SPACING := 32.0
## Where a wave sits after each gate. Bullets are consumed by the gate panel
## ahead of the squad, so zombies hiding behind a gate are untouchable until
## it passes. Placing the wave late in the gap (just before the next gate)
## gives the player a clean window to shoot it after the previous gate clears.
const WAVE_OFFSET := 26.0
## How far past the last gate the boss appears.
const BOSS_LEAD := 40.0

const HIDDEN_CHANCE := [0.0, 0.2, 0.35, 0.5]
## Chance that both panels hurt, so the question becomes which one you can
## shoot back into the black.
const DILEMMA_CHANCE := [0.0, 0.0, 0.15, 0.25]
## Chance the bad side of a gate is a halving (x0.5) instead of a subtraction.
const HALVE_CHANCE := [0.0, 0.0, 0.4, 0.5]
## Chance the good side is a multiplier. Low: multipliers compound.
const MUL2_CHANCE := 0.2
const MUL3_CHANCE := 0.05
const MAX_WAVE := 32
const MAX_BRUTES := 6
const BRUTE_BITE_FRACTION := 0.08
const BRUTE_HP_PER_SOLDIER := 2.0
## Above this squad size the good side stops offering multipliers and the bad
## side leans on halving, so a level cannot snowball out of range.
const BIG_SQUAD := 150

## Boss health is this many seconds of fire from the squad a competent
## player has at the end of the level, as modelled by EXPECTED_SQUAD.
const BOSS_SECONDS_OF_FIRE := 7.0
const DPS_PER_SOLDIER := 2.5
## What fraction of the squad the boss chews per bite once it reaches you.
const BOSS_BITE_FRACTION := 0.12
const BOSS_BITE_INTERVAL := 0.45

var rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	rng.seed = seed_value


## Levels are 1-based. Tiers: level 1, levels 2-3, levels 4-6, level 7+.
static func tier_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level <= 3:
		return 1
	if level <= 6:
		return 2
	return 3


## Distance into the level of gate [param index] (0-based).
static func gate_distance(index: int) -> float:
	return FIRST_GATE_AT + float(index) * GATE_SPACING


static func wave_distance(index: int) -> float:
	return gate_distance(index) + WAVE_OFFSET


static func boss_distance() -> float:
	return gate_distance(GATES_PER_LEVEL - 1) + BOSS_LEAD


## Metres per second the world scrolls toward the squad during gates.
static func world_speed(level: int) -> float:
	return clampf(8.0 + float(level - 1) * 0.5, 8.0, 12.0)


## Scroll speed while the boss is on screen: the squad digs in.
static func boss_world_speed() -> float:
	return 2.5


## Floor on the bullet damage needed to climb a gate panel one step.
static func step_cost(level: int) -> float:
	return 3.0 + float(level - 1) * 0.6


## The real step cost: whichever is larger, the level floor or most of a
## second of the squad's full damage output. This is the throttle that keeps
## gate farming at roughly one step per second no matter how big the squad is.
static func effective_step_cost(level: int, squad_dps: float) -> float:
	return maxf(step_cost(level), squad_dps * 0.9)


## Zombie wave spec after gate [param index] on [param level], scaled by the
## squad's current size so a huge squad meets a huge crowd (rubber band).
## The squad restarts at one soldier every level, so waves ramp mainly with
## the gate index inside the level and only modestly with the level itself.
static func wave_for(level: int, index: int, squad_count: int = 1) -> Dictionary:
	var lv := float(level - 1)
	var ix := float(index)
	var brutes := 0
	if (level >= 2 and index >= 2) or index >= GATES_PER_LEVEL / 2:
		brutes = 1 + int(lv / 2.0) + int(ix / 4.0) + int(squad_count / 60.0)
	var hp := 1.0 + ix * 0.15 + lv * 0.35
	return {
		"count": mini(2 + int(ix * 0.9 + lv) + int(squad_count / 12.0), MAX_WAVE),
		"hp": hp,
		# A brute soaks about a second of the whole squad's fire whatever its
		# size, so brutes stay a threat to a thousand soldiers.
		"brute_hp": hp * 4.0 + float(squad_count) * BRUTE_HP_PER_SOLDIER,
		"speed": 1.5 + minf(lv * 0.15 + ix * 0.04, 1.5),
		"brutes": mini(brutes, MAX_BRUTES),
	}


## Soldiers a brute takes when it reaches the squad: a slice, not a nibble.
static func brute_bite(squad_count: int) -> int:
	return maxi(3, int(float(squad_count) * BRUTE_BITE_FRACTION))


## The squad size a competent player is modelled to have at the boss. The
## auto-player (optimal play) arrives with roughly 240, 120, 60 on levels
## 1 to 3; a person lands below that, so the model sits under the bot.
static func expected_squad(level: int) -> int:
	return 100 + 20 * (level - 1)


static func boss_hp(level: int) -> float:
	return float(expected_squad(level)) * DPS_PER_SOLDIER * BOSS_SECONDS_OF_FIRE


## Soldiers the boss chews per bite once it has reached the squad.
static func boss_bite(squad_count: int) -> int:
	return maxi(2, int(float(squad_count) * BOSS_BITE_FRACTION))


## Score bonus for clearing a level with [param squad_left] soldiers.
static func level_bonus(level: int, squad_left: int) -> int:
	return level * 150 + squad_left * 5


## Returns [left_panel, right_panel] for gate [param index] on [param level].
## Multipliers are rare on purpose: every x2 compounds, so the additive gates
## and the shooting have to stay the main event.
func make_gate_pair(level: int, index: int, squad_count: int = 1) -> Array:
	var t := tier_for_level(level)
	var is_opener := level == 1 and index == 0
	var big := squad_count >= BIG_SQUAD
	var good: GateMath.GatePanel
	var bad: GateMath.GatePanel
	# A roll of 1.0 never lands under any multiplier chance.
	var roll := 1.0 if big else rng.randf()
	match t:
		0:
			good = GateMath.add(rng.randi_range(2, 4))
			if not is_opener and roll < MUL2_CHANCE:
				good = GateMath.mul(2.0)
			bad = GateMath.add(rng.randi_range(-2, 1))
		1:
			good = GateMath.add(rng.randi_range(3, 6))
			if roll < MUL2_CHANCE:
				good = GateMath.mul(2.0)
			bad = GateMath.add(rng.randi_range(-8, -3))
		2:
			good = GateMath.add(rng.randi_range(4, 9))
			if roll < MUL3_CHANCE:
				good = GateMath.mul(3.0)
			elif roll < MUL2_CHANCE:
				good = GateMath.mul(2.0)
			bad = GateMath.add(rng.randi_range(-15, -6))
			if rng.randf() < (0.8 if big else HALVE_CHANCE[t]):
				bad = GateMath.mul(0.5)
		_:
			good = GateMath.add(rng.randi_range(6, 12))
			if roll < MUL3_CHANCE:
				good = GateMath.mul(3.0)
			elif roll < MUL2_CHANCE:
				good = GateMath.mul(2.0)
			bad = GateMath.add(rng.randi_range(-25, -10))
			if rng.randf() < (0.8 if big else HALVE_CHANCE[t]):
				bad = GateMath.mul(0.5)

	# The first gate of any level is a clean, visible, additive gain: the
	# squad has just reset to one soldier and needs a foothold.
	if index == 0:
		good = GateMath.add(rng.randi_range(3, 5))
		if bad.kind == GateMath.Kind.MUL:
			bad = GateMath.add(rng.randi_range(-2, 1))
	elif rng.randf() < (0.4 if big else DILEMMA_CHANCE[t]):
		# Both options hurt. Which one can you shoot back into the black?
		good = GateMath.add(rng.randi_range(-3, -1))
		bad = GateMath.add(rng.randi_range(-12, -6)) if rng.randf() < 0.5 else GateMath.mul(0.5)

	if index > 0 and rng.randf() < HIDDEN_CHANCE[t]:
		if rng.randf() < 0.5:
			good.revealed = false
		else:
			bad.revealed = false

	if rng.randf() < 0.5:
		return [good, bad]
	return [bad, good]
