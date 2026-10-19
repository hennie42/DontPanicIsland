extends ProbeBase
## F43 performance probe (director): the first-dig stall and the frame time per render feature, in the window size
## the user plays in. Run: tools/probe.sh tests/perf.tscn 120 "PERF DONE" --skip-intro [--island=0]
## Prints PERF lines: the worst frames after the landing click and after a second dig, then the mean / 95th
## percentile frame time with effects switched off cumulatively (vsync off, so the numbers are the real cost).

const WINDOW := Vector2i(1920, 2100)


func measure(n: int) -> Array:
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var mean := 0.0
	for t in times:
		mean += t
	return [mean / n, times[int(n * 0.95)], times[-1]]


## Where a frame goes: game scripts (process), the render thread's CPU and the GPU, draw calls and objects.
func breakdown() -> String:
	var rid := get_viewport().get_viewport_rid()
	return "process=%.1fms physics=%.1fms render_cpu=%.1fms gpu=%.1fms draws=%d objects=%d prims=%dk" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(rid),
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]


func dig_stall(label: String, pos: Vector2) -> void:
	var t0 := Time.get_ticks_usec()
	await click(pos)
	var worst := 0.0
	var slow := 0
	var last := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 1500000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		worst = maxf(worst, dt)
		if dt > 50.0:
			slow += 1
		last = now
	print("PERF %s worst_frame=%.0fms frames_over_50ms=%d" % [label, worst, slow])


func run() -> void:
	var size := WINDOW
	for a in OS.get_cmdline_user_args():          # --perf-window=1280x720
		if a.begins_with("--perf-window="):
			var wh := a.substr(14).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	get_window().size = size
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await wait(1.5)
	print("PERF window=%s viewport=%s renderer=%s gpu=%s" % [get_window().size, get_viewport().get_visible_rect().size,
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	var keys: Array = main.board.land.keys()
	await dig_stall("first_dig", screen_of(keys[keys.size() / 2]))
	await wait(1.0)
	var k := reachable(false)
	if k != Vector2i(9999, 9999):
		await dig_stall("second_dig", screen_of(k))
	await wait(1.5)
	var wenv := main.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment
	var env := wenv.environment
	var vp := get_viewport()
	var steps := [
		["all_on", func(): pass],
		["no_ssil", func(): env.ssil_enabled = false],
		["no_ssao", func(): env.ssao_enabled = false],
		["msaa_2x", func(): vp.msaa_3d = Viewport.MSAA_2X],
		["no_msaa", func(): vp.msaa_3d = Viewport.MSAA_DISABLED],
		["no_dof", func(): wenv.camera_attributes = null],
		["no_glow", func(): env.glow_enabled = false],
		["scale_0.75", func(): vp.scaling_3d_scale = 0.75],
	]
	for st in steps:
		(st[1] as Callable).call()
		await frames(30)
		var r: Array = await measure(180)
		print("PERF %-10s mean=%.1fms p95=%.1fms max=%.1fms (%.0f fps) %s" % [st[0], r[0], r[1], r[2], 1000.0 / r[0], breakdown()])
	# where the script time goes: switch the game's subsystems off one at a time (cumulative)
	var count := func(cls: String) -> int: return main.find_children("*", cls, true, false).size()
	print("PERF nodes=%d cpu_particles=%d gpu_particles=%d anim_players=%d label3d=%d" % [
		main.find_children("*", "", true, false).size(), count.call("CPUParticles3D"), count.call("GPUParticles3D"),
		count.call("AnimationPlayer"), count.call("Label3D")])
	var subs := [
		["base", func(): pass],
		["no_ambience", func(): main.ambience.process_mode = Node.PROCESS_MODE_DISABLED],
		["no_decor", func(): main.decor.process_mode = Node.PROCESS_MODE_DISABLED],
		["no_ocean", func():
			for o in main.get_children():
				if o is Ocean:
					o.process_mode = Node.PROCESS_MODE_DISABLED],
		["no_view", func(): main.view.process_mode = Node.PROCESS_MODE_DISABLED],
		["no_particles", func():
			for p in main.find_children("*", "CPUParticles3D", true, false):
				(p as CPUParticles3D).emitting = false
				p.process_mode = Node.PROCESS_MODE_DISABLED],
		["no_anims", func():
			for a in main.find_children("*", "AnimationPlayer", true, false):
				a.process_mode = Node.PROCESS_MODE_DISABLED],
		["no_main", func(): main.set_process(false)],
	]
	for st in subs:
		(st[1] as Callable).call()
		await frames(30)
		var r: Array = await measure(120)
		print("PERF %-12s mean=%.1fms (%.0f fps) %s" % [st[0], r[0], 1000.0 / r[0], breakdown()])
	print("PERF DONE")
