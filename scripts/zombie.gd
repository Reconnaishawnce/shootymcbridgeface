class_name Zombie
extends Node3D
## A walker: hunched torso, arms out, red eyes, shambling legs. Reaches the
## squad, eats [member bite] soldiers, and is spent. Brutes are bigger, with
## shoulder plates, and take a slice of the squad instead of a nibble.
## Thieves sprint the other way, toward the next gate, and knock its value
## down if they get there. Tanks are wide bullet sponges that shield the
## gate behind them.

enum Kind { NORMAL, BRUTE, THIEF, TANK, RUNNER, LATCHER }

const SKIN := Color(0.45, 0.65, 0.35)
const SKIN_PALE := Color(0.62, 0.72, 0.45)
const BRUTE_SKIN := Color(0.46, 0.34, 0.3)
const THIEF_SKIN := Color(0.85, 0.75, 0.3)
const TANK_SKIN := Color(0.35, 0.4, 0.45)
const RUNNER_SKIN := Color(0.75, 0.45, 0.35)
const LATCHER_SKIN := Color(0.7, 0.3, 0.6)
const SHIRTS := [
	Color(0.5, 0.2, 0.2), Color(0.35, 0.35, 0.4), Color(0.4, 0.3, 0.2),
	Color(0.35, 0.2, 0.4), Color(0.2, 0.35, 0.3), Color(0.55, 0.45, 0.2),
]
const PANTS := Color(0.2, 0.2, 0.22)
const PLATE := Color(0.25, 0.22, 0.2)
const EYE := Color(1.0, 0.15, 0.1)
const BAR_BG := Color(0.1, 0.1, 0.1)
const BAR_FG := Color(0.9, 0.2, 0.2)

var hp := 2.0
var max_hp := 2.0
var speed := 1.5
## Sideways speed toward the squad. Zombies want to reach you; they do not
## wander. This is what lets a one-soldier squad line up its shots.
var homing := 1.8
## Each zombie aims for its own spot beside the squad centre so a wave
## arrives as a crowd instead of a single stacked column.
var lane_offset := 0.0
var bite := 1
var kind: int = Kind.NORMAL
var brute := false
var radius := 0.55
var alive := true
## Which wave this zombie belongs to, for wave-clear bonuses. -1 for none.
var wave_id := -1
## Sideways bounds while inside a fork route; the divider keeps them there.
var lane_min := -3.0
var lane_max := 3.0
## A latched zombie rides the squad's front and eats until it is shot off.
var latched := false
var latch_offset_x := 0.0
var latch_timer := 0.0

var _body: Node3D
var _bar: MeshInstance3D
var _cling_ring: MeshInstance3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hit_t := 0.0
var _base_scale := 1.0
var _phase := randf() * TAU


func _init() -> void:
	_body = Node3D.new()
	add_child(_body)


func setup(p_hp: float, p_speed: float, p_kind: int) -> void:
	kind = p_kind
	brute = kind == Kind.BRUTE
	max_hp = p_hp
	hp = max_hp
	match kind:
		Kind.BRUTE:
			speed = p_speed * 0.7
			bite = 3
			radius = 0.85
			homing = 1.2
			_base_scale = 1.7
		Kind.THIEF:
			speed = p_speed
			bite = 1
			radius = 0.4
			homing = 3.0
			_base_scale = 0.8
		Kind.TANK:
			speed = p_speed * 0.45
			bite = 5
			radius = 1.25
			homing = 0.6
			_base_scale = 2.1
		Kind.RUNNER:
			speed = p_speed * 2.6
			bite = 1
			radius = 0.45
			homing = 2.8
			_base_scale = 0.9
		Kind.LATCHER:
			speed = p_speed * 1.3
			bite = 1
			radius = 0.5
			homing = 2.2
			_base_scale = 1.0
		_:
			speed = p_speed
			bite = 1
			radius = 0.55
			# Walkers drift toward you slowly: lining them up is your job.
			homing = 1.0
			_base_scale = 1.0
	_body.scale = Vector3.ONE * _base_scale
	_build()
	if is_thief():
		# Thieves run away from the squad, so they face down the lane.
		_body.rotation.y = PI


