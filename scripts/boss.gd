class_name Boss
extends Node3D
## The level's wall. Huge, slow, and it chews through the squad once it
## arrives. Its glowing core sways side to side; bullets through the core
## deal CORE_MULT damage, so tracking it with your steering is the skill.

const BODY_RADIUS := 1.7
const CORE_RADIUS := 0.42
const CORE_MULT := 3.0
const CORE_SWAY := 1.1
const CORE_SPEED := 1.6

const SKIN := Color(0.55, 0.3, 0.28)
const CORE_COLOR := Color(1.0, 0.85, 0.2)

var hp := 100.0
var max_hp := 100.0
var alive := true
var core_x := 0.0

var _body: Node3D
var _core: MeshInstance3D
var _hit_t := 0.0
var _phase := randf() * TAU


func _init() -> void:
	_body = Node3D.new()
	add_child(_body)
	var torso := Mats.capsule(1.0, 2.6, SKIN)
	torso.position.y = 1.8
	_body.add_child(torso)
	var head := Mats.sphere(0.55, SKIN)
	head.position.y = 3.5
	_body.add_child(head)
	for side in [-1.0, 1.0]:
		var arm := Mats.capsule(0.3, 1.8, SKIN)
		arm.position = Vector3(side * 1.25, 1.9, 0.3)
		arm.rotation_degrees = Vector3(70.0, 0.0, side * 15.0)
		_body.add_child(arm)
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
	hp -= amount * (CORE_MULT if is_core else 1.0)
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
	_core.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 9.0))
	_body.rotation.z = sin(t * 2.5) * 0.06
	_body.position.y = absf(sin(t * 2.5)) * 0.12
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - delta * 10.0)
		_body.scale = Vector3.ONE * (1.0 + 0.06 * _hit_t)
