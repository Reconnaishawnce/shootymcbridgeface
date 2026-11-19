class_name Fx
extends RefCounted
## Particles, built on CPUParticles3D so they run on the Compatibility
## renderer and on phones. One-shot puffs that free themselves, and a
## continuous emitter for dust under the convoy.

const BLOOD := Color(0.45, 0.08, 0.1)
const DUST := Color(0.62, 0.55, 0.45, 0.7)
const SMOKE := Color(0.35, 0.35, 0.38, 0.6)
const SPARK := Color(1.0, 0.8, 0.35)
## One-shot systems alive at once; past this a puff is skipped. A busy
## screen on a weak phone is where freezes were reported.
const MAX_LIVE := 36
static var live := 0
## The most alive at once this session, for the smoke bot's counters.
static var live_peak := 0


## Marks: single meshes that flash and go (a bounce's tracer, a blast's
## ring). Capped on their own so a crowd of card effects stays cheap.
const MAX_MARKS := 24
static var marks := 0


static func _fade(m: Node3D, to_scale: Vector3, life: float) -> void:
	marks += 1
	var tw := m.create_tween()
	tw.tween_property(m, "scale", to_scale, life)
	tw.tween_callback(func() -> void:
		marks = maxi(0, marks - 1)
		m.queue_free())


## A bright line from [param from] to [param to] (in the parent's space)
## that thins out and is gone: where a ricochet went.
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var d := from.distance_to(to)
	if marks >= MAX_MARKS or d < 0.2:
		return
	var m := Mats.box(Vector3(0.09, 0.09, 1.0), color, true)
	m.material_override = Mats.glow(color, 2.6)
	parent.add_child(m)
	m.position = (from + to) * 0.5
	m.basis = Basis.looking_at((to - from).normalized(), Vector3.UP)
	m.scale = Vector3(1.0, 1.0, d)
	_fade(m, Vector3(0.05, 0.05, d), 0.16)


## A ring on the ground that opens to [param radius]: how far a blast
## reached.
static func ring(parent: Node, at: Vector3, radius: float, color: Color) -> void:
	if marks >= MAX_MARKS:
		return
	var m := Mats.torus(0.82, 1.0, color, true)
	m.material_override = Mats.glow(color, 2.2)
	parent.add_child(m)
	m.position = at
	m.scale = Vector3.ONE * radius * 0.25
	_fade(m, Vector3(radius, 0.4, radius), 0.22)


static func _mesh(size: float, color: Color, glow: bool = false) -> Mesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Mats.glow(color, 2.0) if glow else Mats.soft(color)
	return m


static func _one_shot(parent: Node, at: Vector3, amount: int, life: float) -> CPUParticles3D:
	if live >= MAX_LIVE:
		return null
	live += 1
	live_peak = maxi(live_peak, live)
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
	tw.tween_callback(func() -> void:
		live = maxi(0, live - 1)
		p.queue_free())
	return p


## A splash of dark red when a zombie dies.
static func blood(parent: Node, at: Vector3, big: bool = false) -> void:
	var p := _one_shot(parent, at, 14 if big else 8, 0.55)
	if p == null:
		return
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
	if p == null:
		return
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
	if p == null:
		return
	p.mesh = _mesh(0.06, SPARK, true)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0.0, -9.0, 0.0)


## Smoke that rises and fades: muzzle puffs, wrecks.
static func smoke(parent: Node, at: Vector3, amount: int = 6) -> void:
	var p := _one_shot(parent, at, amount, 0.9)
	if p == null:
		return
	p.mesh = _mesh(0.16, SMOKE)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 30.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.scale_amount_curve = _grow()


## Confetti: flat flakes in every colour, thrown up and tumbling down.
## A good gate, a perfect, a level cleared.
static func confetti(parent: Node, at: Vector3, amount: int = 16) -> void:
	var p := _one_shot(parent, at, amount, 1.1)
	if p == null:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 0.025)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	p.mesh = bm
	p.color_ramp = _rainbow()
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 55.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0.0, -7.0, 0.0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3


static func _rainbow() -> Gradient:
	var g := Gradient.new()
	var colors := [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 0.9, 0.4), Color(0.3, 0.6, 1.0), Color(0.8, 0.4, 1.0), Color(1.0, 0.5, 0.75)]
	g.set_color(0, colors[0])
	g.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size() - 1):
		g.add_point(float(i) / float(colors.size() - 1), colors[i])
	return g


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
