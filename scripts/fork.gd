class_name Fork
extends Node3D
## The split in the road: a divider wall down the middle for the length of
## the fork stretch, with the route names over each side at the mouth.

const WALL := Color(0.5, 0.48, 0.42)
const STRIPE := Color(0.95, 0.75, 0.2)
const RICH := Color(1.0, 0.8, 0.25)
const SAFE := Color(0.45, 0.9, 1.0)

var length := 48.0
var routes: Dictionary = {}
var chosen := false


var road_half := 3.3


func setup(p_routes: Dictionary, p_length: float, p_road_half: float = 3.3) -> void:
	routes = p_routes
	length = p_length
	road_half = p_road_half
	var wall := Mats.box(Vector3(0.36, 1.1, length), WALL)
	wall.position = Vector3(0.0, 0.55, -length * 0.5)
	add_child(wall)
	var stripe := Mats.box(Vector3(0.4, 0.08, length), STRIPE, true)
	stripe.position = Vector3(0.0, 1.12, -length * 0.5)
	add_child(stripe)
	# A wedge at the mouth so the split reads from a distance.
	var nose := Mats.cone(0.5, 1.4, WALL)
	nose.position = Vector3(0.0, 0.7, 0.4)
	nose.rotation_degrees.x = 90.0
	add_child(nose)
	for side in [-1, 1]:
		var route: Dictionary = routes["left" if side < 0 else "right"]
		var label := Label3D.new()
		label.text = "%s\n%s" % [route.name, "!".repeat(int(route.threat))]
		label.font_size = 72
		label.outline_size = 16
		label.pixel_size = 0.01
		label.modulate = RICH if route.name == "RICH" else SAFE
		label.outline_modulate = Color(0.05, 0.05, 0.08)
		label.position = Vector3(float(side) * road_half * 0.5, 2.4, 1.0)
		label.no_depth_test = true
		add_child(label)


## Fades the mouth labels once the squad has committed.
func commit() -> void:
	chosen = true
	for c in get_children():
		if c is Label3D:
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0, 0.4)
