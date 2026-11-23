class_name Zombie
extends Node3D
## A walker: hunched torso, arms out, red eyes, shambling legs. Reaches the
## squad, eats [member bite] soldiers, and is spent. Brutes are bigger, with
## shoulder plates, and take a slice of the squad instead of a nibble.
## Thieves sprint the other way, toward the next gate, and knock its value
## down if they get there. Tanks are wide bullet sponges that shield the
## gate behind them.

enum Kind { NORMAL, BRUTE, THIEF, TANK, RUNNER, LATCHER, SPLITTER }

const SKIN := Palette.ZOMBIE
const SKIN_PALE := Palette.ZOMBIE_PALE
const BRUTE_SKIN := Palette.BRUTE
const THIEF_SKIN := Palette.THIEF
const TANK_SKIN := Palette.TANK
const RUNNER_SKIN := Palette.RUNNER
const LATCHER_SKIN := Palette.LATCHER
const SPLITTER_SKIN := Palette.SPLITTER
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
## Passed the squad unshot: it has turned and is running it down. Seconds
## of chase left; zero when it is not chasing.
var chase_left := 0.0
var chasing := false

var _body: Node3D
var _bar: MeshInstance3D
var _bar_bg: MeshInstance3D
var _cling_ring: MeshInstance3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hit_t := 0.0
## Build cards: on fire (damage a second, seconds left) and slowed.
var burn_dps := 0.0
var burn_left := 0.0
var slow_left := 0.0
var slow_mult := 1.0
var _status: MeshInstance3D
var _status_kind := ""
var _base_scale := 1.0
var _phase := randf() * TAU
## Set by warm_looks: this tone and shirt, not a roll of the dice.
var _force_look := -1


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
		Kind.SPLITTER:
			# Slow, bloated, and worse dead than alive.
			speed = p_speed * 0.8
			bite = 2
			radius = 0.72
			homing = 1.0
			_base_scale = 1.3
		_:
			speed = p_speed
			bite = 1
			radius = 0.55
			# Walkers drift toward you slowly: lining them up is your job.
			homing = 1.0
			_base_scale = 1.0
	_body.scale = Vector3.ONE * _base_scale
	_build()
	_refresh_bar()
	if is_thief():
		# Thieves run away from the squad, so they face down the lane.
		_body.rotation.y = PI


func kind_name() -> String:
	return ["normal", "brute", "thief", "tank", "runner", "latcher", "splitter"][kind]


func is_thief() -> bool:
	return kind == Kind.THIEF


func is_tank() -> bool:
	return kind == Kind.TANK


func is_runner() -> bool:
	return kind == Kind.RUNNER


func is_splitter() -> bool:
	return kind == Kind.SPLITTER


func is_latcher() -> bool:
	return kind == Kind.LATCHER


## Welds every look a walker can have, and one of each other kind,
## under the loading screen: the first wave of the session then costs
## what the tenth does.
static func warm_looks() -> int:
	var made := 0
	for look in range(SKIN_TONES * SHIRTS.size()):
		var z := Zombie.new()
		z._force_look = look
		z.setup(1.0, 1.0, Kind.NORMAL)
		z.free()
		made += 1
	for k in range(1, Kind.size()):
		var z := Zombie.new()
		z.setup(1.0, 1.0, k)
		z.free()
		made += 1
	return made


## How many skin tones a walker comes in. A tone and a shirt name a
## look, and every zombie of one look shares its meshes.
const SKIN_TONES := 4
const INK := 0.03


## Five meshes: a trunk (torso, head, face and whatever the kind carries),
## two legs and two arms. Each is welded from its parts once per look and
## shared from then on, so a wave of forty is two hundred nodes and no
## new meshes, where it used to be eight hundred of each.
func _build() -> void:
	var tone := mini(int(randf() * float(SKIN_TONES)), SKIN_TONES - 1)
	var shirt_i := randi() % SHIRTS.size()
	if _force_look >= 0:
		tone = _force_look % SKIN_TONES
		shirt_i = (_force_look / SKIN_TONES) % SHIRTS.size()
	var skin := SKIN.lerp(SKIN_PALE, float(tone) / float(SKIN_TONES - 1))
	var shirt: Color = SHIRTS[shirt_i]
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
		Kind.SPLITTER:
			skin = SPLITTER_SKIN
			shirt = Color(0.35, 0.4, 0.15)
	var look := "%d|%s|%s" % [kind, skin.to_html(false), shirt.to_html(false)]

	# Shambling thick legs, bare feet.
	for side in [-1.0, 1.0]:
		var hip := Mats.weld("zleg|" + skin.to_html(false), func() -> Array: return _leg_parts(skin))
		hip.position = Vector3(side * 0.14, 0.5, 0.0)
		hip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(hip)
		_legs.append(hip)

	_body.add_child(Mats.weld("zbody|" + look, func() -> Array: return _trunk_parts(skin, shirt)))

	# Thick arms out front, big open hands.
	for side in [-1.0, 1.0]:
		var shoulder := Mats.weld("zarm|" + skin.to_html(false), func() -> Array: return _arm_parts(skin))
		shoulder.position = Vector3(side * 0.32, 0.98, 0.12)
		shoulder.rotation_degrees.x = -80.0
		shoulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(shoulder)
		_arms.append(shoulder)


