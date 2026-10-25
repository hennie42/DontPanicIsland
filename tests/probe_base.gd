class_name ProbeBase
extends Node
## Base for probe scenes (director): start the real game, drive it with real input events in window coordinates,
## and assert what happens. Subclasses implement run(); print "<NAME> OK" when fails == 0.
## Run: tools/probe.sh tests/<probe>.tscn SECONDS "<NAME> OK" [--skip-intro]

var main: Node
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	# until the game is playing and the intro is gone (a fixed wait was flaky on a busy machine)
	var waited := 0.0
	while waited < 60.0 and (main.get_children().any(func(n): return n is Intro) or not main._playing):
		await wait(0.25)
		waited += 0.25
	await wait(0.5)
	await run()
	get_tree().quit()


func run() -> void:
	pass


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func win(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func screen_of(c: Vector2i) -> Vector2:
	return main.rig.camera.unproject_position(Hex.to_world(c) + Vector3(0, 0.3, 0))


func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		# a motion to the target first, press and release alike: the real mouse over the window sends motion too, and
		# a Button whose press saw a motion off it never emits `pressed` (play_leaderboard flaked on that, F53)
		var mm := InputEventMouseMotion.new()
		mm.position = win(pos)
		mm.global_position = mm.position
		Input.parse_input_event(mm)
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = win(pos)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await frames(1)
	await frames(2)


## A key event as the OS sends it: physical_keycode for actions bound to physical keys, unicode for what a text
## field types.
func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.pressed = pressed
	ev.keycode = code
	ev.physical_keycode = code
	if pressed and code >= KEY_A and code <= KEY_Z:
		ev.unicode = code
	Input.parse_input_event(ev)


## Tap a key (menus: every key should close what it opened, and nothing else should see it).
func press(code: Key) -> void:
	key(code, true)
	await frames(1)
	key(code, false)
	await frames(3)


## Hold a key (camera and movement actions).
func hold(code: Key, seconds: float) -> void:
	key(code, true)
	await wait(seconds)
	key(code, false)
	await frames(2)


## Land the camp in the middle of the island with a real click.
func land() -> void:
	var keys: Array = main.board.land.keys()
	await click(screen_of(keys[keys.size() / 2]))


## A tile next to the land that can be dug, on screen and away from the HUD, mine or safe as asked.
func reachable(mine: bool, exclude: Array = []) -> Vector2i:
	var size := get_viewport().get_visible_rect().size
	var b = main.board
	for k in b.land:
		if b.can_reveal(k) and not b.revealed.has(k) and not b.flagged.has(k) and b.mines.has(k) == mine \
				and not exclude.has(k):
			var p := screen_of(k)
			if p.x > size.x * 0.12 and p.x < size.x * 0.8 and p.y > size.y * 0.12 and p.y < size.y * 0.82:
				return k
	return Vector2i(9999, 9999)
