extends Node
## Real-input check for the camera and gestures (director, 2026-10-18): mouse and touch events in window
## coordinates, as a player makes them. Run: studio godot-play tests/play_input.tscn 90  -> "INPUT OK"

var main
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func win(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func mouse_button(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = win(pos)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func mouse_move(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = win(pos)
	ev.global_position = ev.position
	ev.relative = rel
	Input.parse_input_event(ev)


func mouse_drag(from: Vector2, to: Vector2, button: MouseButton) -> void:
	mouse_button(from, button, true)
	await frames(1)
	for i in range(1, 11):
		mouse_move(from.lerp(to, i / 10.0), (to - from) / 10.0)
		await frames(1)
	mouse_button(to, button, false)
	await frames(2)


func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = win(pos)
	Input.parse_input_event(ev)


func touch_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = win(pos)
	ev.relative = rel
	Input.parse_input_event(ev)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen_of(c: Vector2i) -> Vector2:
	return main.rig.camera.unproject_position(Hex.to_world(c) + Vector3(0, 0.3, 0))


## A hidden tile next to the land, on screen and away from the HUD.
func hidden_target(exclude: Array = []) -> Vector2i:
	var size := get_viewport().get_visible_rect().size
	for k in main.board.land:
		if main.board.can_reveal(k) and not main.board.revealed.has(k) and not main.board.flagged.has(k) \
				and not main.board.mines.has(k) and not exclude.has(k):
			var p := screen_of(k)
			if p.x > size.x * 0.15 and p.x < size.x * 0.8 and p.y > size.y * 0.15 and p.y < size.y * 0.8:
				return k
	return Vector2i(9999, 9999)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	# wait until the intro is gone (it takes ~13 s, longer on a busy machine: a fixed wait was flaky)
	var waited := 0.0
	while waited < 60.0 and (main.get_children().any(func(n): return n is Intro) or not main._playing):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(0.5).timeout
	var b = main.board
	var rig = main.rig
	var mid: Vector2 = get_viewport().get_visible_rect().size * 0.5

	# mouse: a drag moves the map and digs nothing
	var t0: Vector3 = rig.target
	await mouse_drag(mid, mid + Vector2(300, 150), MOUSE_BUTTON_LEFT)
	check(rig.target.distance_to(t0) > 0.5 and b.revealed.is_empty(), "left drag pans (%.2f) without digging" % rig.target.distance_to(t0))
	rig.go_home()
	await get_tree().create_timer(0.6).timeout

	# mouse: a click digs (lands the camp)
	var keys: Array = b.land.keys()
	var c: Vector2i = keys[keys.size() / 2]
	mouse_button(screen_of(c), MOUSE_BUTTON_LEFT, true)
	await frames(1)
	mouse_button(screen_of(c), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(b.revealed.size() > 0, "click digs (%d opened)" % b.revealed.size())

	# mouse: right drag turns, places no towel; right click places one
	var yaw0: float = rig.yaw
	await mouse_drag(mid, mid + Vector2(200, 0), MOUSE_BUTTON_RIGHT)
	check(absf(rig.yaw - yaw0) > 20.0 and b.flagged.is_empty(), "right drag turns (%.0f deg) without a towel" % (rig.yaw - yaw0))
	rig.go_home()
	await get_tree().create_timer(0.6).timeout
	var f := hidden_target()
	mouse_button(screen_of(f), MOUSE_BUTTON_RIGHT, true)
	await frames(1)
	mouse_button(screen_of(f), MOUSE_BUTTON_RIGHT, false)
	await frames(3)
	check(b.flagged.has(f), "right click places a towel on %s" % f)

	# touch: a tap digs
	var opened_before: int = b.revealed.size()
	var tcell := hidden_target([f])
	touch(0, screen_of(tcell), true)
	await frames(2)
	touch(0, screen_of(tcell), false)
	await frames(3)
	check(b.revealed.size() > opened_before, "tap digs %s" % tcell)

	# touch: holding a finger still places a towel
	var hcell := hidden_target([f])
	touch(0, screen_of(hcell), true)
	await get_tree().create_timer(0.7).timeout
	touch(0, screen_of(hcell), false)
	await frames(3)
	check(b.flagged.has(hcell), "hold places a towel on %s" % hcell)

	# touch: one finger drags the map
	t0 = rig.target
	var opened_now: int = b.revealed.size()
	touch(0, mid, true)
	for i in range(1, 11):
		touch_drag(0, mid + Vector2(0, 25 * i), Vector2(0, 25))
		await frames(1)
	touch(0, mid + Vector2(0, 250), false)
	await frames(2)
	check(rig.target.distance_to(t0) > 0.5 and b.revealed.size() == opened_now, "finger drag pans without digging")

	# touch: pinch zooms, twist turns
	var d0: float = rig.distance
	yaw0 = rig.yaw
	touch(0, mid - Vector2(100, 0), true)
	touch(1, mid + Vector2(100, 0), true)
	await frames(1)
	for i in range(1, 11):
		var half := Vector2(100 + 20 * i, 0).rotated(deg_to_rad(3.0 * i))
		touch_drag(1, mid + half, Vector2.ZERO)
		touch_drag(0, mid - half, Vector2.ZERO)
		await frames(1)
	touch(1, mid, false)
	touch(0, mid, false)
	await frames(2)
	check(rig.distance < d0 - 0.5, "pinch out zooms in (%.1f -> %.1f)" % [d0, rig.distance])
	check(absf(rig.yaw - yaw0) > 10.0, "twist turns (%.0f deg)" % (rig.yaw - yaw0))

	# camera pad
	var pad: Node = main.hud.find_child("CameraPad", true, false)
	check(pad != null and pad.is_visible_in_tree(), "camera pad on screen")
	yaw0 = rig.yaw
	(pad.find_child("Cam_right", true, false) as Button).pressed.emit()
	await get_tree().create_timer(0.4).timeout
	check(absf(rig.yaw - yaw0 - 45.0) < 0.5, "Turn right turns 45 degrees")
	(pad.find_child("Cam_home", true, false) as Button).pressed.emit()
	await get_tree().create_timer(0.5).timeout
	check(absf(rig.yaw) < 0.5 and absf(rig.distance - rig.home_distance) < 0.05, "Centre returns to the whole island")

	print("INPUT OK" if fails == 0 else "INPUT FAILED: %d" % fails)
	get_tree().quit()
