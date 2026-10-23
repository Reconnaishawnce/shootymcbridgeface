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
const RUNNER_SECONDS := 1.1
## Committed fire climbs a panel about 1.4 steps a second.
const STEP_COST_DPS_FRACTION := 0.7
const MAX_RUNNERS := 10

const HIDDEN_CHANCE := [0.0, 0.25, 0.35, 0.5]
## Chance that both panels hurt, so the question becomes which one you can
## shoot back into the black.
const DILEMMA_CHANCE := [0.0, 0.12, 0.22, 0.3]
## Chance the bad side of a gate is a halving (x0.5) instead of a subtraction.
const HALVE_CHANCE := [0.0, 0.0, 0.4, 0.5]
## Chance the good side is a multiplier. Low: multipliers compound.
const MUL2_CHANCE := 0.25
const MUL3_CHANCE := 0.05
const MAX_WAVE := 32
## Chance a gate offers a power-up against a number (never the opener).
const POWER_GATE_CHANCE := 0.18
## Of those, how many are a mystery rather than a named power-up.
const MYSTERY_CHANCE := 0.4
## The fork: at this gate index the road splits into two routes for
## FORK_GATES gates, then merges. Rich pays more and throws more at you.
const FORK_INDEX := 3
const FORK_GATES := 2
## Metres past the last route gate where the divider ends.
const FORK_MERGE_AFTER := 16.0
## The fork line sits this far before the first route gate, so the squad
## has committed to a side before any route panel can be walked through.
const FORK_LEAD := 8.0
const RICH_WAVE_MULT := 1.6
const SAFE_WAVE_MULT := 0.6
## Chance one rich panel is hidden, and the chance that hidden panel is a trap.
const RICH_HIDDEN_CHANCE := 0.3
const RICH_TRAP_CHANCE := 0.5
## Road crates per level, placed in the gap after a random gate.
const CRATES_PER_LEVEL := 2
const CRATE_OFFSET := 14.0
const MAX_BRUTES := 6
const BRUTE_BITE_FRACTION := 0.08
const BRUTE_HP_PER_SOLDIER := 2.0
const TANK_HP_PER_SOLDIER := 6.0
const TANK_BITE_FRACTION := 0.15
const MAX_THIEVES := 3
const MAX_LATCHERS := 4
## Soldiers a latched zombie eats per LATCH_INTERVAL.
const LATCH_BITE := 1
const LATCH_INTERVAL := 0.7
## Thieves sprint away from the squad toward the next gate at this absolute
## speed; the world scrolls the other way, so they close on the gate at
## roughly this minus the world speed.
const THIEF_SPEED := 14.0
## Boss health grows with the perks taken, so a stacked run still has to
## earn its boss kills.
const BOSS_HP_PER_PERK := 0.06
## The spitter never reaches you, so it carries less health than the walker.
const SPITTER_HP_MULT := 0.7
## What one glob of spit takes if it lands on the squad.
const SPIT_BITE_FRACTION := 0.08
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
	return clampf(9.5 + float(level - 1) * 0.5, 9.5, 14.0)


## Runners are released the moment a gate is passed, this far ahead. They
## close at the road speed plus their own, so they arrive about a second
## later: before the wave, after the gate. Never before the gate.
static func runner_release_z(level: int) -> float:
	return -(world_speed(level) + 2.0 * 2.6) * RUNNER_SECONDS


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
	return maxf(step_cost(level), squad_dps * STEP_COST_DPS_FRACTION)


