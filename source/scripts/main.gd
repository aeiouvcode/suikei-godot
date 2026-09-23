extends Node3D
## SUIKEI game controller: pools, casting, bite, fight, landing, journal.

enum G { TITLE, IDLE, CASTING, WAITING, BITE, FIGHT, LANDING, CARD, TRAVEL }

const WorldScript := preload("res://scripts/world.gd")
const FishScript := preload("res://scripts/fish.gd")
const RigScript := preload("res://scripts/rig.gd")
const UIScript := preload("res://scripts/ui.gd")
const RIPPLE_SHADER := preload("res://shaders/ripple.gdshader")

var species: Dictionary
var pools: Array
var journal := {"best": {}, "count": {}, "pool": {}, "unlocked": 1, "total": 0}
var pool_idx := 0
var world: Node3D
var cam: Camera3D
var rig
var ui
var fishes: Array = []
var state := G.TITLE
var holding := false
var cast_from := Vector3.ZERO
var cast_to := Vector3.ZERO
var cast_t := 0.0
var wait_t := 0.0
var engaged = null
var hooked = null
var fight := {}
var land_t := 0.0
var ripple_slots: Array = []
var ripple_i := 0
var rng := RandomNumberGenerator.new()
var last_catch := {}
var cam_base: Transform3D
var qa_mode := false
var amb := AudioStreamPlayer.new()
var sfx_players: Array = []
var sfx_i := 0
var sounds := {}
var tick_t := 0.0

func _ready() -> void:
	rng.randomize()
	species = JSON.parse_string(FileAccess.get_file_as_string("res://data/species.json"))
	pools = JSON.parse_string(FileAccess.get_file_as_string("res://data/pools.json"))
	_load_journal()
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.near = 0.05
	cam.far = 120.0
	add_child(cam)
	rig = RigScript.new()
	add_child(rig)
	rig.setup(cam)
	ui = UIScript.new()
	add_child(ui)
	ui.setup(self)
	for n in ["splash", "plop", "tick", "snap"]:
		sounds[n] = load("res://audio/%s.wav" % n)
	for i in 4:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		sfx_players.append(ap)
	var st: AudioStreamWAV = load("res://audio/stream.wav")
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = 12 * 22050
	amb.stream = st
	amb.volume_db = -8.0
	add_child(amb)
	for i in 8:
		ripple_slots.append(Vector4(0, 0, -10, 0))
	start_pool(0)
	ui.show_title()
	if "dbg" in OS.get_cmdline_user_args():
		var d = preload("res://scripts/dbg.gd").new()
		add_child(d)
		d.run(self)
	if "qa" in OS.get_cmdline_user_args():
		var q = preload("res://scripts/qa.gd").new()
		add_child(q)
		q.run(self)

# ---------------------------------------------------------------- pools
func start_pool(i: int) -> void:
	pool_idx = i
	if world:
		world.queue_free()
		for f in fishes:
			f.queue_free()
	fishes.clear()
	engaged = null
	hooked = null
	world = WorldScript.new()
	add_child(world)
	move_child(world, 0)
	var p: Dictionary = pools[i]
	world.build(p)
	var z0 := 9.0
	var xc: float = world.channel_center(z0)
	cam.position = Vector3(xc + 1.0, 2.5, z0)
	cam.look_at(Vector3(world.channel_center(0.0), -1.1, 0.0))
	cam_base = cam.transform
	var weights: Dictionary = p.species
	for k in int(p.fish):
		var id := _weighted(weights)
		var sd: Dictionary = species[id]
		var f = FishScript.new()
		world.add_child(f)
		var size := _roll_size(sd)
		f.setup(id, sd, size, world, rng.randi())
		var z := rng.randf_range(-8.0, 4.0)
		f.position = Vector3(world.channel_center(z) + rng.randf_range(-0.5, 0.5) * world.channel_half(z), 0, z)
		f.position.y = f.swim_y(f.position.x, f.position.z)
		f.float_ref = rig.float_node
		f.nibble.connect(_on_nibble)
		f.bite.connect(_on_bite)
		f.gave_up.connect(_on_gave_up)
		fishes.append(f)
	rig.float_node.visible = false
	state = G.IDLE
	rig.bend = 0.0
	var tip_target := cam.global_transform * Vector3(0.9, -1.6, -3.5)
	rig.step(0.016, tip_target, false)
	rig.reset_line(tip_target)
	ui.on_pool(p, _pool_count(p.id))

func _weighted(w: Dictionary) -> String:
	var tot := 0.0
	for k in w:
		tot += float(w[k]) * float(species[k].rarity)
	var r := rng.randf() * tot
	for k in w:
		r -= float(w[k]) * float(species[k].rarity)
		if r <= 0.0:
			return k
	return w.keys()[0]

