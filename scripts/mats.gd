class_name Mats
extends RefCounted
## Shared flat-colour materials so hundreds of meshes do not each carry one.
##
## The cache lives as metadata on the Engine singleton rather than in a
## static variable: a static container here kept this script alive at the
## end of Godot's import pass and tripped CI with "resources still in use".

const CACHE_KEY := "mats_cache"


static func _cache() -> Dictionary:
	if not Engine.has_meta(CACHE_KEY):
		Engine.set_meta(CACHE_KEY, {})
	return Engine.get_meta(CACHE_KEY)


static func flat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var cache := _cache()
	var key := "%s|%s" % [color.to_html(true), unshaded]
	if cache.has(key):
		return cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cache[key] = m
	return m


static func box(size: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = flat(color, unshaded)
	return mi


static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = flat(color)
	return mi


static func sphere(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = flat(color)
	return mi


static func cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = flat(color)
	return mi


static func torus(inner: float, outer: float, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	mi.mesh = mesh
	mi.material_override = flat(color, unshaded)
	return mi
