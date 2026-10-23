class_name Soldier
extends Node3D
## One visible squad member, built from primitives and dressed from a
## look: legs that run, boots, a top, a face with eyes, hair, a hat, two
## arms on a gun that recoils, and something on the back. The hero at the
## front carries a name tag. Purely cosmetic: the squad owns the count.
##
## The front of the formation gets the detailed build; the crowd behind it
## gets a cheaper one so a 36-soldier squad stays well under a thousand
## draw calls on a phone.
##
## Look keys (all optional): hero, name, skin, hair, hair_style (short,
## bun, spiky, long, curly, mohawk, bald, none), top, pants, hat (helmet,
## cap, beanie, headband, cat, party, viking, crown, wizard, halo, none),
## weapon (standard, wood, candy, ice, neon, gold), back (pack, cape_red,
## cape_blue, wings, jetpack, none).

const BODY := Color(0.22, 0.45, 0.85)
const SHOTGUN_BODY := Color(0.95, 0.52, 0.16)
const MEDIC_BODY := Color(0.92, 0.92, 0.9)
const CROSS := Color(0.9, 0.15, 0.15)
const SKIN := Color(0.93, 0.76, 0.6)
const SKIN_DARK := Color(0.42, 0.28, 0.2)
const PANTS := Color(0.16, 0.18, 0.24)
const BOOT := Color(0.12, 0.1, 0.1)
const HELMET := Color(0.33, 0.38, 0.26)
const VISOR := Color(0.08, 0.1, 0.14)
const EYE := Color(0.08, 0.08, 0.1)
const GUN := Color(0.3, 0.32, 0.36)
const BAND := Color(0.92, 0.92, 0.88)
const MUZZLE := Color(1.0, 0.85, 0.3)
const PACK := Color(0.28, 0.3, 0.22)
const HAIR_COLORS := [Color(0.35, 0.22, 0.12), Color(0.08, 0.06, 0.05), Color(0.95, 0.55, 0.2), Color(0.85, 0.75, 0.45), Color(0.3, 0.2, 0.55), Color(0.5, 0.5, 0.5)]
const HAIR_STYLES := ["short", "bun", "spiky", "curly", "short", "bald"]
## Hats that cover the hair completely.
const COVERS_HAIR := ["helmet", "beanie", "wizard", "viking"]

var target_offset := Vector3.ZERO
var detailed := true
var squad_type := "rifle"
var shotgun := false
var look: Dictionary = {}
var hero := false

var _muzzle: MeshInstance3D
var _gun: Node3D
var _legs: Array[Node3D] = []
var _cape: Node3D
var _wings: Array[Node3D] = []
var _flame: MeshInstance3D
var _halo: Node3D
var _tag: Label3D
var _flash_t := 0.0
var _recoil := 0.0
var _phase := randf() * TAU
var _stride := randf_range(11.0, 13.5)


func _init(p_detailed: bool = true, p_type: String = "rifle", p_look: Dictionary = {}) -> void:
	detailed = p_detailed
	squad_type = p_type
	shotgun = p_type == "shotgun"
	look = p_look
	hero = bool(look.get("hero", false))
	_build()


func _vest_for_type() -> Color:
	if shotgun:
		return SHOTGUN_BODY
	if squad_type == "medic":
		return MEDIC_BODY
	return BODY