func is_thief() -> bool:
	return kind == Kind.THIEF


func is_tank() -> bool:
	return kind == Kind.TANK


func is_runner() -> bool:
	return kind == Kind.RUNNER


func is_latcher() -> bool:
	return kind == Kind.LATCHER


func _build() -> void:
	var skin := SKIN.lerp(SKIN_PALE, randf())
	var shirt: Color = SHIRTS[randi() % SHIRTS.size()]
	match kind:
		Kind.BRUTE:
			skin = BRUTE_SKIN
			shirt = PLATE
		Kind.THIEF:
			skin = THIEF_SKIN
			shirt = Color(0.2, 0.2, 0.22)
		Kind.TANK:
			skin = TANK_SKIN
			shirt = PLATE
		Kind.RUNNER:
			skin = RUNNER_SKIN
			shirt = Color(0.15, 0.15, 0.18)
		Kind.LATCHER:
			skin = LATCHER_SKIN
			shirt = Color(0.3, 0.1, 0.25)
	var ink := 0.03

	# Shambling legs, bare feet.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.11, 0.5, 0.0)
		var leg := Mats.pill(0.085, 0.36, PANTS)
		leg.position.y = -0.2
		Mats.ink(leg, ink)
		hip.add_child(leg)
		var foot := Mats.ball(0.08, skin.darkened(0.2))
		foot.position = Vector3(0.0, -0.42, -0.04)
		foot.scale = Vector3(1.0, 0.6, 1.3)
		hip.add_child(foot)
		_body.add_child(hip)
		_legs.append(hip)

	# A hunched torso, torn shirt, a rib of darker cloth.
	var torso := Mats.ball(0.24, shirt)
	torso.position = Vector3(0.0, 0.74, 0.06)
	torso.scale = Vector3(1.0, 1.15, 0.85)
	torso.rotation.x = 0.55 if is_runner() else 0.3
	Mats.ink(torso, ink)
	_body.add_child(torso)
	var tear := Mats.ball(0.1, skin)
	tear.position = Vector3(0.09, 0.62, -0.13)
	tear.scale = Vector3(1.0, 1.4, 0.4)
	_body.add_child(tear)

	# A big round head, sunken glowing eyes, a slack jaw.
	var head := Mats.ball(0.2, skin)
	head.position = Vector3(0.0, 1.14, 0.16)
	Mats.ink(head, ink)
	_body.add_child(head)
	var eye_r := 0.055 if brute else 0.04
	for side in [-1.0, 1.0]:
		var socket := Mats.ball(eye_r + 0.02, skin.darkened(0.45))
		socket.position = Vector3(side * 0.075, 1.17, 0.31)
		socket.scale = Vector3(1.0, 1.0, 0.5)
		_body.add_child(socket)
		var eye := Mats.sphere(eye_r, EYE)
		eye.material_override = Mats.glow(EYE, 2.0)
		eye.position = Vector3(side * 0.075, 1.17, 0.34)
		_body.add_child(eye)
	var jaw := Mats.ball(0.08, skin.darkened(0.3))
	jaw.position = Vector3(0.0, 1.0, 0.3)
	jaw.scale = Vector3(1.3, 0.5, 0.7)
	_body.add_child(jaw)
	var hair := Mats.ball(0.19, PANTS.darkened(0.2))
	hair.position = Vector3(0.0, 1.24, 0.12)
	hair.scale = Vector3(1.0, 0.45, 1.0)
	_body.add_child(hair)

	# Arms out front, hands open.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.27, 0.96, 0.12)
		shoulder.rotation_degrees.x = -80.0
		var arm := Mats.pill(0.07, 0.4, skin)
		arm.position.y = -0.2
		Mats.ink(arm, ink)
		shoulder.add_child(arm)
		var hand := Mats.ball(0.075, skin.darkened(0.1))
		hand.position.y = -0.42
		shoulder.add_child(hand)
		_body.add_child(shoulder)
		_arms.append(shoulder)

	if brute:
		for side in [-1.0, 1.0]:
			var pad := Mats.box(Vector3(0.32, 0.16, 0.32), PLATE)
			pad.position = Vector3(side * 0.3, 1.04, 0.06)
			Mats.ink(pad, ink)
			_body.add_child(pad)
		var belt := Mats.torus(0.22, 0.27, PLATE.darkened(0.2))
		belt.position = Vector3(0.0, 0.52, 0.04)
		_body.add_child(belt)
	elif is_tank():
		# A slab of scrap held out front: the thing that eats your bullets.
		var shield := Mats.gbox(Vector3(1.1, 0.9, 0.12), PLATE.lightened(0.15), 0.8, 0.3, 6)
		shield.position = Vector3(0.0, 0.8, 0.42)
		Mats.ink(shield, ink)
		_body.add_child(shield)
		for i in range(3):
			var rivet := Mats.ball(0.04, Color(0.7, 0.7, 0.72))
			rivet.position = Vector3(-0.4 + 0.4 * float(i), 1.15, 0.49)
			_body.add_child(rivet)
	elif is_thief():
		# A sack over the shoulder: it is here to take, not to bite.
		var sack := Mats.ball(0.17, Color(0.5, 0.38, 0.2))
		sack.position = Vector3(-0.22, 1.05, -0.1)
		Mats.ink(sack, ink)
		_body.add_child(sack)
	elif is_latcher():
		# Claws: it holds on.
		for side in [-1.0, 1.0]:
			for k in range(3):
				var claw := Mats.cone(0.02, 0.12, Color(0.9, 0.85, 0.8))
				claw.position = Vector3(side * 0.27 + (float(k) - 1.0) * 0.04, 0.55, 0.52)
				claw.rotation_degrees.x = 90.0
				_body.add_child(claw)

	var bar_bg := Mats.box(Vector3(0.84, 0.1, 0.1), BAR_BG, true)
	bar_bg.position.y = 1.6
	_body.add_child(bar_bg)
	_bar = Mats.box(Vector3(0.8, 0.08, 0.12), BAR_FG, true)
	_bar.position.y = 1.6
	_body.add_child(_bar)
	_refresh_bar()


