class_name Spit
extends Node3D
## A glob the spitter lobs at the squad. Flies in a high arc toward where
## the squad will be; a red ring on the road marks the landing spot so a
## sharp player can step out of it.

const SPEED := 16.0
const COLOR := Color(0.55, 0.85, 0.25)
const MARK := Color(1.0, 0.2, 0.15, 0.7)

var target_x := 0.0
var start_x := 0.0
var start_z := 0.0
var _travel := 0.0
var _total := 1.0
var _marker: MeshInstance3D


func _init() -> void:
	var m := Mats.sphere(0.32, COLOR)
	m.material_override = Mats.flat(COLOR, true)
	add_child(m)


## [param marker_parent] gets the landing ring, which stays put while the
## glob flies.
func launch(from: Vector3, to_x: float, marker_parent: Node) -> void:
	position = from
	start_x = from.x
	start_z = from.z
	target_x = to_x
	_total = maxf(1.0, -from.z)
	_marker = Mats.torus(0.5, 0.75, MARK, true)
	_marker.position = Vector3(to_x, 0.06, -0.4)
	marker_parent.add_child(_marker)


func flight_time() -> float:
	return _total / SPEED


func _process(delta: float) -> void:
	_travel += SPEED * delta
	var u := clampf(_travel / _total, 0.0, 1.0)
	position.x = lerpf(start_x, target_x, u)
	position.z = lerpf(start_z, -0.4, u)
	position.y = 1.2 + sin(u * PI) * 6.0
	if _marker != null:
		var pulse := 1.0 + 0.25 * sin(_travel * 2.0)
		_marker.scale = Vector3(pulse, 1.0, pulse)


func landed() -> bool:
	return _travel >= _total


func _exit_tree() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