func _build() -> void:
	var skin: Color = look.get("skin", SKIN.lerp(SKIN_DARK, randf() * randf()))
	var top: Color = look.get("top", _vest_for_type())
	var pants: Color = look.get("pants", PANTS)
	var hat: String = str(look.get("hat", "helmet"))
	var hair_style: String = str(look.get("hair_style", HAIR_STYLES[randi() % HAIR_STYLES.size()]))
	var hair: Color = look.get("hair", HAIR_COLORS[randi() % HAIR_COLORS.size()])
	var weapon: String = str(look.get("weapon", "standard"))
	var back: String = str(look.get("back", "pack"))

	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, 0.5, 0.0)
		var leg := Mats.capsule(0.085, 0.4, pants)
		leg.position.y = -0.22
		hip.add_child(leg)
		if detailed:
			var boot := Mats.box(Vector3(0.15, 0.09, 0.22), BOOT)
			boot.position = Vector3(0.0, -0.44, -0.03)
			hip.add_child(boot)
		add_child(hip)
		_legs.append(hip)

	var torso := Mats.capsule(0.2, 0.52, top)
	torso.position.y = 0.76
	add_child(torso)

	var head := Mats.sphere(0.155, skin)
	head.position.y = 1.2
	add_child(head)
	if detailed:
		for side in [-1.0, 1.0]:
			var eye := Mats.sphere(0.028, EYE)
			eye.position = Vector3(side * 0.055, 1.22, -0.135)
			add_child(eye)
		if not COVERS_HAIR.has(hat):
			_add_hair(hair_style, hair)
	_add_hat(hat, top)

	_gun = Node3D.new()
	_gun.position = Vector3(0.12, 0.88, -0.2)
	add_child(_gun)
	_add_gun(weapon)

	if not detailed:
		return

	var chest := Mats.box(Vector3(0.28, 0.22, 0.1), top.lightened(0.25))
	chest.position = Vector3(0.0, 0.78, -0.18)
	add_child(chest)
	var belt := Mats.torus(0.19, 0.23, BOOT)
	belt.position.y = 0.56
	add_child(belt)
	_add_back(back, top)
	if squad_type == "medic":
		var cross_v := Mats.box(Vector3(0.06, 0.18, 0.03), CROSS)
		cross_v.position = Vector3(0.0, 0.8, -0.235)
		add_child(cross_v)
		var cross_h := Mats.box(Vector3(0.18, 0.06, 0.03), CROSS)
		cross_h.position = Vector3(0.0, 0.8, -0.235)
		add_child(cross_h)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.25, 0.92, -0.02)
		shoulder.rotation_degrees.x = 75.0
		var arm := Mats.capsule(0.07, 0.42, top)
		arm.position.y = -0.2
		shoulder.add_child(arm)
		var hand := Mats.sphere(0.06, skin)
		hand.position.y = -0.4
		shoulder.add_child(hand)
		add_child(shoulder)
	if hero:
		_tag = Label3D.new()
		_tag.text = str(look.get("name", ""))
		_tag.font_size = 72
		_tag.pixel_size = 0.0045
		_tag.outline_size = 18
		_tag.modulate = Color(1.0, 0.95, 0.6)
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.no_depth_test = true
		_tag.position.y = 1.78 if hat in ["wizard", "party", "halo"] else 1.62
		add_child(_tag)


func _add_hair(style: String, color: Color) -> void:
	match style:
		"short":
			var h := Mats.sphere(0.165, color)
			h.position = Vector3(0.0, 1.245, 0.02)
			h.scale = Vector3(1.0, 0.6, 1.0)
			add_child(h)
		"bun":
			var h := Mats.sphere(0.165, color)
			h.position = Vector3(0.0, 1.245, 0.02)
			h.scale = Vector3(1.0, 0.6, 1.0)
			add_child(h)
			var bun := Mats.sphere(0.07, color)
			bun.position = Vector3(0.0, 1.3, 0.14)
			add_child(bun)
		"spiky":
			for i in range(3):
				var spike := Mats.cone(0.05, 0.16, color)
				spike.position = Vector3((float(i) - 1.0) * 0.08, 1.38, 0.0)
				spike.rotation_degrees.z = (float(i) - 1.0) * -25.0
				add_child(spike)
			var base := Mats.sphere(0.16, color)
			base.position = Vector3(0.0, 1.26, 0.0)
			base.scale = Vector3(1.0, 0.5, 1.0)
			add_child(base)
		"long":
			var h := Mats.sphere(0.165, color)
			h.position = Vector3(0.0, 1.245, 0.02)
			h.scale = Vector3(1.0, 0.6, 1.0)
			add_child(h)
			var fall := Mats.box(Vector3(0.26, 0.34, 0.1), color)
			fall.position = Vector3(0.0, 1.08, 0.13)
			add_child(fall)
		"curly":
			var h := Mats.sphere(0.2, color)
			h.position = Vector3(0.0, 1.27, 0.01)
			h.scale = Vector3(1.0, 0.75, 1.0)
			add_child(h)
		"mohawk":
			var strip := Mats.box(Vector3(0.06, 0.16, 0.26), color)
			strip.position = Vector3(0.0, 1.38, 0.0)
			add_child(strip)
		_:
			pass


