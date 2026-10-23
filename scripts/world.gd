class_name World
extends Node3D
## Owns everything that scrolls past the squad: gates, zombies, the boss,
## road dressing and the bullets in flight. The squad stays at z = 0; the
## world moves +z. Runs the level state machine: gates, boss, clear.

signal gate_passed(panel: GateMath.GatePanel, before: int, after: int)
signal gate_stepped(gate: Gate, index: int)
signal zombie_killed(zombie: Zombie)
signal squad_bitten(bite: int, heavy: bool)
signal boss_spawned(boss: Boss)
signal boss_hit(boss: Boss, is_core: bool)
signal boss_killed(level: int, squad_left: int)
signal level_started(level: int)
signal perk_chosen(id: String)
signal wave_cleared(level: int)
signal gate_perfect(gate: Gate, index: int)
signal powerup_granted(id: String, from_crate: bool)
signal shield_blocked
signal bomb_exploded(at: Vector3, kills: int)
signal fork_ahead(routes: Dictionary)
signal dodged
signal latched(zombie: Zombie)
signal strike_landed(at: Vector3, hit: bool)
signal shaken_off(count: int)
signal fork_chosen(route: Dictionary, side: int)
signal fork_merged
signal gate_robbed(gate: Gate, index: int)
signal spit_landed(hit: bool)

enum Phase { GATES, BOSS, CLEAR }

const SPAWN_AHEAD := 72.0
const DESPAWN_Z := 12.0
## Hidden panels are revealed when the gate gets this close.
const REVEAL_Z := -20.0
## A zombie that crosses this line reaches the squad.
const BITE_Z := -0.9
const LANE_HALF := 3.0
## The boss fight starts when the boss has walked this close.
const BOSS_ENGAGE_Z := -30.0
## The boss stops here and starts chewing.
const BOSS_CHEW_Z := -2.4
const BOSS_WALK_SPEED := 2.2
const CLEAR_SECONDS := 2.2

const ROAD := Color(0.2, 0.2, 0.22)
const CURB := Color(0.55, 0.52, 0.45)
const DASH := Color(0.8, 0.78, 0.6)
const POST := Color(0.35, 0.3, 0.26)

var gates: Array[Gate] = []
var perk_gates: Array[PerkGate] = []
var route_gates: Array[RouteGate] = []
var fork: Fork = null
## -1 left, 1 right, 0 not committed.
var fork_side := 0
var _fork_routes: Dictionary = {}
var zombies: Array[Zombie] = []
var boss: Boss = null
var bullets: Node3D
var gen: Difficulty
## Set by the game so hit resolution can read the squad's damage output.
var squad: Squad
var perks: Perks
var meta: Meta
var powerups: Powerups
## Run seconds, passed in by the game each frame.
var now := 0.0
## Endless: no bosses, no squad reset, gates forever. Levels tick every
## GATES_PER_LEVEL gates for difficulty and the HUD.
var endless := false

var level := 1
var level_distance := 0.0
var phase: int = Phase.GATES
var world_speed := 8.0

var _next_gate := 0
var _next_wave := 0
var _next_runners := 0
var _gates_passed := 0
var _wave_seq := 0
## wave id -> zombies still alive in it; a wave whose last member dies to
## a bullet pays a bonus. A member reaching the squad voids the wave.
var _wave_alive: Dictionary = {}
var _wave_voided: Dictionary = {}
var _boss_spawned := false
var _chew_timer := 0.0
var _clear_timer := 0.0
var _spits: Array[Spit] = []
var _strikes: Array[Strike] = []
var _strike_timer := 1.5
var _adds_timer := Difficulty.BOSS_ADDS_INTERVAL
var _latched: Array[Zombie] = []
var _crates: Array[Crate] = []
var _crate_plan: Array = []
var _bombs: Array[Bomb] = []
## Bosses get tougher as perks stack; the game keeps this current.
var perk_count := 0
var _dashes: Array[Node3D] = []
var _posts: Array[Node3D] = []


func _init() -> void:
	bullets = Node3D.new()
	add_child(bullets)
	_build_dressing()


func reset(seed_value: int) -> void:
	gen = Difficulty.new(seed_value)
	_clear_actors()
	world_speed = Difficulty.world_speed(1)
	_gates_passed = 0
	start_level(1)


func start_level(n: int) -> void:
	level = n
	phase = Phase.GATES
	if not endless or n == 1:
		level_distance = 0.0
		_next_gate = 0
		_next_wave = 0
		_next_runners = 0
	_boss_spawned = false
	_chew_timer = 0.0
	boss = null
	_crate_plan = gen.crates_for_level(level) if gen != null else []
	_fork_routes = gen.make_fork(level) if gen != null else {}
	fork_side = 0
	if squad != null:
		squad.set_lane(-Squad.LANE_HALF, Squad.LANE_HALF)
	# Stragglers from the last level would eat a one-soldier squad.
	for z in zombies:
		z.consume()
	zombies.clear()
	_latched.clear()
	_strike_timer = 1.5
	_adds_timer = Difficulty.BOSS_ADDS_INTERVAL
	level_started.emit(level)


