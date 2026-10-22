class_name GatePanelView
extends Node3D
## The visible half of a gate: a coloured slab with a big number on it.

const WIDTH := 3.1
const HEIGHT := 2.0
const CENTER_X := 1.62

const GOOD := Color(0.2, 0.52, 1.0, 0.82)
const BAD := Color(0.92, 0.22, 0.22, 0.82)
const HIDDEN := Color(0.5, 0.5, 0.56, 0.85)
const CHOSEN := Color(1.0, 0.95, 0.5, 1.0)

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _pop := 0.0


func _init() -> void:
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH, HEIGHT, 0.25)
	_mesh.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.6
	_mesh.material_override = _mat
	add_child(_mesh)

	_label = Label3D.new()
	_label.font_size = 150
	_label.outline_size = 32
	_label.pixel_size = 0.01
	_label.modulate = Color.WHITE
	_label.outline_modulate = Color(0.05, 0.05, 0.08)
	_label.position = Vector3(0.0, 0.05, 0.2)
	_label.no_depth_test = true
	add_child(_label)


func refresh(panel: GateMath.GatePanel) -> void:
	_label.text = GateMath.label(panel)
	if not panel.revealed:
		_mat.albedo_color = HIDDEN
	elif GateMath.is_good(panel):
		_mat.albedo_color = GOOD
	else:
		_mat.albedo_color = BAD


## Little bounce when a shot steps the value up.
func pop() -> void:
	_pop = 1.0


func highlight() -> void:
	_mat.albedo_color = CHOSEN
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.08, 1.15, 1.0), 0.08)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.12)
	tw.parallel().tween_property(_mat, "albedo_color:a", 0.0, 0.5)
	tw.parallel().tween_property(_label, "modulate:a", 0.0, 0.5)


func dim() -> void:
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.35)
	tw.parallel().tween_property(_label, "modulate:a", 0.0, 0.35)


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 5.0)
		_label.scale = Vector3.ONE * (1.0 + 0.35 * _pop)