func _add_hat(hat: String, top: Color) -> void:
	match hat:
		"helmet":
			var helmet := Mats.sphere(0.19, HELMET)
			helmet.position.y = 1.26
			helmet.scale = Vector3(1.0, 0.72, 1.0)
			add_child(helmet)
			# A pale band round the helmet: the squad reads as people from
			# above, not as a pile of olive domes.
			var band := Mats.torus(0.17, 0.205, BAND)
			band.position.y = 1.25
			add_child(band)
			if detailed:
				var visor := Mats.box(Vector3(0.2, 0.07, 0.05), VISOR)
				visor.position = Vector3(0.0, 1.2, -0.15)
				add_child(visor)
		"cap":
			var dome := Mats.sphere(0.17, top)
			dome.position.y = 1.27
			dome.scale = Vector3(1.0, 0.55, 1.0)
			add_child(dome)
			var brim := Mats.box(Vector3(0.22, 0.03, 0.16), top.darkened(0.2))
			brim.position = Vector3(0.0, 1.26, -0.2)
			add_child(brim)
		"beanie":
			var dome := Mats.sphere(0.185, top.darkened(0.1))
			dome.position.y = 1.27
			dome.scale = Vector3(1.0, 0.8, 1.0)
			add_child(dome)
			var pom := Mats.sphere(0.06, BAND)
			pom.position.y = 1.44
			add_child(pom)
		"headband":
			var band := Mats.torus(0.15, 0.185, Color(0.9, 0.2, 0.2))
			band.position.y = 1.27
			add_child(band)
		"cat":
			for side in [-1.0, 1.0]:
				var ear := Mats.cone(0.06, 0.14, Color(0.2, 0.2, 0.22))
				ear.position = Vector3(side * 0.1, 1.38, 0.0)
				ear.rotation_degrees.z = side * -20.0
				add_child(ear)
		"party":
			var cone := Mats.cone(0.1, 0.3, Color(1.0, 0.4, 0.7))
			cone.position.y = 1.46
			add_child(cone)
			var pom := Mats.sphere(0.04, Color(1.0, 0.9, 0.2))
			pom.position.y = 1.62
			add_child(pom)
		"viking":
			var dome := Mats.sphere(0.19, Color(0.55, 0.55, 0.6))
			dome.position.y = 1.26
			dome.scale = Vector3(1.0, 0.72, 1.0)
			add_child(dome)
			for side in [-1.0, 1.0]:
				var horn := Mats.cone(0.05, 0.22, BAND)
				horn.position = Vector3(side * 0.2, 1.36, 0.0)
				horn.rotation_degrees.z = side * -55.0
				add_child(horn)
		"crown":
			var ring := Mats.torus(0.13, 0.17, Color(1.0, 0.8, 0.2))
			ring.position.y = 1.33
			add_child(ring)
			for i in range(4):
				var a := float(i) * TAU / 4.0
				var point := Mats.cone(0.035, 0.1, Color(1.0, 0.8, 0.2))
				point.position = Vector3(sin(a) * 0.14, 1.4, cos(a) * 0.14)
				add_child(point)
		"wizard":
			var cone := Mats.cone(0.17, 0.42, Color(0.3, 0.15, 0.6))
			cone.position.y = 1.48
			add_child(cone)
			var brim := Mats.torus(0.14, 0.26, Color(0.3, 0.15, 0.6))
			brim.position.y = 1.28
			add_child(brim)
		"halo":
			_halo = Mats.torus(0.11, 0.15, Color(1.0, 0.9, 0.4), true)
			_halo.position.y = 1.5
			add_child(_halo)
		_:
			pass


