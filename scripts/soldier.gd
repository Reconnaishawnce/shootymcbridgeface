class_name Soldier
extends Node3D
## One visible squad member: a round, big-headed little person built from
## smooth primitives and dressed from a look. Short legs that run, rounded
## shoes, an egg of a body, a face with big eyes, cheeks and a smile, hair,
## a hat, stubby arms on a small gun that recoils, and something on the
## back. The hero at the front carries a name tag. Purely cosmetic: the
## squad owns the count.
##
## The front of the formation gets the detailed build (face, arms, hair,
## back); the crowd behind it gets a cheaper one so a 60-soldier squad
## stays well under a thousand draw calls on a phone.
##
## Look keys (all optional): hero, name, skin, hair, hair_style (short,
## bun, spiky, long, curly, mohawk, bald, none), top, pants, hat (helmet,
## cap, beanie, headband, cat, party, viking, crown, wizard, halo, bunny,
## chef, none), weapon (standard, wood, candy, ice, neon, gold), back
## (pack, cape_red, cape_blue, wings, jetpack, balloon, shell, none), crew.

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
const EYE_WHITE := Color(0.98, 0.98, 1.0)
const EYE := Color(0.1, 0.1, 0.14)
const CHEEK := Color(1.0, 0.55, 0.6, 0.6)
const MOUTH := Color(0.5, 0.15, 0.2)
const GUN := Color(0.3, 0.32, 0.36)
const BAND := Color(0.92, 0.92, 0.88)
const MUZZLE := Color(1.0, 0.85, 0.3)
const PACK := Color(0.28, 0.3, 0.22)
const HAIR_COLORS := [Color(0.35, 0.22, 0.12), Color(0.08, 0.06, 0.05), Color(0.95, 0.55, 0.2), Color(0.85, 0.75, 0.45), Color(0.3, 0.2, 0.55), Color(0.5, 0.5, 0.5)]
const HAIR_STYLES := ["short", "bun", "spiky", "curly", "short", "bald"]
## Hats that cover the hair completely.
const COVERS_HAIR := ["helmet", "beanie", "wizard", "viking", "chef"]
const RAINBOW := [Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.2), Color(0.3, 0.85, 0.4), Color(0.25, 0.6, 1.0), Color(0.6, 0.35, 0.9), Color(1.0, 0.45, 0.75)]

## Where the head sits and how big it is: everything on it is placed
## relative to these.
const HEAD_Y := 1.08
const HEAD_R := 0.24

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
var _balloon: Node3D
var _arms: Array[Node3D] = []
var _tag: Label3D
var _cheer_t := 0.0
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
	var top: Color = look.get("top", RAINBOW[randi() % RAINBOW.size()] if str(look.get("crew", "")) == "rainbow" else _vest_for_type())
	var pants: Color = look.get("pants", PANTS)
	var hat: String = str(look.get("hat", "helmet"))
	var hair_style: String = str(look.get("hair_style", HAIR_STYLES[randi() % HAIR_STYLES.size()]))
	var hair: Color = look.get("hair", HAIR_COLORS[randi() % HAIR_COLORS.size()])
	var weapon: String = str(look.get("weapon", "standard"))
	var back: String = str(look.get("back", "pack"))

	# Short legs with round shoes.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, 0.38, 0.0)
		var leg := Mats.pill(0.08, 0.24, pants)
		leg.position.y = -0.14
		hip.add_child(leg)
		var shoe := Mats.ball(0.095, BOOT)
		shoe.position = Vector3(0.0, -0.3, -0.03)
		shoe.scale = Vector3(1.05, 0.65, 1.35)
		hip.add_child(shoe)
		add_child(hip)
		_legs.append(hip)

	# An egg of a body.
	var body := Mats.ball(0.235, top)
	body.position.y = 0.64
	body.scale = Vector3(1.0, 1.08, 0.92)
	add_child(body)

	# A big round head.
	var head := Mats.ball(HEAD_R, skin)
	head.position.y = HEAD_Y
	add_child(head)
	if detailed:
		_add_face()
		if not COVERS_HAIR.has(hat):
			_add_hair(hair_style, hair)
	_add_hat(hat, top)

	_gun = Node3D.new()
	_gun.position = Vector3(0.14, 0.6, -0.3)
	_gun.scale = Vector3.ONE * 0.85
	add_child(_gun)
	_add_gun(weapon)

	if not detailed:
		return

	var belt := Mats.torus(0.2, 0.245, BOOT)
	belt.position.y = 0.48
	belt.scale.y = 0.6
	add_child(belt)
	var buckle := Mats.ball(0.035, Color(1.0, 0.85, 0.3))
	buckle.position = Vector3(0.0, 0.48, -0.225)
	add_child(buckle)
	_add_back(back, top)
	if squad_type == "medic":
		var cross_v := Mats.box(Vector3(0.06, 0.18, 0.03), CROSS)
		cross_v.position = Vector3(0.0, 0.68, -0.225)
		add_child(cross_v)
		var cross_h := Mats.box(Vector3(0.18, 0.06, 0.03), CROSS)
		cross_h.position = Vector3(0.0, 0.68, -0.225)
		add_child(cross_h)
	# Stubby arms, both on the gun.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.24, 0.76, -0.02)
		shoulder.rotation_degrees.x = 75.0
		var arm := Mats.pill(0.065, 0.26, top)
		arm.position.y = -0.14
		shoulder.add_child(arm)
		var hand := Mats.ball(0.07, skin)
		hand.position.y = -0.3
		shoulder.add_child(hand)
		add_child(shoulder)
		_arms.append(shoulder)
	if hero:
		_tag = Label3D.new()
		_tag.text = str(look.get("name", ""))
		_tag.font_size = 72
		_tag.pixel_size = 0.0045
		_tag.outline_size = 18
		_tag.modulate = Color(1.0, 0.95, 0.6)
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.no_depth_test = true
		_tag.position.y = 1.9 if hat in ["wizard", "party", "halo", "bunny", "chef"] else 1.62
		add_child(_tag)