## Zombie wave spec after gate [param index] on [param level], scaled by the
## squad's current size so a huge squad meets a huge crowd (rubber band).
## The squad restarts at one soldier every level, so waves ramp mainly with
## the gate index inside the level and only modestly with the level itself.
static func wave_for(level: int, index: int, squad_count: int = 1) -> Dictionary:
	var lv := float(level - 1)
	var ix := float(index)
	# Brutes from the fourth gate of level 1, more with level and depth.
	var brutes := 0
	if index >= 3:
		brutes = 1 + int(lv / 2.0) + int(ix / 4.0) + int(squad_count / 60.0)
	# Thieves run for the next gate and knock its value down: from level 2,
	# on gates that are not the opener, one or two of them.
	var thieves := 0
	if level >= 2 and index >= 1 and index % 2 == 1:
		thieves = 1 + int(lv / 4.0)
	# Tanks are bullet sponges that shield the gate behind them: from level
	# 3, every third gate.
	var tanks := 0
	if level >= 3 and index >= 2 and index % 3 == 2:
		tanks = 1
	# Latchers grab the front of the squad and keep eating until shot off.
	# From level 3, a couple per wave, more with level.
	var latchers := 0
	if Progression.latchers(level) and index >= 1:
		latchers = 1 + int(lv / 2.0)
	# Many bodies, little health: mowing a crowd is the fun part. The
	# opener of every level is gentler because the squad has just reset.
	var hp := 0.8 + ix * 0.1 + lv * 0.3
	var count := 4 + int(ix * 1.0 + lv * 1.0)
	var runners := 1 + int(ix / 3.0) + int(lv / 3.0)
	if index == 0:
		hp = 0.8 + lv * 0.15
		count = 3 + int(lv * 0.5)
		runners = 1
	return {
		"count": mini(count + int(squad_count / 10.0), MAX_WAVE),
		"hp": hp,
		# A brute soaks about a second of the whole squad's fire whatever its
		# size, so brutes stay a threat to a thousand soldiers.
		"brute_hp": hp * 5.0 + float(squad_count) * BRUTE_HP_PER_SOLDIER,
		# A tank soaks several seconds of fire; you go round it or through it.
		"tank_hp": hp * 6.0 + float(squad_count) * TANK_HP_PER_SOLDIER,
		"thief_hp": hp * 1.5,
		"runner_hp": hp * 0.6,
		"speed": 2.0 + minf(lv * 0.15 + ix * 0.05, 1.5),
		"brutes": mini(brutes, MAX_BRUTES),
		"thieves": mini(thieves, MAX_THIEVES),
		"tanks": tanks,
		"latchers": mini(latchers, MAX_LATCHERS),
		"latcher_hp": hp * 2.5,
		# Runners: fast, thin, and they find you. The near-miss engine.
		"runners": mini(runners + int(squad_count / 40.0), MAX_RUNNERS),
	}


## Soldiers a brute takes when it reaches the squad: a slice, not a nibble.
static func brute_bite(squad_count: int, fraction: float = BRUTE_BITE_FRACTION) -> int:
	return maxi(2, int(float(squad_count) * fraction))


## Survivors of a level march on: this fraction of the squad left standing
## after the boss carries over to the next level (never below the shop's
## starting squad). Finishing strong is rewarded, and a reset squad is not
## a lone soldier against a level 5 opener.
const CARRY_OVER_FRACTION := 0.25


static func carry_over(squad_left: int, start_squad: int) -> int:
	return maxi(start_squad, int(float(squad_left) * CARRY_OVER_FRACTION))


## The squad size a competent player is modelled to have at the boss. The
## auto-player (optimal play) arrives with roughly 240, 120, 60 on levels
## 1 to 3; a person lands below that, so the model sits under the bot.
static func expected_squad(level: int) -> int:
	return 70 + 15 * (level - 1)


static func boss_hp(level: int, perk_count: int = 0) -> float:
	var base := float(expected_squad(level)) * DPS_PER_SOLDIER * BOSS_SECONDS_OF_FIRE
	if boss_kind(level) == Boss.Kind.SPITTER:
		base *= SPITTER_HP_MULT
	return base * (1.0 + BOSS_HP_PER_PERK * float(perk_count))


## Boss lightning: strikes land near the squad after a warning ring.
const STRIKE_WARNING := 1.0
const STRIKE_INTERVAL := 3.2
const STRIKE_INTERVAL_ENRAGED := 2.0
const STRIKE_BITE_FRACTION := 0.15
const STRIKE_RADIUS := 1.1
## How many rings a volley puts down.
static func strikes_per_volley(level: int) -> int:
	return clampi(1 + (level - 1) / 3, 1, 3)


## Soldiers a lightning strike takes when it lands on the squad.
static func strike_bite(squad_count: int) -> int:
	return maxi(3, int(float(squad_count) * STRIKE_BITE_FRACTION))


## Runners the boss calls every BOSS_ADDS_INTERVAL seconds.
const BOSS_ADDS_INTERVAL := 6.0
static func boss_adds(level: int) -> int:
	return clampi(1 + level / 2, 1, 4)


## Below this fraction of health the boss attacks faster and harder.
const ENRAGE_FRACTION := 0.5
## Spit per volley once enraged (spread across the lane).
const SPIT_VOLLEY := 3
## Latched walkers and runners eat on this timer, each.
const LATCH_HP_MULT := 2.0


## Soldiers one landed glob of spit takes.
static func spit_bite(squad_count: int) -> int:
	return maxi(2, int(float(squad_count) * SPIT_BITE_FRACTION))


## Bosses alternate: odd levels get the walker, even levels the spitter.
static func boss_kind(level: int) -> int:
	return Boss.Kind.SPITTER if level % 2 == 0 else Boss.Kind.WALKER