func _clear_actors() -> void:
	for g in gates:
		g.queue_free()
	gates.clear()
	for pg in perk_gates:
		pg.queue_free()
	perk_gates.clear()
	for rg in route_gates:
		rg.queue_free()
	route_gates.clear()
	if fork != null and is_instance_valid(fork):
		fork.queue_free()
	fork = null
	fork_side = 0
	_wave_alive.clear()
	_wave_voided.clear()
	for z in zombies:
		z.queue_free()
	zombies.clear()
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	for sp in _spits:
		sp.queue_free()
	_spits.clear()
	for st in _strikes:
		st.queue_free()
	_strikes.clear()
	_latched.clear()
	for c in _crates:
		c.queue_free()
	_crates.clear()
	for b in _bombs:
		b.queue_free()
	_bombs.clear()
	for b in bullets.get_children():
		b.queue_free()


## Advance the world by one frame. Returns the scroll speed used.
func advance(delta: float, p_squad: Squad) -> float:
	var target := Difficulty.boss_world_speed() if phase == Phase.BOSS else Difficulty.world_speed(level)
	if powerups != null:
		target *= powerups.world_speed_mult(now)
	world_speed = lerpf(world_speed, target, 1.0 - exp(-2.5 * delta))
	level_distance += world_speed * delta
	match phase:
		Phase.GATES:
			_spawn()
		Phase.BOSS:
			_tick_boss(delta, p_squad)
		Phase.CLEAR:
			_clear_timer -= delta
			if _clear_timer <= 0.0:
				start_level(level + 1)
	_scroll_dressing(delta)
	_move_gates(delta, p_squad)
	_move_perk_gates(delta, p_squad)
	_move_fork(delta, p_squad)
	_move_zombies(delta, p_squad)
	_move_boss(delta)
	_move_spits(p_squad)
	_move_crates(delta, p_squad)
	_move_bombs(p_squad)
	_move_strikes(delta, p_squad)
	_focus_on_latched(delta, p_squad)
	return world_speed


## Holding focus on a clinging zombie pours fire into it. Bullets cannot
## reach your own flank, so this is the only way to shake one loose
## without dashing.
func _focus_on_latched(delta: float, p_squad: Squad) -> void:
	if not p_squad.focus_on or _latched.is_empty():
		return
	var fp := p_squad.focus_point
	for z in _latched.duplicate():
		var d := Vector2(z.position.x - fp.x, z.position.z - fp.z).length()
		if d > Progression.FOCUS_LATCH_RADIUS:
			continue
		if z.take_damage(p_squad.dps() * Progression.FOCUS_LATCH_DPS_FRACTION * delta):
			_latched.erase(z)
			zombies.erase(z)
			zombie_killed.emit(z)
			_note_wave_death(z)
			z.die()
		break


## A dash throws the first few clingers off the flanks.
func shake_off() -> void:
	var n := 0
	for z in _latched.duplicate():
		if n >= Progression.DASH_SHAKES_OFF:
			break
		_latched.erase(z)
		zombies.erase(z)
		_note_wave_leak(z)
		z.consume()
		n += 1
	if n > 0:
		shaken_off.emit(n)


## How much slower everything that walks is going right now.
func _pace() -> float:
	return powerups.world_speed_mult(now) if powerups != null else 1.0


## The closest live zombie within [param max_range] metres, or null.
## Inside a fork, only zombies on the squad's own route count: the ones
## behind the divider cannot be reached or reach you.
func nearest_zombie(max_range: float) -> Zombie:
	var best: Zombie = null
	for z in zombies:
		if z.position.z < -max_range:
			continue
		if fork_side != 0 and signf(z.position.x) != float(fork_side) and absf(z.position.x) > 0.3:
			continue
		if best == null or z.position.z > best.position.z:
			best = z
	return best


## The best focus-fire target: a latcher on the squad, else the nearest
## brute, tank or thief within [param max_range], else null.
func focus_target(max_range: float) -> Zombie:
	var best: Zombie = null
	for z in zombies:
		if z.latched:
			return z
		if not (z.brute or z.is_tank() or z.is_thief() or z.is_latcher()):
			continue
		if z.position.z < -max_range:
			continue
		if fork_side != 0 and signf(z.position.x) != float(fork_side) and absf(z.position.x) > 0.3:
			continue
		if best == null or z.position.z > best.position.z:
			best = z
	return best


## The next gate the squad has not passed yet, or null.
func nearest_upcoming_gate() -> Gate:
	var best: Gate = null
	for g in gates:
		if g.passed:
			continue
		if best == null or g.position.z > best.position.z:
			best = g
	return best