func _roll_size(sd: Dictionary) -> float:
	var a: float = sd.min
	var b: float = sd.max
	var u := pow(rng.randf(), 1.8)   # big fish are rarer
	return snappedf(lerp(a, b, u), 0.1)

func _pool_count(id: String) -> int:
	return int(journal.pool.get(id, 0))

# ---------------------------------------------------------------- input
func _unhandled_input(ev: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed = ev.pressed
		released = not ev.pressed
		pos = ev.position
	elif ev is InputEventScreenTouch:
		pressed = ev.pressed
		released = not ev.pressed
		pos = ev.position
	else:
		return
	if pressed:
		holding = true
		press_at(pos)
	elif released:
		holding = false

func press_at(screen: Vector2) -> void:
	match state:
		G.IDLE:
			var hit = water_point(screen)
			if hit != null:
				try_cast(hit)
		G.WAITING:
			if engaged and engaged.state in [FishScript.S.INSPECT, FishScript.S.NIBBLE]:
				engaged.set_state(FishScript.S.FLEE)
				ui.flash_message("早合わせ", "Too early - it spooked")
				engaged = null
			reel_in()
		G.BITE:
			start_fight()

func water_point(screen: Vector2):
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if d.y >= -0.01:
		return null
	var t := -o.y / d.y
	var p := o + d * t
	if world.water_depth_at(p.x, p.z) < 0.15:
		ui.flash_message("", "Cast onto the water")
		return null
	var dist := Vector2(p.x - cam.position.x, p.z - cam.position.z).length()
	if dist > 17.0:
		ui.flash_message("", "Too far to reach")
		return null
	return p

func try_cast(p: Vector3) -> void:
	state = G.CASTING
	cast_from = rig.tip
	cast_to = Vector3(p.x, 0.0, p.z)
	cast_t = 0.0
	rig.float_node.visible = true
	ui.set_hint("")

func reel_in() -> void:
	state = G.IDLE
	rig.float_node.visible = false
	engaged = null
	ui.set_hint("Tap the water to cast")

# ---------------------------------------------------------------- fish events
func _on_nibble(f) -> void:
	if f == engaged and state == G.WAITING:
		rig.bob = 0.5
		sfx("plop", -12.0)
		add_ripple(rig.float_node.position, 0.35)

func _on_bite(f) -> void:
	if f == engaged and state == G.WAITING:
		state = G.BITE
		rig.bob = 1.0
		sfx("plop", -2.0)
		add_ripple(rig.float_node.position, 1.0)
		ui.show_strike()

func _on_gave_up(f) -> void:
	if f == engaged and state == G.BITE:
		state = G.WAITING
		engaged = null
		wait_t = 0.0
		rig.bob = 0.0
		ui.hide_strike()
		ui.flash_message("逃げた", "Missed the take")

func start_fight() -> void:
	hooked = engaged
	engaged = null
	hooked.set_state(FishScript.S.HOOKED)
	state = G.FIGHT
	ui.hide_strike()
	var sd: Dictionary = hooked.sp
	var sizef: float = inverse_lerp(float(sd.min), float(sd.max), hooked.length_cm)
	fight = {
		"time": float(sd.fight_time), "max_time": float(sd.fight_time),
		"progress": 0.0, "tension": 0.0,
		"strength": float(sd.strength) * (0.75 + 0.5 * sizef),
		"run": 0.0, "run_cd": rng.randf_range(0.6, 1.4), "dart": Vector3.ZERO,
		"start": hooked.position,
	}
	ui.show_fight(fight)

# ---------------------------------------------------------------- loop
func _process(dt: float) -> void:
	_update_ripples()
	match state:
		G.CASTING:
			cast_t += dt / 0.75
			var t: float = min(cast_t, 1.0)
			var p: Vector3 = cast_from.lerp(cast_to, t)
			p.y = lerp(cast_from.y, 0.0, t) + sin(t * PI) * 1.6
			rig.float_node.position = p
			rig.step(dt, p, false)
			if cast_t >= 1.0:
				_on_land()
		G.WAITING, G.BITE:
			_float_bob(dt)
			rig.step(dt, rig.float_node.position + Vector3(0, 0.03, 0), false)
			if state == G.WAITING:
				_waiting(dt)
		G.FIGHT:
			_fight(dt)
		G.LANDING:
			_landing(dt)
		G.IDLE, G.CARD, G.TITLE:
			var tip_target := cam.global_transform * Vector3(0.9, -1.6, -3.5)
			rig.bend = move_toward(rig.bend, 0.0, dt)
			rig.step(dt, rig.tip + Vector3(0, -0.7, 0), false, tip_target)

func _on_land() -> void:
	state = G.WAITING
	wait_t = 0.0
	add_ripple(cast_to, 1.0)
	sfx("splash", -4.0)
	rig.float_node.position = cast_to
	for f in fishes:
		var d := Vector2(f.position.x - cast_to.x, f.position.z - cast_to.z).length()
		if d < 0.7:
			f.set_state(FishScript.S.FLEE)   # landed on its head
	ui.set_hint("Wait for a fish to take the float")

func _float_bob(dt: float) -> void:
	rig.bob = move_toward(rig.bob, 0.0, dt * (0.6 if state == G.BITE else 2.2))
	var p: Vector3 = rig.float_node.position
	var t := Time.get_ticks_msec() / 1000.0
	p.y = sin(t * 2.3) * 0.008 - rig.bob * 0.09
	if state == G.BITE:
		p.y = -0.12 + sin(t * 18.0) * 0.02
	# slow drift with the current
	p.z += dt * 0.05
	rig.float_node.position = p

func _waiting(dt: float) -> void:
	wait_t += dt
	if engaged == null and wait_t > 0.8:
		var best = null
		var bestd := 4.5
		for f in fishes:
			if f.state in [FishScript.S.WANDER, FishScript.S.HOLD]:
				var d := Vector2(f.position.x - rig.float_node.position.x, f.position.z - rig.float_node.position.z).length()
				if d < bestd:
					bestd = d
					best = f
		if best and rng.randf() < dt * (1.4 - float(best.sp.wariness)):
			engaged = best
			best.set_state(FishScript.S.NOTICE)
	if engaged and engaged.state == FishScript.S.FLEE:
		engaged = null
	if wait_t > 14.0 and engaged == null:
		ui.set_hint("Nothing's interested - tap to reel in and cast nearer a fish")

func _fight(dt: float) -> void:
	var f = hooked
	fight.time -= dt
	fight.run_cd -= dt
	if fight.run_cd <= 0.0 and fight.run <= 0.0:
		fight.run = rng.randf_range(0.6, 1.4) * (0.6 + fight.strength * 0.6)
		fight.run_cd = rng.randf_range(1.0, 2.6)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		fight.dart = Vector3(side * rng.randf_range(0.6, 1.6), 0, -rng.randf_range(0.2, 1.2))
	var pull := 0.25
	if fight.run > 0.0:
		fight.run -= dt
		pull = 1.0
	var s: float = fight.strength
	tick_t -= dt
	if holding and tick_t <= 0.0:
		tick_t = 0.09
		sfx("tick", -10.0)
	if holding:
		fight.progress += dt * (0.16 - 0.1 * pull * s)
		fight.tension += dt * (0.25 + 0.95 * pull * s)
	else:
		fight.progress -= dt * 0.05 * pull * s
		fight.tension -= dt * 0.7
	fight.progress = clamp(fight.progress, 0.0, 1.0)
	fight.tension = clamp(fight.tension, 0.0, 1.2)
	var land_pt := cam.global_transform * Vector3(0.3, -2.2, -2.2)
	land_pt.y = 0.0
	var base: Vector3 = fight.start.lerp(land_pt, fight.progress)
	var dart: Vector3 = fight.dart * (1.0 if fight.run > 0.0 else 0.3)
	var goal := base + dart
	goal.y = max(-0.35, f.swim_y(goal.x, goal.z) * 0.5)
	var prev: Vector3 = f.position
	f.position = f.position.lerp(goal, dt * 1.8)
	var mv: Vector3 = f.position - prev
	if mv.length() > 0.0005:
		f.heading = lerp_angle(f.heading, atan2(-mv.x, -mv.z) + PI * 0.9, dt * 4.0)
	f.rotation.y = f.heading + sin(Time.get_ticks_msec() * 0.02) * 0.25
	f.mat.set_shader_parameter("thrash", 1.0 if fight.run > 0.0 else 0.4)
	rig.float_node.position = f.position + Vector3(0, 0.05, 0)
	if rng.randf() < dt * 3.0 and fight.run > 0.0:
		add_ripple(Vector3(f.position.x, 0, f.position.z), 0.6)
	rig.bend = lerp(rig.bend, clamp(fight.tension, 0.2, 1.0), dt * 6.0)
	rig.step(dt, f.position, true)
	ui.update_fight(fight)
	if fight.tension >= 1.0:
		sfx("snap")
		_lose("糸切れ", "The line snapped")
	elif fight.time <= 0.0:
		_lose("バラし", "It threw the hook")
	elif fight.progress >= 1.0:
		_start_landing()

func _lose(jp: String, en: String) -> void:
	ui.hide_fight()
	ui.flash_message(jp, en)
	hooked.mat.set_shader_parameter("thrash", 0.0)
	hooked.set_state(FishScript.S.FLEE)
	hooked = null
	reel_in()

func _start_landing() -> void:
	state = G.LANDING
	land_t = 0.0
	ui.hide_fight()
	add_ripple(Vector3(hooked.position.x, 0, hooked.position.z), 1.2)
	hooked.set_state(FishScript.S.LANDED)
	sfx("splash", 0.0)
	hooked.mat.set_shader_parameter("out_of_water", 1.0)

func _landing(dt: float) -> void:
	land_t += dt
	var f = hooked
	var hang := cam.global_transform * Vector3(-0.1, -0.02 + sin(land_t * 3.0) * 0.02, -1.25)
	var k: float = clamp(land_t / 0.9, 0.0, 1.0)
	f.position = f.position.lerp(hang, clamp(dt * 7.0 + k * 0.15, 0.0, 1.0))
	# hang head-up, facing the camera side-on
	var basis := Basis(Vector3.UP, cam.rotation.y + PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	f.basis = f.basis.orthonormalized().slerp(basis.orthonormalized(), clamp(dt * 5.0, 0.0, 1.0))
	f.mat.set_shader_parameter("thrash", 0.7 * (1.0 - k * 0.6))
	rig.bend = lerp(rig.bend, 0.55, dt * 3.0)
	rig.step(dt, f.position + f.basis * Vector3(0, 0, -0.5 * f.length_cm / 100.0 * f.VIS_SCALE), true)
	if land_t > 2.2:
		_record_catch()

func _record_catch() -> void:
	var f = hooked
	var id: String = f.sp_id
	var prev_best := float(journal.best.get(id, 0.0))
	var is_record: bool = f.length_cm > prev_best
	var first: bool = not journal.count.has(id)
	if is_record:
		journal.best[id] = f.length_cm
	journal.count[id] = int(journal.count.get(id, 0)) + 1
	var pid: String = pools[pool_idx].id
	journal.pool[pid] = int(journal.pool.get(pid, 0)) + 1
	journal.total = int(journal.total) + 1
	var unlocked_now := false
	if _pool_count(pid) >= int(pools[pool_idx].goal) and int(journal.unlocked) < pool_idx + 2 and pool_idx + 1 < pools.size():
		journal.unlocked = pool_idx + 2
		unlocked_now = true
	_save_journal()
	last_catch = {"id": id, "sp": f.sp, "cm": f.length_cm, "record": is_record and not first, "first": first,
		"prev": prev_best, "pool": pools[pool_idx], "unlocked": unlocked_now}
	state = G.CARD
	ui.show_card(last_catch)
	ui.on_pool(pools[pool_idx], _pool_count(pid), false)

func release_and_continue() -> void:
	if hooked:
		fishes.erase(hooked)
		var f = hooked
		hooked = null
		f.queue_free()
		# a new fish drifts into the pool
		var p: Dictionary = pools[pool_idx]
		var id := _weighted(p.species)
		var nf = FishScript.new()
		world.add_child(nf)
		nf.setup(id, species[id], _roll_size(species[id]), world, rng.randi())
		nf.position = Vector3(world.channel_center(-14.0), -0.6, -14.0)
		nf.float_ref = rig.float_node
		nf.nibble.connect(_on_nibble)
		nf.bite.connect(_on_bite)
		nf.gave_up.connect(_on_gave_up)
		fishes.append(nf)
	reel_in()

func travel(i: int) -> void:
	if i >= int(journal.unlocked) or i >= pools.size():
		return
	state = G.TRAVEL
	await ui.fade(true)
	start_pool(i)
	await ui.fade(false)

func start_audio() -> void:
	if not amb.playing:
		amb.play()

func sfx(n: String, db := 0.0) -> void:
	var ap: AudioStreamPlayer = sfx_players[sfx_i]
	sfx_i = (sfx_i + 1) % sfx_players.size()
	ap.stream = sounds[n]
	ap.volume_db = db
	ap.pitch_scale = randf_range(0.92, 1.08)
	ap.play()

# ---------------------------------------------------------------- ripples
func add_ripple(p: Vector3, strength: float) -> void:
	ripple_slots[ripple_i] = Vector4(p.x, p.z, _shader_time(), strength)
	ripple_i = (ripple_i + 1) % 8
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4) * (0.6 + strength * 0.6)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = RIPPLE_SHADER
	mi.material_override = m
	mi.position = Vector3(p.x, 0.01, p.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var tw := create_tween()
	tw.tween_method(func(a): m.set_shader_parameter("age", a), 0.0, 1.6, 1.6)
	tw.tween_callback(mi.queue_free)

func _shader_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _update_ripples() -> void:
	if world and world.water_mat:
		world.water_mat.set_shader_parameter("ripples", ripple_slots)

# ---------------------------------------------------------------- journal
func _load_journal() -> void:
	if FileAccess.file_exists("user://journal.json"):
		var j = JSON.parse_string(FileAccess.get_file_as_string("user://journal.json"))
		if j is Dictionary:
			for k in j:
				journal[k] = j[k]

func _save_journal() -> void:
	var f := FileAccess.open("user://journal.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(journal))
