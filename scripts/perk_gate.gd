class_name PerkGate
extends Node3D
## Three panels across the lane, one perk each. The squad steers through
## the one it wants at full speed: no card, no pause. Bullets pass through.

const SLOT_W := 2.0
const HEIGHT := 2.1
const COLOR := Color(0.55, 0.3, 0.85, 0.82)
const POST := Color(0.25, 0.25, 0.28)

var ids: Array = []
var passed := false
var slot_w := SLOT_W
var _mats: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _descs: Array[Label3D] = []


## Slots share the road: [param road_half] is half its width.
func setup(p_ids: Array, road_half: float = 3.0, stacks: Dictionary = {}) -> void:
	ids = p_ids
	slot_w = road_half * 2.0 / float(maxi(ids.size(), 1))
	for i in range(ids.size()):
		var x := (float(i) - float(ids.size() - 1) * 0.5) * slot_w
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(slot_w - 0.12, HEIGHT, 0.25)
		mesh.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.6
		mesh.material_override = mat
		mesh.position = Vector3(x, HEIGHT * 0.5, 0.0)
		add_child(mesh)
		_mats.append(mat)
		var label := Label3D.new()
		label.text = Perks.title(ids[i])
		label.font_size = 40
		label.outline_size = 12
		label.pixel_size = 0.01
		label.width = (slot_w - 0.3) / 0.01
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.outline_modulate = Color(0.05, 0.05, 0.08)
		label.position = Vector3(x, HEIGHT * 0.6, 0.2)
		label.no_depth_test = true
		add_child(label)
		_labels.append(label)
		# A held perk shows its count, small; what it does is taught, not
		# printed on the road.
		var have := int(stacks.get(ids[i], 0))
		var desc := Label3D.new()
		desc.text = ("x%d" % have) if have > 0 else ""
		desc.font_size = 24
		desc.outline_size = 8
		desc.pixel_size = 0.01
		desc.modulate = Color(0.95, 0.9, 1.0)
		desc.outline_modulate = Color(0.05, 0.05, 0.08)
		desc.position = Vector3(x, HEIGHT * 0.3, 0.2)
		desc.no_depth_test = true
		add_child(desc)
		_descs.append(desc)
	for i in range(ids.size() + 1):
		var post := Mats.box(Vector3(0.16, HEIGHT + 0.3, 0.3), POST)
		post.position = Vector3((float(i) - float(ids.size()) * 0.5) * slot_w, (HEIGHT + 0.3) * 0.5, 0.0)
		add_child(post)
	var sign := Label3D.new()
	sign.text = "PERK"
	sign.font_size = 48
	sign.outline_size = 14
	sign.pixel_size = 0.01
	sign.modulate = Color(0.9, 0.8, 1.0)
	sign.outline_modulate = Color(0.05, 0.05, 0.08)
	sign.position = Vector3(0.0, HEIGHT + 0.6, 0.0)
	sign.no_depth_test = true
	add_child(sign)


## Index of the slot under [param x].
func slot_at_x(x: float) -> int:
	var i := int(floor(x / slot_w + float(ids.size()) * 0.5))
	return clampi(i, 0, ids.size() - 1)


func choose(i: int) -> String:
	passed = true
	for j in range(ids.size()):
		var tw := create_tween()
		if j == i:
			_mats[j].albedo_color = GatePanelView.CHOSEN
			tw.tween_property(_mats[j], "albedo_color:a", 0.0, 0.5)
		else:
			tw.tween_property(_mats[j], "albedo_color:a", 0.0, 0.3)
		tw.parallel().tween_property(_labels[j], "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(_descs[j], "modulate:a", 0.0, 0.4)
	return ids[i]
