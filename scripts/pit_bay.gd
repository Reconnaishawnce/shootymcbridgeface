class_name PitBay
extends Node3D
## The pit stop bay: a gold strip on the right lane with cones and a
## sign, scrolling with the road. Steer onto it and the road waits.

const STRIP := Color(0.98, 0.78, 0.2, 0.75)
const CONE := Color(1.0, 0.45, 0.1)

var passed := false
var width := 2.2


func setup(x: float, p_width: float) -> void:
	width = p_width
	position = Vector3(x, 0.0, 0.0)
	var strip := Mats.box(Vector3(width, 0.03, 7.0), STRIP, true)
	strip.position.y = 0.02
	add_child(strip)
	for i in range(4):
		for side in [-1.0, 1.0]:
			var cone := Mats.cone(0.16, 0.5, CONE)
			cone.position = Vector3(side * (width * 0.5 - 0.1), 0.25, -3.0 + float(i) * 2.0)
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
	sign.position = Vector3(0.0, 1.6, -3.5)
	add_child(sign)


func covers_x(x: float) -> bool:
	return absf(x - position.x) <= width * 0.5 + 0.3
