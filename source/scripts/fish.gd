extends Node3D
## One stream fish: procedural body mesh, swim shader, simple steering AI.
## States: WANDER -> NOTICE -> INSPECT -> NIBBLE -> BITE -> HOOKED -> LANDED / FLEE

enum S { WANDER, HOLD, NOTICE, INSPECT, NIBBLE, BITE, HOOKED, LANDED, FLEE }

const FISH_SHADER := preload("res://shaders/fish.gdshader")
const SHADOW_SHADER := preload("res://shaders/fishshadow.gdshader")
const VIS_SCALE := 2.2
var shadow: MeshInstance3D

var sp_id := ""
var sp: Dictionary
var length_cm := 20.0
var world
var state := S.WANDER
var vel := Vector3.ZERO
var target := Vector3.ZERO
var heading := 0.0
var t_state := 0.0
var mat: ShaderMaterial
var rng := RandomNumberGenerator.new()
var nibbles_left := 0
var float_ref: Node3D = null
var mesh_inst: MeshInstance3D

signal nibble(fish)
signal bite(fish)
signal gave_up(fish)

func setup(id: String, data: Dictionary, size_cm: float, w, seed_i: int) -> void:
	sp_id = id
	sp = data
	length_cm = size_cm
	world = w
	rng.seed = seed_i
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = build_mesh()
	mat = ShaderMaterial.new()
	mat.shader = FISH_SHADER
	var lk: Dictionary = sp.look
	mat.set_shader_parameter("back_color", _c(lk.back) * 0.5)
	mat.set_shader_parameter("side_color", _c(lk.side))
	mat.set_shader_parameter("belly_color", _c(lk.belly))
	mat.set_shader_parameter("spot_color", _c(lk.spot))
	mat.set_shader_parameter("accent_color", _c(lk.accent))
	mat.set_shader_parameter("parr", lk.parr)
	mat.set_shader_parameter("spots", lk.spots)
	mat.set_shader_parameter("red_spots", lk.red_spots)
	mat.set_shader_parameter("accent_band", lk.band)
	mat.set_shader_parameter("yellow_patch", lk.yellow)
	mat.set_shader_parameter("swim_phase", rng.randf() * TAU)
	mat.set_shader_parameter("noise_tex", load("res://tex/ink_noise.png"))
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	var s := length_cm / 100.0 * VIS_SCALE
	mesh_inst.scale = Vector3(s, s, s)
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(s * 0.42, s * 1.15)
	shadow.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = SHADOW_SHADER
	shadow.material_override = sm
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)
	heading = rng.randf() * TAU
	_pick_target()

func _c(a) -> Color:
	return Color(a[0], a[1], a[2])

static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NL := 18
	var NR := 12
	var rings := []
	for i in NL + 1:
		var t := float(i) / NL
		# body width/height profile (length 1, head at -z)
		var w := 0.11 * pow(sin(PI * pow(t, 0.62)), 0.9) * (1.0 - 0.55 * t)
		var h := 0.12 * pow(sin(PI * pow(t, 0.6)), 0.85) * (1.0 - 0.45 * t)
		if t > 0.86:
			w = lerp(w, 0.012, (t - 0.86) / 0.14)
			h = lerp(h, 0.035, (t - 0.86) / 0.14)
		var ring := []
		for k in NR:
			var a := TAU * k / NR
			ring.append(Vector3(sin(a) * w, cos(a) * h * 0.95 + 0.004, -0.5 + t))
		rings.append(ring)
	for i in NL:
		for k in NR:
			var k2 := (k + 1) % NR
			var t0 := float(i) / NL
			var t1 := float(i + 1) / NL
			var quad = [[rings[i][k], t0, float(k) / NR], [rings[i + 1][k], t1, float(k) / NR], [rings[i][k2], t0, float(k + 1) / NR],
				[rings[i][k2], t0, float(k + 1) / NR], [rings[i + 1][k], t1, float(k) / NR], [rings[i + 1][k2], t1, float(k + 1) / NR]]
			for q in quad:
				st.set_color(Color(0, 0, 0))
				st.set_uv(Vector2(q[1], q[2]))
				st.add_vertex(q[0])
	# caudal fin (forked, vertical)
	var fin_tris := [
		[Vector3(0, 0.01, 0.48), Vector3(0, 0.13, 0.63), Vector3(0, 0.02, 0.56)],
		[Vector3(0, 0.00, 0.48), Vector3(0, -0.11, 0.63), Vector3(0, -0.01, 0.56)],
		[Vector3(0, 0.01, 0.48), Vector3(0, 0.02, 0.56), Vector3(0, -0.01, 0.56)],
		[Vector3(0, 0.0, 0.48), Vector3(0, -0.01, 0.56), Vector3(0, 0.02, 0.56)],
		# dorsal
		[Vector3(0, 0.1, -0.1), Vector3(0, 0.17, -0.02), Vector3(0, 0.09, 0.06)],
		# pectorals (horizontal, visible from above)
		[Vector3(0.03, -0.02, -0.28), Vector3(0.09, -0.035, -0.2), Vector3(0.03, -0.025, -0.2)],
		[Vector3(-0.03, -0.02, -0.28), Vector3(-0.03, -0.025, -0.2), Vector3(-0.09, -0.035, -0.2)],
		# pelvic
		[Vector3(0.02, -0.04, 0.02), Vector3(0.06, -0.05, 0.1), Vector3(0.02, -0.045, 0.08)],
		[Vector3(-0.02, -0.04, 0.02), Vector3(-0.02, -0.045, 0.08), Vector3(-0.06, -0.05, 0.1)],
	]
	for tri in fin_tris:
		for v in tri:
			st.set_color(Color(1, 0, 0))
			st.set_uv(Vector2(v.z + 0.5, 0.0))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _pick_target() -> void:
	for i in 20:
		var z := rng.randf_range(-13.0, 4.0)
		var x: float = world.channel_center(z) + rng.randf_range(-0.8, 0.8) * world.channel_half(z)
		var d: float = world.water_depth_at(x, z)
		if d > 0.35 and not _in_rock(x, z, 0.3):
			target = Vector3(x, 0, z)
			return
	target = Vector3(world.channel_center(0.0), 0, 0.0)