## Called by a bullet each frame. Resolves the hit and returns true if the
## bullet is spent. Sweeps from the bullet's previous z so fast tracers
## cannot tunnel through thin targets.
func try_hit(b: Bullet) -> bool:
	var z_lo := minf(b.prev_z, b.position.z) - 0.35
	var z_hi := maxf(b.prev_z, b.position.z) + 0.35
	for z in zombies.duplicate():
		if z.latched or z.position.z < z_lo or z.position.z > z_hi:
			continue
		if absf(z.position.x - b.position.x) > z.radius * b.radius_mult:
			continue
		if z.take_damage(b.damage):
			zombies.erase(z)
			zombie_killed.emit(z)
			_note_wave_death(z)
			z.die()
			if b.hits_left > 1:
				# Piercing: keep flying, but never count the same kill twice.
				b.hits_left -= 1
				continue
		return true
	if boss != null and boss.alive and boss.position.z >= z_lo - 0.6 and boss.position.z <= z_hi + 0.6:
		if absf(boss.position.x - b.position.x) <= (Boss.BODY_RADIUS * 0.75 if boss.is_spitter() else Boss.BODY_RADIUS):
			var core := boss.is_core_hit(b.position.x)
			var dead := boss.take_damage(b.damage, core)
			boss_hit.emit(boss, core)
			if dead:
				_on_boss_dead()
			return true
	for g in gates:
		if g.passed or g.position.z < z_lo or g.position.z > z_hi:
			continue
		var i := g.panel_index_at_x(b.position.x)
		if i >= 0:
			var dmg := b.damage * (Progression.HOT_MULT if g.is_hot(i, now) else 1.0)
			if g.register_hit(i, dmg, _step_cost()):
				gate_stepped.emit(g, i)
			return true
	for rg in route_gates:
		if rg.passed or rg.position.z < z_lo or rg.position.z > z_hi or not rg.covers_x(b.position.x):
			continue
		rg.register_hit(b.damage * (Progression.HOT_MULT if rg.is_hot(now) else 1.0), _step_cost())
		return true
	return false


func _step_cost() -> float:
	var cost := Difficulty.effective_step_cost(level, squad.dps() if squad != null else 0.0)
	if perks != null:
		cost *= perks.step_cost_mult()
	return cost


## In endless mode gate counters never reset, so the level and the index
## inside it are derived from the running counter.
func _gate_level(n: int) -> int:
	return 1 + n / Difficulty.GATES_PER_LEVEL if endless else level


func _gate_index(n: int) -> int:
	return n % Difficulty.GATES_PER_LEVEL if endless else n


func _spawn() -> void:
	var count := squad.count if squad != null else 1
	var limit := 1 << 30 if endless else Difficulty.GATES_PER_LEVEL
	while _next_gate < limit and Difficulty.gate_distance(_next_gate) - level_distance <= SPAWN_AHEAD:
		var z := -(Difficulty.gate_distance(_next_gate) - level_distance)
		var offer: Array = perks.offer(gen.rng) if (perks != null and Perks.is_pick_gate(_gate_index(_next_gate))) else []
		if Difficulty.is_fork_gate(_gate_index(_next_gate)) and not _fork_routes.is_empty():
			var k := _gate_index(_next_gate) - Difficulty.FORK_INDEX
			if k == 0:
				fork = Fork.new()
				fork.setup(_fork_routes, Difficulty.fork_length())
				fork.position = Vector3(0.0, 0.0, z + Difficulty.FORK_LEAD)
				add_child(fork)
				fork_ahead.emit(_fork_routes)
			for side in [-1, 1]:
				var route: Dictionary = _fork_routes["left" if side < 0 else "right"]
				var rg := RouteGate.new()
				rg.setup(route.panels[k], side)
				rg.hot_enabled = Progression.hot_panels(level)
				rg.hot_phase = gen.rng.randf_range(0.0, Progression.HOT_PERIOD)
				rg.position.z = z
				add_child(rg)
				route_gates.append(rg)
		elif offer.size() >= 2:
			var pg := PerkGate.new()
			pg.setup(offer)
			pg.position = Vector3(0.0, 0.0, z)
			add_child(pg)
			perk_gates.append(pg)
		else:
			var pair := gen.make_gate_pair(_gate_level(_next_gate), _gate_index(_next_gate), count)
			var g := Gate.new()
			g.setup(pair[0], pair[1])
			g.index = _gate_index(_next_gate)
			g.hot_enabled = Progression.hot_panels(level)
			g.hot_phase = gen.rng.randf_range(0.0, Progression.HOT_PERIOD)
			g.position = Vector3(0.0, 0.0, z)
			add_child(g)
			gates.append(g)
		_next_gate += 1
	while _next_wave < limit and Difficulty.wave_distance(_next_wave) - level_distance <= SPAWN_AHEAD:
		_spawn_wave(_next_wave, count)
		_next_wave += 1
	for plan in _crate_plan.duplicate():
		var n: int = plan.index + ((level - 1) * Difficulty.GATES_PER_LEVEL if endless else 0)
		if Difficulty.crate_distance(n) - level_distance <= SPAWN_AHEAD:
			var c := Crate.new()
			c.setup(plan.id)
			c.position = Vector3(gen.rng.randf_range(-LANE_HALF + 1.0, LANE_HALF - 1.0), 0.0, -(Difficulty.crate_distance(n) - level_distance))
			add_child(c)
			_crates.append(c)
			_crate_plan.erase(plan)
	if not endless and not _boss_spawned and Difficulty.boss_distance() - level_distance <= SPAWN_AHEAD:
		_boss_spawned = true
		boss = Boss.new()
		boss.setup(Difficulty.boss_hp(level, perk_count), Difficulty.boss_kind(level))
		boss.core_mult = Boss.CORE_MULT + (perks.core_mult_bonus() if perks != null else 0.0) + (meta.core_mult_bonus() if meta != null else 0.0)
		boss.position = Vector3(0.0, 0.0, -(Difficulty.boss_distance() - level_distance))
		add_child(boss)
		boss_spawned.emit(boss)


