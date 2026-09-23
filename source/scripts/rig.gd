extends Node3D
## Rod (rebuilt tapered loft bending toward the line), red-topped float,
## verlet fishing line from rod tip to float/fish.

var cam: Camera3D
var rod_mi := MeshInstance3D.new()
var line_mi := MeshInstance3D.new()
var line_mesh := ImmediateMesh.new()
var float_node := Node3D.new()
var pts: Array[Vector3] = []
var prev: Array[Vector3] = []
const NP := 26
var bend := 0.0          # 0 slack .. 1 heavy load
var line_end := Vector3.ZERO
var float_on_water := false
var bob := 0.0           # float dip amount (nibble/bite)
var tip := Vector3.ZERO
var rod_mat := StandardMaterial3D.new()
var grip_mat := StandardMaterial3D.new()
var reel_len := 1.0      # line slack factor

func setup(c: Camera3D) -> void:
	cam = c
	rod_mat.albedo_color = Color(1, 1, 1)
	rod_mat.vertex_color_use_as_albedo = true
	rod_mat.roughness = 0.35
	rod_mat.metallic_specular = 0.7
	rod_mi.material_override = rod_mat
	rod_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rod_mi)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.97, 0.95, 0.75)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mi.material_override = lm
	line_mi.mesh = line_mesh
	line_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line_mi)
	_build_float()
	add_child(float_node)
	for i in NP:
		pts.append(Vector3.ZERO)
		prev.append(Vector3.ZERO)

func _build_float() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.08, 0.06)
	red.emission_enabled = true
	red.emission = Color(0.35, 0.02, 0.0)
	red.roughness = 0.4
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.95, 0.9, 0.75)
	var top := MeshInstance3D.new()
	var sm := CapsuleMesh.new()
	sm.radius = 0.03
	sm.height = 0.16
	top.mesh = sm
	top.material_override = red
	top.position.y = 0.08
	float_node.add_child(top)
	var bot := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.045
	bm.height = 0.09
	bot.mesh = bm
	bot.material_override = body
	float_node.add_child(bot)

func rod_base() -> Vector3:
	return cam.global_transform * Vector3(0.4, -0.46, -0.42)

func rod_dir_to(target: Vector3) -> Vector3:
	var b := rod_base()
	var d := (target - b)
	d.y = 0
	d = d.normalized()
	return (d * 0.9 + Vector3(0, 0.36, 0)).normalized()

func _rebuild_rod(target: Vector3) -> void:
	var b := rod_base()
	var dir := rod_dir_to(target)
	var L := 3.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N := 22
	var sides := 6
	var pull := (target - b).normalized()
	var centers: Array[Vector3] = []
	for i in N + 1:
		var t := float(i) / N
		var p := b + dir * L * t
		p += (pull - dir) * L * t * t * bend * 0.45
		p.y -= t * t * 0.25 * (0.3 + bend)
		centers.append(p)
	tip = centers[N]
	for i in N:
		var t0 := float(i) / N
		var t1 := float(i + 1) / N
		var r0: float = (0.011 if t0 < 0.05 else lerp(0.0055, 0.0012, t0))
		var r1: float = (0.011 if t0 < 0.05 else lerp(0.0055, 0.0012, t1))
		var a := centers[i]
		var c := centers[i + 1]
		var ax := (c - a).normalized()
		var s1 := ax.cross(Vector3.UP).normalized()
		var s2 := ax.cross(s1).normalized()
		st.set_color(Color(0.62, 0.46, 0.28) if t0 < 0.05 else Color(0.03, 0.03, 0.035))
		for k in sides:
			var q0 := TAU * k / sides
			var q1 := TAU * (k + 1) / sides
			var o00 := (s1 * cos(q0) + s2 * sin(q0))
			var o01 := (s1 * cos(q1) + s2 * sin(q1))
			for v in [a + o00 * r0, c + o00 * r1, a + o01 * r0, a + o01 * r0, c + o00 * r1, c + o01 * r1]:
				st.add_vertex(v)
	st.generate_normals()
	rod_mi.mesh = st.commit()

func reset_line(end: Vector3) -> void:
	for i in NP:
		var t := float(i) / (NP - 1)
		pts[i] = tip.lerp(end, t)
		prev[i] = pts[i]

func step(dt: float, end: Vector3, taut: bool, aim = null) -> void:
	line_end = end
	_rebuild_rod(aim if aim != null else end)
	var total := tip.distance_to(end)
	var seg := total * (1.0 if taut else 1.08) / (NP - 1)
	for i in range(1, NP - 1):
		var p := pts[i]
		var v := (p - prev[i]) * (0.9 if p.y < 0.0 else 0.98)
		prev[i] = p
		pts[i] = p + v + Vector3(0, -3.0 if p.y > 0.0 else -0.2, 0) * dt * dt
	pts[0] = tip
	pts[NP - 1] = end
	for it in 12:
		for i in NP - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var d := b - a
			var l := d.length()
			if l < 1e-5:
				continue
			var diff := (l - seg) / l * 0.5
			if i != 0:
				pts[i] = a + d * diff
			if i + 1 != NP - 1:
				pts[i + 1] = b - d * diff
		pts[0] = tip
		pts[NP - 1] = end
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()
