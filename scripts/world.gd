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
signal lanes_changed(lanes: int, animated: bool)
## A bet placed at a gate came due: doubled (won) or halved.
signal bet_resolved(won: bool, before: int, after: int)
signal bet_placed
## Scouts went ahead: the next few gates are open books.
signal scouts_sent(gates: int)
## The boss fight proper has started: the road slows, the clock runs.
signal boss_engaged
## The horde behind caught up and ate.
signal horde_bit(bite: int)
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
## Half the road width; two lanes to start. The road widens with the level.
var road_half := Progression.road_half(2)
var lanes := 2
## Difficulty modifier in force: see Modifiers.
var modifier := "normal"
## Bet bookkeeping: the wave ids the bet rides on (a fork splits one wave
## in two), whether it is already lost, whether a bite landed, and the
## wave index still waiting to spawn.
var _bet_waves: Array = []
var _bet_lost := false
var _bet_pending_index := -1
## Wave index -> ids of the waves spawned for it, this level.
var _wave_id_for: Dictionary = {}
## Set once the run is over: bullets still in the air hit nothing.
var frozen := false
## Gates still to be revealed by a scout party.
var _scout_left := 0
var _bet_bitten := false
## The horde behind the squad: creeps up while the road is stopped.
var horde_z := HORDE_REST_Z
var _horde: Node3D
var _horde_timer := 0.0
const HORDE_REST_Z := 10.0
const HORDE_BITE_Z := 1.6
const HORDE_SPEED := 0.65
const HORDE_RETREAT_SPEED := 2.5
const HORDE_INTERVAL := 0.6
## Steering margin inside the curbs.
const EDGE := 0.4
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
var _road: MeshInstance3D
var _curbs: Array[MeshInstance3D] = []
var _lane_tween: Tween


func _on_own_bite(_bite: int, _heavy: bool) -> void:
	if not _bet_waves.is_empty():
		_bet_bitten = true


func _init() -> void:
	squad_bitten.connect(_on_own_bite)
	bullets = Node3D.new()
	add_child(bullets)
	_build_dressing()


func reset(seed_value: int) -> void:
	gen = Difficulty.new(seed_value)
	_clear_actors()
	world_speed = Difficulty.world_speed(1)
	_gates_passed = 0
	_clear_bet()
	_scout_left = 0
	frozen = false
	horde_z = HORDE_REST_Z
	_place_horde()
	set_lanes(2, false)
	start_level(1)


