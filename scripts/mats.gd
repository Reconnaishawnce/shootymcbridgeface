class_name Mats
extends RefCounted
## Shared flat-colour materials so hundreds of meshes do not each carry one.
##
## The cache lives as metadata on the Engine singleton rather than in a
## static variable: a static container here kept this script alive at the
## end of Godot's import pass and tripped CI with "resources still in use".

const CACHE_KEY := "mats_cache"
## Meshes kept for sharing. Sizes that are rolled at random (rubble,
## scenery) would fill the cache for ever; past this, new ones are made
## and not kept.
const MESH_CACHE_MAX := 1200
const MESH_COUNT_KEY := "mesh_count"


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
static func outline(width: float = Palette.INK_WIDTH) -> ShaderMaterial:
	var cache := _cache()
	var key := "outline|%.3f" % width
	if cache.has(key):
		return cache[key]
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode cull_front, unshaded, depth_draw_opaque; uniform float width = 0.028; uniform vec4 ink : source_color = vec4(0.03, 0.03, 0.07, 1.0); void vertex() { VERTEX += NORMAL * width; } void fragment() { ALBEDO = ink.rgb; }"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("width", width)
	cache[key] = m
	return m


## A soft material with the ink line: characters and things that should
## read as drawn.
static func inked(color: Color, width: float = Palette.INK_WIDTH) -> StandardMaterial3D:
	var cache := _cache()
	var key := "inked|%s|%.3f" % [color.to_html(true), width]
	if cache.has(key):
		return cache[key]
	var m := soft(color).duplicate()
	m.next_pass = outline(width)
	cache[key] = m
	return m


## A flat material with the ink line, for things built from boxes.
static func inked_flat(color: Color, width: float = Palette.INK_WIDTH) -> StandardMaterial3D:
	var cache := _cache()
	var key := "inkedflat|%s|%.3f" % [color.to_html(true), width]
	if cache.has(key):
		return cache[key]
	var m := flat(color).duplicate()
	m.next_pass = outline(width)
	cache[key] = m
	return m


## Give an existing mesh the ink line, whatever its material.
static func ink(mi: MeshInstance3D, width: float = Palette.INK_WIDTH) -> MeshInstance3D:
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


