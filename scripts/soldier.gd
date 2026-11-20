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

const BODY := Palette.SOLDIER
const SHOTGUN_BODY := Color(0.95, 0.52, 0.16)
const MEDIC_BODY := Color(0.92, 0.92, 0.9)
const SNIPER_BODY := Color(0.2, 0.58, 0.38)
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
## Chunky: a head almost as wide as the body, short legs, a big gun.
const HEAD_Y := 1.1
## Where the trunk turns: the middle of the body.
const TRUNK_Y := 0.62
const HEAD_R := 0.28

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
var _torso: MeshInstance3D
## Parts of the group being welded, while its builder runs.
var _into: Array = []
var _head: MeshInstance3D
var _squash_t := 0.0
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


## A veteran wears a beret in the colour of their trait. The name lives
## in the banners and the pause menu, not over the squad: three tags on
## three adjacent heads only read as one smear.
func set_veteran(v: Dictionary, _rank: int = 0) -> void:
	clear_veteran()
	var color := Veterans.color(str(v.trait))
	var beret := Mats.ball(HEAD_R + 0.07, color)
	beret.position = Vector3(0.0, HEAD_Y + 0.17, -0.03)
	beret.scale = Vector3(1.05, 0.42, 1.05)
	beret.name = "VetBeret"
	add_child(Mats.ink(beret, 0.02) if detailed else beret)
	set_meta("vet_name", str(v.name))


func veteran_name() -> String:
	return str(get_meta("vet_name", ""))


func clear_veteran() -> void:
	var node := get_node_or_null("VetBeret")
	if node != null:
		node.name = "VetBeretOld"
		node.queue_free()
	set_meta("vet_name", "")


func _vest_for_type() -> Color:
	if shotgun:
		return SHOTGUN_BODY
	if squad_type == "medic":
		return MEDIC_BODY
	if squad_type == "sniper":
		return SNIPER_BODY
	return BODY


## A soldier is a handful of welded meshes: two legs, a trunk, a head
## (with its face, hair and hat), a gun, and two arms up front. Each is
## made once per look and shared, so the sixty bodies of a full squad
## are three hundred draws, not two thousand.
func _build() -> void:
	# Six skin tones, not a different one each: soldiers of one tone and
	# one outfit share their head.
	var skin: Color = look.get("skin", SKIN.lerp(SKIN_DARK, snappedf(randf() * randf(), 0.2)))
	var top: Color = look.get("top", RAINBOW[randi() % RAINBOW.size()] if str(look.get("crew", "")) == "rainbow" else _vest_for_type())
	var pants: Color = look.get("pants", PANTS)
	var hat: String = str(look.get("hat", "helmet"))
	var hair_style: String = str(look.get("hair_style", HAIR_STYLES[randi() % HAIR_STYLES.size()]))
	var hair: Color = look.get("hair", HAIR_COLORS[randi() % HAIR_COLORS.size()])
	var weapon: String = str(look.get("weapon", "standard"))
	var back: String = str(look.get("back", "pack"))
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The front ranks get the ink line; the crowd behind stays cheap.
	var ink_w := 0.022 if detailed else 0.0

	# Short thick legs with big round boots.
	for side in [-1.0, 1.0]:
		var hip := Mats.weld("sleg|" + pants.to_html(false), func() -> Array: return _leg_parts(pants))
		hip.position = Vector3(side * 0.12, 0.38, 0.0)
		hip.cast_shadow = off
		add_child(hip)
		_legs.append(hip)

	# A barrel of a body, and what is strapped to it.
	var medic := detailed and squad_type == "medic"
	var trunk_key := "strunk|%s|%s|%s|%s" % [detailed, top.to_html(false), back if detailed else "", medic]
	_torso = Mats.weld(trunk_key, func() -> Array: return _trunk_parts(top, back, medic, ink_w), Vector3(0.0, TRUNK_Y, 0.0))
	_torso.position.y = TRUNK_Y
	add_child(_torso)

	# A big round head, no neck to speak of, with its face and its hat.
	var hairy := detailed and not COVERS_HAIR.has(hat)
	var head_key := "shead|%s|%s|%s|%s|%s|%s|%s" % [detailed, skin.to_html(false), hat, look.has("hat"), top.to_html(false), hair_style if hairy else "", hair.to_html(false) if hairy else ""]
	_head = Mats.weld(head_key, func() -> Array: return _head_parts(skin, hat, top, hair_style if hairy else "", hair, ink_w), Vector3(0.0, HEAD_Y, 0.0))
	_head.position.y = HEAD_Y
	add_child(_head)
	if hat == "halo":
		_halo = Mats.torus(0.16, 0.21, Color(1.0, 0.9, 0.4), true)
		_halo.position.y = HEAD_Y + 0.42
		add_child(_halo)

	_gun = Node3D.new()
	_gun.position = Vector3(0.17, 0.58, -0.34)
	_gun.scale = Vector3.ONE * 1.05
	add_child(_gun)
	_add_gun(weapon)

	if not detailed:
		return

	_add_back(back)
	# Stubby arms, both on the gun.
	for side in [-1.0, 1.0]:
		var shoulder := Mats.weld("sarm|%s|%s" % [top.to_html(false), skin.to_html(false)], func() -> Array: return _arm_parts(top, skin))
		shoulder.position = Vector3(side * 0.28, 0.76, -0.02)
		shoulder.rotation_degrees.x = 75.0
		shoulder.cast_shadow = off
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


