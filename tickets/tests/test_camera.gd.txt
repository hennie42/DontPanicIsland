extends SceneTree
## Acceptance test for T07 (scripts/camera_rig.gd). Run: tools/test.sh tests/test_camera.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func looks_at(cam: Camera3D, p: Vector3) -> bool:
	var fwd := -cam.global_transform.basis.z
	return fwd.normalized().dot((p - cam.global_position).normalized()) > 0.999


func _init() -> void:
	var rig := CameraRig.new()
	root.add_child(rig)
	await process_frame
	check(rig.camera != null and rig.camera.get_parent() == rig, "camera child created")
	rig.apply()
	var cam := rig.camera
	check(looks_at(cam, rig.target), "looks at the target")
	var h := cam.global_position.y - rig.target.y
	check(absf(h - rig.distance * sin(deg_to_rad(CameraRig.TILT))) < 0.01, "tilt fixed at 50 degrees (height %.2f)" % h)
	# zoom clamps
	for i in 40:
		rig.zoom_by(0.8)
	check(absf(rig.distance - CameraRig.MIN_DIST) < 0.001, "zoom in clamps at MIN_DIST")
	for i in 40:
		rig.zoom_by(1.25)
	check(absf(rig.distance - CameraRig.MAX_DIST) < 0.001, "zoom out clamps at MAX_DIST")
	# rotation keeps distance and the look-at
	var d0 := cam.global_position.distance_to(rig.target)
	rig.rotate_by(90.0)
	check(absf(cam.global_position.distance_to(rig.target) - d0) < 0.01, "rotation keeps the distance")
	check(looks_at(cam, rig.target), "still looks at the target after rotating")
	check(absf(fmod(rig.yaw - 90.0, 360.0)) < 0.001, "yaw updated")
	# pan moves the target on the ground and clamps
	rig.pan_by(Vector2(1.0, 0.0))
	check(absf(rig.target.y) < 0.0001 and rig.target.length() > 0.5, "pan moves the target on the ground")
	for i in 100:
		rig.pan_by(Vector2(3.0, 2.0))
	check(rig.target.length() <= CameraRig.PAN_LIMIT + 0.001, "pan clamped to PAN_LIMIT (%.2f)" % rig.target.length())
	check(looks_at(cam, rig.target), "looks at the panned target")
	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
