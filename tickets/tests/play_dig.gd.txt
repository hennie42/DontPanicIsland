extends ProbeBase
## Acceptance probe for T17 (dig effects). Run: tools/probe.sh tests/play_dig.tscn 90 "DIG OK" --skip-intro


func run() -> void:
	var b = main.board
	var view = main.view
	var keys: Array = b.land.keys()
	var origin: Vector2i = keys[keys.size() / 2]
	# the landing click, then watch every frame from the dig on: when each opened tile settles, the squash, the
	# bursts. (A snapshot at a fixed time missed short ripples at 25 fps: ring steps are only 0.045 s.)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = win(screen_of(origin))
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await frames(1)
	var t0 := Time.get_ticks_msec()
	var settled_at := {}
	var squashed := false
	var burst_cells := {}
	var max_bursts := 0
	var worst_frame := 0
	var last := t0
	while Time.get_ticks_msec() - t0 < 1500:
		await frames(1)
		var now := Time.get_ticks_msec()
		worst_frame = maxi(worst_frame, now - last)
		last = now
		var live := 0
		for c in b.revealed:
			var node := view.cells[c] as Node3D
			if not node.scale.is_equal_approx(Vector3.ONE):
				squashed = true
			if node.find_child("Burst", true, false) is CPUParticles3D:
				burst_cells[c] = true
				live += 1
			if not settled_at.has(c) and absf(node.position.y) < 0.004 and node.scale.is_equal_approx(Vector3.ONE):
				settled_at[c] = now - t0
		max_bursts = maxi(max_bursts, live)
	var opened: Array = b.revealed.keys()
	check(opened.size() >= 8, "the landing click opened tiles (%d)" % opened.size())

	# the final state (visibility) is there at once; only the motion is animated
	var dug_ok := opened.all(func(c): return view.cells[c].get_node("Dug").visible and not view.cells[c].get_node("Tile").visible)
	check(dug_ok, "opened tiles show the dug tile")

	# a ripple: the farthest ring settles later than the ring around the click
	var max_d := 0
	for c in opened:
		max_d = maxi(max_d, Hex.distance(c, origin))
	var near: Array = opened.filter(func(c): return Hex.distance(c, origin) <= 1)
	var far: Array = opened.filter(func(c): return Hex.distance(c, origin) == max_d)
	var mean_t := func(cells: Array) -> float:
		var s := 0.0
		for c in cells:
			s += float(settled_at.get(c, 1500))
		return s / maxf(cells.size(), 1)
	if max_d < 2 or worst_frame > 400:
		print("note ripple not measurable: %d rings, worst frame %d ms" % [max_d, worst_frame])
	else:
		var tn: float = mean_t.call(near)
		var tf: float = mean_t.call(far)
		check(tf > tn + 30.0, "ripple: ring %d settles later (%.0f ms) than the ring at the click (%.0f ms)" % [max_d, tf, tn])
	check(squashed, "tiles squash and pop while they settle")
	check(burst_cells.size() >= 3 and max_bursts <= 14, "sand bursts on the opened tiles (%d cells, at most %d at once)" % [burst_cells.size(), max_bursts])

	# everything settles, numbers popped in
	await wait(1.0)
	var settled := opened.all(func(c): return absf((view.cells[c] as Node3D).position.y) < 0.001 \
		and (view.cells[c] as Node3D).scale.is_equal_approx(Vector3.ONE))
	check(settled, "all opened tiles settle at height 0, scale 1")
	var nums_ok := true
	var shown := 0
	for c in opened:
		var num := view.cells[c].get_node("Number") as Label3D
		if num.visible:
			shown += 1
			nums_ok = nums_ok and num.scale.is_equal_approx(Vector3.ONE)
	check(shown > 0 and nums_ok, "numbers shown (%d) at full size" % shown)
	var leftover := 0
	for c in opened:
		if (view.cells[c] as Node).find_child("Burst", true, false) != null:
			leftover += 1
	check(leftover == 0, "bursts are freed afterwards (%d left)" % leftover)

	# a refresh without an origin (the autopilot, the tests) does not animate
	var safe := reachable(false)
	check(safe != Vector2i(9999, 9999), "a safe tile to dig")
	b.reveal(safe)
	view.refresh(b)
	await frames(1)
	check(absf((view.cells[safe] as Node3D).position.y) < 0.001, "refresh(b) without an origin is instant")
	print("DIG OK" if fails == 0 else "DIG FAILED: %d" % fails)
