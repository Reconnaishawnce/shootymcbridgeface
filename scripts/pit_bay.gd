class_name PitBay
extends Node3D
## The pit stop: a pit lane that pulls off the right side of the road.
## A ramp with chevrons peels off the road, the lane runs beside it
## behind a low pit wall, past a garage with its door up, tyre stacks,
## a fuel pump, floodlights and a crew that waves you in; a second ramp
## brings you back. Steer onto the ramp as it passes and the road waits
## at the garage. The crew keeps moving while the game is paused.

## The lane and its ramps are painted yellow, so the pit reads from the
## far end of the screen; the lead-in arrows on the road itself too.
const APRON := Color(0.93, 0.72, 0.12)
const RAMP := Color(0.96, 0.78, 0.18)
const STRIP := Color(0.08, 0.08, 0.1, 0.9)
const CHEVRON := Color(0.08, 0.08, 0.1)
const LEAD := Color(1.0, 0.82, 0.2)
## Lead-in arrows start this far before the entry ramp.
const LEAD_LENGTH := 16.0
const CONE := Color(1.0, 0.45, 0.1)
const WALL := Color(0.92, 0.92, 0.9)
const WALL_RED := Color(0.85, 0.15, 0.15)
const GARAGE := Color(0.33, 0.35, 0.4)
const GARAGE_DARK := Color(0.05, 0.05, 0.07)
const ROOF := Color(0.75, 0.2, 0.2)
const TYRE := Color(0.07, 0.07, 0.08)
const RIM := Color(0.85, 0.85, 0.8)
const CREW := Color(1.0, 0.5, 0.1)
const SKIN := Color(0.95, 0.75, 0.6)
const PUMP := Color(0.85, 0.2, 0.2)
const LIGHT := Color(1.0, 0.95, 0.7)
const BUNTING := [Color(1.0, 0.3, 0.3), Color(1.0, 0.9, 0.3), Color(0.4, 0.8, 1.0), Color(0.5, 1.0, 0.5)]
## The lane proper, ramps not counted.
const LENGTH := 22.0
## From the road's edge to the lane's far side.
const WIDTH := 3.6
## Each ramp runs this far along the road.
const RAMP_LENGTH := 7.0

var passed := false
## The road's half-width when the bay was laid; the lane starts there.
var road_edge := 3.0
var _crew: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _lamps: Array[MeshInstance3D] = []
var _flag: Node3D = null
var _t := 0.0


