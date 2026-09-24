extends Node
func run(g) -> void:
	g.ui.title_panel.queue_free()
	g.state = g.G.IDLE
	var pi := 0
	var nf := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pool="):
			pi = int(a.substr(5))
		if a.begins_with("fish="):
			nf = int(a.substr(5))
	if pi > 0:
		g.start_pool(pi)
	await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.5).timeout
	var fw: Vector3 = -g.cam.global_transform.basis.z
	fw.y = 0
	fw = fw.normalized()
	var base: Vector3 = g.cam.global_position + fw * 3.2
	for i in mini(nf, g.fishes.size()):
		var f = g.fishes[i]
		f.set_process(false)
		f.position = base + fw.cross(Vector3.UP) * (i - 1) * 1.0
		f.position.y = [-0.3, -0.6, 0.15][i]
		f.rotation.y = atan2(-fw.x, -fw.z) + PI * 0.5
		f.heading = f.rotation.y
		f._update_shadow()
		print("fish ", i, " ", f.position, " shadow ", f.shadow.global_position, " screen ", g.cam.unproject_position(f.position))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/qa/dbg_p%d_f%d.png" % [pi, nf])
	get_tree().quit()
