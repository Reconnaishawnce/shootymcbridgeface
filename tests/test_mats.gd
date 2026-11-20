extends TestCase
## The draw-call budget. A Galaxy S23 Ultra sent a report of 25 frames a
## second on level 1: 5,400 draw calls and 2.1 million triangles for 81
## soldiers and 62 zombies, because every ball and pill of every body
## was a mesh and a draw of its own. These tests hold the line.


## What one body asks of the renderer in the main pass: a draw for every
## surface of every mesh, and one more where a surface carries the ink.
func _draws(root: Node, shadow_pass: bool = false) -> int:
	var n := 0
	var mi := root as MeshInstance3D
	if mi != null and mi.visible and mi.mesh != null:
		if not shadow_pass or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			for s in range(mi.mesh.get_surface_count()):
				n += 1
				var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(s)
				if not shadow_pass and mat != null and mat.next_pass != null:
					n += 1
	for c in root.get_children():
		if not (c is Node3D) or (c as Node3D).visible:
			n += _draws(c, shadow_pass)
	return n


func _triangles(root: Node) -> int:
	var n := 0
	var mi := root as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s in range(mi.mesh.get_surface_count()):
			var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(s) if mi.mesh is ArrayMesh else (mi.mesh as PrimitiveMesh).get_mesh_arrays()
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				n += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	for c in root.get_children():
		n += _triangles(c)
	return n


func test_same_size_same_mesh() -> void:
	Mats.clear()
	var a := Mats.ball(0.25, Color.RED)
	var b := Mats.ball(0.25, Color.BLUE)
	var c := Mats.ball(0.1, Color.RED)
	var others := [Mats.pill(0.1, 0.4, Color.RED), Mats.pill(0.1, 0.4, Color.GREEN), Mats.box(Vector3.ONE, Color.RED), Mats.box(Vector3.ONE, Color.RED, true), Mats.ball(0.05, Color.RED)]
	check(a.mesh == b.mesh, "two balls the same size share one mesh")
	check(a.mesh != c.mesh, "a different size is a different mesh")
	check(others[0].mesh == others[1].mesh, "pills too")
	check(others[2].mesh == others[3].mesh, "and boxes")
	check((a.mesh as SphereMesh).radial_segments > (others[4].mesh as SphereMesh).radial_segments, "an eye gets fewer triangles than a head")
	for n in [a, b, c] + others:
		n.free()
	Mats.clear()