func _leg_parts(skin: Color) -> Array:
	var leg := Mats.pill(0.1, 0.36, PANTS)
	leg.position.y = -0.2
	Mats.ink(leg, INK)
	var foot := Mats.ball(0.1, skin.darkened(0.2))
	foot.position = Vector3(0.0, -0.42, -0.04)
	foot.scale = Vector3(1.0, 0.6, 1.3)
	Mats.ink(foot, INK)
	return [leg, foot]


func _arm_parts(skin: Color) -> Array:
	var arm := Mats.pill(0.085, 0.4, skin)
	arm.position.y = -0.2
	Mats.ink(arm, INK)
	var hand := Mats.ball(0.095, skin.darkened(0.1))
	hand.position.y = -0.42
	Mats.ink(hand, INK)
	return [arm, hand]


## Everything that rides the hips without moving against them.
func _trunk_parts(skin: Color, shirt: Color) -> Array:
	var parts: Array = []
	# A hunched torso, torn shirt, a rib of darker cloth.
	var torso := Mats.ball(0.29, shirt)
	torso.position = Vector3(0.0, 0.76, 0.06)
	torso.scale = Vector3(1.08, 1.1, 0.9)
	torso.rotation.x = 0.55 if is_runner() else 0.3
	parts.append(Mats.ink(torso, INK))
	var tear := Mats.ball(0.12, skin)
	tear.position = Vector3(0.1, 0.62, -0.17)
	tear.scale = Vector3(1.0, 1.4, 0.4)
	parts.append(tear)

	# A big round head, sunken glowing eyes, a slack jaw.
	var head := Mats.ball(0.25, skin)
	head.position = Vector3(0.0, 1.16, 0.16)
	parts.append(Mats.ink(head, INK))
	var eye_r := 0.07 if brute else 0.05
	for side in [-1.0, 1.0]:
		var socket := Mats.ball(eye_r + 0.025, skin.darkened(0.45))
		socket.position = Vector3(side * 0.09, 1.19, 0.37)
		socket.scale = Vector3(1.0, 1.0, 0.5)
		parts.append(socket)
		var eye := Mats.sphere(eye_r, EYE)
		eye.material_override = Mats.glow(EYE, 2.2)
		eye.position = Vector3(side * 0.09, 1.19, 0.4)
		parts.append(eye)
	var jaw := Mats.ball(0.1, skin.darkened(0.3))
	jaw.position = Vector3(0.0, 0.98, 0.36)
	jaw.scale = Vector3(1.4, 0.5, 0.7)
	parts.append(jaw)
	var hair := Mats.ball(0.24, PANTS.darkened(0.2))
	hair.position = Vector3(0.0, 1.28, 0.12)
	hair.scale = Vector3(1.0, 0.45, 1.0)
	parts.append(hair)

	if brute:
		for side in [-1.0, 1.0]:
			var pad := Mats.box(Vector3(0.36, 0.18, 0.36), PLATE)
			pad.position = Vector3(side * 0.36, 1.08, 0.06)
			parts.append(Mats.ink(pad, INK))
		var belt := Mats.torus(0.26, 0.32, PLATE.darkened(0.2))
		belt.position = Vector3(0.0, 0.52, 0.04)
		parts.append(belt)
	elif is_tank():
		# A slab of scrap held out front: the thing that eats your bullets.
		var shield := Mats.gbox(Vector3(1.1, 0.9, 0.12), PLATE.lightened(0.15), 0.8, 0.3, 6)
		shield.position = Vector3(0.0, 0.8, 0.42)
		parts.append(Mats.ink(shield, INK))
		for i in range(3):
			var rivet := Mats.ball(0.04, Color(0.7, 0.7, 0.72))
			rivet.position = Vector3(-0.4 + 0.4 * float(i), 1.15, 0.49)
			parts.append(rivet)
	elif is_thief():
		# A sack over the shoulder: it is here to take, not to bite.
		var sack := Mats.ball(0.17, Color(0.5, 0.38, 0.2))
		sack.position = Vector3(-0.22, 1.05, -0.1)
		parts.append(Mats.ink(sack, INK))
	elif is_splitter():
		# Bloated: a belly that bulges past the shirt, and the pustules of
		# the three runners waiting inside.
		var belly := Mats.ball(0.34, skin)
		belly.position = Vector3(0.0, 0.68, 0.14)
		belly.scale = Vector3(1.15, 0.95, 1.0)
		parts.append(Mats.ink(belly, INK))
		for k in range(3):
			var pus := Mats.ball(0.09, skin.lightened(0.3))
			var a := -0.7 + float(k) * 0.7
			pus.position = Vector3(sin(a) * 0.3, 0.72 + float(k % 2) * 0.12, 0.14 + cos(a) * 0.3)
			parts.append(pus)
	elif is_latcher():
		# Claws: it holds on.
		for side in [-1.0, 1.0]:
			for k in range(3):
				var claw := Mats.cone(0.02, 0.12, Color(0.9, 0.85, 0.8))
				claw.position = Vector3(side * 0.27 + (float(k) - 1.0) * 0.04, 0.55, 0.52)
				claw.rotation_degrees.x = 90.0
				parts.append(claw)
	return parts


