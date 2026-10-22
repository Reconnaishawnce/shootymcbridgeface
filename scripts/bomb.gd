class_name Bomb
extends Node3D
## A thrown bomb: arcs from the squad to a point down the road, then the
## world detonates it. Dark ball, lit fuse.

const FLIGHT := 0.55
const RANGE := 13.0
const RADIUS := 5.0
const COLOR := Color(0.12, 0.12, 0.14)
const FUSE := Color(1.0, 0.6, 0.1)

var start := Vector3.ZERO
var target := Vector3.ZERO
var _t := 0.0
var _fuse: MeshInstance3D


func _init() -> void:
	add_child(Mats.sphere(0.32, COLOR))
	_fuse = Mats.box(Vector3(0.1, 0.1, 0.1), FUSE, true)
	_fuse.position.y = 0.38
	add_child(_fuse)


func launch(from: Vector3) -> void:
	start = from
	target = Vector3(from.x, 0.3, from.z - RANGE)
	position = from


func _process(delta: float) -> void:
	_t += delta
	var u := clampf(_t / FLIGHT, 0.0, 1.0)
	position = start.lerp(target, u)
	position.y = start.y + sin(u * PI) * 3.5
	rotation.x -= delta * 10.0
	_fuse.visible = int(_t * 20.0) % 2 == 0


func landed() -> bool:
	return _t >= FLIGHT