## Widen (or reset) the road. Animated: curbs slide out, the camera pulls
## back (the game listens), and every gate spawned from now on has one
## panel per lane.
func set_lanes(n: int, animate: bool = true) -> void:
	n = clampi(n, 2, Progression.MAX_LANES)
	if n == lanes and not animate:
		_apply_road_width(Progression.road_half(n))
		return
	if n == lanes:
		return
	lanes = n
	var target := Progression.road_half(n)
	if _lane_tween != null:
		_lane_tween.kill()
	if animate:
		_lane_tween = create_tween()
		_lane_tween.tween_method(_apply_road_width, road_half, target, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_lane_tween.tween_callback(_place_dashes.bind(n))
	else:
		_apply_road_width(target)
		_place_dashes(n)
	lanes_changed.emit(n, animate)


func _apply_road_width(h: float) -> void:
	road_half = h
	if squad != null:
		squad.set_road_half(h - EDGE)
	if _road != null:
		_road.scale.x = (h * 2.0 + 0.6) / 7.2
	for i in range(_curbs.size()):
		_curbs[i].position.x = (-1.0 if i == 0 else 1.0) * (h + 0.65)
	for i in range(_posts.size()):
		var side := -1.0 if i % 2 == 0 else 1.0
		_posts[i].position.x = side * (h + 0.65)


func _clear_bet() -> void:
	_bet_waves = []
	_bet_lost = false
	_bet_bitten = false
	_bet_pending_index = -1


func start_level(n: int) -> void:
	level = n
	phase = Phase.GATES
	# Waves that outlived the level are gone with it; so is any open bet.
	_wave_alive.clear()
	_wave_voided.clear()
	_wave_id_for.clear()
	_clear_bet()
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
		squad.set_lane(-squad.road_half, squad.road_half)
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
	_tick_horde(delta, p_squad)
	return world_speed


## The horde behind: while the road is stopped for a boss it creeps up,
## and if it arrives it eats on a timer. Kill the boss and it falls back.
func _tick_horde(delta: float, p_squad: Squad) -> void:
	var active := level >= int(Modifiers.get_value(modifier, "horde_level")) and not endless
	var pressing := active and phase == Phase.BOSS and boss != null and boss.alive and boss.position.z > BOSS_ENGAGE_Z - 2.0
	if pressing:
		horde_z = maxf(HORDE_BITE_Z, horde_z - HORDE_SPEED * mod("horde_speed") * _pace() * delta)
	else:
		horde_z = minf(HORDE_REST_Z, horde_z + HORDE_RETREAT_SPEED * delta)
	_place_horde()
	if pressing and horde_z <= HORDE_BITE_Z + 0.05:
		_horde_timer -= delta
		if _horde_timer <= 0.0:
			_horde_timer = HORDE_INTERVAL
			if not p_squad.is_shielded():
				var bite := _bite(Difficulty.horde_bite(p_squad.count))
				p_squad.add(-bite)
				squad_bitten.emit(bite, true)
				horde_bit.emit(bite)
	else:
		_horde_timer = 0.0


func _place_horde() -> void:
	if _horde == null:
		return
	_horde.position.z = horde_z
	_horde.visible = horde_z < HORDE_REST_Z - 0.05


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


## The clinging zombie whose on-screen position is within [param max_px]
## of [param screen], or null. Lets a tap land on a clinger wherever it is.
func latched_near_screen(cam: Camera3D, screen: Vector2, max_px: float) -> Zombie:
	var best: Zombie = null
	var best_d := max_px
	for z in _latched:
		if not z.alive:
			continue
		var at := z.global_position + Vector3(0.0, 0.8, 0.0)
		if cam.is_position_behind(at):
			continue
		var d := cam.unproject_position(at).distance_to(screen)
		if d < best_d:
			best_d = d
			best = z
	return best


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
## The modifier's multiplier for [param key]. The threat multipliers
## (waves, health, boss, bites) ramp in over the first levels, so a hard
## run is still playable from one soldier; the payouts are full from the
## start.
func mod(key: String) -> float:
	var v := float(Modifiers.get_value(modifier, key))
	if key in ["wave", "hp", "boss", "bite"]:
		return 1.0 + (v - 1.0) * Modifiers.ramp(level)
	return v


## Scale a bite by the modifier and the shop's armor; never below one.
func _bite(n: int) -> int:
	var armor := meta.bite_mult() if meta != null else 1.0
	return maxi(1, int(round(float(n) * mod("bite") * armor)))


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
	if frozen:
		return true
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
		if absf(boss.position.x - b.position.x) <= (Boss.BODY_RADIUS * 0.75 if boss.holds_back() else Boss.BODY_RADIUS):
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
				fork.setup(_fork_routes, Difficulty.fork_length(), road_half)
				fork.position = Vector3(0.0, 0.0, z + Difficulty.FORK_LEAD)
				add_child(fork)
				fork_ahead.emit(_fork_routes)
			for side in [-1, 1]:
				var route: Dictionary = _fork_routes["left" if side < 0 else "right"]
				var rg := RouteGate.new()
				rg.setup(route.panels[k], side, road_half)
				rg.hot_enabled = Progression.hot_panels(level)
				rg.hot_phase = gen.rng.randf_range(0.0, Progression.HOT_PERIOD)
				rg.position.z = z
				add_child(rg)
				route_gates.append(rg)
		elif offer.size() >= 2:
			var pg := PerkGate.new()
			pg.setup(offer, road_half)
			pg.position = Vector3(0.0, 0.0, z)
			add_child(pg)
			perk_gates.append(pg)
		else:
			var want_lanes := Progression.lanes_for(_gate_level(_next_gate), _gate_index(_next_gate))
			if want_lanes != lanes:
				set_lanes(want_lanes)
			var g := Gate.new()
			g.setup(gen.make_gate(_gate_level(_next_gate), _gate_index(_next_gate), count, lanes), Progression.LANE_W)
			g.index = _gate_index(_next_gate)
			if _scout_left > 0:
				g.reveal_all()
				_scout_left -= 1
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
			c.position = Vector3(gen.rng.randf_range(-road_half + 1.0, road_half - 1.0), 0.0, -(Difficulty.crate_distance(n) - level_distance))
			add_child(c)
			_crates.append(c)
			_crate_plan.erase(plan)
	if not endless and not _boss_spawned and Difficulty.boss_distance() - level_distance <= SPAWN_AHEAD:
		_boss_spawned = true
		boss = Boss.new()
		boss.setup(Difficulty.boss_hp(level, perk_count) * mod("boss"), Difficulty.boss_kind(level))
		boss.core_mult = Boss.CORE_MULT + (perks.core_mult_bonus() if perks != null else 0.0) + (meta.core_mult_bonus() if meta != null else 0.0)
		boss.position = Vector3(0.0, 0.0, -(Difficulty.boss_distance() - level_distance))
		add_child(boss)
		boss_spawned.emit(boss)


func _spawn_wave(n: int, count: int) -> void:
	var spec := _spec(_gate_level(n), _gate_index(n), count)
	var base_z := -(Difficulty.wave_distance(n) - level_distance)
	# A wave that sits inside the fork is split per route: each side gets
	# its own crowd, scaled by how rich that route is.
	var index := _gate_index(n)
	if Difficulty.is_fork_gate(index) and Difficulty.wave_distance(index) < Difficulty.fork_distance() + Difficulty.fork_length() and not _fork_routes.is_empty():
		for side in [-1, 1]:
			var route: Dictionary = _fork_routes["left" if side < 0 else "right"]
			_wave_seq += 1
			var wave := _wave_seq
			_note_wave_id(n, wave)
			var lo := 0.6 if side > 0 else -road_half + 0.5
			var hi := road_half - 0.5 if side > 0 else -0.6
			for i in range(int(ceil(spec.count * float(route.wave_mult)))):
				_spawn_zombie_in(spec.hp, spec.speed, Zombie.Kind.NORMAL, base_z - gen.rng.randf_range(0.0, 7.0), wave, lo, hi)
			for i in range(int(spec.brutes * float(route.wave_mult)) + int(route.extra_brutes)):
				_spawn_zombie_in(spec.brute_hp, spec.speed, Zombie.Kind.BRUTE, base_z - gen.rng.randf_range(4.0, 9.0), wave, lo, hi)
		return
	_wave_seq += 1
	var wave := _wave_seq
	_note_wave_id(n, wave)
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


## Remember which wave ids belong to wave index [param n], and hand them
## to a bet that was waiting for this wave to spawn.
func _note_wave_id(n: int, wave: int) -> void:
	var ids: Array = _wave_id_for.get(n, [])
	ids.append(wave)
	_wave_id_for[n] = ids
	if n == _bet_pending_index:
		_bet_waves = ids.duplicate()


## A wave spec with the modifier applied: more bodies, more health.
func _spec(p_level: int, index: int, count: int) -> Dictionary:
	var spec := Difficulty.wave_for(p_level, index, count)
	var w := mod("wave")
	var h := mod("hp")
	spec.count = mini(int(ceil(float(spec.count) * w)), Difficulty.MAX_WAVE + 12)
	spec.runners = int(ceil(float(spec.runners) * w))
	for key in ["hp", "brute_hp", "tank_hp", "thief_hp", "runner_hp", "latcher_hp"]:
		spec[key] = float(spec[key]) * h
	return spec


## Flankers: runners that come over the curbs beside the squad. Only on a
## road wide enough to have room out there (four lanes and up).
func _spawn_flankers(spec: Dictionary, p_squad: Squad) -> void:
	if lanes < 4 or int(spec.flankers) <= 0:
		return
	_wave_seq += 1
	var wave := _wave_seq
	for i in range(int(spec.flankers)):
		var side := -1.0 if gen.rng.randf() < 0.5 else 1.0
		var zb := Zombie.new()
		zb.setup(float(spec.runner_hp), float(spec.speed) * 1.2, Zombie.Kind.RUNNER)
		zb.wave_id = wave
		zb.lane_min = -road_half + 0.6
		zb.lane_max = road_half - 0.6
		zb.position = Vector3(side * (road_half + 1.4), 0.0, -6.0 - gen.rng.randf_range(0.0, 5.0))
		add_child(zb)
		zombies.append(zb)
		_wave_alive[wave] = int(_wave_alive.get(wave, 0)) + 1


## Runners come in a tight pack from one side, released as a gate passes.
func _spawn_runners(n: int, count: int) -> void:
	var spec := _spec(_gate_level(n), _gate_index(n), count)
	var base_z := Difficulty.runner_release_z(level)
	var side := -1.0 if gen.rng.randf() < 0.5 else 1.0
	var lo := -road_half + 0.5
	var hi := road_half - 0.5
	if fork_side != 0:
		# Inside a fork the pack comes down your own route.
		side = float(fork_side)
		lo = 0.6 if fork_side > 0 else -road_half + 0.5
		hi = road_half - 0.5 if fork_side > 0 else -0.6
	for i in range(spec.runners):
		var zb := Zombie.new()
		zb.setup(spec.runner_hp, spec.speed, Zombie.Kind.RUNNER)
		zb.lane_offset = gen.rng.randf_range(-0.8, 0.8)
		zb.lane_min = lo
		zb.lane_max = hi
		zb.position = Vector3(clampf(side * gen.rng.randf_range(1.0, road_half - 0.5), lo, hi), 0.0, base_z - gen.rng.randf_range(0.0, 3.0))
		add_child(zb)
		zombies.append(zb)


func _spawn_zombie(hp: float, speed: float, kind: int, z: float, wave: int = -1) -> void:
	# Waves spawn in a band that grows at half the road's rate: a wider road
	# is more to read at the gates, not a wall of zombies at every angle.
	var band := minf(road_half - 0.8, 2.5 + (road_half - Progression.road_half(2)) * 0.85)
	_spawn_zombie_in(hp, speed, kind, z, wave, -band, band)


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
		_bet_wave_done(z.wave_id, _wave_voided.has(z.wave_id) or _bet_bitten)
		_wave_alive.erase(z.wave_id)
		_wave_voided.erase(z.wave_id)


func _note_wave_leak(z: Zombie) -> void:
	if z.wave_id < 0:
		return
	_wave_voided[z.wave_id] = true
	var left := int(_wave_alive.get(z.wave_id, 1)) - 1
	_wave_alive[z.wave_id] = left
	if left <= 0:
		_bet_wave_done(z.wave_id, true)
		_wave_alive.erase(z.wave_id)
		_wave_voided.erase(z.wave_id)


## One of the bet's waves finished. The bet settles when the last does.
func _bet_wave_done(wave: int, lost: bool) -> void:
	if not _bet_waves.has(wave):
		return
	_bet_waves.erase(wave)
	if lost:
		_bet_lost = true
	if _bet_waves.is_empty():
		_resolve_bet(not _bet_lost)


## Double or half. A bite during the wave, or a zombie that got through,
## loses it.
func _resolve_bet(won: bool) -> void:
	_clear_bet()
	if squad == null:
		return
	var before := squad.count
	var after := before * 2 if won else maxi(1, before / 2)
	squad.set_count(after)
	bet_resolved.emit(won, before, after)


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
				var index: int = g.panel_index_at_x(p_squad.position.x)
				if index < 0:
					index = 0 if p_squad.position.x < 0.0 else g.panels.size() - 1
				var panel: GateMath.GatePanel = g.choose(index)
				var before := p_squad.count
				var after := GateMath.apply(before, panel)
				if GateMath.is_power(panel):
					powerup_granted.emit(Powerups.resolve(panel.power, gen.rng), false)
				elif GateMath.is_trade(panel):
					powerup_granted.emit(panel.power, false)
				elif GateMath.is_scout(panel):
					_scout_left = GateMath.SCOUT_GATES
					for other in gates:
						if not other.passed and other != g and _scout_left > 0:
							other.reveal_all()
							_scout_left -= 1
					scouts_sent.emit(GateMath.SCOUT_GATES)
				elif GateMath.is_bet(panel):
					# Rides on the wave that follows this gate, which shares
					# its index. Usually spawned already; else it is pending.
					_clear_bet()
					var ids: Array = _wave_id_for.get(_next_runners, [])
					if ids.is_empty():
						_bet_pending_index = _next_runners
					else:
						_bet_waves = ids.duplicate()
					bet_placed.emit()
				if after > 0:
					if meta != null and panel.kind == GateMath.Kind.ADD and panel.value > 0.0:
						after += meta.gate_bonus()
					if perks != null:
						after += perks.recruit_per_gate()
				p_squad.set_count(after)
				_gates_passed += 1
				gate_passed.emit(panel, before, after)
				_spawn_runners(_next_runners, p_squad.count)
				_spawn_flankers(_spec(_gate_level(_next_runners), _gate_index(_next_runners), p_squad.count), p_squad)
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
				p_squad.set_lane(-p_squad.road_half, -0.55)
			else:
				p_squad.set_lane(0.55, p_squad.road_half)
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
		p_squad.set_lane(-p_squad.road_half, p_squad.road_half)
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
		var aim_x := clampf(p_squad.position.x + z.lane_offset, maxf(-road_half + 0.4, z.lane_min), minf(road_half - 0.4, z.lane_max))
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
			var can_cling: bool = Progression.clinging(level) and not (z.brute or z.is_tank()) and not p_squad.is_shielded() and _latched.size() < Progression.MAX_LATCHED
			if can_cling:
				# Clings to a flank and rides along, eating, until shot off.
				z.mark_latched()
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
				bite = _bite(maxi(1, int(Difficulty.brute_bite(p_squad.count, fraction) * p_squad.bite_mult())))
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
	var best := GateMath.best_index(g.panels, squad.count if squad != null else 1)
	var aim_x := g.panel_center_x(best)
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
				boss_engaged.emit()
		Phase.BOSS:
			var walk := BOSS_WALK_SPEED * _pace() * (1.6 if boss_enraged() else 1.0)
			if boss.holds_back():
				boss.position.z = minf(boss.position.z + walk * delta, boss.hold_z())
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
	# Lightning: rings near the squad, then bolts. Move or dash out. The
	# storm calls lines across the road instead: find the gap.
	_strike_timer -= delta * _pace()
	if boss.is_storm():
		if _strike_timer <= 0.0 and boss.position.z > BOSS_ENGAGE_Z - 2.0:
			_strike_timer = Difficulty.STORM_INTERVAL_ENRAGED if enraged else Difficulty.STORM_INTERVAL
			_storm_line(0.0)
			if enraged:
				_storm_line(Difficulty.STORM_SECOND_LINE_DELAY)
	elif _strike_timer <= 0.0 and boss.position.z > BOSS_ENGAGE_Z - 2.0:
		_strike_timer = Difficulty.STRIKE_INTERVAL_ENRAGED if enraged else Difficulty.STRIKE_INTERVAL
		var n := Difficulty.strikes_per_volley(level) + (1 if enraged else 0) + int(mod("strikes"))
		for i in range(n):
			var offset := 0.0 if i == 0 else gen.rng.randf_range(-road_half * 0.7, road_half * 0.7)
			var st := Strike.new()
			st.setup(clampf(p_squad.position.x + p_squad.velocity_x * 0.5 + offset, -road_half, road_half))
			add_child(st)
			_strikes.append(st)
	# Adds: the boss calls runners down the road.
	_adds_timer -= delta * _pace()
	if _adds_timer <= 0.0:
		_adds_timer = Difficulty.BOSS_ADDS_INTERVAL * (0.7 if enraged else 1.0)
		var spec := _spec(level, Difficulty.GATES_PER_LEVEL - 1, p_squad.count)
		for i in range(Difficulty.boss_adds(level)):
			var zb := Zombie.new()
			zb.setup(spec.runner_hp, spec.speed, Zombie.Kind.RUNNER)
			zb.lane_offset = gen.rng.randf_range(-1.0, 1.0)
			zb.lane_min = -road_half + 0.6
			zb.lane_max = road_half - 0.6
			zb.position = Vector3(gen.rng.randf_range(-road_half + 0.6, road_half - 0.6), 0.0, boss.position.z + 1.0)
			add_child(zb)
			zombies.append(zb)
	if boss.is_storm():
		return
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
			var aim := clampf(p_squad.position.x + p_squad.velocity_x * flight * 0.8, -road_half + 0.3, road_half - 0.3)
			var volley := Difficulty.SPIT_VOLLEY if enraged else 1
			for i in range(volley):
				var to_x := clampf(aim + (float(i) - float(volley - 1) * 0.5) * 1.6, -road_half + 0.3, road_half - 0.3)
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
		var bite := _bite(Difficulty.boss_bite(p_squad.count))
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
			var bite := _bite(Difficulty.spit_bite(p_squad.count))
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
				var bite := _bite(Difficulty.strike_bite(p_squad.count))
				p_squad.add(-bite)
				squad_bitten.emit(bite, true)
			strike_landed.emit(st.position, hit)
		if st.done:
			_strikes.erase(st)
			st.queue_free()


## A storm line: bolts across the whole road with one gap, placed
## [param delay] seconds from now. The gap never sits where the squad is
## already standing still, so there is always a move to make.
func _storm_line(delay: float) -> void:
	var gap := gen.rng.randf_range(-road_half + Difficulty.STORM_GAP * 0.5, road_half - Difficulty.STORM_GAP * 0.5)
	if squad != null and absf(gap - squad.position.x) < Difficulty.STORM_GAP * 0.5:
		gap = clampf(squad.position.x + (Difficulty.STORM_GAP if squad.position.x < 0.0 else -Difficulty.STORM_GAP), -road_half + Difficulty.STORM_GAP * 0.5, road_half - Difficulty.STORM_GAP * 0.5)
	for x in Difficulty.storm_line(road_half, gap):
		var st := Strike.new()
		st.setup(x)
		st.delay(delay)
		add_child(st)
		_strikes.append(st)


## The nearest x to [param x] that no warning ring threatens within
## [param dx], scanning the road both ways. Returns x itself when safe.
func safe_x_near(x: float, dx: float) -> float:
	if not strike_threat_at(x, dx):
		return x
	var step := 0.5
	var d := step
	while d <= road_half * 2.0:
		for side in [-1.0, 1.0]:
			var cand: float = x + float(side) * d
			if absf(cand) <= road_half and not strike_threat_at(cand, dx):
				return cand
		d += step
	return x


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


## A wall of cheap zombies: dark bodies, red eyes, spread across the
## widest road. It lives behind the squad and only shows when it moves.
func _build_horde() -> void:
	_horde = Node3D.new()
	var half := Progression.road_half(Progression.MAX_LANES)
	for i in range(18):
		var x := -half + (float(i) + 0.5) * (half * 2.0 / 18.0)
		var zb := Mats.pill(0.3, 0.9, Zombie.SKIN.darkened(0.35))
		zb.position = Vector3(x + randf_range(-0.2, 0.2), 0.75, randf_range(0.0, 1.6))
		_horde.add_child(zb)
		for side in [-1.0, 1.0]:
			var eye := Mats.box(Vector3(0.07, 0.07, 0.05), Zombie.EYE, true)
			eye.position = zb.position + Vector3(side * 0.1, 0.45, -0.28)
			_horde.add_child(eye)
	_horde.position.z = HORDE_REST_Z
	_horde.visible = false
	add_child(_horde)


func _build_dressing() -> void:
	_build_horde()
	_road = Mats.box(Vector3(7.2, 0.2, 260.0), ROAD)
	_road.position = Vector3(0.0, -0.1, -100.0)
	add_child(_road)
	for side in [-1.0, 1.0]:
		var curb := Mats.box(Vector3(0.7, 0.45, 260.0), CURB)
		curb.position = Vector3(side * (road_half + 0.65), 0.1, -100.0)
		add_child(curb)
		_curbs.append(curb)
	# Enough dashed lines for the widest road; unused ones hide under the road.
	for line in range(Progression.MAX_LANES - 1):
		for i in range(26):
			var d := Mats.box(Vector3(0.18, 0.02, 2.4), DASH)
			d.position = Vector3(0.0, -0.5, 6.0 - i * 6.0)
			add_child(d)
			_dashes.append(d)
	_place_dashes(lanes)
	for i in range(16):
		for side in [-1.0, 1.0]:
			var p := Mats.box(Vector3(0.3, 1.4, 0.3), POST)
			p.position = Vector3(side * (road_half + 0.65), 0.9, 8.0 - i * 12.0)
			add_child(p)
			_posts.append(p)


## Lane dividers sit on the boundaries between [param n] lanes; spare
## lines drop below the road.
func _place_dashes(n: int) -> void:
	var lines := n - 1
	for line in range(Progression.MAX_LANES - 1):
		var x := 0.0
		var y := -0.5
		if line < lines:
			x = (float(line) - float(lines - 1) * 0.5) * Progression.LANE_W
			y = 0.01
		for i in range(26):
			var d := _dashes[line * 26 + i]
			d.position.x = x
			d.position.y = y


func _scroll_dressing(delta: float) -> void:
	for d in _dashes:
		d.position.z += world_speed * delta
		if d.position.z > 10.0:
			d.position.z -= 26.0 * 6.0
	for p in _posts:
		p.position.z += world_speed * delta
		if p.position.z > 12.0:
			p.position.z -= 16.0 * 12.0
