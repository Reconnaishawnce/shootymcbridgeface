class_name Strike
extends Node3D
## Boss lightning. A red ring warns on the road for STRIKE_WARNING seconds,
## then a bolt lands: a bright column, a flash, and anyone inside loses a
## slice. The world checks the hit; this is the look and the clock.

const RING := Color(1.0, 0.25, 0.15, 0.75)
const BOLT := Color(1.0, 1.0, 0.75)

var x := 0.0
var fired := false
var done := false
var _age := 0.0
var _ring: MeshInstance3D
var _bolt: MeshInstance3D


func setup(p_x: float) -> void:
	x = p_x
	position = Vector3(x, 0.05, -0.4)
	_ring = Mats.torus(Difficulty.STRIKE_RADIUS - 0.2, Difficulty.STRIKE_RADIUS + 0.05, RING, true)
	add_child(_ring)
	_bolt = Mats.box(Vector3(0.22, 9.0, 0.22), BOLT, true)
	_bolt.position.y = 4.5
	_bolt.visible = false
	add_child(_bolt)


## Hold the ring back for [param seconds] before the warning starts.
func delay(seconds: float) -> void:
	_age = -seconds
	_ring.visible = seconds <= 0.0


## True on the single frame the bolt lands.
func tick(delta: float) -> bool:
	_age += delta
	if _age < 0.0:
		return false
	_ring.visible = not fired
	if not fired:
		var u := clampf(_age / Difficulty.STRIKE_WARNING, 0.0, 1.0)
		var pulse := 1.0 + 0.3 * sin(_age * 18.0 * (0.5 + u))
		_ring.scale = Vector3(pulse, 1.0, pulse)
		if _age >= Difficulty.STRIKE_WARNING:
			fired = true
			_ring.visible = false
			_bolt.visible = true
			return true
		return false
	if _age >= Difficulty.STRIKE_WARNING + 0.18:
		done = true
	else:
		_bolt.scale = Vector3(1.0 + sin(_age * 60.0) * 0.4, 1.0, 1.0)
	return false