func setup(p_road_half: float) -> void:
	road_edge = p_road_half
	position = Vector3(0.0, 0.0, 0.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cx := road_edge + WIDTH * 0.5 + 0.1
	# The lane: tarmac over the curb's line and out to the far side, a
	# dashed gold line where it leaves the road, a rumble edge beyond.
	var apron := Mats.gbox(Vector3(WIDTH + 0.4, 0.06, LENGTH), APRON, 0.25, 0.18, 1)
	apron.position = Vector3(cx, 0.0, 0.0)
	add_child(apron)
	for i in range(8):
		var dash := Mats.box(Vector3(0.14, 0.02, 1.4), STRIP, true)
		dash.position = Vector3(road_edge + 0.12, 0.035, -LENGTH * 0.5 + 1.2 + float(i) * 2.7)
		add_child(dash)
	# Two ramps: slabs that peel off the road ahead and rejoin it behind,
	# with chevrons pointing the way in.
	for end in [-1.0, 1.0]:
		var ramp := Mats.gbox(Vector3(WIDTH + 0.4, 0.06, RAMP_LENGTH + 0.6), RAMP, 0.25, 0.18, 2)
		ramp.position = Vector3(cx, -0.005, end * (LENGTH * 0.5 + RAMP_LENGTH * 0.5))
		add_child(ramp)
		var wedge := Mats.box(Vector3(WIDTH * 0.5, 0.05, RAMP_LENGTH * 0.9), RAMP.darkened(0.15))
		wedge.position = Vector3(road_edge + WIDTH * 0.2, 0.0, end * (LENGTH * 0.5 + RAMP_LENGTH * 0.5))
		wedge.rotation.y = -end * 0.42
		add_child(wedge)
		for i in range(3):
			var chev := Mats.box(Vector3(0.9, 0.025, 0.22), CHEVRON, true)
			chev.position = Vector3(road_edge + 1.0 + float(i) * 0.75, 0.04, end * (LENGTH * 0.5 + 1.4 + float(i) * 1.6))
			chev.rotation.y = -end * 0.6
			add_child(chev)
	# Lead-in paint on the road itself: yellow arrows down the right half
	# pointing at the ramp, and PIT written on the asphalt.
	for i in range(4):
		var zl := -LENGTH * 0.5 - RAMP_LENGTH - 2.0 - float(i) * (LEAD_LENGTH / 4.0)
		for leg in [-1.0, 1.0]:
			var stroke := Mats.box(Vector3(1.1, 0.02, 0.26), LEAD, true)
			stroke.position = Vector3(road_edge * 0.5 + leg * 0.35, 0.03, zl - leg * 0.3)
			stroke.rotation.y = leg * 0.75
			add_child(stroke)
	var paint := Label3D.new()
	paint.text = "PIT"
	paint.font_size = 160
	paint.pixel_size = 0.012
	paint.modulate = LEAD
	paint.outline_size = 0
	paint.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	paint.position = Vector3(road_edge * 0.5, 0.04, -LENGTH * 0.5 - RAMP_LENGTH - LEAD_LENGTH - 3.0)
	add_child(paint)
	# A glow strip where the lane leaves the road.
	var edge := Mats.box(Vector3(0.12, 0.03, LENGTH + RAMP_LENGTH * 2.0), LEAD, true)
	edge.material_override = Mats.glow(LEAD, 1.6)
	edge.position = Vector3(road_edge - 0.1, 0.035, 0.0)
	add_child(edge)
	# The pit wall along the far side: white blocks, every other red.
	for i in range(11):
		var block := Mats.box(Vector3(0.3, 0.7, 1.8), WALL_RED if i % 2 == 0 else WALL)
		block.position = Vector3(road_edge + WIDTH + 0.35, 0.35, -LENGTH * 0.5 + 1.0 + float(i) * 2.0)
		add_child(block)
	# The garage behind the wall: a block with its door up, a red roof, a
	# lit sign.
	var gx := road_edge + WIDTH + 3.1
	var garage := Mats.gbox(Vector3(3.6, 3.4, 7.0), GARAGE, 0.15, 0.3, 3)
	garage.position = Vector3(gx, 1.7, 0.0)
	add_child(garage)
	var door := Mats.box(Vector3(0.2, 2.6, 4.6), GARAGE_DARK, true)
	door.position = Vector3(gx - 1.75, 1.3, 0.0)
	add_child(door)
	var lintel := Mats.box(Vector3(0.3, 0.5, 5.0), ROOF)
	lintel.position = Vector3(gx - 1.7, 2.85, 0.0)
	add_child(lintel)
	var roof := Mats.box(Vector3(4.4, 0.25, 7.6), ROOF)
	roof.position = Vector3(gx, 3.5, 0.0)
	add_child(roof)
	var sign := Label3D.new()
	sign.text = "PIT STOP"
	sign.font_size = 72
	sign.outline_size = 18
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.9, 0.5)
	sign.outline_modulate = Color(0.05, 0.05, 0.08)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.position = Vector3(road_edge + WIDTH + 0.9, 4.6, 0.0)
	add_child(sign)
	var arrow := Label3D.new()
	arrow.text = "PULL IN  >"
	arrow.font_size = 52
	arrow.outline_size = 14
	arrow.pixel_size = 0.01
	arrow.modulate = CHEVRON
	arrow.outline_modulate = Color(0.05, 0.05, 0.08)
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	arrow.position = Vector3(road_edge + 1.2, 2.0, -LENGTH * 0.5 - RAMP_LENGTH - 1.0)
	add_child(arrow)
	# Floodlights on posts at each end of the wall, lamps that blink in
	# turn.
	for zc in [-LENGTH * 0.5 + 0.5, LENGTH * 0.5 - 0.5]:
		var post := Mats.box(Vector3(0.14, 3.6, 0.14), GARAGE_DARK)
		post.position = Vector3(road_edge + WIDTH + 1.0, 1.8, zc)
		add_child(post)
		var lamp := Mats.sphere(0.3, LIGHT)
		lamp.material_override = Mats.glow(LIGHT, 2.4)
		lamp.position = Vector3(road_edge + WIDTH + 1.0, 3.7, zc)
		add_child(lamp)
		_lamps.append(lamp)
	# Tyre stacks by the garage door, a fuel pump, a jack.
	for k in range(3):
		var stack := Node3D.new()
		stack.position = Vector3(road_edge + WIDTH + 0.95, 0.0, -2.8 + float(k) * 0.9 + (0.4 if k == 1 else 0.0))
		for j in range(3 if k != 1 else 4):
			var tyre := Mats.torus(0.14, 0.36, TYRE)
			tyre.position.y = 0.16 + float(j) * 0.3
			stack.add_child(tyre)
			var rim := Mats.sphere(0.12, RIM)
			rim.position.y = 0.16 + float(j) * 0.3
			stack.add_child(rim)
		add_child(stack)
	var pump := Mats.box(Vector3(0.6, 1.4, 0.5), PUMP)
	pump.position = Vector3(road_edge + WIDTH + 0.95, 0.7, 2.6)
	add_child(pump)
	var pump_face := Mats.box(Vector3(0.1, 0.5, 0.36), LIGHT, true)
	pump_face.position = Vector3(road_edge + WIDTH + 0.63, 1.0, 2.6)
	add_child(pump_face)
	var jack := Mats.box(Vector3(0.5, 0.18, 1.1), WALL_RED)
	jack.position = Vector3(cx + 0.9, 0.12, 2.0)
	add_child(jack)
	# The crew: orange overalls, one with a flag, all waving you in.
	for k in range(3):
		var who := Node3D.new()
		who.position = Vector3(road_edge + WIDTH - 0.5, 0.0, -2.4 + float(k) * 2.4)
		var body := Mats.capsule(0.26, 1.0, CREW)
		body.position.y = 0.75
		who.add_child(body)
		var head := Mats.sphere(0.2, SKIN)
		head.position.y = 1.5
		who.add_child(head)
		var helmet := Mats.sphere(0.22, WALL)
		helmet.position.y = 1.58
		helmet.scale = Vector3(1.0, 0.6, 1.0)
		who.add_child(helmet)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(-0.3, 1.2, 0.0)
		var arm := Mats.capsule(0.08, 0.7, CREW)
		arm.position.y = 0.35
		shoulder.add_child(arm)
		if k == 1:
			var flag := Mats.box(Vector3(0.04, 0.4, 0.6), CHEVRON, true)
			flag.position = Vector3(0.0, 0.85, 0.3)
			shoulder.add_child(flag)
			_flag = shoulder
		who.add_child(shoulder)
		_arms.append(shoulder)
		add_child(who)
		_crew.append(who)
	# Bunting over the lane between the posts.
	for i in range(12):
		var tri := Mats.box(Vector3(0.02, 0.35, 0.3), BUNTING[i % BUNTING.size()], true)
		var zt := -LENGTH * 0.5 + 1.0 + float(i) * (LENGTH - 2.0) / 11.0
		tri.position = Vector3(road_edge + WIDTH + 1.0 - (float(i % 2) * 0.1), 3.3 - 0.35 * sin(float(i) / 11.0 * PI), zt)
		add_child(tri)
	for zc in [-LENGTH * 0.5 - RAMP_LENGTH + 0.3, LENGTH * 0.5 + RAMP_LENGTH - 0.3]:
		var cone := Mats.cone(0.16, 0.5, CONE)
		cone.position = Vector3(road_edge + 0.5, 0.25, zc)
		add_child(cone)


