class_name Squad
extends Node3D
## The player. Holds the logical soldier count, lays out the visible soldiers,
## steers on drag input and auto-fires down the lane. Rifles fire one tracer
## per shot; shotguns fire three pellets in a fan for more total damage.

signal count_changed(new_count: int)
signal wiped_out

const LANE_HALF := 2.6
const MAX_VISUAL := 36
## Soldiers in the front rings get the detailed build.
const DETAILED := 19
const STEER_LERP := 16.0
const MAX_SHOTS_PER_SECOND := 30.0
const DPS_PER_SOLDIER := 2.5
const SHOTGUN_PELLETS := 3
const SHOTGUN_DAMAGE_MULT := 1.35
const SHOTGUN_SPREAD := 1.6
## Medics trade a little damage for a steady trickle of revived soldiers
## and tougher skin against brutes.
const MEDIC_DAMAGE_MULT := 0.85
const MEDIC_REVIVE_SECONDS := 3.0
const MEDIC_BITE_MULT := 0.75

var count := 1
var target_x := 0.0
var active := false
var world: World
var perks: Perks
var meta: Meta
var squad_type := "rifle"

var _soldiers: Array[Soldier] = []
var _fire_accum := 0.0
var _fire_index := 0
var _revive_timer := 0.0


func reset(start_count: int = 1) -> void:
	target_x = 0.0
	position.x = 0.0
	_fire_accum = 0.0
	for s in _soldiers:
		s.queue_free()
	_soldiers.clear()
	set_count(start_count)


## New level: back to the starting squad where you stand.
func redeploy(start_count: int) -> void:
	_fire_accum = 0.0
	set_count(start_count)


func set_count(n: int) -> void:
	count = maxi(0, n)
	_sync_visuals()
	count_changed.emit(count)
	if count == 0:
		wiped_out.emit()


func add(n: int) -> void:
	set_count(count + n)


## Half-width of the squad's footprint, for deciding whether a zombie that
## reaches z = 0 actually touches anyone or just shambles past.
func reach() -> float:
	return Formation.half_width(mini(count, MAX_VISUAL)) + 0.5


func nudge(dx: float) -> void:
	target_x = clampf(target_x + dx, -LANE_HALF, LANE_HALF)


func is_shotgun() -> bool:
	return squad_type == "shotgun"


func is_medic() -> bool:
	return squad_type == "medic"


## Extra multiplier on what a brute or tank takes.
func bite_mult() -> float:
	return MEDIC_BITE_MULT if is_medic() else 1.0


func _fire_mult() -> float:
	return perks.fire_rate_mult() if perks != null else 1.0


func _damage_mult() -> float:
	var m := meta.damage_mult() if meta != null else 1.0
	if is_shotgun():
		m *= SHOTGUN_DAMAGE_MULT
	elif is_medic():
		m *= MEDIC_DAMAGE_MULT
	return m


## Damage per second of the whole squad. Linear in count by design.
func dps() -> float:
	return float(count) * DPS_PER_SOLDIER * _fire_mult() * _damage_mult()


## Total shots per second. Capped so a huge squad stays cheap to render.
func shots_per_second() -> float:
	return minf(float(count) * DPS_PER_SOLDIER * _fire_mult(), MAX_SHOTS_PER_SECOND)


## Damage per shot rises once the rate cap is hit, so DPS stays linear.
func damage_per_shot() -> float:
	if count <= 0:
		return 0.0
	return dps() / shots_per_second()


func _sync_visuals() -> void:
	var want := mini(count, MAX_VISUAL)
	while _soldiers.size() < want:
		var s := Soldier.new(_soldiers.size() < DETAILED, squad_type)
		add_child(s)
		_soldiers.append(s)
	while _soldiers.size() > want:
		var s: Soldier = _soldiers.pop_back()
		s.queue_free()
	var pos := Formation.positions(want)
	for i in range(want):
		_soldiers[i].target_offset = Vector3(pos[i].x, 0.0, pos[i].y)


func _process(delta: float) -> void:
	position.x = lerpf(position.x, target_x, 1.0 - exp(-STEER_LERP * delta))
	if not active or count == 0 or world == null:
		return
	_fire(delta)
	if is_medic():
		_revive_timer += delta
		if _revive_timer >= MEDIC_REVIVE_SECONDS:
			_revive_timer -= MEDIC_REVIVE_SECONDS
			add(1)


func _fire(delta: float) -> void:
	_fire_accum += delta * shots_per_second()
	while _fire_accum >= 1.0:
		_fire_accum -= 1.0
		if _soldiers.is_empty():
			return
		_fire_index = (_fire_index + 1) % _soldiers.size()
		var s := _soldiers[_fire_index]
		var origin := s.muzzle_world_position()
		if is_shotgun():
			var per := damage_per_shot() / float(SHOTGUN_PELLETS)
			for i in range(SHOTGUN_PELLETS):
				var spread := (float(i) - float(SHOTGUN_PELLETS - 1) * 0.5) * SHOTGUN_SPREAD
				_spawn_bullet(origin, per, spread, 0.9)
		else:
			_spawn_bullet(origin, damage_per_shot(), 0.0, 1.0)
		s.flash()


func _spawn_bullet(origin: Vector3, damage: float, vx: float, size: float) -> void:
	var b := Bullet.new(size * (perks.bullet_radius_mult() if perks != null else 1.0))
	b.damage = damage
	b.vx = vx
	b.world = world
	b.radius_mult = perks.bullet_radius_mult() if perks != null else 1.0
	b.hits_left = 1 + (perks.pierce() if perks != null else 0)
	world.bullets.add_child(b)
	b.global_position = origin