func _spawn_wave(n: int, count: int) -> void:
	var spec := Difficulty.wave_for(_gate_level(n), _gate_index(n), count)
	var base_z := -(Difficulty.wave_distance(n) - level_distance)
	# A wave that sits inside the fork is split per route: each side gets
	# its own crowd, scaled by how rich that route is.
	var index := _gate_index(n)
	if Difficulty.is_fork_gate(index) and Difficulty.wave_distance(index) < Difficulty.fork_distance() + Difficulty.fork_length() and not _fork_routes.is_empty():
		for side in [-1, 1]:
			var route: Dictionary = _fork_routes["left" if side < 0 else "right"]
			_wave_seq += 1
			var wave := _wave_seq
			var lo := 0.6 if side > 0 else -LANE_HALF + 0.5
			var hi := LANE_HALF - 0.5 if side > 0 else -0.6
			for i in range(int(ceil(spec.count * float(route.wave_mult)))):
				_spawn_zombie_in(spec.hp, spec.speed, Zombie.Kind.NORMAL, base_z - gen.rng.randf_range(0.0, 7.0), wave, lo, hi)
			for i in range(int(spec.brutes * float(route.wave_mult)) + int(route.extra_brutes)):
				_spawn_zombie_in(spec.brute_hp, spec.speed, Zombie.Kind.BRUTE, base_z - gen.rng.randf_range(4.0, 9.0), wave, lo, hi)
		return
	_wave_seq += 1
	var wave := _wave_seq
	for i in range(spec.count):
		_spawn_zombie(spec.hp, spec.speed, Zombie.Kind.NORMAL, base_z - gen.rng.randf_range(0.0, 7.0), wave)
	for i in range(spec.brutes):
		_spawn_zombie(spec.brute_hp, spec.speed, Zombie.Kind.BRUTE, base_z - gen.rng.randf_range(4.0, 9.0), wave)
	for i in range(spec.tanks):
		_spawn_zombie(spec.tank_hp, spec.speed, Zombie.Kind.TANK, base_z + 3.0, wave)
	for i in range(spec.latchers):
		_spawn_zombie(spec.latcher_hp, spec.speed, Zombie.Kind.LATCHER, base_z - gen.rng.randf_range(2.0, 6.0), wave)
	# Thieves start on the squad's side of the gate ahead and sprint for it.
	# The gate this wave follows is at wave_distance - WAVE_OFFSET; the next
	# gate is GATE_SPACING further. Put thieves 14 m short of that next gate.
	for i in range(spec.thieves):
		var z := base_z - (Difficulty.GATE_SPACING - Difficulty.WAVE_OFFSET) + 14.0 + gen.rng.randf_range(0.0, 3.0)
		_spawn_zombie(spec.thief_hp, spec.speed, Zombie.Kind.THIEF, z)


## Runners come in a tight pack from one side, released as a gate passes.
func _spawn_runners(n: int, count: int) -> void:
	var spec := Difficulty.wave_for(_gate_level(n), _gate_index(n), count)
	var base_z := Difficulty.runner_release_z(level)
	var side := -1.0 if gen.rng.randf() < 0.5 else 1.0
	var lo := -LANE_HALF + 0.5
	var hi := LANE_HALF - 0.5
	if fork_side != 0:
		# Inside a fork the pack comes down your own route.
		side = float(fork_side)
		lo = 0.6 if fork_side > 0 else -LANE_HALF + 0.5
		hi = LANE_HALF - 0.5 if fork_side > 0 else -0.6
	for i in range(spec.runners):
		var zb := Zombie.new()
		zb.setup(spec.runner_hp, spec.speed, Zombie.Kind.RUNNER)
		zb.lane_offset = gen.rng.randf_range(-0.8, 0.8)
		zb.lane_min = lo
		zb.lane_max = hi
		zb.position = Vector3(clampf(side * gen.rng.randf_range(1.0, LANE_HALF - 0.5), lo, hi), 0.0, base_z - gen.rng.randf_range(0.0, 3.0))
		add_child(zb)
		zombies.append(zb)


func _spawn_zombie(hp: float, speed: float, kind: int, z: float, wave: int = -1) -> void:
	_spawn_zombie_in(hp, speed, kind, z, wave, -LANE_HALF + 0.8, LANE_HALF - 0.8)


