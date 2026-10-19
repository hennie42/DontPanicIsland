extends ProbeBase
## F43 follow-up (director): the number labels still face the camera after the per-frame work was cached (they now
## turn only when the camera turns). Saves two screenshots: after landing, and after the camera has turned 70 deg.
## Run: tools/probe.sh tests/shot_numbers.tscn 60 "NUMBERS OK" --skip-intro --island=0


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func run() -> void:
	await land()
	await wait(2.0)
	await snap("numbers_a")
	main.rig.yaw += 70.0
	await wait(1.5)
	await snap("numbers_b")
	var lbl: Label3D = null
	for c in main.board.revealed:
		var l := main.view.cells[c].get_node("Number") as Label3D
		if l.visible and l.text != "":
			lbl = l
			break
	var cam: Camera3D = main.rig.camera
	check(lbl != null and absf(wrapf(lbl.global_rotation_degrees.y - cam.global_rotation_degrees.y, -180, 180)) < 2.0,
		"a revealed number faces the camera's yaw after the camera turned")
	if fails == 0:
		print("NUMBERS OK")