## A part of the group being welded. The builders below place parts in
## the soldier's own space; the weld takes the group's origin off them.
func _put(part: Node3D) -> void:
	_into.append(part)


func _leg_parts(pants: Color) -> Array:
	var leg := Mats.pill(0.095, 0.24, pants)
	leg.position.y = -0.14
	var shoe := Mats.ball(0.11, BOOT)
	shoe.position = Vector3(0.0, -0.3, -0.03)
	shoe.scale = Vector3(1.05, 0.65, 1.4)
	return [leg, shoe]


func _arm_parts(top: Color, skin: Color) -> Array:
	var arm := Mats.pill(0.078, 0.26, top)
	arm.position.y = -0.14
	var hand := Mats.ball(0.085, skin)
	hand.position.y = -0.3
	return [arm, hand]


func _trunk_parts(top: Color, back: String, medic: bool, ink_w: float) -> Array:
	_into = []
	var body := Mats.ball(0.27, top)
	body.position.y = TRUNK_Y
	body.scale = Vector3(1.05, 1.0, 0.95)
	if ink_w > 0.0:
		Mats.ink(body, ink_w)
	_put(body)
	if detailed:
		var belt := Mats.torus(0.23, 0.285, BOOT)
		belt.position.y = 0.46
		belt.scale.y = 0.6
		_put(belt)
		var buckle := Mats.ball(0.035, Color(1.0, 0.85, 0.3))
		buckle.position = Vector3(0.0, 0.46, -0.26)
		_put(buckle)
		_add_back_fixed(back, top)
		if medic:
			var cross_v := Mats.box(Vector3(0.06, 0.18, 0.03), CROSS)
			cross_v.position = Vector3(0.0, 0.66, -0.26)
			_put(cross_v)
			var cross_h := Mats.box(Vector3(0.18, 0.06, 0.03), CROSS)
			cross_h.position = Vector3(0.0, 0.66, -0.26)
			_put(cross_h)
	var parts := _into
	_into = []
	return parts


func _head_parts(skin: Color, hat: String, top: Color, hair_style: String, hair: Color, ink_w: float) -> Array:
	_into = []
	var head := Mats.ball(HEAD_R, skin)
	head.position.y = HEAD_Y
	if ink_w > 0.0:
		Mats.ink(head, ink_w)
	_put(head)
	if detailed:
		_add_face()
		if hair_style != "":
			_add_hair(hair_style, hair)
	_add_hat(hat, top)
	var parts := _into
	_into = []
	return parts


## Big eyes with a catchlight, pink cheeks, a small smile.
func _add_face() -> void:
	for side in [-1.0, 1.0]:
		var white := Mats.ball(0.058, EYE_WHITE)
		white.position = Vector3(side * 0.09, HEAD_Y + 0.03, -HEAD_R + 0.04)
		white.scale = Vector3(1.0, 1.25, 0.6)
		_put(white)
		var pupil := Mats.ball(0.034, EYE)
		pupil.position = Vector3(side * 0.09, HEAD_Y + 0.025, -HEAD_R + 0.005)
		pupil.scale = Vector3(1.0, 1.3, 0.5)
		_put(pupil)
		var shine := Mats.box(Vector3(0.016, 0.016, 0.01), EYE_WHITE, true)
		shine.position = Vector3(side * 0.09 - 0.012, HEAD_Y + 0.045, -HEAD_R - 0.012)
		_put(shine)
		var cheek := Mats.ball(0.04, CHEEK)
		cheek.position = Vector3(side * 0.16, HEAD_Y - 0.05, -HEAD_R + 0.07)
		cheek.scale = Vector3(1.0, 0.7, 0.4)
		_put(cheek)
	var mouth := Mats.ball(0.03, MOUTH)
	mouth.position = Vector3(0.0, HEAD_Y - 0.1, -HEAD_R + 0.02)
	mouth.scale = Vector3(1.9, 0.45, 0.4)
	_put(mouth)


