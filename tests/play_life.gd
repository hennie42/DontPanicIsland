extends ProbeBase
## Acceptance probe for T16 (ambient life). Run: tools/probe.sh tests/play_life.tscn 90 "LIFE OK" --skip-intro


func run() -> void:
	var amb = main.get("ambience")
	check(amb != null and amb.get_script() != null and amb.get_script().get_global_name() == "Ambience",
		"main.ambience is an Ambience")
	if amb == null:
		print("LIFE FAILED")
		return
	var view = main.view

	# three gulls, moving
	var gulls: Array = []
	for i in 3:
		gulls.append(amb.find_child("Gull_%d" % i, true, false))
	check(gulls.all(func(g): return g is Node3D), "Gull_0, Gull_1, Gull_2 exist")
	# palms: global transforms of their meshes, now and in 0.6 s (the fog is checked after landing: before the first
	# click the whole island is clear of fog by design)
	var palms: Array = []
	for c in main.board.land:
		var cell: Node3D = view.cells[c]
		var tp: Node = cell.get_node_or_null("Props/TerrainProp")
		if main.board.land[c] == "palm" and tp != null and tp.get_child_count() > 0 and palms.size() < 6:
			palms.append(tp.get_child(0))
	check(palms.size() >= 3, "found palms (%d)" % palms.size())
	var g0: Array = gulls.map(func(g): return g.global_position if g is Node3D else Vector3.ZERO)
	var p0: Array = palms.map(func(p): return (p as Node3D).global_transform.basis)
	await wait(0.6)
	var moved := 0
	for i in 3:
		if gulls[i] is Node3D and (gulls[i] as Node3D).global_position.distance_to(g0[i]) > 0.05:
			moved += 1
	check(moved == 3, "all gulls move (%d of 3)" % moved)
	var heights_ok := gulls.all(func(g): return g is Node3D and g.global_position.y > 2.0 and g.global_position.y < 5.0)
	check(heights_ok, "gulls fly 2-5 units up")
	var swayed := 0
	for i in palms.size():
		var b1: Basis = (palms[i] as Node3D).global_transform.basis
		if not b1.is_equal_approx(p0[i]):
			swayed += 1
	check(swayed == palms.size(), "palms sway (%d of %d)" % [swayed, palms.size()])

	# smoke from the camp fire once the camp is there
	check(amb.find_child("Smoke", true, false) == null, "no smoke before the camp")
	await land()
	await wait(0.5)
	var smoke := amb.find_child("Smoke", true, false) as CPUParticles3D
	check(smoke != null and smoke.emitting, "smoke rises after landing")
	# the fog covers the island now: its clouds drift
	var fogs: Array = []
	for c in main.board.land:
		var fog: Node = (view.cells[c] as Node3D).get_node_or_null("Fog")
		if fog != null and fog.visible and fog.get_child_count() > 0 and fogs.size() < 6:
			fogs.append(fog.get_child(0))
	check(fogs.size() >= 3, "found fog clouds after landing (%d)" % fogs.size())
	var f0: Array = fogs.map(func(f): return (f as Node3D).global_position)
	await wait(0.6)
	var bobbed := 0
	for i in fogs.size():
		if (fogs[i] as Node3D).global_position.distance_to(f0[i]) > 0.002:
			bobbed += 1
	check(fogs.size() > 0 and bobbed == fogs.size(), "fog clouds drift (%d of %d)" % [bobbed, fogs.size()])
	var fire: Vector3 = main.decor.fire_position()
	check(smoke != null and fire != Vector3.INF and smoke.global_position.distance_to(fire) < 0.5,
		"smoke is at the camp fire")
	print("LIFE OK" if fails == 0 else "LIFE FAILED: %d" % fails)
