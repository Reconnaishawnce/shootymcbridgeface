class_name Bullet
extends Node3D
## A tracer that flies straight down the lane and asks the world what it hit.

const SPEED := 42.0
const LIFETIME := 1.8
const COLOR := Color(1.0, 0.9, 0.35)

var damage := 1.0
var world: World
var prev_z := 0.0
var _age := 0.0


func _init() -> void:
	var m := Mats.box(Vector3(0.09, 0.09, 0.7), COLOR, true)
	add_child(m)


func _ready() -> void:
	prev_z = position.z


func _process(delta: float) -> void:
	prev_z = position.z
	position.z -= SPEED * delta
	_age += delta
	if world != null and world.try_hit(self):
		queue_free()
		return
	if _age > LIFETIME:
		queue_free()
