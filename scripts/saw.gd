class_name Saw
extends Node3D
## A buzz saw loose on the bridge: a toothed disc with a hot edge that
## rolls down the road at you a little faster than the road moves,
## wobbling across its lane. Steer round it or dash through it; touching
## it takes a slice. It cuts zombies too. The world moves it and checks
## the hit; this is the look.

const STEEL := Color(0.55, 0.58, 0.62)
const DARK := Color(0.2, 0.2, 0.22)
const EDGE := Color(1.0, 0.35, 0.15)
const RADIUS := 0.9
## How much faster than the road it comes.
const OWN_SPEED := 3.5
const WOBBLE := 0.7

var base_x := 0.0
var passed := false
## The foreman's throws roll faster than a saw loose on the road.
var own_speed := OWN_SPEED
var _blade: Node3D
var _t := randf() * TAU


func _init() -> void:
	_blade = Node3D.new()
	_blade.rotation_degrees.z = 90.0
	_blade.position.y = RADIUS
	add_child(_blade)
	var disc := Mats.torus(0.25, RADIUS - 0.08, STEEL)
	_blade.add_child(Mats.ink(disc, 0.02))
	var hub := Mats.sphere(0.3, DARK)
	_blade.add_child(hub)
	for i in range(10):
		var a := float(i) * TAU / 10.0
		var tooth := Mats.box(Vector3(0.32, 0.12, 0.3), STEEL)
		tooth.position = Vector3(cos(a) * RADIUS, 0.0, sin(a) * RADIUS)
		tooth.rotation.y = -a
		_blade.add_child(tooth)
	var edge := Mats.torus(RADIUS - 0.02, RADIUS + 0.08, EDGE, true)
	edge.material_override = Mats.glow(EDGE, 1.8)
	_blade.add_child(edge)


func setup(p_x: float, z: float) -> void:
	base_x = p_x
	position = Vector3(p_x, 0.0, z)


## Roll: the road's speed plus its own, spinning, wobbling across the lane.
func tick(delta: float, road_speed: float, road_half: float) -> void:
	_t += delta
	position.z += (road_speed + own_speed) * delta
	position.x = clampf(base_x + sin(_t * 1.3) * WOBBLE, -road_half + 0.6, road_half - 0.6)
	_blade.rotation.y -= delta * 16.0
