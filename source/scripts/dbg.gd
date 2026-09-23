extends Node
func run(g) -> void:
	g.ui.title_panel.queue_free()
	g.state = g.G.IDLE
	await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.5).timeout
	var fw: Vector3 = -g.cam.global_transform.basis.z
	fw.y = 0
	fw = fw.normalized()
	var base: Vector3 = g.cam.global_position + fw * 5.0
	for i in 0:
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
	get_viewport().get_texture().get_image().save_png("/tmp/qa/dbg.png")
	get_tree().quit()
