class_name Bullet
extends Node3D
## A tracer that flies down the lane and asks the world what it hit. Shotgun
## pellets also drift sideways. Piercing bullets survive a kill or two.

const SPEED := 42.0
const LIFETIME := 1.8
const COLOR := Color(1.0, 0.9, 0.35)

var damage := 1.0
var vx := 0.0
var radius_mult := 1.0
var hits_left := 1
var world: World
var prev_z := 0.0
var _age := 0.0


func _init(size: float = 1.0) -> void:
	var m := Mats.box(Vector3(0.09 * size, 0.09 * size, 0.7), COLOR, true)
	add_child(m)


func _ready() -> void:
	prev_z = position.z


func _process(delta: float) -> void:
	prev_z = position.z
	position.z -= SPEED * delta
	position.x += vx * delta
	_age += delta
	if world != null and world.try_hit(self):
		queue_free()
		return
	if _age > LIFETIME:
		queue_free()
