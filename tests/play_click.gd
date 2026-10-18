extends Node
## Real-input check (the autopilot bypasses mouse input): start the game, wait out the intro, click a land cell
## in window coordinates like a player. Run: studio godot-play tests/play_click.tscn 60  -> "CLICK OK"

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	# wait until the intro is gone (it takes ~13 s, longer on a busy machine: a fixed wait was flaky)
	var waited := 0.0
	while waited < 60.0 and (main.get_children().any(func(n): return n is Intro) or not main._playing):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(0.5).timeout
	var b = main.board
	var cam: Camera3D = main.rig.camera
	var keys: Array = b.land.keys()
	var c: Vector2i = keys[keys.size() / 2]
	var screen: Vector2 = cam.unproject_position(Hex.to_world(c))
	print("PROBE playing=", main._playing, " finished=", main._finished, " autopilot=", main.autopilot,
		" target=", c, " screen=", screen, " viewport=", get_viewport().get_visible_rect().size)
	print("PROBE cell_at(screen)=", main._cell_at(screen))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	var win: Vector2 = get_viewport().get_screen_transform() * screen   # window coordinates, as a real click has
	print("PROBE window pos=", win, " window=", DisplayServer.window_get_size())
	ev.position = win
	ev.global_position = win
	Input.parse_input_event(ev)
	var up: InputEventMouseButton = ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	for i in 5:
		await get_tree().process_frame
	print("PROBE after click: revealed=", b.revealed.size(), " gui_hovered=", get_viewport().gui_get_hovered_control())
	var fog = main.view.get_node("Cell_%d_%d" % [c.x, c.y]).get_node_or_null("Fog")
	print("PROBE fog visible on target=", fog.visible if fog else "no node")
	print("CLICK OK" if b.revealed.size() > 0 else "CLICK FAILED: the click revealed nothing")
	get_tree().quit()
