class_name Shell
extends Node3D
## A tank shell: flies down the road and bursts on the first zombie in
## its path, or at the end of its range. The world resolves the burst.

const SPEED := 26.0
const RANGE := 34.0
const COLOR := Color(0.35, 0.38, 0.3)
const TRAIL := Color(1.0, 0.7, 0.3)

var damage := 50.0
var splash := 1.9
var world: World
var source: Node = null
var _travelled := 0.0


func _init() -> void:
	var body := Mats.capsule(0.12, 0.5, COLOR)
	body.rotation_degrees.x = 90.0
	add_child(body)
	var trail := Mats.box(Vector3(0.08, 0.08, 0.6), TRAIL, true)
	trail.position.z = 0.5
	add_child(trail)


func _process(delta: float) -> void:
	var step := SPEED * delta
	position.z -= step
	_travelled += step
	position.y = 0.6 + sin(minf(_travelled / RANGE, 1.0) * PI) * 1.2
	if world == null:
		return
	if world.shell_should_burst(self) or _travelled >= RANGE:
		# The tank may have been wrecked while the shell was in the air.
		world.explode_at(Vector3(position.x, 0.0, position.z), splash, damage, source if is_instance_valid(source) else null)
		queue_free()
