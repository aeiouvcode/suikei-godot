extends Node3D
## Builds one pool: riverbed heightfield, water surface, granite boulders,
## cedar banks, light and environment. Exposes bed_height() and rock circles
## so fish can steer.

const BED_SHADER := preload("res://shaders/bed.gdshader")
const ROCK_SHADER := preload("res://shaders/rock.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")

var cfg: Dictionary
var seedf := 0.0
var depth := 1.5
var half_w := 5.0
var rocks: Array = []   # [{pos: Vector3, r: float, top: float}]
var noise := FastNoiseLite.new()
var fine := FastNoiseLite.new()
var water_mat: ShaderMaterial
var sun: DirectionalLight3D
var env: WorldEnvironment
var rapid_z := -17.0
var rng := RandomNumberGenerator.new()

const X0 := -15.0
const X1 := 15.0
const Z0 := -36.0
const Z1 := 14.0

func build(c: Dictionary) -> void:
	cfg = c
	rng.seed = int(c.seed)
	seedf = float(c.seed)
	depth = float(c.depth)
	half_w = float(c.half_w)
	noise.seed = int(c.seed)
	noise.frequency = 0.08
	noise.fractal_octaves = 4
	fine.seed = int(c.seed) + 5
	fine.frequency = 0.6
	RenderingServer.global_shader_parameter_set("g_absorb", Vector3(c.absorb[0], c.absorb[1], c.absorb[2]))
	RenderingServer.global_shader_parameter_set("g_scatter", Vector3(c.scatter[0], c.scatter[1], c.scatter[2]))
	_place_rocks(int(c.rocks))
	print("done _place_rocks ", Time.get_ticks_msec())
	_build_bed()
	print("done _build_bed ", Time.get_ticks_msec())
	_build_water()
	print("done _build_water ", Time.get_ticks_msec())
	for r in rocks:
		_build_rock(r)
	for i in 18:
		var z := rng.randf_range(-24.0, 10.0)
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		var x := channel_center(z) + sgn * (channel_half(z) + rng.randf_range(0.3, 4.0))
		var base := bed_height(x, z)
		if base < 0.0:
			continue
		var r := rng.randf_range(0.3, 0.9)
		_build_rock({"pos": Vector3(x, base - 0.1, z), "r": r, "top": base + r * rng.randf_range(0.5, 0.9)})
	_build_trees()
	print("done _build_trees ", Time.get_ticks_msec())
	_build_light(c.sun)
	print("done _build_light ", Time.get_ticks_msec())

func channel_center(z: float) -> float:
	return sin(z * 0.085 + seedf) * 1.6 + sin(z * 0.21 + seedf * 2.1) * 0.5

func channel_half(z: float) -> float:
	return half_w + sin(z * 0.12 + seedf * 3.0) * 1.0

func bed_height(x: float, z: float) -> float:
	var xc := channel_center(z)
	var hw := channel_half(z)
	var u: float = abs(x - xc) / hw
	var pool := depth * (0.45 + 0.55 * exp(-pow((z + 3.0) / 10.0, 2.0)))
	if z < rapid_z + 3.0:
		pool *= lerp(1.0, 0.35, clamp((rapid_z + 3.0 - z) / 6.0, 0.0, 1.0))
	var h: float
	if u < 1.0:
		h = -pool * pow(1.0 - u * u, 0.65) + 0.04
	else:
		var s := (u - 1.0) * hw
		h = 0.04 + s * 0.42 + s * s * 0.05
		if z < rapid_z:
			h += (rapid_z - z) * 0.03
	h += noise.get_noise_2d(x, z) * 0.28 + fine.get_noise_2d(x, z) * 0.04
	if z < rapid_z:
		h += (rapid_z - z) * 0.09
	if h > 1.6:
		h = 1.6 + (h - 1.6) * 0.7
	return h

func water_depth_at(x: float, z: float) -> float:
	return -bed_height(x, z)

func _place_rocks(n: int) -> void:
	rocks.clear()
	var tries := 0
	while rocks.size() < n and tries < 400:
		tries += 1
		var z := rng.randf_range(-22.0, 9.0)
		var side := rng.randf()
		var xc := channel_center(z)
		var hw := channel_half(z)
		var x: float
		var r: float
		if side < 0.45:
			# submerged in the channel
			x = xc + rng.randf_range(-0.8, 0.8) * hw
			r = rng.randf_range(0.7, 1.5)
		else:
			# bank boulders that break the surface
			var sgn := -1.0 if rng.randf() < 0.5 else 1.0
			x = xc + sgn * hw * rng.randf_range(0.8, 1.35)
			r = rng.randf_range(1.0, 2.2)
		# keep the near foreground (casting lane) open
		if z > 4.0 and abs(x - xc) < hw * 0.7:
			continue
		var ok := true
		for o in rocks:
			if Vector2(o.pos.x - x, o.pos.z - z).length() < (o.r + r) * 0.95:
				ok = false
				break
		if not ok:
			continue
		var base := bed_height(x, z)
		var top: float
		if side < 0.45:
			top = min(base + r * 0.9, -0.12 - rng.randf() * 0.35)
		else:
			top = base + r * rng.randf_range(0.7, 1.1)
		rocks.append({"pos": Vector3(x, base, z), "r": r, "top": top})

