class_name Soldier
extends Node3D
## One visible squad member. Purely cosmetic: the squad owns the count.

const BODY := Color(0.22, 0.45, 0.85)
const SKIN := Color(0.93, 0.76, 0.6)
const GUN := Color(0.15, 0.15, 0.17)
const MUZZLE := Color(1.0, 0.85, 0.3)

var target_offset := Vector3.ZERO
var _muzzle: MeshInstance3D
var _flash_t := 0.0
var _phase := randf() * TAU


func _init() -> void:
	var body := Mats.capsule(0.22, 0.9, BODY)
	body.position.y = 0.55
	add_child(body)
	var head := Mats.sphere(0.17, SKIN)
	head.position.y = 1.15
	add_child(head)
	var gun := Mats.box(Vector3(0.1, 0.1, 0.6), GUN)
	gun.position = Vector3(0.2, 0.8, -0.25)
	add_child(gun)
	_muzzle = Mats.box(Vector3(0.18, 0.18, 0.25), MUZZLE, true)
	_muzzle.position = Vector3(0.2, 0.8, -0.65)
	_muzzle.visible = false
	add_child(_muzzle)


func muzzle_world_position() -> Vector3:
	return _muzzle.global_position


func flash() -> void:
	_flash_t = 0.06
	_muzzle.visible = true


func _process(delta: float) -> void:
	position = position.lerp(target_offset, 1.0 - exp(-10.0 * delta))
	var t := Time.get_ticks_msec() * 0.001
	position.y = absf(sin(t * 11.0 + _phase)) * 0.08
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_muzzle.visible = false