## Water: two moving bands of blue with a little foam on the crests, no
## textures, unshaded so it costs nothing and looks the same everywhere.
static func water() -> ShaderMaterial:
	var cache := _cache()
	if cache.has("water"):
		return cache["water"]
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode unshaded, cull_back; uniform vec4 deep : source_color; uniform vec4 light : source_color; uniform vec4 foam : source_color; varying vec3 wpos; void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; } void fragment() { float w1 = sin(wpos.x * 0.35 + wpos.z * 0.6 + TIME * 0.9); float w2 = sin(wpos.x * 0.9 - wpos.z * 0.4 + TIME * 1.4); float t = 0.5 + 0.25 * w1 + 0.25 * w2; vec3 c = mix(deep.rgb, light.rgb, t); float crest = smoothstep(0.86, 0.98, t); ALBEDO = mix(c, foam.rgb, crest * 0.6); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("deep", Palette.WATER_DEEP)
	m.set_shader_parameter("light", Palette.WATER_LIGHT)
	m.set_shader_parameter("foam", Palette.FOAM)
	cache["water"] = m
	return m


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
	mi.mesh = _box_mesh(size)
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
	mi.mesh = _sphere_mesh(radius)
	mi.material_override = soft(color)
	return mi


## A smooth capsule for limbs and bodies.
static func pill(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _capsule_mesh(radius, height)
	mi.material_override = soft(color)
	return mi


static func box(size: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = flat(color, unshaded)
	return mi


static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _capsule_mesh(radius, height)
	mi.material_override = flat(color)
	return mi


static func sphere(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh(radius)
	mi.material_override = flat(color)
	return mi


static func cone(radius: float, height: float, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cache := _cache()
	var key := "m|cone|%.3f|%.3f" % [radius, height]
	var mesh: CylinderMesh = cache.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 8
		mesh.rings = 1
		_keep(cache, key, mesh)
	mi.mesh = mesh
	mi.material_override = flat(color, unshaded)
	return mi


static func torus(inner: float, outer: float, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cache := _cache()
	var key := "m|torus|%.3f|%.3f" % [inner, outer]
	var mesh: TorusMesh = cache.get(key)
	if mesh == null:
		mesh = TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 14
		mesh.ring_segments = 6
		_keep(cache, key, mesh)
	mi.mesh = mesh
	mi.material_override = flat(color, unshaded)
	return mi


# --- shared meshes ---------------------------------------------------------
#
# Every ball, pill and box used to be a mesh of its own: a wave of forty
# zombies was eight hundred new vertex buffers in one frame, and a phone
# stopped for a fifth of a second to make them. Two things the same size
# now share one mesh. Nothing may change a mesh it got from here.

static func _keep(cache: Dictionary, key: String, value: Resource) -> void:
	var n := int(cache.get(MESH_COUNT_KEY, 0))
	if n >= MESH_CACHE_MAX:
		return
	cache[key] = value
	cache[MESH_COUNT_KEY] = n + 1


## How many meshes are being shared: for the tests and the bot.
static func shared_meshes() -> int:
	return int(_cache().get(MESH_COUNT_KEY, 0))


## Round things get the triangles their size on screen can show: a head
## is a hand's width of pixels, an eye is a few.
static func _sphere_mesh(radius: float) -> SphereMesh:
	var cache := _cache()
	var key := "m|sphere|%.3f" % radius
	var mesh: SphereMesh = cache.get(key)
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		if radius >= 0.2:
			mesh.radial_segments = 16
			mesh.rings = 8
		elif radius >= 0.08:
			mesh.radial_segments = 12
			mesh.rings = 6
		else:
			mesh.radial_segments = 8
			mesh.rings = 4
		_keep(cache, key, mesh)
	return mesh


static func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var cache := _cache()
	var key := "m|capsule|%.3f|%.3f" % [radius, height]
	var mesh: CapsuleMesh = cache.get(key)
	if mesh == null:
		mesh = CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 12 if radius >= 0.15 else 10
		mesh.rings = 4 if radius >= 0.15 else 3
		_keep(cache, key, mesh)
	return mesh


static func _box_mesh(size: Vector3) -> BoxMesh:
	var cache := _cache()
	var key := "m|box|%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	var mesh: BoxMesh = cache.get(key)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_keep(cache, key, mesh)
	return mesh


# --- welding ---------------------------------------------------------------

## One mesh from many. The parts of a thing that never move against each
## other (a zombie's torso, head and face; a leg and its foot) are drawn
## in one call instead of ten: each part keeps its colour as a vertex
## colour, its shape, and its ink line if it had one.
##
## [param key] names the result, so the second zombie of the same look
## costs one node and no new mesh. [param build] returns the parts (mesh
## instances from this class), each placed relative to the thing's own
## origin; it is only called the first time. [param origin] is taken off
## every part: put the welded mesh there to turn it about that point.
static func weld(key: String, build: Callable, origin: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var cache := _cache()
	var k := "weld|" + key
	var mesh: ArrayMesh = cache.get(k)
	if mesh == null:
		var parts: Array = build.call()
		mesh = weld_mesh(parts, origin)
		for p in parts:
			if p is Node:
				(p as Node).free()
		_keep(cache, k, mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## The mesh [method weld] makes: one surface per kind of material. Lit,
## plain-coloured parts share one vertex-coloured surface (two if some
## carry the ink line); glowing, see-through and textured parts keep the
## material they came with.
static func weld_mesh(parts: Array, origin: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var groups := {}
	var order: Array = []
	for p in parts:
		var mi := p as MeshInstance3D
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var picked := _weld_material(mi.material_override)
		var mat: Material = picked[0]
		var id := mat.get_instance_id() if mat != null else 0
		if not groups.has(id):
			groups[id] = {"mat": mat, "parts": []}
			order.append(id)
		(groups[id].parts as Array).append([mi, picked[1]])
	var out := ArrayMesh.new()
	for id in order:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for entry in groups[id].parts:
			var mi: MeshInstance3D = entry[0]
			# A primitive hands over its arrays without a trip to the
			# graphics card and back.
			var prim := mi.mesh as PrimitiveMesh
			var src: Array = prim.get_mesh_arrays() if prim != null else mi.mesh.surface_get_arrays(0)
			var xf := mi.transform
			xf.origin -= origin
			var v: PackedVector3Array = xf * (src[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			# Normals turn with the inverse transpose, so a squashed ball
			# still shades like one.
			var nb := xf.basis.inverse().transposed()
			var n: PackedVector3Array = Transform3D(nb, Vector3.ZERO) * (src[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			for j in range(n.size()):
				n[j] = n[j].normalized()
			var base := verts.size()
			verts.append_array(v)
			normals.append_array(n)
			var c := PackedColorArray()
			c.resize(v.size())
			c.fill(entry[1])
			colors.append_array(c)
			var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX] if src[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for j in range(v.size()):
					idx[j] = j
			# A mirrored part would come out inside out: wind it the other way.
			var flip := xf.basis.determinant() < 0.0
			var at := indices.size()
			indices.resize(at + idx.size())
			for j in range(0, idx.size(), 3):
				indices[at + j] = idx[j] + base
				indices[at + j + 1] = idx[j + (2 if flip else 1)] + base
				indices[at + j + 2] = idx[j + (1 if flip else 2)] + base
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, groups[id].mat)
	return out


## Which material a part is welded under, and the colour its vertices
## carry. A lit or unshaded part of one plain colour moves to a shared
## vertex-coloured material; anything cleverer keeps its own.
static func _weld_material(m: Material) -> Array:
	var std := m as StandardMaterial3D
	if std == null or std.albedo_texture != null or std.emission_enabled or std.albedo_color.a < 0.999 or std.vertex_color_use_as_albedo:
		return [m, Color.WHITE]
	var cache := _cache()
	var unshaded := std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	var pass_id := std.next_pass.get_instance_id() if std.next_pass != null else 0
	var key := "vc|%s|%d" % [unshaded, pass_id]
	if not cache.has(key):
		var twin := StandardMaterial3D.new()
		twin.vertex_color_use_as_albedo = true
		twin.vertex_color_is_srgb = true
		if unshaded:
			twin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		else:
			twin.roughness = 0.62
			twin.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			twin.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		twin.next_pass = std.next_pass
		cache[key] = twin
	return [cache[key], std.albedo_color]
