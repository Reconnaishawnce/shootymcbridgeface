class_name Turret
extends Node3D
## A gold turret on the curb beside the road: it keeps pace with the
## squad and fires on its own at the nearest zombie in range. Bought
## with bounty at the pit stop or a supply panel; it lasts the run and
## its fire does not count against the squad's cap, so it is the one
## purchase that makes a big squad hit harder.

const GOLD := Color(1.0, 0.78, 0.2)
const GOLD_DARK := Color(0.75, 0.5, 0.1)
const STEEL := Color(0.25, 0.26, 0.3)
const TRACER := Color(1.0, 0.85, 0.3)

var side := 1
var dps := 14.0
var shots_per_second := 4.0
var range_z := 30.0
var world: World
var _head: Node3D
var _muzzles: Array[Node3D] = []
var _flash: MeshInstance3D
var _accum := 0.0
var _flash_t := 0.0
var _target_x := 0.0


func setup(p_side: int, p_dps: float) -> void:
	side = p_side
	dps = p_dps
	# The base: a gold drum with a dark band, on a steel plate.
	var plate := Mats.box(Vector3(1.3, 0.12, 1.3), STEEL)
	plate.position.y = 0.06
	Mats.ink(plate, 0.02)
	add_child(plate)
	var drum := Mats.torus(0.3, 0.55, GOLD)
	drum.position.y = 0.3
	drum.scale.y = 1.6
	Mats.ink(drum, 0.02)
	add_child(drum)
	var band := Mats.torus(0.5, 0.58, GOLD_DARK)
	band.position.y = 0.3
	band.scale.y = 0.6
	add_child(band)
	# The head: a gold box with twin barrels, turning to face its target.
	_head = Node3D.new()
	_head.position.y = 0.78
	add_child(_head)
	var box := Mats.box(Vector3(0.7, 0.42, 0.8), GOLD)
	Mats.ink(box, 0.02)
	_head.add_child(box)
	var visor := Mats.box(Vector3(0.5, 0.14, 0.1), STEEL)
	visor.position = Vector3(0.0, 0.08, -0.42)
	_head.add_child(visor)
	for bx in [-0.18, 0.18]:
		var barrel := Mats.pill(0.06, 0.9, STEEL)
		barrel.rotation_degrees.x = 90.0
		barrel.position = Vector3(bx, -0.02, -0.75)
		_head.add_child(barrel)
		var m := Node3D.new()
		m.position = Vector3(bx, -0.02, -1.2)
		_head.add_child(m)
		_muzzles.append(m)
	_flash = Mats.box(Vector3(0.5, 0.5, 0.08), TRACER, true)
	_flash.material_override = Mats.glow(TRACER, 3.0)
	_flash.position = Vector3(0.0, -0.02, -1.25)
	_flash.visible = false
	_head.add_child(_flash)
	var cap := Mats.ball(0.14, Color(1.0, 0.95, 0.6))
	cap.material_override = Mats.glow(Color(1.0, 0.95, 0.6), 1.8)
	cap.position.y = 0.3
	_head.add_child(cap)
	scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Where it stands: on the curb on its side, a few metres ahead of the
## squad, where the camera can see it (the walkway beyond is off screen
## at the squad's own depth).
const AHEAD_Z := -4.0


func stand_x(road_half: float) -> float:
	return float(side) * (road_half + 0.8)


func _process(delta: float) -> void:
	if world == null:
		return
	position.x = lerpf(position.x, stand_x(world.road_half), 1.0 - exp(-6.0 * delta))
	var target: Zombie = world.nearest_zombie_for_turret(range_z)
	if target != null:
		_target_x = target.position.x
		var to := target.position - global_position
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
	else:
		_head.rotation.y = lerp_angle(_head.rotation.y, 0.0, 1.0 - exp(-3.0 * delta))
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	if target == null or world.frozen:
		_accum = 0.0
		return
	_accum += delta * shots_per_second
	var k := 0
	while _accum >= 1.0 and k < 3:
		_accum -= 1.0
		k += 1
		_shoot(target)


func _shoot(target: Zombie) -> void:
	var m: Node3D = _muzzles[k_pick()]
	var origin := m.global_position
	var b := Bullet.new(0.9, TRACER, 0.8)
	b.damage = dps / shots_per_second
	var dz := maxf(0.5, origin.z - target.position.z)
	b.vx = (target.position.x - origin.x) / (dz / Bullet.SPEED)
	b.world = world
	b.hits_left = 1
	world.bullets.add_child(b)
	b.global_position = origin
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash_t = 0.05


var _pick := 0


func k_pick() -> int:
	_pick = (_pick + 1) % _muzzles.size()
	return _pick
