class_name Burst
extends Node3D
## A puff of cubes that fly out, fall and vanish. Cheap juice for deaths,
## soldier losses, gate steps and the boss. Self-frees.

const GRAVITY := 16.0

var _bits: Array = []
var _life := 0.5
var _max_life := 0.5


static func spawn(parent: Node, at: Vector3, color: Color, count: int, size: float = 0.14, speed: float = 4.0, life: float = 0.5) -> void:
	var b := Burst.new()
	b._life = life
	b._max_life = life
	b.position = at
	parent.add_child(b)
	for i in range(count):
		var m := Mats.box(Vector3.ONE * size, color, true)
		b.add_child(m)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.5), randf_range(-1.0, 1.0)).normalized()
		b._bits.append({"node": m, "vel": dir * speed * randf_range(0.5, 1.2)})


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var s := clampf(_life / _max_life, 0.0, 1.0)
	for bit in _bits:
		bit.vel.y -= GRAVITY * delta
		var n: Node3D = bit.node
		n.position += bit.vel * delta
		n.scale = Vector3.ONE * s