func test_weld() -> void:
	Mats.clear()
	var calls := [0]
	var build := func() -> Array:
		calls[0] += 1
		var body := Mats.ink(Mats.ball(0.3, Color.RED), 0.03)
		var patch := Mats.ball(0.1, Color.BLUE)
		patch.position = Vector3(0.0, 1.0, 0.0)
		var patch2 := Mats.ball(0.1, Color.GREEN)
		patch2.position = Vector3(0.0, 2.0, 0.0)
		patch2.scale = Vector3(-1.0, 1.0, 1.0)
		var eye := Mats.sphere(0.05, Color.RED)
		eye.material_override = Mats.glow(Color.RED, 2.2)
		return [body, patch, patch2, eye]
	var one := Mats.weld("test", build)
	var two := Mats.weld("test", build)
	check_eq(calls[0], 1, "the parts are only built the first time")
	check(one.mesh == two.mesh, "the second of a look shares the first's mesh")
	var mesh := one.mesh as ArrayMesh
	check_eq(mesh.get_surface_count(), 3, "inked, plain and glowing: three surfaces from four parts")
	check(mesh.surface_get_material(0).next_pass != null, "the inked part keeps its line")
	check(mesh.surface_get_material(1).next_pass == null, "and the plain ones stay plain")
	check((mesh.surface_get_material(1) as StandardMaterial3D).vertex_color_use_as_albedo, "colour rides on the vertices")
	var plain := mesh.surface_get_arrays(1)
	var colors: PackedColorArray = plain[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = plain[Mesh.ARRAY_VERTEX]
	check(colors[0].is_equal_approx(Color.BLUE) and colors[colors.size() - 1].is_equal_approx(Color.GREEN), "each part keeps its own colour")
	var top := -INF
	for v in verts:
		top = maxf(top, v.y)
	check_near(top, 2.1, 0.001, "and its place")
	# The mirrored part faces out: its first triangle's winding agrees
	# with its normals, like the unmirrored one's.
	var idx: PackedInt32Array = plain[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = plain[Mesh.ARRAY_NORMAL]
	var agree := [0, 0]
	for t in range(0, idx.size(), 3):
		var p0 := verts[idx[t]]
		var p1 := verts[idx[t + 1]]
		var p2 := verts[idx[t + 2]]
		var face := (p2 - p0).cross(p1 - p0)
		if face.length() < 0.000001:
			continue
		var which := 0 if p0.y < 1.5 else 1
		agree[which] += 1 if face.dot(normals[idx[t]] + normals[idx[t + 1]] + normals[idx[t + 2]]) > 0.0 else -1
	check(agree[0] != 0 and signi(agree[0]) == signi(agree[1]), "a mirrored part is not inside out")
	var moved := Mats.weld("test_origin", build, Vector3(0.0, 1.0, 0.0))
	var moved_top := -INF
	for v in (moved.mesh as ArrayMesh).surface_get_arrays(1)[Mesh.ARRAY_VERTEX]:
		moved_top = maxf(moved_top, v.y)
	check_near(moved_top, 1.1, 0.001, "the origin comes off every part")
	for n in [one, two, moved]:
		n.free()
	Mats.clear()


func test_zombie_budget() -> void:
	Mats.clear()
	var worst := 0
	var worst_shadow := 0
	var worst_tris := 0
	for kind in range(Zombie.Kind.size()):
		var z := Zombie.new()
		z.setup(10.0, 2.0, kind)
		worst = maxi(worst, _draws(z))
		worst_shadow = maxi(worst_shadow, _draws(z, true))
		worst_tris = maxi(worst_tris, _triangles(z))
		z.free()
	check(worst <= 14, "a zombie is at most 14 draws (a walker was 23, a tank 28): %d" % worst)
	check(worst_shadow <= 4, "and at most 4 in the shadow pass (they were 17 and 21): %d" % worst_shadow)
	check(worst_tris <= 4400, "the heaviest kind is under 4,400 triangles before its ink, about half what it was: %d" % worst_tris)
	# A wave: the looks are all made by now, so more zombies are no more meshes.
	var crowd: Array = []
	for i in range(400):
		var z := Zombie.new()
		z.setup(10.0, 2.0, Zombie.Kind.NORMAL)
		crowd.append(z)
	var before := Mats.shared_meshes()
	for i in range(40):
		var z := Zombie.new()
		z.setup(10.0, 2.0, Zombie.Kind.NORMAL)
		crowd.append(z)
	check_eq(Mats.shared_meshes(), before, "a wave of forty makes no new mesh")
	check(before < 120, "all the looks of a walker fit in a hundred-odd meshes: %d" % before)
	var z0: Zombie = crowd[0]
	var healthy := _draws(z0)
	z0.take_damage(1.0)
	check_eq(_draws(z0), healthy + 2, "the health bar is made by the first hit, not before")
	for z in crowd:
		z.free()
	Mats.clear()


func test_soldier_budget() -> void:
	Mats.clear()
	var back := Soldier.new(false, "rifle", {})
	check(_draws(back) <= 6, "a soldier in the crowd is at most 6 draws (it was 10): %d" % _draws(back))
	check(_draws(back, true) <= 2, "and 2 in the shadow pass: %d" % _draws(back, true))
	var front := Soldier.new(true, "medic", {})
	check(_draws(front) <= 16, "one in the front rank at most 16 (it was 31): %d" % _draws(front))
	back.flash()
	check(_draws(back) <= 8, "firing adds the muzzle flash and nothing else")
	# Every wardrobe piece still builds, and none of them breaks the budget.
	var worst := 0
	for hat in ["helmet", "cap", "beanie", "headband", "cat", "party", "viking", "crown", "wizard", "halo", "bunny", "chef"]:
		for pack in ["pack", "cape_red", "wings", "jetpack", "balloon", "shell"]:
			var s := Soldier.new(true, "rifle", {"hat": hat, "back": pack, "weapon": "neon"})
			worst = maxi(worst, _draws(s))
			s.free()
	check(worst <= 20, "the fanciest outfit is at most 20: %d" % worst)
	var before := Mats.shared_meshes()
	var squad: Array = []
	for i in range(60):
		squad.append(Soldier.new(false, "rifle", {}))
	check(Mats.shared_meshes() - before <= 8, "sixty more soldiers are a handful of skin tones, not sixty heads: %d" % (Mats.shared_meshes() - before))
	for s in squad:
		s.free()
	back.free()
	front.free()
	Mats.clear()