func _spawn_zombie_in(hp: float, speed: float, kind: int, z: float, wave: int, lo: float, hi: float) -> void:
	var zb := Zombie.new()
	zb.setup(hp, speed, kind)
	zb.wave_id = wave
	if wave >= 0:
		_wave_alive[wave] = int(_wave_alive.get(wave, 0)) + 1
	zb.lane_offset = gen.rng.randf_range(-1.1, 1.1)
	zb.lane_min = lo
	zb.lane_max = hi
	zb.position = Vector3(gen.rng.randf_range(lo, hi), 0.0, z)
	add_child(zb)
	zombies.append(zb)


func _note_wave_death(z: Zombie) -> void:
	if z.wave_id < 0:
		return
	var left := int(_wave_alive.get(z.wave_id, 1)) - 1
	_wave_alive[z.wave_id] = left
	if left <= 0:
		if not _wave_voided.has(z.wave_id):
			wave_cleared.emit(level)
		_wave_alive.erase(z.wave_id)
		_wave_voided.erase(z.wave_id)


func _note_wave_leak(z: Zombie) -> void:
	if z.wave_id < 0:
		return
	_wave_voided[z.wave_id] = true
	var left := int(_wave_alive.get(z.wave_id, 1)) - 1
	_wave_alive[z.wave_id] = left
	if left <= 0:
		_wave_alive.erase(z.wave_id)
		_wave_voided.erase(z.wave_id)


## The nearest unpassed gate ahead of [param z] (more negative), or null.
func _gate_ahead_of(z: float) -> Gate:
	var best: Gate = null
	for g in gates:
		if g.passed or g.position.z > z:
			continue
		if best == null or g.position.z > best.position.z:
			best = g
	return best


func _move_gates(delta: float, p_squad: Squad) -> void:
	var reveal_z := REVEAL_Z - (perks.reveal_bonus() if perks != null else 0.0) - (meta.reveal_bonus() if meta != null else 0.0)
	for g in gates.duplicate():
		g.position.z += world_speed * delta
		g.update_hot(now)
		if not g.passed:
			if g.position.z >= reveal_z:
				g.reveal_all()
			if g.position.z >= 0.0:
				var index := 0 if p_squad.position.x < 0.0 else 1
				var panel: GateMath.GatePanel = g.choose(index)
				var before := p_squad.count
				var after := GateMath.apply(before, panel)
				if GateMath.is_power(panel):
					powerup_granted.emit(Powerups.resolve(panel.power, gen.rng), false)
				if after > 0:
					if meta != null and panel.kind == GateMath.Kind.ADD and panel.value > 0.0:
						after += meta.gate_bonus()
					if perks != null:
						after += perks.recruit_per_gate()
				p_squad.set_count(after)
				_gates_passed += 1
				gate_passed.emit(panel, before, after)
				_spawn_runners(_next_runners, p_squad.count)
				_next_runners += 1
				if after > 0 and g.steps_up[index] >= Difficulty.PERFECT_STEPS:
					gate_perfect.emit(g, index)
				if endless and _gates_passed % Difficulty.GATES_PER_LEVEL == 0:
					start_level(level + 1)
		if g.position.z > DESPAWN_Z:
			gates.erase(g)
			g.queue_free()


func _move_perk_gates(delta: float, p_squad: Squad) -> void:
	for pg in perk_gates.duplicate():
		pg.position.z += world_speed * delta
		if not pg.passed and pg.position.z >= 0.0:
			var id: String = pg.choose(pg.slot_at_x(p_squad.position.x))
			_gates_passed += 1
			perk_chosen.emit(id)
			_spawn_runners(_next_runners, p_squad.count)
			_next_runners += 1
			if endless and _gates_passed % Difficulty.GATES_PER_LEVEL == 0:
				start_level(level + 1)
		if pg.position.z > DESPAWN_Z:
			perk_gates.erase(pg)
			pg.queue_free()


func _move_fork(delta: float, p_squad: Squad) -> void:
	if fork != null:
		fork.position.z += world_speed * delta
		if not fork.chosen and fork.position.z >= 0.0:
			fork_side = -1 if p_squad.position.x < 0.0 else 1
			fork.commit()
			if fork_side < 0:
				p_squad.set_lane(-Squad.LANE_HALF, -0.55)
			else:
				p_squad.set_lane(0.55, Squad.LANE_HALF)
			fork_chosen.emit(_fork_routes["left" if fork_side < 0 else "right"], fork_side)
	for rg in route_gates.duplicate():
		rg.position.z += world_speed * delta
		rg.update_hot(now)
		if not rg.passed:
			if rg.position.z >= REVEAL_Z - (perks.reveal_bonus() if perks != null else 0.0):
				rg.reveal()
			if rg.position.z >= 0.0:
				if rg.side == fork_side:
					var panel: GateMath.GatePanel = rg.choose()
					var before := p_squad.count
					var after := GateMath.apply(before, panel)
					if after > 0 and perks != null:
						after += perks.recruit_per_gate()
					p_squad.set_count(after)
					_gates_passed += 1
					gate_passed.emit(panel, before, after)
					_spawn_runners(_next_runners, p_squad.count)
					_next_runners += 1
					if after > 0 and rg.steps_up >= Difficulty.PERFECT_STEPS:
						gate_perfect.emit(null, rg.side)
				else:
					rg.skip()
		if rg.position.z > DESPAWN_Z:
			route_gates.erase(rg)
			rg.queue_free()
	if fork == null:
		return
	if fork.chosen and fork.position.z >= fork.length:
		fork_side = 0
		p_squad.set_lane(-Squad.LANE_HALF, Squad.LANE_HALF)
		fork_merged.emit()
		fork.queue_free()
		fork = null


