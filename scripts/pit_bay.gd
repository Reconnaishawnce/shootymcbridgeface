class_name PitBay
extends Node3D
## The pit stop: a lay-by off the right side of the road. The curb opens,
## a tarmac apron runs beside the road with cones along its far edge and
## a sign over it. Steer off the road onto the apron as it passes and
## the road waits.

const APRON := Color(0.21, 0.22, 0.25)
const STRIP := Color(0.98, 0.78, 0.2, 0.8)
const CONE := Color(1.0, 0.45, 0.1)
const LENGTH := 9.0
## From the road's edge to the apron's far side.
const WIDTH := 3.0

var passed := false
## The road's half-width when the bay was laid; the apron starts there.
var road_edge := 3.0


func setup(p_road_half: float) -> void:
	road_edge = p_road_half
	position = Vector3(0.0, 0.0, 0.0)
	# Tarmac over the curb's line and out to the lay-by's far edge.
	var apron := Mats.gbox(Vector3(WIDTH + 0.4, 0.06, LENGTH), APRON, 0.3, 0.3, 1)
	apron.position = Vector3(road_edge + WIDTH * 0.5 + 0.1, 0.0, 0.0)
	add_child(apron)
	var strip := Mats.box(Vector3(WIDTH - 0.6, 0.02, LENGTH - 1.0), STRIP, true)
	strip.position = Vector3(road_edge + WIDTH * 0.5 + 0.3, 0.035, 0.0)
	add_child(strip)
	for i in range(5):
		var cone := Mats.cone(0.16, 0.5, CONE)
		cone.position = Vector3(road_edge + WIDTH + 0.15, 0.25, -LENGTH * 0.5 + 0.5 + float(i) * (LENGTH - 1.0) / 4.0)
		add_child(cone)
	for zc in [-LENGTH * 0.5, LENGTH * 0.5]:
		var cone := Mats.cone(0.16, 0.5, CONE)
		cone.position = Vector3(road_edge + 0.6, 0.25, zc)
		add_child(cone)
	var sign := Label3D.new()
	sign.text = "PIT STOP"
	sign.font_size = 52
	sign.outline_size = 14
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.9, 0.5)
	sign.outline_modulate = Color(0.05, 0.05, 0.08)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.position = Vector3(road_edge + WIDTH * 0.5, 1.7, -LENGTH * 0.5)
	add_child(sign)


## Where the squad may steer to while the bay is beside it.
static func outer_for(p_road_edge: float) -> float:
	return p_road_edge + WIDTH - 0.3


## On the apron: past the road's edge.
static func apron_covers(x: float, p_road_edge: float) -> bool:
	return x >= p_road_edge + 0.2


## True while a curb segment at [param dz] from the bay should be gone.
static func curb_open_at(dz: float) -> bool:
	return absf(dz) <= LENGTH * 0.5 + 1.0


func outer_x() -> float:
	return outer_for(road_edge)


func covers_x(x: float) -> bool:
	return apron_covers(x, road_edge)


func opens_curb_at(z: float) -> bool:
	return curb_open_at(z - position.z)