## Big eyes with a catchlight, pink cheeks, a small smile.
func _add_face() -> void:
	for side in [-1.0, 1.0]:
		var white := Mats.ball(0.058, EYE_WHITE)
		white.position = Vector3(side * 0.09, HEAD_Y + 0.03, -HEAD_R + 0.04)
		white.scale = Vector3(1.0, 1.25, 0.6)
		add_child(white)
		var pupil := Mats.ball(0.034, EYE)
		pupil.position = Vector3(side * 0.09, HEAD_Y + 0.025, -HEAD_R + 0.005)
		pupil.scale = Vector3(1.0, 1.3, 0.5)
		add_child(pupil)
		var shine := Mats.box(Vector3(0.016, 0.016, 0.01), EYE_WHITE, true)
		shine.position = Vector3(side * 0.09 - 0.012, HEAD_Y + 0.045, -HEAD_R - 0.012)
		add_child(shine)
		var cheek := Mats.ball(0.04, CHEEK)
		cheek.position = Vector3(side * 0.16, HEAD_Y - 0.05, -HEAD_R + 0.07)
		cheek.scale = Vector3(1.0, 0.7, 0.4)
		add_child(cheek)
	var mouth := Mats.ball(0.03, MOUTH)
	mouth.position = Vector3(0.0, HEAD_Y - 0.1, -HEAD_R + 0.02)
	mouth.scale = Vector3(1.9, 0.45, 0.4)
	add_child(mouth)