## The next perk gate the squad has not passed yet, or null.
func nearest_upcoming_perk_gate() -> PerkGate:
	var best: PerkGate = null
	for pg in perk_gates:
		if pg.passed:
			continue
		if best == null or pg.position.z > best.position.z:
			best = pg
	return best


func _move_zombies(delta: float, p_squad: Squad) -> void:
	for z in zombies.duplicate():
		if z.is_thief():
			_move_thief(delta, z)
			continue
		if z.latched:
			_tick_latched(delta, z, p_squad)
			continue
		var pace := _pace()
		z.position.z += (world_speed + z.speed * pace) * delta
		var aim_x := clampf(p_squad.position.x + z.lane_offset, maxf(-LANE_HALF + 0.4, z.lane_min), minf(LANE_HALF - 0.4, z.lane_max))
		z.position.x = move_toward(z.position.x, aim_x, z.homing * pace * delta)
		var in_reach: bool = absf(z.position.x - p_squad.position.x) <= p_squad.reach() + z.radius
		var same_route: bool = p_squad.position.x >= z.lane_min - 0.6 and p_squad.position.x <= z.lane_max + 0.6
		if z.position.z >= BITE_Z and in_reach and same_route:
			if p_squad.is_invulnerable():
				# Dashed through it: it stumbles past and is gone.
				zombies.erase(z)
				_note_wave_leak(z)
				z.consume()
				dodged.emit()
				continue
			var can_cling: bool = not (z.brute or z.is_tank()) and not p_squad.is_shielded() and _latched.size() < Progression.MAX_LATCHED
			if can_cling:
				# Clings to a flank and rides along, eating, until shot off.
				z.latched = true
				z.latch_timer = Difficulty.LATCH_INTERVAL
				z.hp = maxf(z.hp, z.max_hp) * Difficulty.LATCH_HP_MULT
				z.max_hp = z.hp
				_latched.append(z)
				latched.emit(z)
				continue
			zombies.erase(z)
			_note_wave_leak(z)
			z.consume()
			if p_squad.is_shielded():
				shield_blocked.emit()
				continue
			var bite: int = z.bite
			if z.is_tank():
				bite = maxi(1, int(Difficulty.tank_bite(p_squad.count) * p_squad.bite_mult()))
			elif z.brute:
				var fraction := Difficulty.BRUTE_BITE_FRACTION
				if meta != null:
					fraction = meta.brute_bite_fraction(fraction)
				if perks != null:
					fraction *= perks.brute_bite_mult()
				bite = maxi(1, int(Difficulty.brute_bite(p_squad.count, fraction) * p_squad.bite_mult()))
			p_squad.add(-bite)
			squad_bitten.emit(bite, z.brute or z.is_tank())
		elif z.position.z > DESPAWN_Z:
			zombies.erase(z)
			_note_wave_leak(z)
			z.queue_free()


## A latched zombie clings to the squad's front rank and eats on a timer.
## It is a target on your own doorstep: focus fire takes it off.
func _tick_latched(delta: float, z: Zombie, p_squad: Squad) -> void:
	var slot := p_squad.latch_slot(_latched.find(z))
	var target := p_squad.position + slot
	z.position.x = lerpf(z.position.x, target.x, 1.0 - exp(-12.0 * delta))
	z.position.z = lerpf(z.position.z, target.z, 1.0 - exp(-12.0 * delta))
	z.look_at(p_squad.position + Vector3(0.0, 0.0, z.position.z - p_squad.position.z), Vector3.UP)
	z.latch_timer -= delta
	if z.latch_timer <= 0.0:
		z.latch_timer = Difficulty.LATCH_INTERVAL
		if p_squad.is_shielded():
			return
		p_squad.add(-Difficulty.LATCH_BITE)
		squad_bitten.emit(Difficulty.LATCH_BITE, false)
		if p_squad.count <= 0:
			_latched.erase(z)
			zombies.erase(z)
			z.consume()


