extends ProbeBase
## Look probe (director, F40): the same view with the polish switched per variant, saved as PNGs for studio-shotdiff.
## One run, so every variant shows the same scene (the autopilot's frames differ between runs).
## Run: tools/probe.sh tests/look.tscn 120 "LOOK DONE" --skip-intro --look-dir=/abs/dir [--look-near=0.3,0.15]
## Writes <zoom>_<variant>.png for the zooms home, close (0.6x) and far (the zoom-out limit).

const WINDOW := Vector2i(1920, 1080)


func run() -> void:
	var dir := ""
	var near_try: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look-dir="):
			dir = a.substr(11)
		elif a.begins_with("--look-near="):   # extra near blur candidates: d,t:d,t
			for pair in a.substr(12).split(":"):
				var dt := pair.split(",")
				near_try.append(Vector2(float(dt[0]), float(dt[1])))
	if dir == "":
		print("LOOK needs --look-dir=")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = WINDOW
	await land()
	await wait(2.0)
	var wenv := main.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment
	var env := wenv.environment
	var attr := wenv.camera_attributes as CameraAttributesPractical
	var near0: Vector2 = main.dof_near
	var reset := func():
		env.ssao_enabled = true
		env.ssil_enabled = true
		env.glow_enabled = true
		attr.dof_blur_near_enabled = true
		attr.dof_blur_far_enabled = true
		main.dof_near = near0
	var variants := [
		["cur", func(): pass],
		["off", func():
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.glow_enabled = false
			attr.dof_blur_near_enabled = false
			attr.dof_blur_far_enabled = false],
		["nonear", func(): attr.dof_blur_near_enabled = false],
		["nofar", func(): attr.dof_blur_far_enabled = false],
		["noao", func(): env.ssao_enabled = false],
	]
	for v in near_try:
		variants.append(["near%.2f-%.2f" % [v.x, v.y], func(): main.dof_near = v])
	var rig: CameraRig = main.rig
	var home: float = rig.distance
	for z in [["home", home], ["close", home * 0.6], ["far", rig.max_dist]]:
		rig.distance = clampf(z[1], CameraRig.MIN_DIST, rig.max_dist)
		rig.apply()
		for v in variants:
			reset.call()
			(v[1] as Callable).call()
			await frames(20)
			await RenderingServer.frame_post_draw
			var path: String = dir.path_join("%s_%s.png" % [z[0], v[0]])
			get_viewport().get_texture().get_image().save_png(path)
			print("LOOK %s distance=%.1f" % [path, rig.distance])
	reset.call()
	print("LOOK DONE")