func _process(delta: float) -> void:
	_t += delta
	for i in range(_arms.size()):
		_arms[i].rotation.z = 2.4 + sin(_t * 5.0 + float(i) * 1.3) * 0.6
	for i in range(_crew.size()):
		_crew[i].position.y = absf(sin(_t * 4.0 + float(i) * 1.7)) * 0.06
	for i in range(_lamps.size()):
		var on := fmod(_t + float(i) * 0.5, 1.0) < 0.5
		_lamps[i].scale = Vector3.ONE * (1.25 if on else 0.85)


## Where the squad may steer to while the lane is beside it.
static func outer_for(p_road_edge: float) -> float:
	return p_road_edge + WIDTH - 0.4


## On the lane: past the road's edge.
static func apron_covers(x: float, p_road_edge: float) -> bool:
	return x >= p_road_edge + 0.3


## True while a curb segment at [param dz] from the bay should be gone.
static func curb_open_at(dz: float) -> bool:
	return absf(dz) <= LENGTH * 0.5 + RAMP_LENGTH


## True while shoulder scenery at [param dz] would stand in the pit.
static func clears_shoulder_at(dz: float) -> bool:
	return absf(dz) <= LENGTH * 0.5 + RAMP_LENGTH + 4.0


## The lane opens to the squad from this far ahead of the bay's centre.
static func lane_opens_at() -> float:
	return -(LENGTH * 0.5 + RAMP_LENGTH + 10.0)


## How far right the camera pans while the lane is open: the road's
## right half and the lane share the frame.
static func pan_for(p_road_edge: float) -> float:
	return p_road_edge * 0.45 + WIDTH * 0.6


func outer_x() -> float:
	return outer_for(road_edge)


func covers_x(x: float) -> bool:
	return apron_covers(x, road_edge)


func opens_curb_at(z: float) -> bool:
	return curb_open_at(z - position.z)


func clears_shoulder(z: float) -> bool:
	return clears_shoulder_at(z - position.z)
