class_name Boss
extends Node3D
## The level's wall. Huge, slow, spiked, red-eyed, and it chews through the
## squad once it arrives. Its glowing core sways side to side; bullets
## through the core deal [member core_mult] damage, so tracking it with your
## steering is the skill.

const BODY_RADIUS := 1.7
const CORE_RADIUS := 0.42
const CORE_MULT := 3.0
const CORE_SWAY := 1.1
const CORE_SPEED := 1.6

const SKIN := Color(0.55, 0.3, 0.28)
const DARK := Color(0.3, 0.16, 0.15)
const CORE_COLOR := Color(1.0, 0.85, 0.2)
const EYE := Color(1.0, 0.15, 0.1)

var hp := 100.0
var max_hp := 100.0
var alive := true
var core_x := 0.0
var core_mult := CORE_MULT

var _body: Node3D
var _core: MeshInstance3D
var _ring: MeshInstance3D
var _legs: Array[Node3D] = []
var _hit_t := 0.0
var _phase := randf() * TAU


func _init() -> void:
	_body = Node3D.new()
	add_child(_body)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.55, 1.1, 0.0)
		var leg := Mats.capsule(0.32, 1.0, DARK)
		leg.position.y = -0.5
		hip.add_child(leg)
		_body.add_child(hip)
		_legs.append(hip)
	var torso := Mats.capsule(1.0, 2.4, SKIN)
	torso.position.y = 2.2
	_body.add_child(torso)
	for side in [-1.0, 1.0]:
		var plate := Mats.box(Vector3(0.9, 0.35, 0.9), DARK)
		plate.position = Vector3(side * 1.15, 3.0, 0.0)
		plate.rotation_degrees.z = side * -12.0
		_body.add_child(plate)
		var arm := Mats.capsule(0.3, 1.8, SKIN)
		arm.position = Vector3(side * 1.3, 2.1, 0.4)
		arm.rotation_degrees = Vector3(70.0, 0.0, side * 15.0)
		_body.add_child(arm)
		var fist := Mats.sphere(0.38, DARK)
		fist.position = Vector3(side * 1.3, 1.55, 1.2)
		_body.add_child(fist)
	var head := Mats.sphere(0.55, SKIN)
	head.position = Vector3(0.0, 3.75, 0.2)
	_body.add_child(head)
	var jaw := Mats.box(Vector3(0.7, 0.25, 0.5), DARK)
	jaw.position = Vector3(0.0, 3.45, 0.5)
	_body.add_child(jaw)
	for side in [-1.0, 1.0]:
		var eye := Mats.sphere(0.1, EYE)
		eye.material_override = Mats.flat(EYE, true)
		eye.position = Vector3(side * 0.22, 3.85, 0.68)
		_body.add_child(eye)
	for i in range(3):
		var spike := Mats.cone(0.22, 0.9, DARK)
		spike.position = Vector3(0.0, 2.3 + i * 0.55, -0.85 + i * 0.1)
		spike.rotation_degrees.x = -40.0 + i * 10.0
		_body.add_child(spike)
	_ring = Mats.torus(0.42, 0.56, CORE_COLOR.darkened(0.35), true)
	_ring.position = Vector3(0.0, 1.9, 1.02)
	_ring.rotation_degrees.x = 90.0
	_body.add_child(_ring)
	_core = Mats.sphere(0.4, CORE_COLOR)
	_core.material_override = Mats.flat(CORE_COLOR, true)
	_core.position = Vector3(0.0, 1.9, 1.05)
	_body.add_child(_core)


func setup(p_hp: float) -> void:
	max_hp = p_hp
	hp = p_hp


func is_core_hit(x: float) -> bool:
	return absf(x - (global_position.x + core_x)) <= CORE_RADIUS


## Returns true when this hit killed the boss.
func take_damage(amount: float, is_core: bool) -> bool:
	if not alive:
		return false
	hp -= amount * (core_mult if is_core else 1.0)
	_hit_t = 1.0
	return hp <= 0.0


func die() -> void:
	alive = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4), 0.3)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if not alive:
		return
	var t := Time.get_ticks_msec() * 0.001
	core_x = sin(t * CORE_SPEED + _phase) * CORE_SWAY
	_core.position.x = core_x
	_ring.position.x = core_x
	_core.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 9.0))
	_body.rotation.z = sin(t * 2.5) * 0.06
	_body.position.y = absf(sin(t * 2.5)) * 0.12
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t * 2.5 + PI * i) * 0.35
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - delta * 10.0)
		_body.scale = Vector3.ONE * (1.0 + 0.06 * _hit_t)
