class_name World
extends Node3D
## Owns everything that scrolls past the squad: gates, zombies, road dressing
## and the bullets in flight. The squad stays at z = 0; the world moves +z.

signal gate_passed(panel: GateMath.GatePanel, before: int, after: int)
signal zombie_killed(zombie: Zombie)
signal squad_bitten(bite: int)

const SPAWN_AHEAD := 72.0
const DESPAWN_Z := 12.0
## Hidden panels are revealed when the gate gets this close.
const REVEAL_Z := -20.0
## A zombie that crosses this line reaches the squad.
const BITE_Z := -0.9
const LANE_HALF := 3.0

const ROAD := Color(0.2, 0.2, 0.22)
const CURB := Color(0.55, 0.52, 0.45)
const DASH := Color(0.8, 0.78, 0.6)
const POST := Color(0.35, 0.3, 0.26)

var gates: Array[Gate] = []
var zombies: Array[Zombie] = []
var bullets: Node3D
var gen: Difficulty
## Set by the game so hit resolution can read the squad's damage output.
var squad: Squad

var _distance := 0.0

var _next_gate_at := Difficulty.FIRST_GATE_AT
var _next_wave_at := Difficulty.FIRST_GATE_AT + Difficulty.WAVE_OFFSET
var _dashes: Array[Node3D] = []
var _posts: Array[Node3D] = []


func _init() -> void:
	bullets = Node3D.new()
	add_child(bullets)
	_build_dressing()


func reset(seed_value: int) -> void:
	gen = Difficulty.new(seed_value)
	_next_gate_at = Difficulty.FIRST_GATE_AT
	_next_wave_at = Difficulty.FIRST_GATE_AT + Difficulty.WAVE_OFFSET
	for g in gates:
		g.queue_free()
	gates.clear()
	for z in zombies:
		z.queue_free()
	zombies.clear()
	for b in bullets.get_children():
		b.queue_free()


func advance(delta: float, world_speed: float, distance: float, squad: Squad) -> void:
	_distance = distance
	_spawn(distance)
	_scroll_dressing(delta, world_speed)
	_move_gates(delta, world_speed, squad)
	_move_zombies(delta, world_speed, squad)


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
	for z in zombies:
		if z.position.z < z_lo or z.position.z > z_hi:
			continue
		if absf(z.position.x - b.position.x) > z.radius:
			continue
		if z.take_damage(b.damage):
			zombies.erase(z)
			zombie_killed.emit(z)
			z.die()
		return true
	for g in gates:
		if g.passed or g.position.z < z_lo or g.position.z > z_hi:
			continue
		var i := g.panel_index_at_x(b.position.x)
		if i >= 0:
			var cost := Difficulty.effective_step_cost(_distance, squad.dps() if squad != null else 0.0)
			g.register_hit(i, b.damage, cost)
			return true
	return false


func _spawn(distance: float) -> void:
	while _next_gate_at - distance <= SPAWN_AHEAD:
		var pair := gen.make_gate_pair(_next_gate_at, squad.count if squad != null else 1)
		var g := Gate.new()
		g.setup(pair[0], pair[1])
		g.position = Vector3(0.0, 0.0, -(_next_gate_at - distance))
		add_child(g)
		gates.append(g)
		_next_gate_at += Difficulty.GATE_SPACING
	while _next_wave_at - distance <= SPAWN_AHEAD:
		_spawn_wave(_next_wave_at, distance)
		_next_wave_at += Difficulty.GATE_SPACING


func _spawn_wave(at: float, distance: float) -> void:
	var spec := Difficulty.wave_for(at, squad.count if squad != null else 1)
	var base_z := -(at - distance)
	for i in range(spec.count):
		_spawn_zombie(spec, base_z - gen.rng.randf_range(0.0, 7.0), false)
	for i in range(spec.brutes):
		_spawn_zombie(spec, base_z - gen.rng.randf_range(4.0, 9.0), true)


func _spawn_zombie(spec: Dictionary, z: float, brute: bool) -> void:
	var zb := Zombie.new()
	zb.setup(spec.brute_hp if brute else spec.hp, spec.speed, brute)
	zb.lane_offset = gen.rng.randf_range(-1.1, 1.1)
	zb.position = Vector3(gen.rng.randf_range(-LANE_HALF + 0.8, LANE_HALF - 0.8), 0.0, z)
	add_child(zb)
	zombies.append(zb)


func _move_gates(delta: float, world_speed: float, squad: Squad) -> void:
	for g in gates.duplicate():
		g.position.z += world_speed * delta
		if not g.passed:
			if g.position.z >= REVEAL_Z:
				g.reveal_all()
			if g.position.z >= 0.0:
				var index := 0 if squad.position.x < 0.0 else 1
				var panel: GateMath.GatePanel = g.choose(index)
				var before := squad.count
				var after := GateMath.apply(before, panel)
				squad.set_count(after)
				gate_passed.emit(panel, before, after)
		if g.position.z > DESPAWN_Z:
			gates.erase(g)
			g.queue_free()


func _move_zombies(delta: float, world_speed: float, squad: Squad) -> void:
	for z in zombies.duplicate():
		z.position.z += (world_speed + z.speed) * delta
		var aim_x := clampf(squad.position.x + z.lane_offset, -LANE_HALF + 0.4, LANE_HALF - 0.4)
		z.position.x = move_toward(z.position.x, aim_x, z.homing * delta)
		if z.position.z >= BITE_Z and absf(z.position.x - squad.position.x) <= squad.reach() + z.radius:
			zombies.erase(z)
			z.consume()
			var bite: int = Difficulty.brute_bite(squad.count) if z.brute else z.bite
			squad.add(-bite)
			squad_bitten.emit(bite)
		elif z.position.z > DESPAWN_Z:
			zombies.erase(z)
			z.queue_free()


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


func _scroll_dressing(delta: float, world_speed: float) -> void:
	for d in _dashes:
		d.position.z += world_speed * delta
		if d.position.z > 10.0:
			d.position.z -= 26.0 * 6.0
	for p in _posts:
		p.position.z += world_speed * delta
		if p.position.z > 12.0:
			p.position.z -= 16.0 * 12.0
