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
const POWER := Color(0.6, 0.35, 0.9, 0.85)
## Sum panels: neither blue nor red. You have to work it out.
const THINK := Color(0.15, 0.7, 0.68, 0.85)
## Trades and bets: amber. A deal, not a number.
const DEAL := Color(0.95, 0.6, 0.15, 0.85)

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _pop := 0.0
var _hot := false
var _base_color := GOOD


var width := WIDTH


func _init(p_width: float = WIDTH) -> void:
	width = p_width
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, HEIGHT, 0.25)
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
	var n := _label.text.length()
	_label.font_size = 150 if n <= 4 else (84 if n <= 8 else 60)
	_label.width = (width - 0.2) / 0.01
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var color := BAD
	if not panel.revealed:
		color = HIDDEN
	elif GateMath.is_power(panel):
		color = POWER
	elif GateMath.is_deal(panel):
		color = DEAL
	elif GateMath.is_expr(panel):
		color = THINK
	elif GateMath.is_good(panel):
		color = GOOD
	_base_color = color
	if not _hot:
		_mat.albedo_color = color


## Little bounce when a shot steps the value up.
func pop() -> void:
	_pop = 1.0


## Hot flash: the slab goes near-white while hits count extra.
func set_hot(hot: bool) -> void:
	if hot == _hot:
		return
	_hot = hot
	if hot:
		_base_color = _mat.albedo_color
		_mat.albedo_color = Color(1.0, 1.0, 0.9, 0.95)
	else:
		_mat.albedo_color = _base_color


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
