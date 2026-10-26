class_name Vehicle
extends Node3D
## A convoy vehicle riding with the squad: its own gun, its own health.
## JEEP: a mounted gun, fast straight bullets that pierce. TANK: shells
## that burst on a crowd. Built from primitives; the squad places it,
## the world is asked what the shots hit.

signal destroyed(id: String)

const BODY := Color(0.42, 0.45, 0.32)
const DARK := Color(0.18, 0.18, 0.16)
const STEEL := Color(0.55, 0.57, 0.6)
const BAR_BG := Color(0.1, 0.1, 0.1)
const BAR_FG := Color(0.4, 0.85, 1.0)

var id := "jeep"
var hp := 60.0
var max_hp := 60.0
var alive := true
var target_offset := Vector3.ZERO
var _fire_accum := 0.0
var _turret: Node3D
var _muzzle: Node3D
var _bar: MeshInstance3D
var _wheels: Array[Node3D] = []
var _recoil := 0.0


func _init(p_id: String) -> void:
	id = p_id
	var s := Convoy.spec(id)
	max_hp = float(s.hp)
	hp = max_hp
	if id == "tank":
		_build_tank()
	else:
		_build_jeep()
	_bar = Mats.box(Vector3(1.0, 0.08, 0.08), BAR_FG, true)
	_bar.position.y = 1.9 if id == "tank" else 1.5
	add_child(_bar)
	var bg := Mats.box(Vector3(1.04, 0.1, 0.1), BAR_BG, true)
	bg.position = _bar.position + Vector3(0.0, 0.0, 0.02)
	add_child(bg)
	_refresh_bar()


func _build_jeep() -> void:
	var body := Mats.box(Vector3(0.9, 0.4, 1.5), BODY)
	body.position.y = 0.5
	add_child(body)
	var hood := Mats.box(Vector3(0.8, 0.2, 0.5), BODY.darkened(0.15))
	hood.position = Vector3(0.0, 0.72, -0.45)
	add_child(hood)
	var cab := Mats.box(Vector3(0.7, 0.3, 0.5), DARK)
	cab.position = Vector3(0.0, 0.85, 0.2)
	add_child(cab)
	for x in [-0.45, 0.45]:
		for z in [-0.5, 0.5]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.26, z)
			var tyre := Mats.torus(0.12, 0.26, DARK)
			tyre.rotation_degrees.z = 90.0
			w.add_child(tyre)
			add_child(w)
			_wheels.append(w)
	_turret = Node3D.new()
	_turret.position = Vector3(0.0, 1.05, 0.1)
	add_child(_turret)
	var mount := Mats.capsule(0.06, 0.3, STEEL)
	mount.position.y = -0.1
	_turret.add_child(mount)
	var gun := Mats.box(Vector3(0.1, 0.1, 0.9), DARK)
	gun.position = Vector3(0.0, 0.08, -0.35)
	_turret.add_child(gun)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.08, -0.85)
	_turret.add_child(_muzzle)


func _build_tank() -> void:
	var hull := Mats.box(Vector3(1.5, 0.55, 2.3), BODY)
	hull.position.y = 0.55
	add_child(hull)
	for x in [-0.8, 0.8]:
		var track := Mats.box(Vector3(0.35, 0.5, 2.4), DARK)
		track.position = Vector3(x, 0.35, 0.0)
		add_child(track)
	_turret = Node3D.new()
	_turret.position = Vector3(0.0, 1.0, 0.1)
	add_child(_turret)
	var dome := Mats.ball(0.55, BODY.darkened(0.1))
	dome.scale = Vector3(1.0, 0.6, 1.0)
	_turret.add_child(dome)
	var barrel := Mats.capsule(0.09, 1.7, DARK)
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.15, -1.0)
	_turret.add_child(barrel)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.15, -1.9)
	_turret.add_child(_muzzle)


func muzzle_world_position() -> Vector3:
	return _muzzle.global_position


## Fire for [param delta] seconds at whatever is ahead. The squad passes
## its world and focus so the jeep leans toward what you are aiming at.
func tick(delta: float, world: World, focus_on: bool, focus_point: Vector3) -> void:
	if not alive or world == null:
		return
	var s := Convoy.spec(id)
	_fire_accum += delta * float(s.shots)
	while _fire_accum >= 1.0:
		_fire_accum -= 1.0
		var origin := muzzle_world_position()
		if id == "tank":
			var shell := Shell.new()
			shell.damage = Convoy.damage_per_shot(id)
			shell.splash = float(s.splash)
			shell.world = world
			world.bullets.add_child(shell)
			shell.global_position = origin
		else:
			var b := Bullet.new(1.2)
			b.damage = Convoy.damage_per_shot(id)
			b.hits_left = int(s.pierce)
			b.world = world
			if focus_on:
				var dz := maxf(0.5, origin.z - focus_point.z)
				b.vx = (focus_point.x - origin.x) / (dz / Bullet.SPEED)
			world.bullets.add_child(b)
			b.global_position = origin
		_recoil = 1.0


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_refresh_bar()
	if hp <= 0.0:
		alive = false
		destroyed.emit(id)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.35)
		tw.tween_callback(queue_free)


func _refresh_bar() -> void:
	var f := clampf(hp / max_hp, 0.0, 1.0)
	_bar.scale.x = maxf(f, 0.01)
	_bar.position.x = -(1.0 - f) * 0.5
	_bar.visible = f < 0.999


func _process(delta: float) -> void:
	position = position.lerp(target_offset, 1.0 - exp(-6.0 * delta))
	var t := Time.get_ticks_msec() * 0.001
	for w in _wheels:
		w.rotation.x = t * 9.0
	position.y = absf(sin(t * 7.0)) * 0.02
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 8.0)
		_turret.position.z = (0.1 if id != "tank" else 0.1) + _recoil * (0.25 if id == "tank" else 0.08)