func _add_hair(style: String, color: Color) -> void:
	var cap_y := HEAD_Y + 0.07
	match style:
		"short":
			var h := Mats.ball(HEAD_R + 0.015, color)
			h.position = Vector3(0.0, cap_y, 0.02)
			h.scale = Vector3(1.0, 0.62, 1.0)
			add_child(h)
		"bun":
			var h := Mats.ball(HEAD_R + 0.015, color)
			h.position = Vector3(0.0, cap_y, 0.02)
			h.scale = Vector3(1.0, 0.62, 1.0)
			add_child(h)
			var bun := Mats.ball(0.1, color)
			bun.position = Vector3(0.0, HEAD_Y + 0.17, 0.2)
			add_child(bun)
		"spiky":
			for i in range(3):
				var spike := Mats.cone(0.07, 0.22, color)
				spike.position = Vector3((float(i) - 1.0) * 0.12, HEAD_Y + 0.33, 0.0)
				spike.rotation_degrees.z = (float(i) - 1.0) * -28.0
				add_child(spike)
			var base := Mats.ball(HEAD_R + 0.01, color)
			base.position = Vector3(0.0, cap_y + 0.02, 0.0)
			base.scale = Vector3(1.0, 0.5, 1.0)
			add_child(base)
		"long":
			var h := Mats.ball(HEAD_R + 0.015, color)
			h.position = Vector3(0.0, cap_y, 0.02)
			h.scale = Vector3(1.0, 0.62, 1.0)
			add_child(h)
			var fall := Mats.ball(0.2, color)
			fall.position = Vector3(0.0, HEAD_Y - 0.12, 0.17)
			fall.scale = Vector3(1.25, 1.5, 0.55)
			add_child(fall)
		"curly":
			var h := Mats.ball(HEAD_R + 0.06, color)
			h.position = Vector3(0.0, HEAD_Y + 0.09, 0.01)
			h.scale = Vector3(1.0, 0.78, 1.0)
			add_child(h)
			for i in range(5):
				var a := float(i) * TAU / 5.0
				var curl := Mats.ball(0.075, color)
				curl.position = Vector3(sin(a) * 0.24, HEAD_Y + 0.14 + cos(a * 2.0) * 0.03, cos(a) * 0.24)
				add_child(curl)
		"mohawk":
			var strip := Mats.pill(0.055, 0.36, color)
			strip.position = Vector3(0.0, HEAD_Y + 0.29, 0.0)
			strip.rotation_degrees.x = 90.0
			add_child(strip)
		_:
			pass


