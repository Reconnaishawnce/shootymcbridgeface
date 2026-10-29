class_name Spit
extends Node3D
## A glob the spitter lobs at the squad. Flies in a high arc toward where
## the squad will be; a red ring on the road marks the landing spot so a
## sharp player can step out of it.

const SPEED := 13.0
const COLOR := Color(0.55, 0.85, 0.25)
const MARK := Color(1.0, 0.2, 0.15, 0.7)
const SHADOW := Color(0.05, 0.08, 0.02, 0.55)
## How far from the glob's landing spot the splash reaches.
const SPLASH := 0.5

var target_x := 0.0
var start_x := 0.0
var start_z := 0.0
var _travel := 0.0
var _total := 1.0
var _marker: MeshInstance3D
var _shadow: MeshInstance3D


func _init() -> void:
	# Big, bright and trailing a tail: you see it leave the boss.
	var m := Mats.sphere(0.42, COLOR)
	m.material_override = Mats.glow(COLOR, 1.5)
	add_child(m)
	for i in range(3):
		var bead := Mats.sphere(0.26 - float(i) * 0.06, COLOR)
		bead.material_override = Mats.glow(Color(COLOR.r, COLOR.g, COLOR.b, 0.7 - float(i) * 0.2), 1.2)
		bead.position = Vector3(0.0, 0.25 + float(i) * 0.3, -0.35 - float(i) * 0.4)
		add_child(bead)


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
	# A shadow on the road under the glob: where it is and how high.
	_shadow = Mats.sphere(0.5, SHADOW)
	_shadow.material_override = Mats.glow(SHADOW, 0.0)
	_shadow.scale = Vector3(1.0, 0.04, 1.0)
	marker_parent.add_child(_shadow)


func flight_time() -> float:
	return _total / SPEED


func _process(delta: float) -> void:
	_travel += SPEED * delta
	var u := clampf(_travel / _total, 0.0, 1.0)
	position.x = lerpf(start_x, target_x, u)
	position.z = lerpf(start_z, -0.4, u)
	position.y = 1.2 + sin(u * PI) * 6.0
	if _marker != null:
		# The ring closes in as the glob comes down: the timing reads.
		var pulse := 1.0 + 0.2 * sin(_travel * 3.0)
		var close := lerpf(1.9, 1.0, u)
		_marker.scale = Vector3(pulse * close, 1.0, pulse * close)
	if _shadow != null:
		_shadow.position = Vector3(position.x, 0.04, position.z)
		var s := clampf(1.3 - position.y / 9.0, 0.5, 1.3)
		_shadow.scale = Vector3(s, 0.04, s)


func landed() -> bool:
	return _travel >= _total


func _exit_tree() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.queue_free()