func _add_gun(weapon: String) -> void:
	var main := GUN
	var accent := GUN
	var glow := false
	match weapon:
		"wood":
			main = Color(0.45, 0.28, 0.14)
			accent = Color(0.3, 0.32, 0.36)
		"candy":
			main = Color(1.0, 0.55, 0.75)
			accent = Color(1.0, 1.0, 1.0)
		"ice":
			main = Color(0.65, 0.88, 1.0)
			accent = Color(0.9, 0.98, 1.0)
		"neon":
			main = Color(0.2, 1.0, 0.9)
			accent = Color(1.0, 0.2, 0.9)
			glow = true
		"gold":
			main = Color(1.0, 0.8, 0.2)
			accent = Color(0.9, 0.6, 0.1)
		_:
			pass
	var barrel := Mats.box(Vector3(0.11, 0.11, 0.4) if shotgun else Vector3(0.085, 0.085, 0.58), main, glow)
	barrel.position.z = -0.24
	_gun.add_child(barrel)
	var receiver := Mats.box(Vector3(0.09, 0.13, 0.22), accent if weapon != "standard" else GUN, glow)
	receiver.position.z = 0.06
	_gun.add_child(receiver)
	_muzzle = Mats.box(Vector3(0.16, 0.16, 0.22), MUZZLE, true)
	_muzzle.position.z = -0.52
	_muzzle.visible = false
	_gun.add_child(_muzzle)
	if detailed:
		var mag := Mats.box(Vector3(0.06, 0.12, 0.07), accent, glow)
		mag.position = Vector3(0.0, -0.12, 0.02)
		_gun.add_child(mag)
		if weapon == "candy":
			var stripe := Mats.box(Vector3(0.09, 0.09, 0.08), accent)
			stripe.position.z = -0.3
			_gun.add_child(stripe)


func _add_back(back: String, top: Color) -> void:
	match back:
		"pack":
			var pack := Mats.box(Vector3(0.22, 0.26, 0.13), top.darkened(0.35))
			pack.position = Vector3(0.0, 0.8, 0.21)
			add_child(pack)
		"cape_red", "cape_blue":
			_cape = Node3D.new()
			_cape.position = Vector3(0.0, 1.0, 0.16)
			var cloth := Mats.box(Vector3(0.4, 0.55, 0.03), Color(0.85, 0.15, 0.15) if back == "cape_red" else Color(0.15, 0.3, 0.9))
			cloth.position.y = -0.28
			_cape.add_child(cloth)
			add_child(_cape)
		"wings":
			for side in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(side * 0.12, 0.95, 0.18)
				var feather := Mats.sphere(0.2, Color(0.97, 0.97, 1.0))
				feather.position = Vector3(side * 0.18, 0.05, 0.0)
				feather.scale = Vector3(1.4, 0.7, 0.25)
				w.add_child(feather)
				add_child(w)
				_wings.append(w)
		"jetpack":
			for side in [-1.0, 1.0]:
				var tank := Mats.capsule(0.07, 0.3, Color(0.7, 0.72, 0.75))
				tank.position = Vector3(side * 0.09, 0.82, 0.22)
				add_child(tank)
			_flame = Mats.cone(0.07, 0.18, Color(1.0, 0.6, 0.15), true)
			_flame.position = Vector3(0.0, 0.58, 0.22)
			_flame.rotation_degrees.x = 180.0
			add_child(_flame)
		_:
			pass


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
	if _cape != null:
		_cape.rotation.x = -0.35 - absf(sin(t * 0.5)) * 0.25
	for i in range(_wings.size()):
		_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * (0.3 + sin(t * 0.6) * 0.35)
	if _flame != null:
		_flame.scale = Vector3(1.0, 0.8 + absf(sin(t * 1.3)) * 0.6, 1.0)
	if _halo != null:
		_halo.position.y = 1.5 + sin(t * 0.3) * 0.03
		_halo.rotation.y = t * 0.1
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 12.0)
		_gun.position.z = -0.2 + _recoil * 0.1
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_muzzle.visible = false