func _add_hat(hat: String, top: Color) -> void:
	match hat:
		"helmet":
			var helmet := Mats.ball(HEAD_R + 0.05, HELMET)
			helmet.position.y = HEAD_Y + 0.08
			helmet.scale = Vector3(1.0, 0.74, 1.0)
			add_child(helmet)
			# A pale band round the helmet: the squad reads as people from
			# above, not as a pile of olive domes.
			var band := Mats.torus(HEAD_R + 0.02, HEAD_R + 0.065, BAND)
			band.position.y = HEAD_Y + 0.06
			add_child(band)
			if detailed:
				var visor := Mats.box(Vector3(0.3, 0.07, 0.05), VISOR)
				visor.position = Vector3(0.0, HEAD_Y + 0.11, -HEAD_R - 0.04)
				add_child(visor)
		"cap":
			var dome := Mats.ball(HEAD_R + 0.03, top)
			dome.position.y = HEAD_Y + 0.08
			dome.scale = Vector3(1.0, 0.55, 1.0)
			add_child(dome)
			var brim := Mats.ball(0.16, top.darkened(0.2))
			brim.position = Vector3(0.0, HEAD_Y + 0.07, -HEAD_R - 0.1)
			brim.scale = Vector3(1.1, 0.12, 1.0)
			add_child(brim)
		"beanie":
			var dome := Mats.ball(HEAD_R + 0.045, top.darkened(0.1))
			dome.position.y = HEAD_Y + 0.08
			dome.scale = Vector3(1.0, 0.85, 1.0)
			add_child(dome)
			var pom := Mats.ball(0.075, BAND)
			pom.position.y = HEAD_Y + 0.36
			add_child(pom)
		"headband":
			var band := Mats.torus(HEAD_R - 0.02, HEAD_R + 0.03, Color(0.9, 0.2, 0.2))
			band.position.y = HEAD_Y + 0.1
			add_child(band)
		"cat":
			for side in [-1.0, 1.0]:
				var ear := Mats.cone(0.08, 0.17, Color(0.2, 0.2, 0.22))
				ear.position = Vector3(side * 0.15, HEAD_Y + 0.29, 0.0)
				ear.rotation_degrees.z = side * -22.0
				add_child(ear)
				var inner := Mats.cone(0.04, 0.1, Color(1.0, 0.65, 0.75))
				inner.position = Vector3(side * 0.15, HEAD_Y + 0.27, -0.03)
				inner.rotation_degrees.z = side * -22.0
				add_child(inner)
		"party":
			var cone := Mats.cone(0.13, 0.36, Color(1.0, 0.4, 0.7))
			cone.position.y = HEAD_Y + 0.38
			add_child(cone)
			var pom := Mats.ball(0.05, Color(1.0, 0.9, 0.2))
			pom.position.y = HEAD_Y + 0.58
			add_child(pom)
		"viking":
			var dome := Mats.ball(HEAD_R + 0.05, Color(0.55, 0.55, 0.6))
			dome.position.y = HEAD_Y + 0.08
			dome.scale = Vector3(1.0, 0.74, 1.0)
			add_child(dome)
			for side in [-1.0, 1.0]:
				var horn := Mats.cone(0.06, 0.26, BAND)
				horn.position = Vector3(side * 0.3, HEAD_Y + 0.2, 0.0)
				horn.rotation_degrees.z = side * -55.0
				add_child(horn)
		"crown":
			var ring := Mats.torus(0.19, 0.24, Color(1.0, 0.8, 0.2))
			ring.position.y = HEAD_Y + 0.2
			add_child(ring)
			for i in range(5):
				var a := float(i) * TAU / 5.0
				var point := Mats.cone(0.04, 0.12, Color(1.0, 0.8, 0.2))
				point.position = Vector3(sin(a) * 0.2, HEAD_Y + 0.28, cos(a) * 0.2)
				add_child(point)
			var jewel := Mats.ball(0.035, Color(0.9, 0.2, 0.4))
			jewel.position = Vector3(0.0, HEAD_Y + 0.22, -0.22)
			add_child(jewel)
		"wizard":
			var cone := Mats.cone(0.25, 0.5, Color(0.3, 0.15, 0.6))
			cone.position.y = HEAD_Y + 0.42
			add_child(cone)
			var brim := Mats.torus(0.2, 0.38, Color(0.3, 0.15, 0.6))
			brim.position.y = HEAD_Y + 0.18
			add_child(brim)
			var star := Mats.ball(0.04, Color(1.0, 0.9, 0.3))
			star.position = Vector3(0.0, HEAD_Y + 0.4, -0.17)
			add_child(star)
		"halo":
			_halo = Mats.torus(0.16, 0.21, Color(1.0, 0.9, 0.4), true)
			_halo.position.y = HEAD_Y + 0.42
			add_child(_halo)
		"bunny":
			for side in [-1.0, 1.0]:
				var ear := Mats.pill(0.055, 0.36, Color(0.97, 0.95, 0.95))
				ear.position = Vector3(side * 0.1, HEAD_Y + 0.4, 0.0)
				ear.rotation_degrees.z = side * -12.0
				add_child(ear)
				var inner := Mats.pill(0.025, 0.22, Color(1.0, 0.7, 0.8))
				inner.position = Vector3(side * 0.1, HEAD_Y + 0.4, -0.035)
				inner.rotation_degrees.z = side * -12.0
				add_child(inner)
		"chef":
			var toque := Mats.pill(0.22, 0.5, Color(0.98, 0.98, 0.98))
			toque.position.y = HEAD_Y + 0.34
			add_child(toque)
			var band := Mats.torus(HEAD_R - 0.03, HEAD_R + 0.02, Color(0.98, 0.98, 0.98))
			band.position.y = HEAD_Y + 0.17
			add_child(band)
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
	var barrel: MeshInstance3D
	if glow:
		barrel = Mats.box(Vector3(0.11, 0.11, 0.4) if shotgun else Vector3(0.085, 0.085, 0.58), main, true)
	else:
		barrel = Mats.pill(0.055 if shotgun else 0.042, 0.4 if shotgun else 0.58, main)
		barrel.rotation_degrees.x = 90.0
	barrel.position.z = -0.24
	_gun.add_child(barrel)
	var receiver := Mats.box(Vector3(0.09, 0.13, 0.22), accent if weapon != "standard" else GUN, glow)
	receiver.position.z = 0.06
	_gun.add_child(receiver)
	_muzzle = Mats.box(Vector3(0.16, 0.16, 0.22), MUZZLE, true)
	_muzzle.material_override = Mats.glow(MUZZLE, 3.0)
	_muzzle.position.z = -0.52
	_muzzle.visible = false
	_gun.add_child(_muzzle)
	if detailed:
		var mag := Mats.box(Vector3(0.06, 0.12, 0.07), accent, glow)
		mag.position = Vector3(0.0, -0.12, 0.02)
		_gun.add_child(mag)
		if weapon == "candy":
			var stripe := Mats.torus(0.04, 0.06, accent)
			stripe.position.z = -0.3
			stripe.rotation_degrees.x = 90.0
			_gun.add_child(stripe)


