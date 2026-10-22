class_name Spit
extends Node3D
## A glob the spitter lobs at the squad. Flies in an arc toward where the
## squad was when it launched; the world checks whether it lands on anyone.

const SPEED := 9.0
const COLOR := Color(0.55, 0.85, 0.25)

var target_x := 0.0
var start_x := 0.0
var start_z := 0.0
var _travel := 0.0
var _total := 1.0


func _init() -> void:
	var m := Mats.sphere(0.32, COLOR)
	m.material_override = Mats.flat(COLOR, true)
	add_child(m)


func launch(from: Vector3, to_x: float) -> void:
	position = from
	start_x = from.x
	start_z = from.z
	target_x = to_x
	_total = maxf(1.0, -from.z)


func _process(delta: float) -> void:
	_travel += SPEED * delta
	var u := clampf(_travel / _total, 0.0, 1.0)
	position.x = lerpf(start_x, target_x, u)
	position.z = lerpf(start_z, 0.0, u)
	position.y = 1.2 + sin(u * PI) * 4.5


func landed() -> bool:
	return _travel >= _total