func _add_hair(style: String, color: Color) -> void:
	var cap_y := HEAD_Y + 0.07
	match style:
		"short":
			var h := Mats.ball(HEAD_R + 0.015, color)
			h.position = Vector3(0.0, cap_y, 0.02)
			h.scale = Vector3(1.0, 0.62, 1.0)
			_put(h)
		"bun":
			var h := Mats.ball(HEAD_R + 0.015, color)
			h.position = Vector3(0.0, cap_y, 0.02)
			h.scale = Vector3(1.0, 0.62, 1.0)
			_put(h)
			var bun := Mats.ball(0.1, color)
			bun.position = Vector3(0.0, HEAD_Y + 0.17, 0.2)
			_put(bun)
		"spiky":
			for i in range(3):
				var spike := Mats.cone(0.07, 0.22, color)
				spike.position = Vector3((float(i) - 1.0) * 0.12, HEAD_Y + 0.33, 0.0)
				spike.rotation_degrees.z = (float(i) - 1.0) * -28.0
				_put(spike)
			var base := Mats.ball(HEAD_R + 0.01, color)
			base.position = Vector3(0.0, cap_y + 0.02, 0.0)
			base.scale = Vector3(1.0, 0.5, 1.0)
			_put(base)
		"long":
			var h := Mats.ball(HEAD_R + 0.015, color)
			h.position = Vector3(0.0, cap_y, 0.02)
			h.scale = Vector3(1.0, 0.62, 1.0)
			_put(h)
			var fall := Mats.ball(0.2, color)
			fall.position = Vector3(0.0, HEAD_Y - 0.12, 0.17)
			fall.scale = Vector3(1.25, 1.5, 0.55)
			_put(fall)
		"curly":
			var h := Mats.ball(HEAD_R + 0.06, color)
			h.position = Vector3(0.0, HEAD_Y + 0.09, 0.01)
			h.scale = Vector3(1.0, 0.78, 1.0)
			_put(h)
			for i in range(5):
				var a := float(i) * TAU / 5.0
				var curl := Mats.ball(0.075, color)
				curl.position = Vector3(sin(a) * 0.24, HEAD_Y + 0.14 + cos(a * 2.0) * 0.03, cos(a) * 0.24)
				_put(curl)
		"mohawk":
			var strip := Mats.pill(0.055, 0.36, color)
			strip.position = Vector3(0.0, HEAD_Y + 0.29, 0.0)
			strip.rotation_degrees.x = 90.0
			_put(strip)
		_:
			pass


