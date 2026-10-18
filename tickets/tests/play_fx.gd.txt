extends ProbeBase
## Acceptance probe for T18 (mine and towel effects). Run: tools/probe.sh tests/play_fx.tscn 90 "FX OK" --skip-intro


func run() -> void:
	var fx = main.get("fx")
	check(fx != null and fx.get_script() != null and fx.get_script().get_global_name() == "Fx", "main.fx is an Fx")
	var rig = main.rig
	check("shake_offset" in rig, "the camera rig has shake_offset")
	if fx == null or not ("shake_offset" in rig):
		print("FX FAILED")
		return
	var b = main.board
	await land()
	await wait(1.0)

	# a towel bounces in
	var t := reachable(true)
	if t == Vector2i(9999, 9999):
		t = reachable(false)
	await click(screen_of(t), MOUSE_BUTTON_RIGHT)
	var flag := main.view.cells[t].get_node("Flag") as Node3D
	check(b.flagged.has(t), "right click placed a towel")
	check(not flag.scale.is_equal_approx(Vector3.ONE) or absf(flag.position.y) > 0.01, "the towel is bouncing in")
	await wait(0.8)
	check(flag.scale.is_equal_approx(Vector3.ONE) and absf(flag.position.y) < 0.001, "the towel settles")
	await click(screen_of(t), MOUSE_BUTTON_RIGHT)   # take it off again

	# a mine: flash, smoke, sparks, camera shake
	var m := reachable(true, [t])
	check(m != Vector2i(9999, 9999), "a mine next to the land")
	if m == Vector2i(9999, 9999):
		print("FX FAILED: %d" % fails)
		return
	var crew: int = b.crew
	await click(screen_of(m))
	check(b.exploded.has(m) and b.crew == crew - 1, "the click set off the mine")
	var flashes: Array = fx.find_children("Flash*", "OmniLight3D", true, false)
	var flash: OmniLight3D = flashes[0] if flashes.size() > 0 else null
	check(flash != null and flash.light_energy > 0.5, "a flash of light")
	check(fx.find_children("Smoke*", "CPUParticles3D", true, false).size() > 0, "smoke")
	check(fx.find_children("Sparks*", "CPUParticles3D", true, false).size() > 0, "sparks")
	var shook := false
	for i in 8:
		if (rig.shake_offset as Vector3).length() > 0.01:
			shook = true
		await frames(1)
	check(shook, "the camera shakes")
	await wait(1.5)
	check((rig.shake_offset as Vector3).length() < 0.0001, "the shake ends")
	check(fx.find_children("Flash*", "OmniLight3D", true, false).is_empty(), "the flash is gone")
	var expected: Vector3 = rig.target + Vector3(sin(deg_to_rad(rig.yaw)), 0, cos(deg_to_rad(rig.yaw))) \
		* rig.distance * cos(deg_to_rad(rig.TILT)) + Vector3.UP * rig.distance * sin(deg_to_rad(rig.TILT))
	check(rig.camera.global_position.distance_to(expected) < 0.01, "the camera is back where the rig puts it")
	print("FX OK" if fails == 0 else "FX FAILED: %d" % fails)
