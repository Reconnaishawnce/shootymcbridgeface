class_name Boss
extends Node3D
## The level's wall. Huge, slow, spiked, red-eyed, and it chews through the
## squad once it arrives. Its glowing core sways side to side; bullets
## through the core deal [member core_mult] damage, so tracking it with your
## steering is the skill.

enum Kind { WALKER, SPITTER, STORM, FOREMAN }

const BODY_RADIUS := 1.7
## The spitter holds this far away and lobs at you instead of walking in.
const SPITTER_HOLD_Z := -24.0
const SPIT_INTERVAL := 3.0
## The spitter is a smaller target that swings its whole body side to side.
const SPITTER_SWAY := 1.8
const SPITTER_SWAY_SPEED := 1.1
const CORE_RADIUS := 0.42
const CORE_MULT := 3.0
const CORE_SWAY := 1.1
const CORE_SPEED := 1.6

const SKIN := Color(0.55, 0.3, 0.28)
const DARK := Color(0.3, 0.16, 0.15)
const CORE_COLOR := Color(1.0, 0.85, 0.2)
const EYE := Color(1.0, 0.15, 0.1)
const SPITTER_SKIN := Color(0.4, 0.55, 0.3)
const STORM_SKIN := Color(0.3, 0.35, 0.55)
const STORM_GLOW := Color(0.7, 0.85, 1.0)
const STORM_HOLD_Z := -22.0
const STORM_SWAY := 2.6
const STORM_SWAY_SPEED := 0.7
## The foreman works the road: hurls saws, drops crates, holds back.
const FOREMAN_SKIN := Color(0.6, 0.42, 0.3)
const HARD_HAT := Color(1.0, 0.8, 0.15)
const VEST := Color(1.0, 0.45, 0.1)
const FOREMAN_HOLD_Z := -23.0
const FOREMAN_SWAY := 2.2
const FOREMAN_SWAY_SPEED := 0.9

var hp := 100.0
var max_hp := 100.0
var alive := true
var core_x := 0.0
var core_mult := CORE_MULT
var kind: int = Kind.WALKER
## Body sway (spitter only), applied to position.x by the world.
var sway_x := 0.0
var spit_timer := SPIT_INTERVAL * 0.6

var _body: Node3D
var _core: MeshInstance3D
var _ring: MeshInstance3D
var _legs: Array[Node3D] = []
var _hit_t := 0.0
var _phase := randf() * TAU


func _init() -> void:
	_body = Node3D.new()
	add_child(_body)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.55, 1.1, 0.0)
		var leg := Mats.capsule(0.32, 1.0, DARK)
		leg.position.y = -0.5
		hip.add_child(leg)
		_body.add_child(hip)
		_legs.append(hip)
	var torso := Mats.capsule(1.0, 2.4, SKIN)
	torso.position.y = 2.2
	Mats.ink(torso, 0.05)
	_body.add_child(torso)
	for side in [-1.0, 1.0]:
		var plate := Mats.box(Vector3(0.9, 0.35, 0.9), DARK)
		plate.position = Vector3(side * 1.15, 3.0, 0.0)
		plate.rotation_degrees.z = side * -12.0
		_body.add_child(plate)
		var arm := Mats.capsule(0.3, 1.8, SKIN)
		arm.position = Vector3(side * 1.3, 2.1, 0.4)
		arm.rotation_degrees = Vector3(70.0, 0.0, side * 15.0)
		_body.add_child(arm)
		var fist := Mats.sphere(0.38, DARK)
		fist.position = Vector3(side * 1.3, 1.55, 1.2)
		_body.add_child(fist)
	var head := Mats.sphere(0.55, SKIN)
	head.position = Vector3(0.0, 3.75, 0.2)
	Mats.ink(head, 0.05)
	_body.add_child(head)
	var jaw := Mats.box(Vector3(0.7, 0.25, 0.5), DARK)
	jaw.position = Vector3(0.0, 3.45, 0.5)
	_body.add_child(jaw)
	for side in [-1.0, 1.0]:
		var eye := Mats.sphere(0.1, EYE)
		eye.material_override = Mats.flat(EYE, true)
		eye.position = Vector3(side * 0.22, 3.85, 0.68)
		_body.add_child(eye)
	for i in range(3):
		var spike := Mats.cone(0.22, 0.9, DARK)
		spike.position = Vector3(0.0, 2.3 + i * 0.55, -0.85 + i * 0.1)
		spike.rotation_degrees.x = -40.0 + i * 10.0
		_body.add_child(spike)
	_ring = Mats.torus(0.42, 0.56, CORE_COLOR.darkened(0.35), true)
	_ring.position = Vector3(0.0, 1.9, 1.02)
	_ring.rotation_degrees.x = 90.0
	_body.add_child(_ring)
	_core = Mats.sphere(0.4, CORE_COLOR)
	_core.material_override = Mats.glow(CORE_COLOR, 3.0)
	_core.position = Vector3(0.0, 1.9, 1.05)
	_body.add_child(_core)


