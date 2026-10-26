class_name Vehicle
extends Node3D
## A convoy vehicle riding with the squad: its own gun, its own health.
## JEEP: a mounted gun, fast straight bullets that pierce. TANK: shells
## that burst on a crowd. Built from primitives; the squad places it,
## the world is asked what the shots hit.

signal destroyed(id: String)
signal ranked(id: String, rank: int)

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
var kills := 0
var rank := 0
var _fire_accum := 0.0
var _turret: Node3D
var _muzzle: Node3D
var _bar: MeshInstance3D
var _wheels: Array[Node3D] = []
var _rotor: Node3D
var _legs: Array[Node3D] = []
var _beam: MeshInstance3D
var _stripes: Array[Node3D] = []
var _recoil := 0.0
var _turret_rest_z := 0.1
const STRIPE := Color(1.0, 0.85, 0.3)


func _init(p_id: String) -> void:
	id = p_id
	var s := Convoy.spec(id)
	max_hp = float(s.hp)
	hp = max_hp
	match id:
		"tank":
			_build_tank()
		"heli":
			_build_heli()
		"mech":
			_build_mech()
		_:
			_build_jeep()
	_turret_rest_z = _turret.position.z
	_bar = Mats.box(Vector3(1.0, 0.08, 0.08), BAR_FG, true)
	_bar.position.y = {"tank": 1.9, "heli": 1.6, "mech": 3.2}.get(id, 1.5)
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


func _build_heli() -> void:
	# Built at ground level; the squad floats it. Fuselage, tail, skids,
	# a rotor that spins.
	var body := Mats.pill(0.42, 1.4, BODY)
	body.rotation_degrees.x = 90.0
	body.position.y = 0.6
	add_child(body)
	var glass := Mats.ball(0.34, Color(0.5, 0.75, 0.9))
	glass.position = Vector3(0.0, 0.7, -0.75)
	glass.scale = Vector3(1.0, 0.8, 0.8)
	add_child(glass)
	var tail := Mats.box(Vector3(0.14, 0.14, 1.4), BODY.darkened(0.1))
	tail.position = Vector3(0.0, 0.75, 1.3)
	add_child(tail)
	var fin := Mats.box(Vector3(0.06, 0.5, 0.3), BODY.darkened(0.2))
	fin.position = Vector3(0.0, 1.0, 1.9)
	add_child(fin)
	for x in [-0.35, 0.35]:
		var skid := Mats.box(Vector3(0.06, 0.06, 1.3), DARK)
		skid.position = Vector3(x, 0.12, 0.0)
		add_child(skid)
	_rotor = Node3D.new()
	_rotor.position.y = 1.15
	add_child(_rotor)
	for a in [0.0, 90.0]:
		var blade := Mats.box(Vector3(3.0, 0.03, 0.14), DARK)
		blade.rotation_degrees.y = a
		_rotor.add_child(blade)
	_turret = Node3D.new()
	_turret.position = Vector3(0.0, 0.35, -0.6)
	add_child(_turret)
	var gun := Mats.box(Vector3(0.1, 0.1, 0.6), DARK)
	gun.position.z = -0.3
	_turret.add_child(gun)
	_muzzle = Node3D.new()
	_muzzle.position.z = -0.6
	_turret.add_child(_muzzle)


func _build_mech() -> void:
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.55, 1.4, 0.0)
		var leg := Mats.pill(0.18, 1.1, DARK)
		leg.position.y = -0.6
		hip.add_child(leg)
		var foot := Mats.box(Vector3(0.5, 0.18, 0.7), DARK)
		foot.position = Vector3(0.0, -1.3, -0.1)
		hip.add_child(foot)
		add_child(hip)
		_legs.append(hip)
	var torso := Mats.box(Vector3(1.4, 1.0, 1.0), BODY)
	torso.position.y = 2.0
	add_child(torso)
	var head := Mats.ball(0.32, STEEL)
	head.position = Vector3(0.0, 2.75, -0.1)
	add_child(head)
	var eye := Mats.box(Vector3(0.4, 0.08, 0.05), Color(1.0, 0.2, 0.2), true)
	eye.position = Vector3(0.0, 2.78, -0.4)
	add_child(eye)
	_turret = Node3D.new()
	_turret.position = Vector3(0.95, 2.05, -0.2)
	add_child(_turret)
	var cannon := Mats.pill(0.16, 1.2, DARK)
	cannon.rotation_degrees.x = 90.0
	cannon.position.z = -0.5
	_turret.add_child(cannon)
	var ring := Mats.torus(0.14, 0.22, Color(1.0, 0.3, 0.25), true)
	ring.rotation_degrees.x = 90.0
	ring.position.z = -1.1
	_turret.add_child(ring)
	_muzzle = Node3D.new()
	_muzzle.position.z = -1.15
	_turret.add_child(_muzzle)
	var shoulder := Mats.box(Vector3(0.6, 0.3, 0.6), STEEL)
	shoulder.position = Vector3(-0.9, 2.5, 0.0)
	add_child(shoulder)
	_beam = Mats.box(Vector3(0.14, 0.14, 1.0), Color(1.0, 0.35, 0.3, 0.9), true)
	_beam.visible = false
	add_child(_beam)


