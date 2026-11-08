class_name GatePanelView
extends Node3D
## The visible half of a gate: a coloured slab with a big number on it.

const WIDTH := 3.1
const HEIGHT := 2.0
const CENTER_X := 1.62

const GOOD := Palette.GOOD
const BAD := Palette.BAD
const HIDDEN := Palette.HIDDEN
const CHOSEN := Color(1.0, 0.95, 0.5, 1.0)
const POWER := Palette.POWER
## Sum panels: neither blue nor red. You have to work it out.
const THINK := Palette.THINK
## Trades and bets: amber. A deal, not a number.
const DEAL := Palette.DEAL
## Convoy panels: olive steel. Soldiers in, a vehicle out.
const CONVOY := Palette.CONVOY
## Supply: gold, the colour of the bounty it spends.
const SUPPLY := Palette.SUPPLY

var _mesh: MeshInstance3D
var _strip: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _pop := 0.0
var _hot := false
var _base_color := GOOD


var width := WIDTH


func _init(p_width: float = WIDTH) -> void:
	width = p_width
	# A dark bevelled frame behind a glossy coloured face, and a thin
	# glowing strip along the top so the row of panels reads from far off.
	var frame := Mats.box(Vector3(width + 0.16, HEIGHT + 0.16, 0.2), Palette.PANEL_FRAME)
	# Behind the face: the camera looks at the +z side, and a frame that
	# reached past the face hid its colour.
	frame.position.z = -0.1
	Mats.ink(frame, 0.02)
	add_child(frame)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, HEIGHT, 0.25)
	_mesh.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# A lit sign: the face shows its own colour whatever the sky does (a
	# glossy face reflected the sky and read grey), and glows a little.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 0.35
	_mesh.material_override = _mat
	add_child(_mesh)
	_strip = Mats.box(Vector3(width + 0.16, 0.08, 0.22), Color.WHITE)
	_strip.position = Vector3(0.0, HEIGHT * 0.5 + 0.12, 0.04)
	add_child(_strip)

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
	elif GateMath.is_vehicle(panel):
		color = CONVOY
	elif GateMath.is_supply(panel):
		color = SUPPLY
	elif GateMath.is_deal(panel):
		color = DEAL
	elif GateMath.is_expr(panel):
		color = THINK
	elif GateMath.is_good(panel):
		color = GOOD
	_base_color = color
	if not _hot:
		_mat.albedo_color = color
	_mat.emission = Color(color.r, color.g, color.b)
	_strip.material_override = Mats.glow(Color(color.r, color.g, color.b).lightened(0.3), 2.4)


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