## Thieves sprint away from the squad toward the gate ahead of them and
## knock its better panel down when they arrive. Kill them first.
func _move_thief(delta: float, z: Zombie) -> void:
	var g := _gate_ahead_of(z.position.z)
	z.position.z += (world_speed - Difficulty.THIEF_SPEED * _pace()) * delta
	if g == null:
		if z.position.z < -SPAWN_AHEAD - 10.0:
			zombies.erase(z)
			z.queue_free()
		return
	var best := GateMath.better_index(g.panels[0], g.panels[1], squad.count if squad != null else 1)
	var aim_x := -GatePanelView.CENTER_X if best == 0 else GatePanelView.CENTER_X
	z.position.x = move_toward(z.position.x, aim_x, z.homing * delta)
	if z.position.z <= g.position.z + 0.6:
		zombies.erase(z)
		z.consume()
		g.rob(best)
		gate_robbed.emit(g, best)


func _move_boss(delta: float) -> void:
	if boss == null or not boss.alive:
		return
	match phase:
		Phase.GATES:
			boss.position.z += (world_speed + 1.0) * delta
			# The fight starts once the last gate is behind you, so the road
			# never crawls with a number gate still ahead.
			if boss.position.z >= BOSS_ENGAGE_Z and _all_gates_passed():
				phase = Phase.BOSS
		Phase.BOSS:
			var walk := BOSS_WALK_SPEED * _pace() * (1.6 if boss_enraged() else 1.0)
			if boss.is_spitter():
				boss.position.z = minf(boss.position.z + walk * delta, Boss.SPITTER_HOLD_Z)
				boss.position.x = boss.sway_x
			else:
				boss.position.z = minf(boss.position.z + walk * delta, BOSS_CHEW_Z)


func _all_gates_passed() -> bool:
	for g in gates:
		if not g.passed:
			return false
	for pg in perk_gates:
		if not pg.passed:
			return false
	for rg in route_gates:
		if not rg.passed:
			return false
	return true


func boss_enraged() -> bool:
	return boss != null and boss.alive and boss.hp <= boss.max_hp * Difficulty.ENRAGE_FRACTION


func _tick_boss(delta: float, p_squad: Squad) -> void:
	if boss == null or not boss.alive:
		return
	var enraged := boss_enraged()
	# Lightning: rings near the squad, then bolts. Move or dash out.
	_strike_timer -= delta * _pace()
	if _strike_timer <= 0.0 and boss.position.z > BOSS_ENGAGE_Z - 2.0:
		_strike_timer = Difficulty.STRIKE_INTERVAL_ENRAGED if enraged else Difficulty.STRIKE_INTERVAL
		var n := Difficulty.strikes_per_volley(level) + (1 if enraged else 0)
		for i in range(n):
			var offset := 0.0 if i == 0 else gen.rng.randf_range(-2.2, 2.2)
			var st := Strike.new()
			st.setup(clampf(p_squad.position.x + p_squad.velocity_x * 0.5 + offset, -LANE_HALF, LANE_HALF))
			add_child(st)
			_strikes.append(st)
	# Adds: the boss calls runners down the road.
	_adds_timer -= delta * _pace()
	if _adds_timer <= 0.0:
		_adds_timer = Difficulty.BOSS_ADDS_INTERVAL * (0.7 if enraged else 1.0)
		var spec := Difficulty.wave_for(level, Difficulty.GATES_PER_LEVEL - 1, p_squad.count)
		for i in range(Difficulty.boss_adds(level)):
			var zb := Zombie.new()
			zb.setup(spec.runner_hp, spec.speed, Zombie.Kind.RUNNER)
			zb.lane_offset = gen.rng.randf_range(-1.0, 1.0)
			zb.position = Vector3(gen.rng.randf_range(-LANE_HALF + 0.6, LANE_HALF - 0.6), 0.0, boss.position.z + 1.0)
			add_child(zb)
			zombies.append(zb)
	if boss.is_spitter():
		if boss.position.z < Boss.SPITTER_HOLD_Z - 0.5:
			return
		boss.spit_timer -= delta * _pace()
		if boss.spit_timer <= 0.0:
			# Faster once hurt, and a volley instead of a single glob. Aim
			# where the squad will be, not where it is.
			boss.spit_timer = Boss.SPIT_INTERVAL * 0.6 if enraged else Boss.SPIT_INTERVAL
			var from := boss.position + Vector3(0.0, 3.3, 0.8)
			var flight := -from.z / Spit.SPEED
			var aim := clampf(p_squad.position.x + p_squad.velocity_x * flight * 0.8, -LANE_HALF + 0.3, LANE_HALF - 0.3)
			var volley := Difficulty.SPIT_VOLLEY if enraged else 1
			for i in range(volley):
				var to_x := clampf(aim + (float(i) - float(volley - 1) * 0.5) * 1.6, -LANE_HALF + 0.3, LANE_HALF - 0.3)
				var sp := Spit.new()
				add_child(sp)
				sp.launch(from, to_x, self)
				_spits.append(sp)
		return
	if boss.position.z < BOSS_CHEW_Z:
		return
	_chew_timer -= delta
	if _chew_timer <= 0.0:
		_chew_timer = Difficulty.BOSS_BITE_INTERVAL
		if p_squad.is_invulnerable():
			dodged.emit()
			return
		if p_squad.is_shielded():
			shield_blocked.emit()
			return
		var bite := Difficulty.boss_bite(p_squad.count)
		p_squad.add(-bite)
		squad_bitten.emit(bite, true)