func dps_mult() -> float:
	return Convoy.rank_dps_mult(rank)


## A kill by this vehicle's fire. Enough of them and it ranks up: harder
## hitting, tougher, healed, and a gold stripe.
func note_kill() -> void:
	kills += 1
	var r := Convoy.rank_for(kills)
	if r > rank:
		rank = r
		var s := Convoy.spec(id)
		max_hp = float(s.hp) * Convoy.rank_hp_mult(rank)
		hp = max_hp
		_refresh_bar()
		var stripe := Mats.box(Vector3(0.12, 0.05, 0.4), STRIPE, true)
		stripe.position = Vector3(-0.5 + 0.18 * float(rank), _bar.position.y - 0.25, 0.3)
		add_child(stripe)
		_stripes.append(stripe)
		ranked.emit(id, rank)


func muzzle_world_position() -> Vector3:
	return _muzzle.global_position


## Fire for [param delta] seconds at whatever is ahead. The squad passes
## its world and focus so the jeep leans toward what you are aiming at.
func tick(delta: float, world: World, focus_on: bool, focus_point: Vector3, fire_mult: float = 1.0) -> void:
	if not alive or world == null:
		return
	var s := Convoy.spec(id)
	var dmg := Convoy.damage_per_shot(id) * dps_mult()
	if id == "heli":
		# The helicopter's gun reaches the flank: it chews on clingers.
		world.heli_hit_latched(float(s.cling_dps) * dps_mult() * fire_mult, delta, self)
	_fire_accum += delta * float(s.shots) * fire_mult
	while _fire_accum >= 1.0:
		_fire_accum -= 1.0
		var origin := muzzle_world_position()
		if id == "tank":
			var shell := Shell.new()
			shell.damage = dmg
			shell.splash = float(s.splash)
			shell.world = world
			shell.source = self
			world.bullets.add_child(shell)
			shell.global_position = origin
		else:
			var beam: bool = bool(s.get("beam", false))
			var b := Bullet.new(0.8 if beam else 1.2, Color(1.0, 0.35, 0.3) if beam else Bullet.COLOR, 2.4 if beam else 0.7)
			b.damage = dmg
			b.hits_left = int(s.pierce)
			b.world = world
			b.source = self
			var aim := focus_point if focus_on else Vector3.ZERO
			var aiming := focus_on
			if id == "heli" and not focus_on:
				var pest := world.pest_target(40.0)
				if pest != null:
					aim = pest.position
					aiming = true
			if aiming:
				var dz := maxf(0.5, origin.z - aim.z)
				b.vx = (aim.x - origin.x) / (dz / Bullet.SPEED)
			world.bullets.add_child(b)
			b.global_position = Vector3(origin.x, minf(origin.y, 0.9), origin.z)
		_recoil = 1.0


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_recoil = maxf(_recoil, 0.6)
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
	if _rotor != null:
		_rotor.rotation.y = t * 30.0
		position.y = target_offset.y + sin(t * 2.0) * 0.15
		rotation.z = sin(t * 1.3) * 0.04
	elif not _legs.is_empty():
		for i in range(_legs.size()):
			_legs[i].rotation.x = sin(t * 4.0 + PI * i) * 0.35
		position.y = absf(sin(t * 4.0)) * 0.08
		if _beam != null:
			_beam.visible = _recoil > 0.3
			_beam.position = _turret.position + Vector3(0.0, 0.0, -1.7)
	else:
		position.y = absf(sin(t * 7.0)) * 0.02
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 8.0)
		_turret.position.z = _turret_rest_z + _recoil * (0.25 if id == "tank" else 0.08)
