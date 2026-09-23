extends Node
## Scripted QA run: `godot -- qa` plays the loop and saves frames to /tmp/qa.
var g

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if OS.has_feature("web"):
		print("QA web step ", name)
		if ("stop=" + name) in OS.get_cmdline_user_args():
			await get_tree().create_timer(9999.0).timeout
		return
	get_viewport().get_texture().get_image().save_png("/tmp/qa/%s.png" % name)
	print("QA shot ", name, " state=", g.state)

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func run(game) -> void:
	g = game
	g.journal = {"best": {}, "count": {}, "pool": {}, "unlocked": 1, "total": 0}
	g.ui.on_pool(g.pools[0], 0, false)
	await wait(1.0)
	await shot("00_title")
	g.ui.title_panel.queue_free()
	g.state = g.G.IDLE
	await wait(1.5)
	await shot("01_pool1_idle")
	for ff in g.fishes: print("fish ", ff.sp_id, " ", ff.position, " vis=", ff.is_visible_in_tree(), " st=", ff.state)
	print("cam ", g.cam.global_position)
	# cast next to the nearest fish
	var f = g.fishes[0]
	for ff in g.fishes:
		if ff.position.z > f.position.z:
			f = ff
	var tgt: Vector3 = f.position + Vector3(0.4, 0, -0.5)
	g.try_cast(Vector3(tgt.x, 0, tgt.z))
	await wait(0.4)
	await shot("02_casting")
	await wait(0.6)
	await shot("03_float_landed")
	g.journal.pool[g.pools[0].id] = 2
	g.engaged = f
	f.set_state(f.S.NOTICE)
	var t := 0.0
	while g.state != g.G.BITE and t < 12.0:
		await wait(0.1)
		t += 0.1
	await shot("04_bite")
	g.press_at(Vector2(640, 360))
	await wait(0.2)
	# fight: pulse the reel
	for i in 30:
		g.holding = g.fight.tension < 0.6
		await wait(0.1)
	await shot("05_fight")
	var guard := 0
	while g.state == g.G.FIGHT and guard < 200:
		g.holding = g.fight.tension < 0.6
		await wait(0.1)
		guard += 1
	g.holding = false
	if g.state == g.G.IDLE:
		print("QA: fish lost in fight, forcing a landing for frames")
	await wait(1.4)
	await shot("06_landing")
	t = 0.0
	while g.state != g.G.CARD and t < 4.0:
		await wait(0.1)
		t += 0.1
	await wait(0.5)
	await shot("07_card")
	for b in g.ui.card.find_children("*", "Button", true, false):
		print("card button: ", b.text)
	g.ui.show_journal()
	await wait(0.3)
	await shot("08_journal")
	g.ui.journal_panel.queue_free()
	var nb = null
	for b in g.ui.card.find_children("*", "Button", true, false):
		if b.text.begins_with("次の淵へ"):
			nb = b
	if nb:
		nb.pressed.emit()
		await wait(2.5)
		await shot("09_next_pool_via_card")
	else:
		print("QA FAIL: no next-pool button on card")
		g.ui.card.queue_free()
		g.release_and_continue()
	g.journal.unlocked = 4
	for i in [1, 2, 3]:
		g.start_pool(i)
		await wait(2.0)
		await shot("1%d_pool%d" % [i, i + 1])
	g.ui.show_map()
	await wait(0.3)
	await shot("20_map")
	get_tree().quit()