func _add_hat(hat: String, top: Color) -> void:
	match hat:
		"helmet":
			# The helmet wears the squad's colour: seen from above, the
			# squad is mostly helmets, and a blue squad should look blue.
			var helmet := Mats.ball(HEAD_R + 0.05, top.darkened(0.18) if not look.has("hat") else HELMET)
			helmet.position.y = HEAD_Y + 0.08
			helmet.scale = Vector3(1.0, 0.74, 1.0)
			_put(helmet)
			# A pale band round the helmet: the squad reads as people from
			# above, not as a pile of olive domes.
			var band := Mats.torus(HEAD_R + 0.02, HEAD_R + 0.065, BAND)
			band.position.y = HEAD_Y + 0.06
			_put(band)
			if detailed:
				var visor := Mats.box(Vector3(0.3, 0.07, 0.05), VISOR)
				visor.position = Vector3(0.0, HEAD_Y + 0.11, -HEAD_R - 0.04)
				_put(visor)
		"cap":
			var dome := Mats.ball(HEAD_R + 0.03, top)
			dome.position.y = HEAD_Y + 0.08
			dome.scale = Vector3(1.0, 0.55, 1.0)
			_put(dome)
			var brim := Mats.ball(0.16, top.darkened(0.2))
			brim.position = Vector3(0.0, HEAD_Y + 0.07, -HEAD_R - 0.1)
			brim.scale = Vector3(1.1, 0.12, 1.0)
			_put(brim)
		"beanie":
			var dome := Mats.ball(HEAD_R + 0.045, top.darkened(0.1))
			dome.position.y = HEAD_Y + 0.08
			dome.scale = Vector3(1.0, 0.85, 1.0)
			_put(dome)
			var pom := Mats.ball(0.075, BAND)
			pom.position.y = HEAD_Y + 0.36
			_put(pom)
		"headband":
			var band := Mats.torus(HEAD_R - 0.02, HEAD_R + 0.03, Color(0.9, 0.2, 0.2))
			band.position.y = HEAD_Y + 0.1
			_put(band)
		"cat":
			for side in [-1.0, 1.0]:
				var ear := Mats.cone(0.08, 0.17, Color(0.2, 0.2, 0.22))
				ear.position = Vector3(side * 0.15, HEAD_Y + 0.29, 0.0)
				ear.rotation_degrees.z = side * -22.0
				_put(ear)
				var inner := Mats.cone(0.04, 0.1, Color(1.0, 0.65, 0.75))
				inner.position = Vector3(side * 0.15, HEAD_Y + 0.27, -0.03)
				inner.rotation_degrees.z = side * -22.0
				_put(inner)
		"party":
			var cone := Mats.cone(0.13, 0.36, Color(1.0, 0.4, 0.7))
			cone.position.y = HEAD_Y + 0.38
			_put(cone)
			var pom := Mats.ball(0.05, Color(1.0, 0.9, 0.2))
			pom.position.y = HEAD_Y + 0.58
			_put(pom)
		"viking":
			var dome := Mats.ball(HEAD_R + 0.05, Color(0.55, 0.55, 0.6))
			dome.position.y = HEAD_Y + 0.08
			dome.scale = Vector3(1.0, 0.74, 1.0)
			_put(dome)
			for side in [-1.0, 1.0]:
				var horn := Mats.cone(0.06, 0.26, BAND)
				horn.position = Vector3(side * 0.3, HEAD_Y + 0.2, 0.0)
				horn.rotation_degrees.z = side * -55.0
				_put(horn)
		"crown":
			var ring := Mats.torus(0.19, 0.24, Color(1.0, 0.8, 0.2))
			ring.position.y = HEAD_Y + 0.2
			_put(ring)
			for i in range(5):
				var a := float(i) * TAU / 5.0
				var point := Mats.cone(0.04, 0.12, Color(1.0, 0.8, 0.2))
				point.position = Vector3(sin(a) * 0.2, HEAD_Y + 0.28, cos(a) * 0.2)
				_put(point)
			var jewel := Mats.ball(0.035, Color(0.9, 0.2, 0.4))
			jewel.position = Vector3(0.0, HEAD_Y + 0.22, -0.22)
			_put(jewel)
		"wizard":
			var cone := Mats.cone(0.25, 0.5, Color(0.3, 0.15, 0.6))
			cone.position.y = HEAD_Y + 0.42
			_put(cone)
			var brim := Mats.torus(0.2, 0.38, Color(0.3, 0.15, 0.6))
			brim.position.y = HEAD_Y + 0.18
			_put(brim)
			var star := Mats.ball(0.04, Color(1.0, 0.9, 0.3))
			star.position = Vector3(0.0, HEAD_Y + 0.4, -0.17)
			_put(star)
		"halo":
			# It floats and turns on its own: made in _build, not welded.
			pass
		"bunny":
			for side in [-1.0, 1.0]:
				var ear := Mats.pill(0.055, 0.36, Color(0.97, 0.95, 0.95))
				ear.position = Vector3(side * 0.1, HEAD_Y + 0.4, 0.0)
				ear.rotation_degrees.z = side * -12.0
				_put(ear)
				var inner := Mats.pill(0.025, 0.22, Color(1.0, 0.7, 0.8))
				inner.position = Vector3(side * 0.1, HEAD_Y + 0.4, -0.035)
				inner.rotation_degrees.z = side * -12.0
				_put(inner)
		"chef":
			var toque := Mats.pill(0.22, 0.5, Color(0.98, 0.98, 0.98))
			toque.position.y = HEAD_Y + 0.34
			_put(toque)
			var band := Mats.torus(HEAD_R - 0.03, HEAD_R + 0.02, Color(0.98, 0.98, 0.98))
			band.position.y = HEAD_Y + 0.17
			_put(band)
		_:
			pass


func _add_gun(weapon: String) -> void:
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gun := Mats.weld("sgun|%s|%s|%s|%s" % [weapon, shotgun, squad_type == "sniper", detailed], func() -> Array: return _gun_parts(weapon))
	gun.cast_shadow = off
	_gun.add_child(gun)
	# The muzzle flash: a four-point star of light at the barrel's end,
	# turned a little differently each shot.
	_muzzle = Mats.weld("smuzzle", _muzzle_parts)
	_muzzle.position.z = -0.56
	_muzzle.visible = false
	_muzzle.cast_shadow = off
	_gun.add_child(_muzzle)


