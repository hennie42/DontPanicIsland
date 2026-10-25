extends Node
## The intro with real input (review, 2026-10-25). Played to the end, it leaves the camera in the play view (two
## tweens on the camera fought and it ended at 1.5x the play distance); skipped with a click, it digs nothing (the
## click's release landed the camp) and the game starts as after a full intro (the skip left main.gd waiting forever:
## no landing hint, and every Play again replayed the full intro).
## Run: tools/probe.sh tests/play_intro.tscn 60 "INTRO OK"                 (the full intro)
##      tools/probe.sh tests/play_intro.tscn 60 "INTRO OK" --probe-short   (the 3 s Play again version)
##      tools/probe.sh tests/play_intro.tscn 60 "INTRO OK" --probe-skip    (skipped with a click after 2 s)

var main: Node
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var skip := "--probe-skip" in args
	main = load("res://scenes/main.tscn").instantiate()
	main.set("_is_first_run", not "--probe-short" in args)
	add_child(main)
	var t0 := Time.get_ticks_msec() / 1000.0
	if skip:
		await wait(2.0)
		await click(get_viewport().get_visible_rect().size * 0.5)
		await wait(0.5)
	# the camera moves smoothly all the way: the largest change between two frames (the fight between the tweens
	# jumped it from the play distance back out to 1.5x at 11 s)
	var rig: CameraRig = main.rig
	var jump_d := 0.0
	var jump_yaw := 0.0
	var last_d := -1.0
	var last_yaw := 0.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 30.0 and _intro_alive():
		await get_tree().process_frame
		if last_d >= 0.0 and Time.get_ticks_msec() / 1000.0 - t0 > 0.5:   # after the cut to the far start
			jump_d = maxf(jump_d, absf(rig.distance - last_d))
			jump_yaw = maxf(jump_yaw, absf(wrapf(rig.yaw - last_yaw, -180.0, 180.0)))
		last_d = rig.distance
		last_yaw = rig.yaw
	var took := Time.get_ticks_msec() / 1000.0 - t0
	await frames(2)
	if not skip:
		check(jump_d < 1.0 and jump_yaw < 10.0, "no camera jumps (largest step: distance %.2f, yaw %.1f)" % [jump_d, jump_yaw])
	check(not _intro_alive(), "the intro is over (%.1f s)" % took)
	if skip:
		check(took < 4.0, "the click skipped it")
	check(absf(rig.distance - rig.home_distance) < 0.01, "camera at the play distance (%.2f, home %.2f)" % [rig.distance, rig.home_distance])
	check(absf(wrapf(rig.yaw, -180.0, 180.0)) < 0.01, "camera faces the play view (yaw %.2f)" % rig.yaw)
	check(main.board.revealed.is_empty() and not main.board.placed, "nothing dug: the camp is not landed")
	check(main._landing_hint != null, "the landing hint is up: the game started")
	check(not main.get("_is_first_run"), "a Play again gets the short intro")
	var d: float = rig.distance
	var y: float = rig.yaw
	await wait(1.5)
	check(rig.distance == d and rig.yaw == y, "nothing drives the camera afterwards")

	print("INTRO OK" if fails == 0 else "INTRO FAILED: %d" % fails)
	get_tree().quit()


func _intro_alive() -> bool:
	return main.get_children().any(func(n): return n is Intro)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = get_viewport().get_screen_transform() * pos
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await frames(1)
	await frames(2)
