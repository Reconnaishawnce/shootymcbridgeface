class_name Difficulty
extends RefCounted
## Deterministic content generation as a function of track distance (metres).
##
## Everything random flows through one seeded RNG, so a run can be replayed.
## Daily seeded runs, replays and score sharing all come for free later.
## Static functions are pure curves; instance functions consume the RNG.

const FIRST_GATE_AT := 24.0
const GATE_SPACING := 32.0
## Where a wave sits after each gate. Bullets are consumed by the gate panel
## ahead of the squad, so zombies hiding behind a gate are untouchable until
## it passes. Placing the wave late in the gap (just before the next gate)
## gives the player a clean window to shoot it after the previous gate clears.
const WAVE_OFFSET := 26.0

const TIER_EDGES := [120.0, 320.0, 640.0]
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
## side leans on halving, so an endless run plateaus instead of exploding.
const BIG_SQUAD := 150

var rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	rng.seed = seed_value


static func tier_for(distance: float) -> int:
	for i in range(TIER_EDGES.size()):
		if distance < TIER_EDGES[i]:
			return i
	return TIER_EDGES.size()


## Metres per second the world scrolls toward the squad.
static func world_speed(distance: float) -> float:
	return clampf(8.0 + distance * 0.004, 8.0, 12.0)


## Floor on the bullet damage needed to climb a gate panel one step.
static func step_cost(distance: float) -> float:
	return 3.0 + distance * 0.01


## The real step cost: whichever is larger, the distance floor or most of a
## second of the squad's full damage output. This is the throttle that keeps
## gate farming at roughly one step per second no matter how big the squad is.
static func effective_step_cost(distance: float, squad_dps: float) -> float:
	return maxf(step_cost(distance), squad_dps * 0.9)


## Zombie wave spec for a wave anchored at [param distance], scaled by the
## squad's current size so a huge squad meets a huge crowd (rubber band).
static func wave_for(distance: float, squad_count: int = 1) -> Dictionary:
	var t := tier_for(distance)
	var brutes := 0
	if t > 0:
		brutes = 1 + int((distance - TIER_EDGES[0]) / 250.0) + int(squad_count / 60.0)
	var hp := 1.0 + distance / 110.0
	return {
		"count": mini(2 + int(distance / 45.0) + int(squad_count / 12.0), MAX_WAVE),
		"hp": hp,
		# A brute soaks about a second of the whole squad's fire whatever its
		# size, so brutes stay a threat to a thousand soldiers.
		"brute_hp": hp * 4.0 + float(squad_count) * BRUTE_HP_PER_SOLDIER,
		"speed": 1.5 + minf(distance / 400.0, 1.5),
		"brutes": mini(brutes, MAX_BRUTES),
	}


## Soldiers a brute takes when it reaches the squad: a slice, not a nibble.
static func brute_bite(squad_count: int) -> int:
	return maxi(3, int(float(squad_count) * BRUTE_BITE_FRACTION))


## Returns [left_panel, right_panel] for the gate at [param distance].
## Multipliers are rare on purpose: in an endless run every x2 compounds, so
## the additive gates and the shooting have to stay the main event.
func make_gate_pair(distance: float, squad_count: int = 1) -> Array:
	var t := tier_for(distance)
	var is_first := distance <= FIRST_GATE_AT + 0.001
	var big := squad_count >= BIG_SQUAD
	var good: GateMath.GatePanel
	var bad: GateMath.GatePanel
	# A roll of 1.0 never lands under any multiplier chance.
	var roll := 1.0 if big else rng.randf()
	match t:
		0:
			good = GateMath.add(rng.randi_range(2, 4))
			if not is_first and roll < MUL2_CHANCE:
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

	if rng.randf() < (0.4 if big else DILEMMA_CHANCE[t]):
		# Both options hurt. Which one can you shoot back into the black?
		good = GateMath.add(rng.randi_range(-3, -1))
		bad = GateMath.add(rng.randi_range(-12, -6)) if rng.randf() < 0.5 else GateMath.mul(0.5)

	if not is_first and rng.randf() < HIDDEN_CHANCE[t]:
		if rng.randf() < 0.5:
			good.revealed = false
		else:
			bad.revealed = false

	if rng.randf() < 0.5:
		return [good, bad]
	return [bad, good]


func _pick(options: Array) -> GateMath.GatePanel:
	return options[rng.randi_range(0, options.size() - 1)]
