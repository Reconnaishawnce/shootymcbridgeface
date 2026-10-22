class_name Crate
extends Node3D
## A power-up crate on the road. Drive over it to collect. Spins so it reads
## as a pickup, with its contents (or a ?) floating above.

const COLOR := Color(0.6, 0.35, 0.9)
const EDGE := Color(1.0, 0.85, 0.3)

var id := ""
var _spin := 0.0


func setup(p_id: String) -> void:
	id = p_id
	var box := Mats.box(Vector3(0.8, 0.8, 0.8), COLOR)
	box.position.y = 0.6
	add_child(box)
	var band := Mats.box(Vector3(0.86, 0.14, 0.86), EDGE, true)
	band.position.y = 0.6
	add_child(band)
	var label := Label3D.new()
	label.text = Powerups.title(id)
	label.font_size = 56 if label.text.length() <= 2 else 36
	label.outline_size = 12
	label.pixel_size = 0.01
	label.outline_modulate = Color(0.05, 0.05, 0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.5
	label.no_depth_test = true
	add_child(label)


func _process(delta: float) -> void:
	_spin += delta * 2.0
	rotation.y = _spin
	position.y = 0.1 + sin(_spin * 1.5) * 0.08