func _build_bed() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.28
	var nx := int((X1 - X0) / step) + 1
	var nz := int((Z1 - Z0) / step) + 1
	for j in nz:
		for i in nx:
			var x := X0 + i * step
			var z := Z0 + j * step
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, bed_height(x, z), z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + nx)
			st.add_index(a + 1); st.add_index(a + nx + 1); st.add_index(a + nx)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = BED_SHADER
	m.set_shader_parameter("albedo_tex", load("res://tex/pebbles.png"))
	m.set_shader_parameter("normal_tex", load("res://tex/pebbles_n.png"))
	m.set_shader_parameter("detail_noise", load("res://tex/ink_noise.png"))
	mi.material_override = m
	add_child(mi)

func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(X1 - X0, Z1 - Z0)
	pm.subdivide_width = 8
	pm.subdivide_depth = 12
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3((X0 + X1) * 0.5, 0.0, (Z0 + Z1) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water_mat.set_shader_parameter("channel_half", half_w)
	water_mat.set_shader_parameter("rapid_z", rapid_z)
	water_mat.set_shader_parameter("foam_noise", load("res://tex/ink_noise.png"))
	water_mat.render_priority = 1
	mi.material_override = water_mat
	add_child(mi)

func _build_rock(r: Dictionary) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 28
	sm.rings = 16
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = 0.9
	n.fractal_octaves = 3
	var sx := rng.randf_range(0.85, 1.25)
	var sz := rng.randf_range(0.8, 1.2)
	var height: float = r.top - r.pos.y
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + n.get_noise_3dv(v * 1.2) * 0.28 + n.get_noise_3dv(v * 4.0) * 0.04
		v *= d
		# flatten into a river-worn boulder: wide, rounded top, buried base
		var ty := (v.y + 0.3) / 1.3
		v.y = ty * height if ty > 0.0 else ty * r.r * 0.6
		v.x *= r.r * sx
		v.z *= r.r * sz
		verts[i] = v
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.deindex()
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = r.pos
	mi.rotation.y = rng.randf() * TAU
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	m.set_shader_parameter("rock_noise", load("res://tex/rock_noise.png"))
	m.set_shader_parameter("seed", rng.randf() * 10.0)
	m.set_shader_parameter("moss_amount", rng.randf_range(0.4, 1.0))
	var g := rng.randf_range(0.46, 0.6)
	m.set_shader_parameter("granite", Color(g, g, g * 0.97))
	mi.material_override = m
	add_child(mi)

func _cedar_mesh(h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 9
	# trunk
	st.set_color(Color(0, 0, 0))
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var rb := h * 0.025
		var rt := h * 0.008
		var p0 := Vector3(cos(a0) * rb, 0, sin(a0) * rb)
		var p1 := Vector3(cos(a1) * rb, 0, sin(a1) * rb)
		var q0 := Vector3(cos(a0) * rt, h * 0.9, sin(a0) * rt)
		var q1 := Vector3(cos(a1) * rt, h * 0.9, sin(a1) * rt)
		for v in [p0, q0, p1, p1, q0, q1]:
			st.add_vertex(v)
	# sugi crown: many narrow drooping tiers tapering to a spire
	st.set_color(Color(0, 1, 0))
	var tiers := 13
	for k in tiers:
		var f := float(k) / tiers
		var y0 := h * (0.3 + 0.62 * f)
		var rad := h * 0.13 * pow(1.0 - f, 0.9) + h * 0.015
		var y1 := y0 + h * 0.12
		var off := Vector3(sin(k * 2.3) * 0.08, 0, cos(k * 1.7) * 0.08) * rad
		for i in seg:
			var a0 := TAU * i / seg + k * 0.7
			var a1 := TAU * (i + 1) / seg + k * 0.7
			var jag0: float = 0.8 + 0.4 * abs(sin(a0 * 2.5 + k * 1.3))
			var jag1: float = 0.8 + 0.4 * abs(sin(a1 * 2.5 + k * 1.3))
			var b0 := Vector3(cos(a0) * rad * jag0, y0 - rad * 0.45, sin(a0) * rad * jag0) + off
			var b1 := Vector3(cos(a1) * rad * jag1, y0 - rad * 0.45, sin(a1) * rad * jag1) + off
			var tip := Vector3(0, y1, 0) + off * 0.3
			for v in [b0, tip, b1]:
				st.add_vertex(v)
			# underside so tiers read as dense from below
			var inner := Vector3(0, y0 - rad * 0.1, 0) + off
			for v in [b1, inner, b0]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _build_trees() -> void:
	var meshes := [_cedar_mesh(11.0), _cedar_mesh(14.0), _cedar_mesh(17.0)]
	var mat := ShaderMaterial.new()
	mat.shader = FOLIAGE_SHADER
	mat.set_shader_parameter("noise_tex", load("res://tex/ink_noise.png"))
	var placed := 0
	var tries := 0
	while placed < 90 and tries < 900:
		tries += 1
		var z := rng.randf_range(Z0 + 2.0, Z1 - 2.0)
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		var x := channel_center(z) + sgn * (channel_half(z) + rng.randf_range(5.0, 12.0))
		if x < X0 + 0.5 or x > X1 - 0.5:
			continue
		var y := bed_height(x, z)
		if y < 0.8:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[rng.randi() % 3]
		mi.material_override = mat
		mi.position = Vector3(x, y - 0.3, z)
		mi.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.8, 1.2)
		mi.scale = Vector3(s, s, s)
		add_child(mi)
		placed += 1
	# undergrowth: low shrubs and ferny mounds along the banks
	var bush := _bush_mesh()
	var bmat := ShaderMaterial.new()
	bmat.shader = FOLIAGE_SHADER
	bmat.set_shader_parameter("noise_tex", load("res://tex/ink_noise.png"))
	bmat.set_shader_parameter("leaf", Color(0.075, 0.115, 0.055))
	var nb := 0
	tries = 0
	while nb < 90 and tries < 900:
		tries += 1
		var z := rng.randf_range(Z0 + 4.0, Z1 - 1.0)
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		var x := channel_center(z) + sgn * (channel_half(z) + rng.randf_range(1.8, 8.0))
		if x < X0 or x > X1:
			continue
		var y := bed_height(x, z)
		if y < 0.45:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bush
		mi.material_override = bmat
		mi.position = Vector3(x, y - 0.15, z)
		mi.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.5, 1.4)
		mi.scale = Vector3(s * rng.randf_range(0.9, 1.6), s * rng.randf_range(0.5, 0.9), s)
		add_child(mi)
		nb += 1
	# upstream forest wall
	for i in 26:
		var x := rng.randf_range(X0, X1)
		var z := rng.randf_range(Z0, Z0 + 6.0)
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[rng.randi() % 3]
		mi.material_override = mat
		mi.position = Vector3(x, bed_height(x, z) - 0.3, z)
		add_child(mi)