## Soldiers a tank takes when it reaches the squad.
static func tank_bite(squad_count: int) -> int:
	return maxi(5, int(float(squad_count) * TANK_BITE_FRACTION))


## Soldiers the boss chews per bite once it has reached the squad.
static func boss_bite(squad_count: int) -> int:
	return maxi(2, int(float(squad_count) * BOSS_BITE_FRACTION))


## Score for clearing a whole wave before any of it reached you.
static func wave_clear_bonus(level: int) -> int:
	return 20 + 10 * level


## Score for walking through a panel you shot up at least PERFECT_STEPS.
const PERFECT_STEPS := 3
const PERFECT_BONUS := 50


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
			good = GateMath.add(rng.randi_range(2, 5))
			if not is_opener and roll < MUL2_CHANCE:
				good = GateMath.mul(2.0)
			bad = GateMath.add(rng.randi_range(-4, 1))
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

	# The first gate of any level is a clean, visible, additive gain against
	# a mild other side: the squad has just reset and needs a foothold, and
	# a wrong step there should sting, not wipe.
	if index == 0:
		good = GateMath.add(rng.randi_range(3, 5))
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

	# Sometimes the choice is soldiers now or a tool for later.
	if index > 0 and rng.randf() < POWER_GATE_CHANCE:
		var id: String = Powerups.MYSTERY if rng.randf() < MYSTERY_CHANCE else Powerups.ORDER[rng.randi_range(0, Powerups.ORDER.size() - 1)]
		bad = GateMath.power(id)
		if good.kind == GateMath.Kind.ADD and good.value <= 0.0:
			good = GateMath.add(rng.randi_range(2, 5))
		good.revealed = true

	if rng.randf() < 0.5:
		return [good, bad]
	return [bad, good]


static func is_fork_gate(index: int) -> bool:
	return index >= FORK_INDEX and index < FORK_INDEX + FORK_GATES


static func fork_distance() -> float:
	return gate_distance(FORK_INDEX) - FORK_LEAD


static func fork_length() -> float:
	return gate_distance(FORK_INDEX + FORK_GATES - 1) + FORK_MERGE_AFTER - fork_distance()


## Two routes for the fork on [param level]: {"left": route, "right": route}.
## A route is {name, threat (1..3), wave_mult, extra_brutes, panels}.
## One side is RICH, the other SAFE; which is which is random.
func make_fork(level: int) -> Dictionary:
	var lv := level - 1
	var t := tier_for_level(level)
	var rich := {
		"name": "RICH",
		"threat": 3 if t >= 2 else 2,
		"wave_mult": RICH_WAVE_MULT,
		"extra_brutes": 1 + int(lv / 3.0),
		"panels": [],
	}
	for i in range(FORK_GATES):
		var roll := rng.randf()
		var panel: GateMath.GatePanel
		if roll < 0.1:
			panel = GateMath.mul(3.0)
		elif roll < 0.4:
			panel = GateMath.mul(2.0)
		else:
			panel = GateMath.add(rng.randi_range(6, 10) + 2 * lv)
		rich.panels.append(panel)
	if level >= Progression.HIDDEN_LEVEL and rng.randf() < RICH_HIDDEN_CHANCE:
		var which := rng.randi_range(0, FORK_GATES - 1)
		if rng.randf() < RICH_TRAP_CHANCE:
			rich.panels[which] = GateMath.add(rng.randi_range(-6, -3) - lv, true)
		else:
			rich.panels[which].revealed = false
	var safe := {
		"name": "SAFE",
		"threat": 1,
		"wave_mult": SAFE_WAVE_MULT,
		"extra_brutes": 0,
		"panels": [GateMath.add(rng.randi_range(3, 5) + lv / 2), GateMath.add(rng.randi_range(3, 5) + lv / 2)],
	}
	if rng.randf() < 0.5:
		return {"left": rich, "right": safe}
	return {"left": safe, "right": rich}


## Chance a gate (after the opener) carries a sum panel, by tier.
const EXPR_CHANCE := [0.0, 0.35, 0.4, 0.45]
## How close a sum's result sits to the plain panel it competes with, so
## the comparison takes thought rather than a glance.
const EXPR_BAND := 0.4