func _add_back(back: String, top: Color) -> void:
	match back:
		"pack":
			var pack := Mats.pill(0.11, 0.26, top.darkened(0.35))
			pack.position = Vector3(0.0, 0.66, 0.22)
			pack.scale = Vector3(1.3, 1.0, 0.8)
			add_child(pack)
		"cape_red", "cape_blue":
			_cape = Node3D.new()
			_cape.position = Vector3(0.0, 0.84, 0.16)
			var cloth := Mats.box(Vector3(0.42, 0.5, 0.03), Color(0.85, 0.15, 0.15) if back == "cape_red" else Color(0.15, 0.3, 0.9))
			cloth.position.y = -0.25
			_cape.add_child(cloth)
			add_child(_cape)
		"wings":
			for side in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(side * 0.12, 0.78, 0.18)
				var feather := Mats.ball(0.2, Color(0.97, 0.97, 1.0))
				feather.position = Vector3(side * 0.18, 0.05, 0.0)
				feather.scale = Vector3(1.4, 0.7, 0.25)
				w.add_child(feather)
				add_child(w)
				_wings.append(w)
		"jetpack":
			for side in [-1.0, 1.0]:
				var tank := Mats.pill(0.07, 0.3, Color(0.7, 0.72, 0.75))
				tank.position = Vector3(side * 0.09, 0.66, 0.24)
				add_child(tank)
			_flame = Mats.cone(0.07, 0.18, Color(1.0, 0.6, 0.15), true)
			_flame.position = Vector3(0.0, 0.42, 0.24)
			_flame.rotation_degrees.x = 180.0
			add_child(_flame)
		"balloon":
			_balloon = Node3D.new()
			_balloon.position = Vector3(0.0, 0.75, 0.2)
			var string := Mats.box(Vector3(0.015, 0.7, 0.015), BAND)
			string.position.y = 0.35
			_balloon.add_child(string)
			var ball := Mats.ball(0.17, RAINBOW[randi() % RAINBOW.size()])
			ball.position.y = 0.85
			ball.scale = Vector3(1.0, 1.15, 1.0)
			_balloon.add_child(ball)
			add_child(_balloon)
		"shell":
			var shell := Mats.ball(0.27, Color(0.35, 0.55, 0.3))
			shell.position = Vector3(0.0, 0.66, 0.2)
			shell.scale = Vector3(1.0, 1.1, 0.6)
			add_child(shell)
			var rim := Mats.torus(0.2, 0.28, Color(0.85, 0.75, 0.45))
			rim.position = Vector3(0.0, 0.66, 0.12)
			rim.rotation_degrees.x = 90.0
			add_child(rim)
		_:
			pass


## A jump with the arms up. The hero jumps higher.
func cheer() -> void:
	_cheer_t = 1.0


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
	if _cheer_t > 0.0:
		_cheer_t = maxf(0.0, _cheer_t - delta * 1.1)
		var hop := sin(_cheer_t * PI * 2.0)
		position.y += maxf(0.0, hop) * (0.55 if hero else 0.3)
		for a in _arms:
			a.rotation_degrees.x = lerpf(75.0, -160.0, clampf(_cheer_t * 1.6, 0.0, 1.0))
	if _balloon != null:
		_balloon.rotation.x = sin(t * 0.25) * 0.15
		_balloon.rotation.z = cos(t * 0.2) * 0.12
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(t + PI * i) * 0.7
	if _cape != null:
		_cape.rotation.x = -0.35 - absf(sin(t * 0.5)) * 0.25
	for i in range(_wings.size()):
		_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * (0.3 + sin(t * 0.6) * 0.35)
	if _flame != null:
		_flame.scale = Vector3(1.0, 0.8 + absf(sin(t * 1.3)) * 0.6, 1.0)
	if _halo != null:
		_halo.position.y = HEAD_Y + 0.42 + sin(t * 0.3) * 0.03
		_halo.rotation.y = t * 0.1
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 12.0)
		_gun.position.z = -0.3 + _recoil * 0.1
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_muzzle.visible = false