func _in_rock(x: float, z: float, pad: float) -> bool:
	for r in world.rocks:
		if Vector2(r.pos.x - x, r.pos.z - z).length() < r.r * 0.9 + pad:
			return true
	return false

func swim_y(x: float, z: float) -> float:
	var bed: float = world.bed_height(x, z)
	return clamp(max(bed + 0.25, -0.5 - length_cm * 0.004), bed + 0.12, -0.14)

func set_state(s: int) -> void:
	state = s
	t_state = 0.0

func _process(dt: float) -> void:
	t_state += dt
	var desired := Vector3.ZERO
	var speed := 0.35
	match state:
		S.WANDER:
			if Vector2(target.x - position.x, target.z - position.z).length() < 0.6:
				if rng.randf() < 0.5:
					set_state(S.HOLD)
				_pick_target()
			desired = target - position
			speed = 0.3 + 0.1 * sin(t_state)
		S.HOLD:
			# face upstream (-z) and hold station in the current
			desired = Vector3(sin(t_state * 0.7) * 0.2, 0, -1.0)
			speed = 0.02
			if t_state > rng.randf_range(3.0, 7.0):
				set_state(S.WANDER)
		S.NOTICE:
			desired = float_ref.global_position - position
			speed = 0.45
			if Vector2(desired.x, desired.z).length() < 0.7:
				set_state(S.INSPECT)
				nibbles_left = rng.randi_range(0, 3)
		S.INSPECT:
			var to := float_ref.global_position - position
			desired = to
			speed = 0.18
			if t_state > 0.9 + rng.randf() * 1.2:
				if nibbles_left > 0:
					nibbles_left -= 1
					set_state(S.NIBBLE)
					nibble.emit(self)
				else:
					set_state(S.BITE)
					bite.emit(self)
		S.NIBBLE:
			desired = float_ref.global_position - position
			speed = 0.12
			if t_state > 0.45:
				set_state(S.INSPECT)
		S.BITE:
			desired = float_ref.global_position - position
			speed = 0.3
			if t_state > float(sp.bite_window):
				set_state(S.FLEE)
				gave_up.emit(self)
		S.HOOKED:
			_update_shadow()
			return   # driven by the game
		S.LANDED:
			shadow.visible = false
			return
		S.FLEE:
			desired = position - (float_ref.global_position if float_ref else position + Vector3(0, 0, 1))
			speed = 1.6
			if t_state > 2.0:
				set_state(S.WANDER)
				_pick_target()
	desired.y = 0
	if desired.length() > 0.001:
		var want := atan2(-desired.x, -desired.z)
		heading = lerp_angle(heading, want, clamp(dt * 2.2, 0.0, 1.0))
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var nx := position + fwd * speed * dt
	if _in_rock(nx.x, nx.z, 0.15) or world.water_depth_at(nx.x, nx.z) < 0.25:
		heading += dt * 2.5
		_pick_target()
	else:
		position.x = nx.x
		position.z = nx.z
	position.y = lerp(position.y, swim_y(position.x, position.z), dt * 2.0)
	rotation.y = heading
	_update_shadow()
	mat.set_shader_parameter("swim_freq", 5.0 + speed * 8.0)
	mat.set_shader_parameter("swim_amp", 0.04 + speed * 0.05)

func _update_shadow() -> void:
	if not world.sun:
		return
	var ld: Vector3 = world.sun.global_transform.basis.z   # toward the sun
	var bed: float = world.bed_height(global_position.x, global_position.z)
	var hgt: float = max(global_position.y - bed, 0.0)
	var off: Vector2 = Vector2(-ld.x, -ld.z) / max(ld.y, 0.3) * hgt
	shadow.global_position = Vector3(global_position.x + off.x, bed + 0.03, global_position.z + off.y)
	shadow.global_rotation = Vector3(0, heading, 0)