func _bush_mesh() -> ArrayMesh:
	# several leafy lobes per shrub instead of one smooth blob
	var n := FastNoiseLite.new()
	n.frequency = 1.6
	var r := RandomNumberGenerator.new()
	r.seed = 4711
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := 6
	for l in lobes:
		var sm := SphereMesh.new()
		var rad := r.randf_range(0.45, 0.75)
		sm.radius = rad
		sm.height = rad * 2.0
		sm.radial_segments = 9
		sm.rings = 5
		var arr := sm.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var ang := TAU * float(l) / float(lobes) + r.randf() * 0.6
		var off := Vector3(cos(ang) * r.randf_range(0.2, 0.6), r.randf_range(0.0, 0.5), sin(ang) * r.randf_range(0.2, 0.6))
		if l == 0:
			off = Vector3(0, 0.45, 0)
		var tint := r.randf()
		for i in verts.size():
			var v := verts[i]
			v *= 1.0 + n.get_noise_3dv(v * 3.0 + off * 5.0) * 0.55
			v += off
			if v.y < 0.0:
				v.y *= 0.25
			verts[i] = v
		for k in idx.size():
			st.set_color(Color(tint, 1, 0))
			st.add_vertex(verts[idx[k]])
	st.generate_normals()
	return st.commit()

func _build_light(sun_angles) -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_angles[0], sun_angles[1], 0)
	RenderingServer.global_shader_parameter_set("g_sun_dir", Basis.from_euler(sun.rotation).z.normalized())
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.45, 0.62, 0.78)
	sm.sky_horizon_color = Color(0.78, 0.84, 0.86)
	sm.ground_horizon_color = Color(0.3, 0.36, 0.3)
	sm.ground_bottom_color = Color(0.12, 0.16, 0.12)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.9
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.1
	e.fog_enabled = true
	e.fog_light_color = Color(0.62, 0.72, 0.72)
	e.fog_density = 0.006
	e.fog_sky_affect = 0.3
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.08
	e.adjustment_contrast = 1.05
	env.environment = e
	add_child(env)
