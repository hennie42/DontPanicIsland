extends SceneTree
## Acceptance test for scripts/hex.gd. Run: studio godot-script tests/test_hex.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	# neighbours are distance 1 and their centres are exactly one tile width apart
	var c := Vector2i(2, -3)
	for n in Hex.neighbors(c):
		check(Hex.distance(c, n) == 1, "neighbour distance %s" % n)
		check(absf(Hex.to_world(c).distance_to(Hex.to_world(n)) - Hex.WIDTH) < 1e-4, "neighbour spacing %s" % n)
	# round trip world <-> axial, also for points off-centre inside the hex
	for q in range(-6, 7):
		for r in range(-6, 7):
			var a := Vector2i(q, r)
			var w := Hex.to_world(a)
			check(Hex.from_world(w) == a, "round trip %s" % a)
			check(Hex.from_world(w + Vector3(0.3, 0, 0.2)) == a, "inside point %s" % a)
	# spiral sizes: 1, 7, 19, 37 ... = 3k(k+1)+1, all unique
	for k in 5:
		var s := Hex.spiral(Vector2i.ZERO, k)
		check(s.size() == 3 * k * (k + 1) + 1, "spiral size k=%d got %d" % [k, s.size()])
		var u := {}
		for h in s:
			u[h] = true
		check(u.size() == s.size(), "spiral unique k=%d" % k)
	# ray picking from above lands on the right tile
	var hit = Hex.ray_to_ground(Vector3(3.0, 10.0, 2.0), Vector3(0, -1, 0))
	check(hit != null and Hex.from_world(hit) == Hex.from_world(Vector3(3.0, 0, 2.0)), "ray_to_ground")
	check(Hex.ray_to_ground(Vector3(0, 10, 0), Vector3(0, 1, 0)) == null, "ray pointing up")
	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
