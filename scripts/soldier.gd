class_name Soldier
extends Node3D
## One visible squad member, built from primitives: legs that run, a vest
## and chest plate, helmet and visor, backpack, two arms on a gun that
## recoils. Purely cosmetic: the squad owns the count.
##
## The front of the formation gets the detailed build; the crowd behind it
## gets a cheaper one so a 36-soldier squad stays well under a thousand
## draw calls on a phone.

const BODY := Color(0.22, 0.45, 0.85)
const SHOTGUN_BODY := Color(0.95, 0.52, 0.16)
const SKIN := Color(0.93, 0.76, 0.6)
const SKIN_DARK := Color(0.42, 0.28, 0.2)
const PANTS := Color(0.16, 0.18, 0.24)
const HELMET := Color(0.33, 0.38, 0.26)
const VISOR := Color(0.08, 0.1, 0.14)
const GUN := Color(0.3, 0.32, 0.36)
const BAND := Color(0.92, 0.92, 0.88)
const MUZZLE := Color(1.0, 0.85, 0.3)
const PACK := Color(0.28, 0.3, 0.22)

var target_offset := Vector3.ZERO
var detailed := true
var shotgun := false

var _muzzle: MeshInstance3D
var _gun: Node3D
var _legs: Array[Node3D] = []
var _flash_t := 0.0
var _recoil := 0.0
var _phase := randf() * TAU
var _stride := randf_range(11.0, 13.5)


func _init(p_detailed: bool = true, p_shotgun: bool = false) -> void:
	detailed = p_detailed
	shotgun = p_shotgun
	_build()


func _build() -> void:
	var skin := SKIN.lerp(SKIN_DARK, randf() * randf())
	var vest := SHOTGUN_BODY if shotgun else BODY

	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, 0.5, 0.0)
		var leg := Mats.capsule(0.085, 0.4, PANTS)
		leg.position.y = -0.22
		hip.add_child(leg)
		add_child(hip)
		_legs.append(hip)

	var torso := Mats.capsule(0.2, 0.52, vest)
	torso.position.y = 0.76
	add_child(torso)

	var head := Mats.sphere(0.155, skin)
	head.position.y = 1.2
	add_child(head)
	var helmet := Mats.sphere(0.19, HELMET)
	helmet.position.y = 1.26
	helmet.scale = Vector3(1.0, 0.72, 1.0)
	add_child(helmet)
	# A pale band round the helmet: the squad reads as people from above,
	# not as a pile of olive domes.
	var band := Mats.torus(0.17, 0.205, BAND)
	band.position.y = 1.25
	add_child(band)

	_gun = Node3D.new()
	_gun.position = Vector3(0.12, 0.88, -0.2)
	add_child(_gun)
	var barrel := Mats.box(Vector3(0.11, 0.11, 0.4) if shotgun else Vector3(0.085, 0.085, 0.58), GUN)
	barrel.position.z = -0.24
	_gun.add_child(barrel)
	var receiver := Mats.box(Vector3(0.09, 0.13, 0.22), GUN)
	receiver.position.z = 0.06
	_gun.add_child(receiver)
	_muzzle = Mats.box(Vector3(0.16, 0.16, 0.22), MUZZLE, true)
	_muzzle.position.z = -0.52
	_muzzle.visible = false
	_gun.add_child(_muzzle)

	if not detailed:
		return

	var chest := Mats.box(Vector3(0.28, 0.22, 0.1), vest.lightened(0.25))
	chest.position = Vector3(0.0, 0.78, -0.18)
	add_child(chest)
	var pack := Mats.box(Vector3(0.22, 0.26, 0.13), vest.darkened(0.35))
	pack.position = Vector3(0.0, 0.8, 0.21)
	add_child(pack)
	var visor := Mats.box(Vector3(0.2, 0.07, 0.05), VISOR)
	visor.position = Vector3(0.0, 1.2, -0.15)
	add_child(visor)
	var mag := Mats.box(Vector3(0.06, 0.12, 0.07), GUN)
	mag.position = Vector3(0.0, -0.12, 0.02)
	_gun.add_child(mag)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.25, 0.92, -0.02)
		shoulder.rotation_degrees.x = 75.0
		var arm := Mats.capsule(0.07, 0.42, vest)
		arm.position.y = -0.2
		shoulder.add_child(arm)
		var hand := Mats.sphere(0.06, skin)
		hand.position.y = -0.4
		shoulder.add_child(hand)
		add_child(shoulder)


func _ready() -> void:
	# Pop in, so a +5 gate reads as five people arriving.
	scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func muzzle_world_position() -> Vector3:
	return _muzzle.global_position


func flash() -> void:
	_flash_t = 0.06
	_recoil = 1.0
	_muzzle.visible = true


func _process(delta: float) -> void:
	position = position.lerp(target_offset, 1.0 - exp(-10.0 * delta))
	var t := Time.get_ticks_msec() * 0.001 * _stride + _phase
	position.y = absf(sin(t)) * 0.06
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t + PI * i) * 0.6
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 12.0)
		_gun.position.z = -0.2 + _recoil * 0.1
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_muzzle.visible = false