## A short sum for [param level]: two terms, three from
## EXPR_THREE_TERMS_LEVEL. A big squad (see BIG_SQUAD) gets no doubling
## terms, the same brake make_gate_pair applies to plain multipliers.
func make_expr(level: int, count: int = 1) -> GateMath.GatePanel:
	var lv := level - 1
	var terms := 3 if level >= Progression.EXPR_THREE_TERMS_LEVEL else 2
	var big := count >= BIG_SQUAD
	var ops := []
	var last_kind := -1
	for i in range(terms):
		var kind := GateMath.Kind.ADD if (last_kind == GateMath.Kind.MUL or rng.randf() < 0.5) else GateMath.Kind.MUL
		if kind == GateMath.Kind.ADD:
			var v := rng.randi_range(2, 7) + lv
			if rng.randf() < 0.4:
				v = -rng.randi_range(2, 5) - lv / 2
			ops.append([kind, float(v)])
		else:
			var roll := rng.randf()
			var m := 2.0
			if roll < 0.25 or big:
				m = 0.5
			elif roll < 0.35:
				m = 3.0
			ops.append([kind, m])
		last_kind = kind
	return GateMath.expr(ops)


## A sum that lands within EXPR_BAND of [param rival] for a squad of
## [param count], so neither side is obviously better. Falls back to the
## last attempt if nothing lands in the band.
func make_rival_expr(level: int, rival: GateMath.GatePanel, count: int) -> GateMath.GatePanel:
	var target := GateMath.apply(maxi(count, 4), rival)
	var e := make_expr(level, count)
	for i in range(10):
		var v := GateMath.apply(maxi(count, 4), e)
		if v >= float(target) * (1.0 - EXPR_BAND) and v <= float(target) * (1.0 + EXPR_BAND) and v != target:
			break
		e = make_expr(level, count)
	return e


## All the panels of a gate, one per lane. The first two come from
## make_gate_pair; a sum may replace one of them from EXPR_LEVEL; extra
## lanes get a mix of small gains, traps, sums and power-ups. Shuffled.
func make_gate(level: int, index: int, count: int, lanes: int) -> Array:
	var t := tier_for_level(level)
	var panels: Array = make_gate_pair(level, index, count)
	if index > 0 and level >= Progression.EXPR_LEVEL and rng.randf() < EXPR_CHANCE[t]:
		# The sum competes with the good side: both look like gains, one is
		# better for the squad you actually have.
		var good_i := 0 if GateMath.is_good(panels[0]) and not GateMath.is_power(panels[0]) else 1
		var other := 1 - good_i
		if GateMath.is_good(panels[good_i]):
			panels[other] = make_rival_expr(level, panels[good_i], count)
	# Extra lanes: one of them is a rival worth weighing (a sum close to the
	# good side, or a modest gain), the rest are traps with the odd power-up.
	# More lanes means more to read, not more to collect.
	var lv := level - 1
	var best_i := -1
	for i in range(panels.size()):
		if GateMath.is_good(panels[i]) and not GateMath.is_power(panels[i]) and not GateMath.is_expr(panels[i]):
			best_i = i
	for i in range(lanes - 2):
		if index == 0:
			panels.append(GateMath.add(rng.randi_range(1, 3)))
		elif i == 0 and best_i >= 0 and level >= Progression.EXPR_LEVEL and rng.randf() < 0.6:
			panels.append(make_rival_expr(level, panels[best_i], count))
		elif i == 0 and rng.randf() < 0.6:
			panels.append(GateMath.add(rng.randi_range(1, 3) + lv / 2))
		elif rng.randf() < 0.15:
			panels.append(GateMath.power(Powerups.MYSTERY if rng.randf() < MYSTERY_CHANCE else Powerups.ORDER[rng.randi_range(0, Powerups.ORDER.size() - 1)]))
		elif rng.randf() < 0.3 and level >= Progression.EXPR_LEVEL:
			# A sum that reads tempting and isn't.
			var trap := make_expr(level, count)
			for k in range(6):
				if not GateMath.is_good(trap):
					break
				trap = make_expr(level, count)
			panels.append(trap)
		else:
			panels.append(GateMath.add(-rng.randi_range(3, 8) - lv))
	for i in range(panels.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = panels[i]
		panels[i] = panels[j]
		panels[j] = tmp
	return panels


## Gate indices (0-based) that get a crate in the gap after them, and what
## is in each. Returns [{index, id}].
func crates_for_level(level: int) -> Array:
	var out := []
	var used := {}
	for i in range(CRATES_PER_LEVEL):
		var index := rng.randi_range(0, GATES_PER_LEVEL - 2)
		while used.has(index) or is_fork_gate(index):
			index = (index + 1) % (GATES_PER_LEVEL - 1)
		used[index] = true
		var id: String = Powerups.MYSTERY if rng.randf() < 0.5 else Powerups.ORDER[rng.randi_range(0, Powerups.ORDER.size() - 1)]
		out.append({"index": index, "id": id})
	return out


static func crate_distance(index: int) -> float:
	return gate_distance(index) + CRATE_OFFSET
