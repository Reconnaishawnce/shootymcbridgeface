class_name Squad
extends Node3D
## The player. Holds the logical soldier count, lays out the visible soldiers,
## steers on drag input and auto-fires down the lane.

signal count_changed(new_count: int)
signal wiped_out

const LANE_HALF := 2.6
const MAX_VISUAL := 50
const STEER_LERP := 16.0
const MAX_SHOTS_PER_SECOND := 30.0
const DPS_PER_SOLDIER := 2.5

var count := 1
var target_x := 0.0
var active := false
var world: World

var _soldiers: Array[Soldier] = []
var _fire_accum := 0.0
var _fire_index := 0


func reset() -> void:
	target_x = 0.0
	position.x = 0.0
	_fire_accum = 0.0
	set_count(1)


## New level: back to one soldier where you stand.
func redeploy() -> void:
	_fire_accum = 0.0
	set_count(1)


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


## Damage per second of the whole squad. Linear in count by design.
func dps() -> float:
	return float(count) * DPS_PER_SOLDIER


## Total tracer rate. Capped so a huge squad stays cheap to render.
func shots_per_second() -> float:
	return minf(dps(), MAX_SHOTS_PER_SECOND)


## Damage per tracer rises once the rate cap is hit, so DPS stays linear.
func damage_per_bullet() -> float:
	if count <= 0:
		return 0.0
	return maxf(1.0, dps() / shots_per_second())


func _sync_visuals() -> void:
	var want := mini(count, MAX_VISUAL)
	while _soldiers.size() < want:
		var s := Soldier.new()
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


func _fire(delta: float) -> void:
	_fire_accum += delta * shots_per_second()
	while _fire_accum >= 1.0:
		_fire_accum -= 1.0
		if _soldiers.is_empty():
			return
		_fire_index = (_fire_index + 1) % _soldiers.size()
		var s := _soldiers[_fire_index]
		var b := Bullet.new()
		b.damage = damage_per_bullet()
		b.world = world
		world.bullets.add_child(b)
		b.global_position = s.muzzle_world_position()
		s.flash()
