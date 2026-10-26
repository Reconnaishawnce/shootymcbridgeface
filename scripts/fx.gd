class_name Fx
extends RefCounted
## Particles, built on CPUParticles3D so they run on the Compatibility
## renderer and on phones. One-shot puffs that free themselves, and a
## continuous emitter for dust under the convoy.

const BLOOD := Color(0.45, 0.08, 0.1)
const DUST := Color(0.62, 0.55, 0.45, 0.7)
const SMOKE := Color(0.35, 0.35, 0.38, 0.6)
const SPARK := Color(1.0, 0.8, 0.35)


static func _mesh(size: float, color: Color, glow: bool = false) -> Mesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Mats.glow(color, 2.0) if glow else Mats.soft(color)
	return m


static func _one_shot(parent: Node, at: Vector3, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.local_coords = false
	parent.add_child(p)
	p.global_position = at
	var tw := p.create_tween()
	tw.tween_interval(life + 0.2)
	tw.tween_callback(p.queue_free)
	return p


## A splash of dark red when a zombie dies.
static func blood(parent: Node, at: Vector3, big: bool = false) -> void:
	var p := _one_shot(parent, at, 14 if big else 8, 0.55)
	p.mesh = _mesh(0.11 if big else 0.08, BLOOD)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5 if big else 5.0
	p.gravity = Vector3(0.0, -18.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2


## A puff of dust: a soldier down, a shell landing, a vehicle wrecked.
static func dust(parent: Node, at: Vector3, amount: int = 10, size: float = 0.25) -> void:
	var p := _one_shot(parent, at, amount, 0.7)
	p.mesh = _mesh(size, DUST)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 85.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, -1.5, 0.0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.scale_amount_curve = _grow()


## Sparks: a shell burst, a boss core hit, a vehicle rank.
static func sparks(parent: Node, at: Vector3, amount: int = 12) -> void:
	var p := _one_shot(parent, at, amount, 0.4)
	p.mesh = _mesh(0.06, SPARK, true)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0.0, -9.0, 0.0)


## Smoke that rises and fades: muzzle puffs, wrecks.
static func smoke(parent: Node, at: Vector3, amount: int = 6) -> void:
	var p := _one_shot(parent, at, amount, 0.9)
	p.mesh = _mesh(0.16, SMOKE)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 30.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.scale_amount_curve = _grow()


## Dust kicked up behind a vehicle, as long as it exists.
static func trail(parent: Node3D, offset: Vector3, size: float = 0.22) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.7
	p.local_coords = false
	p.mesh = _mesh(size, DUST)
	p.direction = Vector3(0.0, 0.6, 1.0)
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0.0, -0.8, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _grow()
	p.position = offset
	parent.add_child(p)
	return p


static func _grow() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c
