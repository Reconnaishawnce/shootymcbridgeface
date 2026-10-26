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


## Drop every cached material. Called on the way out so nothing is still
## referenced when the engine checks for leaked resources at exit.
static func clear() -> void:
	if Engine.has_meta(CACHE_KEY):
		Engine.remove_meta(CACHE_KEY)


static func flat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var cache := _cache()
	var key := "%s|%s" % [color.to_html(true), unshaded]
	if cache.has(key):
		return cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.78
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cache[key] = m
	return m


## The ink line round characters and things: an inverted hull drawn as a
## second pass, front faces culled, pushed out along the normal. Cheap,
## and it works on the Compatibility renderer.
static func outline(width: float = 0.028) -> ShaderMaterial:
	var cache := _cache()
	var key := "outline|%.3f" % width
	if cache.has(key):
		return cache[key]
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode cull_front, unshaded, depth_draw_opaque; uniform float width = 0.028; uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.08, 1.0); void vertex() { VERTEX += NORMAL * width; } void fragment() { ALBEDO = ink.rgb; }"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("width", width)
	cache[key] = m
	return m


## A soft material with the ink line: characters and things that should
## read as drawn.
static func inked(color: Color, width: float = 0.028) -> StandardMaterial3D:
	var cache := _cache()
	var key := "inked|%s|%.3f" % [color.to_html(true), width]
	if cache.has(key):
		return cache[key]
	var m := soft(color).duplicate()
	m.next_pass = outline(width)
	cache[key] = m
	return m


## A flat material with the ink line, for things built from boxes.
static func inked_flat(color: Color, width: float = 0.028) -> StandardMaterial3D:
	var cache := _cache()
	var key := "inkedflat|%s|%.3f" % [color.to_html(true), width]
	if cache.has(key):
		return cache[key]
	var m := flat(color).duplicate()
	m.next_pass = outline(width)
	cache[key] = m
	return m


## Give an existing mesh the ink line, whatever its material.
static func ink(mi: MeshInstance3D, width: float = 0.028) -> MeshInstance3D:
	var base := mi.material_override
	if base is StandardMaterial3D:
		var key := "ink|%s|%.3f" % [base.get_instance_id(), width]
		var cache := _cache()
		if not cache.has(key):
			var dup: StandardMaterial3D = base.duplicate()
			dup.next_pass = outline(width)
			cache[key] = dup
		mi.material_override = cache[key]
	return mi


## Something that gives off light: bullets, the boss core, neon, lamps.
## Bright enough to bloom under the environment's glow.
static func glow(color: Color, energy: float = 2.2) -> StandardMaterial3D:
	var cache := _cache()
	var key := "glow|%s|%.1f" % [color.to_html(true), energy]
	if cache.has(key):
		return cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cache[key] = m
	return m


## A grainy surface: colour with a noise texture laid on in world units,
## so asphalt reads as asphalt and dirt as dirt, with no art files.
static func grainy(color: Color, scale: float = 0.25, strength: float = 0.35, seed_value: int = 1, roughness: float = 0.9) -> StandardMaterial3D:
	var cache := _cache()
	var key := "grainy|%s|%.2f|%.2f|%d" % [color.to_html(true), scale, strength, seed_value]
	if cache.has(key):
		return cache[key]
	var tex_key := "noise|%d|%.2f" % [seed_value, strength]
	var tex: ImageTexture
	if cache.has(tex_key):
		tex = cache[tex_key]
	else:
		var noise := FastNoiseLite.new()
		noise.seed = seed_value
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.06
		noise.fractal_octaves = 4
		var img := noise.get_image(128, 128, false, false, true)
		# Remap the noise into [1 - strength, 1]: the texture only takes a
		# little off the colour, it never halves it.
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var v := 1.0 - strength * img.get_pixel(x, y).r
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
		cache[tex_key] = tex
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cache[key] = m
	return m


## A box with a grainy material.
static func gbox(size: Vector3, color: Color, scale: float = 0.25, strength: float = 0.35, seed_value: int = 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = grainy(color, scale, strength, seed_value)
	return mi


## Character material: wrapped lighting so curves shade softly instead of
## splitting into a lit half and a dark half, and a little sheen. Reads as
## a toy, not a crate.
static func soft(color: Color) -> StandardMaterial3D:
	var cache := _cache()
	var key := "soft|%s" % color.to_html(true)
	if cache.has(key):
		return cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.62
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cache[key] = m
	return m


## A smooth sphere for faces and round bodies: more segments, soft shading.
static func ball(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	mi.mesh = mesh
	mi.material_override = soft(color)
	return mi


## A smooth capsule for limbs and bodies.
static func pill(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = soft(color)
	return mi


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


static func cone(radius: float, height: float, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = flat(color, unshaded)
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