func _muzzle_parts() -> Array:
	var bar := Mats.box(Vector3(0.4, 0.13, 0.06), MUZZLE, true)
	bar.material_override = Mats.glow(MUZZLE, 3.2)
	var cross := Mats.box(Vector3(0.13, 0.4, 0.06), MUZZLE, true)
	cross.material_override = Mats.glow(MUZZLE, 3.2)
	var core := Mats.ball(0.1, Color(1.0, 0.98, 0.85))
	core.material_override = Mats.glow(Color(1.0, 0.98, 0.85), 3.6)
	return [bar, cross, core]


func _gun_parts(weapon: String) -> Array:
	var parts: Array = []
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
		barrel = Mats.pill(0.065 if shotgun else 0.05, 0.4 if shotgun else (0.82 if squad_type == "sniper" else 0.58), main)
		barrel.rotation_degrees.x = 90.0
	barrel.position.z = -0.24
	parts.append(barrel)
	var receiver := Mats.box(Vector3(0.11, 0.15, 0.26), accent if weapon != "standard" else GUN, glow)
	receiver.position.z = 0.06
	parts.append(receiver)
	if detailed:
		var mag := Mats.box(Vector3(0.07, 0.14, 0.08), accent, glow)
		mag.position = Vector3(0.0, -0.13, 0.02)
		parts.append(mag)
		var stock := Mats.box(Vector3(0.08, 0.11, 0.16), accent if weapon != "standard" else GUN.darkened(0.2), glow)
		stock.position = Vector3(0.0, -0.02, 0.26)
		parts.append(stock)
		if weapon == "candy":
			var stripe := Mats.torus(0.04, 0.06, accent)
			stripe.position.z = -0.3
			stripe.rotation_degrees.x = 90.0
			parts.append(stripe)
	return parts


## What rides the back without moving: welded into the trunk.
func _add_back_fixed(back: String, top: Color) -> void:
	match back:
		"pack":
			var pack := Mats.pill(0.11, 0.26, top.darkened(0.35))
			pack.position = Vector3(0.0, 0.66, 0.22)
			pack.scale = Vector3(1.3, 1.0, 0.8)
			_put(pack)
		"jetpack":
			for side in [-1.0, 1.0]:
				var tank := Mats.pill(0.07, 0.3, Color(0.7, 0.72, 0.75))
				tank.position = Vector3(side * 0.09, 0.66, 0.24)
				_put(tank)
		"shell":
			var shell := Mats.ball(0.27, Color(0.35, 0.55, 0.3))
			shell.position = Vector3(0.0, 0.66, 0.2)
			shell.scale = Vector3(1.0, 1.1, 0.6)
			_put(shell)
			var rim := Mats.torus(0.2, 0.28, Color(0.85, 0.75, 0.45))
			rim.position = Vector3(0.0, 0.66, 0.12)
			rim.rotation_degrees.x = 90.0
			_put(rim)
		_:
			pass


## What flaps, floats or burns on the back: nodes of their own.
func _add_back(back: String) -> void:
	match back:
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
	_flash_t = 0.07
	_recoil = 1.0
	_muzzle.visible = true
	_muzzle.rotation.z = randf() * TAU
	_muzzle.scale = Vector3.ONE * randf_range(0.8, 1.2)


## Bitten: a squash, wider and shorter for a moment.
func squash() -> void:
	_squash_t = 1.0


func _process(delta: float) -> void:
	position = position.lerp(target_offset, 1.0 - exp(-10.0 * delta))
	var t := Time.get_ticks_msec() * 0.001 * _stride + _phase
	# The run: a bob, a lean into each step, the head a beat behind.
	position.y = absf(sin(t)) * 0.08
	if _torso != null:
		_torso.rotation.z = sin(t) * 0.07
	if _head != null:
		_head.position.y = HEAD_Y + absf(sin(t + 0.6)) * 0.03
	if _squash_t > 0.0:
		_squash_t = maxf(0.0, _squash_t - delta * 6.0)
		var sq := sin(_squash_t * PI)
		scale = Vector3(1.0 + 0.2 * sq, 1.0 - 0.18 * sq, 1.0 + 0.2 * sq)
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
		_legs[i].rotation.x = sin(t + PI * i) * 0.85
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
