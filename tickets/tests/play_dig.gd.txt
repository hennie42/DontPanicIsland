extends ProbeBase
## Acceptance probe for T17 (dig effects). Run: tools/probe.sh tests/play_dig.tscn 90 "DIG OK" --skip-intro


func run() -> void:
	var b = main.board
	var view = main.view
	var keys: Array = b.land.keys()
	var origin: Vector2i = keys[keys.size() / 2]
	await click(screen_of(origin))          # the landing click opens a flood fill around origin
	await wait(0.06)
	var opened: Array = b.revealed.keys()
	check(opened.size() >= 8, "the landing click opened tiles (%d)" % opened.size())

	# the final state (visibility) is there at once; only the motion is animated
	var dug_ok := opened.all(func(c): return view.cells[c].get_node("Dug").visible and not view.cells[c].get_node("Tile").visible)
	check(dug_ok, "opened tiles show the dug tile at once")

	# a ripple: shortly after the click, near tiles are further down than far ones
	var near: Array = opened.filter(func(c): return Hex.distance(c, origin) <= 1)
	var far: Array = opened.filter(func(c): return Hex.distance(c, origin) >= 3)
	check(near.size() > 0 and far.size() > 0, "opened tiles near (%d) and far (%d) from the click" % [near.size(), far.size()])
	var avg_y := func(cells: Array) -> float:
		var s := 0.0
		for c in cells:
			s += (view.cells[c] as Node3D).position.y
		return s / maxf(cells.size(), 1)
	var y_near: float = avg_y.call(near)
	var y_far: float = avg_y.call(far)
	check(y_far > y_near + 0.02, "ripple: far tiles still up (%.3f) while near ones settle (%.3f)" % [y_far, y_near])
	var squashed := opened.any(func(c): return not (view.cells[c] as Node3D).scale.is_equal_approx(Vector3.ONE))
	check(squashed, "tiles squash and pop while they settle")
	var bursts := 0
	for c in opened:
		if (view.cells[c] as Node).find_child("Burst", true, false) is CPUParticles3D:
			bursts += 1
	check(bursts >= 3 and bursts <= 14, "sand bursts on the opened tiles (%d, at most 14)" % bursts)

	# everything settles, numbers popped in
	await wait(2.5)
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
