class_name Bullet
extends Node3D
## A tracer that flies down the lane and asks the world what it hit. Shotgun
## pellets also drift sideways. Piercing bullets survive a kill or two.

## Metres a second. Set by the world each level (Difficulty.bullet_speed):
## slow enough to watch on the first levels, a streak later.
static var speed := 42.0
## How far a bullet flies before it is gone, whatever its speed.
const RANGE := 66.0
const COLOR := Color(1.0, 0.9, 0.35)
## A DEAD EYE shot: red, fat, triple.
const CRIT_COLOR := Color(1.0, 0.3, 0.25)

var damage := 1.0
var vx := 0.0
var radius_mult := 1.0
var hits_left := 1
var world: World
var prev_z := 0.0
## The vehicle that fired it, if any: kills count toward its rank.
var source: Node = null
var _age := 0.0


var hits_left_bonus := 0


func _init(size: float = 1.0, color: Color = COLOR, length: float = 0.95) -> void:
	# Fat tracers: a bright head and a long streak behind it.
	var m := Mats.box(Vector3(0.12 * size, 0.12 * size, length), color, true)
	m.material_override = Mats.glow(color, 2.8)
	add_child(m)
	var tail := Mats.box(Vector3(0.065 * size, 0.065 * size, length * 1.9), Color(color.r, color.g, color.b, 0.45), true)
	tail.material_override = Mats.glow(Color(color.r, color.g, color.b, 0.45), 1.8)
	tail.position.z = length * 1.3
	add_child(tail)


func _ready() -> void:
	prev_z = position.z


func _process(delta: float) -> void:
	prev_z = position.z
	position.z -= speed * delta
	position.x += vx * delta
	_age += delta
	if world != null and world.try_hit(self):
		queue_free()
		return
	if _age * speed > RANGE:
		queue_free()
