class_name Zombie
extends Node3D
## A walker. Reaches the squad, eats [member bite] soldiers, and is spent.

const SKIN := Color(0.45, 0.65, 0.35)
const BRUTE_SKIN := Color(0.62, 0.42, 0.35)
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
var brute := false
var radius := 0.45
var alive := true

var _body: Node3D
var _bar: MeshInstance3D
var _hit_t := 0.0
var _base_scale := 1.0


func _init() -> void:
	_body = Node3D.new()
	add_child(_body)


func setup(p_hp: float, p_speed: float, p_brute: bool) -> void:
	brute = p_brute
	max_hp = p_hp
	hp = max_hp
	speed = p_speed * (0.7 if brute else 1.0)
	bite = 3 if brute else 1
	radius = 0.85 if brute else 0.55
	homing = 1.2 if brute else 1.8
	_base_scale = 1.7 if brute else 1.0
	_body.scale = Vector3.ONE * _base_scale

	var body := Mats.capsule(0.25, 0.9, BRUTE_SKIN if brute else SKIN)
	body.position.y = 0.55
	_body.add_child(body)
	var head := Mats.sphere(0.2, BRUTE_SKIN if brute else SKIN)
	head.position.y = 1.2
	_body.add_child(head)
	var arm_l := Mats.box(Vector3(0.1, 0.1, 0.5), SKIN)
	arm_l.position = Vector3(-0.3, 0.9, 0.25)
	_body.add_child(arm_l)
	var arm_r := Mats.box(Vector3(0.1, 0.1, 0.5), SKIN)
	arm_r.position = Vector3(0.3, 0.9, 0.25)
	_body.add_child(arm_r)

	var bar_bg := Mats.box(Vector3(0.84, 0.1, 0.1), BAR_BG, true)
	bar_bg.position.y = 1.65
	_body.add_child(bar_bg)
	_bar = Mats.box(Vector3(0.8, 0.08, 0.12), BAR_FG, true)
	_bar.position.y = 1.65
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
	var t := Time.get_ticks_msec() * 0.001
	_body.rotation.z = sin(t * 6.0 + position.x * 3.0) * 0.08
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - delta * 8.0)
		_body.scale = Vector3.ONE * _base_scale * (1.0 + 0.18 * _hit_t)
