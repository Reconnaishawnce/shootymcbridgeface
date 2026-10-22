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
	# Stragglers from the last level would eat a one-soldier squad.
	for z in zombies:
		z.consume()
	zombies.clear()
	level_started.emit(level)


func _clear_actors() -> void:
	for g in gates:
		g.queue_free()
	gates.clear()
	for pg in perk_gates:
		pg.queue_free()
	perk_gates.clear()
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
	_move_zombies(delta, p_squad)
	_move_boss(delta)
	_move_spits(p_squad)
	_move_crates(delta, p_squad)
	_move_bombs(p_squad)
	return world_speed


## How much slower everything that walks is going right now.
func _pace() -> float:
	return powerups.world_speed_mult(now) if powerups != null else 1.0


## The closest live zombie within [param max_range] metres, or null.
func nearest_zombie(max_range: float) -> Zombie:
	var best: Zombie = null
	for z in zombies:
		if z.position.z < -max_range:
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
		if z.position.z < z_lo or z.position.z > z_hi:
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
			var cost := Difficulty.effective_step_cost(level, squad.dps() if squad != null else 0.0)
			if perks != null:
				cost *= perks.step_cost_mult()
			if g.register_hit(i, b.damage, cost):
				gate_stepped.emit(g, i)
			return true
	return false


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
		if offer.size() >= 2:
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
	_wave_seq += 1
	var wave := _wave_seq
	for i in range(spec.count):
		_spawn_zombie(spec.hp, spec.speed, Zombie.Kind.NORMAL, base_z - gen.rng.randf_range(0.0, 7.0), wave)
	for i in range(spec.brutes):
		_spawn_zombie(spec.brute_hp, spec.speed, Zombie.Kind.BRUTE, base_z - gen.rng.randf_range(4.0, 9.0), wave)
	for i in range(spec.tanks):
		_spawn_zombie(spec.tank_hp, spec.speed, Zombie.Kind.TANK, base_z + 3.0, wave)
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
	for i in range(spec.runners):
		var zb := Zombie.new()
		zb.setup(spec.runner_hp, spec.speed, Zombie.Kind.RUNNER)
		zb.lane_offset = gen.rng.randf_range(-0.8, 0.8)
		zb.position = Vector3(side * gen.rng.randf_range(1.0, LANE_HALF - 0.5), 0.0, base_z - gen.rng.randf_range(0.0, 3.0))
		add_child(zb)
		zombies.append(zb)


func _spawn_zombie(hp: float, speed: float, kind: int, z: float, wave: int = -1) -> void:
	var zb := Zombie.new()
	zb.setup(hp, speed, kind)
	zb.wave_id = wave
	if wave >= 0:
		_wave_alive[wave] = int(_wave_alive.get(wave, 0)) + 1
	zb.lane_offset = gen.rng.randf_range(-1.1, 1.1)
	zb.position = Vector3(gen.rng.randf_range(-LANE_HALF + 0.8, LANE_HALF - 0.8), 0.0, z)
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
		var pace := _pace()
		z.position.z += (world_speed + z.speed * pace) * delta
		var aim_x := clampf(p_squad.position.x + z.lane_offset, -LANE_HALF + 0.4, LANE_HALF - 0.4)
		z.position.x = move_toward(z.position.x, aim_x, z.homing * pace * delta)
		if z.position.z >= BITE_Z and absf(z.position.x - p_squad.position.x) <= p_squad.reach() + z.radius:
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
			if boss.position.z >= BOSS_ENGAGE_Z:
				phase = Phase.BOSS
		Phase.BOSS:
			var walk := BOSS_WALK_SPEED * _pace()
			if boss.is_spitter():
				boss.position.z = minf(boss.position.z + walk * delta, Boss.SPITTER_HOLD_Z)
				boss.position.x = boss.sway_x
			else:
				boss.position.z = minf(boss.position.z + walk * delta, BOSS_CHEW_Z)


func _tick_boss(delta: float, p_squad: Squad) -> void:
	if boss == null or not boss.alive:
		return
	if boss.is_spitter():
		if boss.position.z < Boss.SPITTER_HOLD_Z - 0.5:
			return
		boss.spit_timer -= delta * _pace()
		if boss.spit_timer <= 0.0:
			# Faster once hurt. Aim where the squad will be, not where it is.
			boss.spit_timer = Boss.SPIT_INTERVAL if boss.hp > boss.max_hp * 0.5 else Boss.SPIT_INTERVAL * 0.6
			var from := boss.position + Vector3(0.0, 3.3, 0.8)
			var flight := -from.z / Spit.SPEED
			var to_x := clampf(p_squad.position.x + p_squad.velocity_x * flight * 0.8, -LANE_HALF + 0.3, LANE_HALF - 0.3)
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
		if hit and p_squad.is_shielded():
			shield_blocked.emit()
			hit = false
		elif hit:
			var bite := Difficulty.spit_bite(p_squad.count)
			p_squad.add(-bite)
			squad_bitten.emit(bite, true)
		spit_landed.emit(hit)
		sp.queue_free()


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
			if z.position.distance_to(at) > Bomb.RADIUS:
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