## The health bar is only made once something has been taken off: a
## black bar over every healthy head was the heaviest thing on screen,
## and most walkers die to the first volley without ever needing one.
func _make_bar() -> void:
	_bar_bg = Mats.box(Vector3(0.84, 0.1, 0.1), BAR_BG, true)
	_bar_bg.position.y = 1.72
	_bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_bar_bg)
	_bar = Mats.box(Vector3(0.8, 0.08, 0.12), BAR_FG, true)
	_bar.position.y = 1.72
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_bar)


## Returns true when this hit killed the zombie.
## Start clinging: flagged for the world, and a pulsing red ring on the
## ground that says "tap me".
func mark_latched() -> void:
	latched = true
	if _cling_ring == null:
		_cling_ring = Mats.torus(0.42, 0.6, Color(1.0, 0.3, 0.25, 0.9), true)
		_cling_ring.position.y = 0.04
		add_child(_cling_ring)


## Sets it alight: the strongest fire wins, the clock restarts.
func ignite(dps: float, seconds: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_left = seconds


func chill(mult: float, seconds: float) -> void:
	slow_mult = minf(slow_mult, mult) if slow_left > 0.0 else mult
	slow_left = seconds


## How fast it walks right now: slowed zombies drag.
func pace_mult() -> float:
	return slow_mult if slow_left > 0.0 else 1.0


## Burns and thaws. True when the fire killed it. No flinch: fire is a
## steady drain, not a hit.
func tick_status(delta: float) -> bool:
	if slow_left > 0.0:
		slow_left -= delta
	if burn_left <= 0.0 or not alive:
		return false
	burn_left -= delta
	hp -= burn_dps * delta
	_refresh_bar()
	return hp <= 0.0


func take_damage(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	_hit_t = 1.0
	_refresh_bar()
	return hp <= 0.0


func die() -> void:
	# Shot: it goes over backwards, bounces once, and is gone.
	alive = false
	if _cling_ring != null:
		_cling_ring.visible = false
	if _bar != null:
		_bar.visible = false
		_bar_bg.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_body, "rotation:x", -1.45, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_body, "position:z", _body.position.z + 0.6, 0.22)
	tw.chain().tween_property(self, "scale", Vector3(1.1, 0.25, 1.1), 0.18).set_delay(0.25)
	tw.chain().tween_callback(queue_free)


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
	if _bar == null:
		if ratio >= 0.999:
			return
		_make_bar()
	_bar.scale.x = maxf(ratio, 0.001)
	_bar.position.x = -(1.0 - ratio) * 0.4
	_bar.visible = ratio < 0.999
	_bar_bg.visible = _bar.visible


## A small flame or a shard of ice over the head while it burns or drags.
func _show_status() -> void:
	var want := "burn" if burn_left > 0.0 else ("slow" if slow_left > 0.0 else "")
	if want == _status_kind:
		return
	_status_kind = want
	if want == "":
		if _status != null:
			_status.visible = false
		return
	if _status == null:
		_status = Mats.cone(0.16, 0.42, Color(1.0, 0.55, 0.1), true)
		_status.position = Vector3(0.0, 1.72, 0.1)
		_body.add_child(_status)
	_status.material_override = Mats.glow(Color(1.0, 0.55, 0.1) if want == "burn" else Color(0.55, 0.85, 1.0), 2.4)
	_status.visible = true


func _process(delta: float) -> void:
	if not alive:
		return
	_show_status()
	if _status != null and _status.visible:
		_status.scale = Vector3.ONE * (1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.02 + _phase))
	# A stumbling lurch so a wave reads as a crowd, not a grid.
	var t := Time.get_ticks_msec() * 0.001 * (14.0 if is_thief() or is_runner() or latched or chasing else 7.0) + _phase
	_body.rotation.z = sin(t * 0.8) * 0.1
	_body.position.y = absf(sin(t * 0.5)) * 0.07
	var swing := 0.65 if is_runner() or is_thief() else 0.5
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t + PI * i) * swing
	for i in range(_arms.size()):
		_arms[i].rotation_degrees.x = -80.0 + sin(t * 0.7 + i) * 14.0
	if _cling_ring != null:
		_cling_ring.scale = Vector3.ONE * (1.0 + 0.18 * sin(t * 1.2))
		_cling_ring.rotation.y = t * 0.3
	if _hit_t > 0.0:
		# Squash: wider and shorter for a moment, knocked back a step.
		_hit_t = maxf(0.0, _hit_t - delta * 8.0)
		_body.scale = Vector3(1.0 + 0.32 * _hit_t, 1.0 - 0.26 * _hit_t, 1.0 + 0.32 * _hit_t) * _base_scale
		_body.position.z = -0.22 * _hit_t