func _move_spits(p_squad: Squad) -> void:
	for sp in _spits.duplicate():
		if not sp.landed():
			continue
		_spits.erase(sp)
		var hit := absf(sp.position.x - p_squad.position.x) <= p_squad.reach() + 1.0
		if hit and p_squad.is_invulnerable():
			dodged.emit()
			hit = false
		elif hit and p_squad.is_shielded():
			shield_blocked.emit()
			hit = false
		elif hit:
			var bite := Difficulty.spit_bite(p_squad.count)
			p_squad.add(-bite)
			squad_bitten.emit(bite, true)
		spit_landed.emit(hit)
		sp.queue_free()


func _move_strikes(delta: float, p_squad: Squad) -> void:
	for st in _strikes.duplicate():
		if st.tick(delta):
			var hit := absf(st.x - p_squad.position.x) <= p_squad.reach() + Difficulty.STRIKE_RADIUS * 0.5
			if hit and (p_squad.is_invulnerable()):
				dodged.emit()
				hit = false
			elif hit and p_squad.is_shielded():
				shield_blocked.emit()
				hit = false
			elif hit:
				var bite := Difficulty.strike_bite(p_squad.count)
				p_squad.add(-bite)
				squad_bitten.emit(bite, true)
			strike_landed.emit(st.position, hit)
		if st.done:
			_strikes.erase(st)
			st.queue_free()


## True when a warning ring is about to fire within [param dx] of x.
func strike_threat_at(x: float, dx: float) -> bool:
	for st in _strikes:
		if not st.fired and absf(st.x - x) <= dx:
			return true
	return false


func _move_crates(delta: float, p_squad: Squad) -> void:
	for c in _crates.duplicate():
		c.position.z += world_speed * delta
		if c.position.z >= -0.6 and absf(c.position.x - p_squad.position.x) <= p_squad.reach() + 0.7:
			_crates.erase(c)
			powerup_granted.emit(Powerups.resolve(c.id, gen.rng), true)
			c.queue_free()
		elif c.position.z > DESPAWN_Z:
			_crates.erase(c)
			c.queue_free()


## Lob a bomb from the squad. It detonates where it lands.
func throw_bomb(from_x: float) -> void:
	var b := Bomb.new()
	add_child(b)
	b.launch(Vector3(from_x, 1.0, -0.5))
	_bombs.append(b)


func _move_bombs(p_squad: Squad) -> void:
	for b in _bombs.duplicate():
		if not b.landed():
			continue
		_bombs.erase(b)
		var at: Vector3 = b.target
		var kills := 0
		var heavy := (p_squad.dps() if p_squad != null else 10.0) * 3.0
		for z in zombies.duplicate():
			if z.latched or z.position.distance_to(at) > Bomb.RADIUS:
				continue
			var dead := true
			if z.brute or z.is_tank():
				dead = z.take_damage(heavy)
			if dead:
				zombies.erase(z)
				zombie_killed.emit(z)
				_note_wave_death(z)
				z.die()
				kills += 1
		if boss != null and boss.alive and boss.position.distance_to(at) <= Bomb.RADIUS + 1.5:
			var dead := boss.take_damage(heavy * 1.5, false)
			boss_hit.emit(boss, false)
			if dead:
				_on_boss_dead()
		bomb_exploded.emit(at, kills)
		b.queue_free()


func _on_boss_dead() -> void:
	var squad_left := squad.count if squad != null else 0
	boss.die()
	phase = Phase.CLEAR
	_clear_timer = CLEAR_SECONDS
	boss_killed.emit(level, squad_left)


func _build_dressing() -> void:
	var road := Mats.box(Vector3(LANE_HALF * 2.0 + 0.6, 0.2, 260.0), ROAD)
	road.position = Vector3(0.0, -0.1, -100.0)
	add_child(road)
	for side in [-1.0, 1.0]:
		var curb := Mats.box(Vector3(0.7, 0.45, 260.0), CURB)
		curb.position = Vector3(side * (LANE_HALF + 0.65), 0.1, -100.0)
		add_child(curb)
	for i in range(26):
		var d := Mats.box(Vector3(0.18, 0.02, 2.4), DASH)
		d.position = Vector3(0.0, 0.01, 6.0 - i * 6.0)
		add_child(d)
		_dashes.append(d)
	for i in range(16):
		for side in [-1.0, 1.0]:
			var p := Mats.box(Vector3(0.3, 1.4, 0.3), POST)
			p.position = Vector3(side * (LANE_HALF + 0.65), 0.9, 8.0 - i * 12.0)
			add_child(p)
			_posts.append(p)


func _scroll_dressing(delta: float) -> void:
	for d in _dashes:
		d.position.z += world_speed * delta
		if d.position.z > 10.0:
			d.position.z -= 26.0 * 6.0
	for p in _posts:
		p.position.z += world_speed * delta
		if p.position.z > 12.0:
			p.position.z -= 16.0 * 12.0