func setup(p_hp: float, p_kind: int = Kind.WALKER) -> void:
	kind = p_kind
	max_hp = p_hp
	hp = p_hp
	if kind == Kind.SPITTER:
		# Sickly green, no fists, a wide maw: it does not need to reach you.
		_recolour(SPITTER_SKIN)
		var maw := Mats.sphere(0.42, Color(0.1, 0.05, 0.05))
		maw.position = Vector3(0.0, 3.5, 0.62)
		_body.add_child(maw)
	elif kind == Kind.STORM:
		# Slate blue, a crown of glowing rods: it calls the lightning.
		_recolour(STORM_SKIN)
		for i in range(5):
			var a := float(i) * TAU / 5.0
			var rod := Mats.box(Vector3(0.12, 1.1, 0.12), STORM_GLOW, true)
			rod.position = Vector3(sin(a) * 0.5, 4.5, cos(a) * 0.5 + 0.2)
			rod.rotation_degrees = Vector3(cos(a) * 25.0, 0.0, -sin(a) * 25.0)
			_body.add_child(rod)
	elif kind == Kind.FOREMAN:
		# A hard hat, a hi-vis vest and a saw in one hand: it works the road.
		_recolour(FOREMAN_SKIN)
		var hat := Mats.ball(0.62, HARD_HAT)
		hat.position = Vector3(0.0, 4.05, 0.2)
		hat.scale = Vector3(1.0, 0.62, 1.0)
		_body.add_child(Mats.ink(hat, 0.05))
		var brim := Mats.torus(0.55, 0.78, HARD_HAT)
		brim.position = Vector3(0.0, 3.85, 0.25)
		_body.add_child(brim)
		var vest := Mats.box(Vector3(1.9, 1.5, 1.2), VEST)
		vest.position = Vector3(0.0, 2.4, 0.4)
		_body.add_child(Mats.ink(vest, 0.05))
		for y in [2.0, 2.8]:
			var stripe := Mats.box(Vector3(1.95, 0.16, 1.25), Color(0.95, 0.95, 0.9), true)
			stripe.position = Vector3(0.0, y, 0.4)
			_body.add_child(stripe)
		var blade := Mats.torus(0.25, 0.85, Saw.STEEL)
		blade.position = Vector3(1.6, 2.4, 1.3)
		blade.rotation_degrees.z = 90.0
		_body.add_child(blade)
		var edge := Mats.torus(0.83, 0.93, Saw.EDGE, true)
		edge.material_override = Mats.glow(Saw.EDGE, 1.6)
		edge.position = blade.position
		edge.rotation_degrees.z = 90.0
		_body.add_child(edge)


## Swap every skin-coloured part (inked or not) for another skin.
func _recolour(to: Color) -> void:
	for c in _body.get_children():
		if c is MeshInstance3D and c != _core and c != _ring and c.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = c.material_override
			if m.albedo_color.is_equal_approx(SKIN):
				c.material_override = Mats.inked_flat(to, 0.05) if m.next_pass != null else Mats.flat(to)


func is_spitter() -> bool:
	return kind == Kind.SPITTER


func is_storm() -> bool:
	return kind == Kind.STORM


func is_foreman() -> bool:
	return kind == Kind.FOREMAN


func kind_name() -> String:
	return ["walker", "spitter", "storm", "foreman"][kind]


## Bosses that never walk up to you, and hold a distance instead.
func holds_back() -> bool:
	return is_spitter() or is_storm() or is_foreman()


func hold_z() -> float:
	if is_storm():
		return STORM_HOLD_Z
	if is_foreman():
		return FOREMAN_HOLD_Z
	return SPITTER_HOLD_Z


func is_core_hit(x: float) -> bool:
	return absf(x - (global_position.x + core_x)) <= CORE_RADIUS


## Returns true when this hit killed the boss.
func take_damage(amount: float, is_core: bool) -> bool:
	if not alive:
		return false
	hp -= amount * (core_mult if is_core else 1.0)
	_hit_t = 1.0
	return hp <= 0.0


func die() -> void:
	alive = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4), 0.3)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if not alive:
		return
	var t := Time.get_ticks_msec() * 0.001
	core_x = sin(t * CORE_SPEED + _phase) * CORE_SWAY
	if is_spitter():
		sway_x = sin(t * SPITTER_SWAY_SPEED + _phase * 0.5) * SPITTER_SWAY
	elif is_storm():
		sway_x = sin(t * STORM_SWAY_SPEED + _phase * 0.5) * STORM_SWAY
	elif is_foreman():
		sway_x = sin(t * FOREMAN_SWAY_SPEED + _phase * 0.5) * FOREMAN_SWAY
	_core.position.x = core_x
	_ring.position.x = core_x
	_core.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 9.0))
	_body.rotation.z = sin(t * 2.5) * 0.06
	_body.position.y = absf(sin(t * 2.5)) * 0.12
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t * 2.5 + PI * i) * 0.35
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - delta * 10.0)
		_body.scale = Vector3(1.0 + 0.07 * _hit_t, 1.0 - 0.05 * _hit_t, 1.0 + 0.07 * _hit_t)
