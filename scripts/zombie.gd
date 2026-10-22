class_name Zombie
extends Node3D
## A walker: hunched torso, arms out, red eyes, shambling legs. Reaches the
## squad, eats [member bite] soldiers, and is spent. Brutes are bigger, with
## shoulder plates, and take a slice of the squad instead of a nibble.
## Thieves sprint the other way, toward the next gate, and knock its value
## down if they get there. Tanks are wide bullet sponges that shield the
## gate behind them.

enum Kind { NORMAL, BRUTE, THIEF, TANK, RUNNER }

const SKIN := Color(0.45, 0.65, 0.35)
const SKIN_PALE := Color(0.62, 0.72, 0.45)
const BRUTE_SKIN := Color(0.46, 0.34, 0.3)
const THIEF_SKIN := Color(0.85, 0.75, 0.3)
const TANK_SKIN := Color(0.35, 0.4, 0.45)
const RUNNER_SKIN := Color(0.75, 0.45, 0.35)
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

var _body: Node3D
var _bar: MeshInstance3D
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

	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.11, 0.5, 0.0)
		var leg := Mats.capsule(0.09, 0.4, PANTS)
		leg.position.y = -0.22
		hip.add_child(leg)
		_body.add_child(hip)
		_legs.append(hip)

	var torso := Mats.capsule(0.21, 0.5, shirt)
	torso.position = Vector3(0.0, 0.76, 0.04)
	torso.rotation.x = 0.55 if is_runner() else 0.3
	_body.add_child(torso)

	var head := Mats.sphere(0.17, skin)
	head.position = Vector3(0.0, 1.16, 0.14)
	_body.add_child(head)
	var eye_r := 0.05 if brute else 0.035
	for side in [-1.0, 1.0]:
		var eye := Mats.sphere(eye_r, EYE)
		eye.material_override = Mats.flat(EYE, true)
		eye.position = Vector3(side * 0.065, 1.18, 0.29)
		_body.add_child(eye)

	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.26, 0.96, 0.1)
		shoulder.rotation_degrees.x = -80.0
		var arm := Mats.capsule(0.07, 0.44, skin)
		arm.position.y = -0.2
		shoulder.add_child(arm)
		_body.add_child(shoulder)
		_arms.append(shoulder)

	if brute:
		for side in [-1.0, 1.0]:
			var pad := Mats.box(Vector3(0.3, 0.14, 0.3), PLATE)
			pad.position = Vector3(side * 0.3, 1.06, 0.05)
			_body.add_child(pad)
	elif is_tank():
		# A slab of scrap held out front: the thing that eats your bullets.
		var shield := Mats.box(Vector3(1.1, 0.9, 0.12), PLATE.lightened(0.15))
		shield.position = Vector3(0.0, 0.8, 0.42)
		_body.add_child(shield)
	elif is_thief():
		# A sack over the shoulder: it is here to take, not to bite.
		var sack := Mats.sphere(0.16, Color(0.5, 0.38, 0.2))
		sack.position = Vector3(-0.22, 1.05, -0.1)
		_body.add_child(sack)

	var bar_bg := Mats.box(Vector3(0.84, 0.1, 0.1), BAR_BG, true)
	bar_bg.position.y = 1.6
	_body.add_child(bar_bg)
	_bar = Mats.box(Vector3(0.8, 0.08, 0.12), BAR_FG, true)
	_bar.position.y = 1.6
	_body.add_child(_bar)
	_refresh_bar()


## Returns true when this hit killed the zombie.
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
	var t := Time.get_ticks_msec() * 0.001 * (14.0 if is_thief() or is_runner() else 7.0) + _phase
	_body.rotation.z = sin(t * 0.8) * 0.08
	_body.position.y = absf(sin(t * 0.5)) * 0.05
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t + PI * i) * 0.45
	for i in range(_arms.size()):
		_arms[i].rotation_degrees.x = -80.0 + sin(t * 0.7 + i) * 10.0
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - delta * 8.0)
		_body.scale = Vector3.ONE * _base_scale * (1.0 + 0.18 * _hit_t)