## Returns true when this hit killed the zombie.
## Start clinging: flagged for the world, and a pulsing red ring on the
## ground that says "tap me".
func mark_latched() -> void:
	latched = true
	if _cling_ring == null:
		_cling_ring = Mats.torus(0.42, 0.6, Color(1.0, 0.3, 0.25, 0.9), true)
		_cling_ring.position.y = 0.04
		add_child(_cling_ring)


func take_damage(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	_hit_t = 1.0
	_refresh_bar()
	return hp <= 0.0


func die() -> void:
	_vanish()


## Reached the squad and was consumed.
func consume() -> void:
	_vanish()


func _vanish() -> void:
	alive = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.14)
	tw.tween_callback(queue_free)


func _refresh_bar() -> void:
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_bar.scale.x = maxf(ratio, 0.001)
	_bar.position.x = -(1.0 - ratio) * 0.4
	_bar.visible = ratio < 0.999


func _process(delta: float) -> void:
	if not alive:
		return
	# A stumbling lurch so a wave reads as a crowd, not a grid.
	var t := Time.get_ticks_msec() * 0.001 * (14.0 if is_thief() or is_runner() or latched else 7.0) + _phase
	_body.rotation.z = sin(t * 0.8) * 0.08
	_body.position.y = absf(sin(t * 0.5)) * 0.05
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t + PI * i) * 0.45
	for i in range(_arms.size()):
		_arms[i].rotation_degrees.x = -80.0 + sin(t * 0.7 + i) * 10.0
	if _cling_ring != null:
		_cling_ring.scale = Vector3.ONE * (1.0 + 0.18 * sin(t * 1.2))
		_cling_ring.rotation.y = t * 0.3
	if _hit_t > 0.0:
		# Squash: wider and shorter for a moment, then back.
		_hit_t = maxf(0.0, _hit_t - delta * 8.0)
		_body.scale = Vector3(1.0 + 0.22 * _hit_t, 1.0 - 0.18 * _hit_t, 1.0 + 0.22 * _hit_t) * _base_scale
