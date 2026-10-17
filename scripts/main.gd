extends Node3D

static var _is_first_run: bool = true
## Game controller (T09). Builds the environment, the board, the board view,
## the camera rig and the HUD in code. Handles player mouse input and drives
## the --autopilot play loop.

var board: Board
var view: BoardView
var rig: CameraRig
var hud: Hud
var solver: Solver
var menu: Menu
var sfx: Sfx
var decor: Decor
var _camp_placed: bool = false

var _last_gold: int = 0
var seed_value: int = 0
var autopilot: bool = false
var force_lose: bool = false
var skip_intro: bool = false

var _playing: bool = true
var _finished: bool = false

# Tip state
var _tips_shown: Array[int] = []
var _font: FontFile

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	_set_up_environment()
	_ensure_audio_buses()
	_font = load("res://assets/kenney/kenney-fonts/Kenney Future.ttf")

	sfx = Sfx.new()
	add_child(sfx)

	board = Board.new()

	view = BoardView.new()
	add_child(view)
	view.build(board)
	view.refresh(board)

	decor = Decor.new()
	add_child(decor)
	decor.build(board, view)

	rig = CameraRig.new()
	add_child(rig)

	hud = Hud.new()
	add_child(hud)
	hud.update_from(board)
	hud.tool_selected.connect(_on_tool_selected)
	hud.help_requested.connect(_on_hud_help_requested)
	hud.button_clicked.connect(func(): sfx.play("click"))

	menu = Menu.new()
	add_child(menu)
	menu.help_requested.connect(func(): sfx.play("click"); _on_menu_help_requested())
	menu.menu_requested.connect(func(): sfx.play("click"); _on_menu_menu_requested())
	menu.resume_requested.connect(func(): sfx.play("click"); _on_menu_resume_requested())
	menu.restart_requested.connect(func(): sfx.play("click"); _on_menu_restart_requested())
	menu.quit_requested.connect(func(): sfx.play("click"); _on_menu_quit_requested())
	menu.help_closed.connect(func(): sfx.play("click"); _on_menu_help_closed())
	menu.menu_closed.connect(func(): sfx.play("click"); _on_menu_menu_closed())

	_parse_flags()

	if not skip_intro:
		var intro := Intro.new()
		add_child(intro)
		await intro.play(_is_first_run, rig, sfx)
		_is_first_run = false

	GameEvent.marker("START", "seed=%d" % seed_value)

	if autopilot:
		solver = Solver.new()
		_play_autopilot()


func _set_up_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4aa8ff")
	sky_material.sky_horizon_color = Color("#bfe6ff")
	# Sea-blue ground colours so the water reads as an endless ocean.
	sky_material.ground_horizon_color = Color("#7fc8f0")
	sky_material.ground_bottom_color = Color("#4a9fd8")

	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	# Ambient light from the sky (sunny).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)


func _ensure_audio_buses() -> void:
	var bus_count := AudioServer.get_bus_count()
	var music_idx := -1
	var sfx_idx := -1

	for i in range(bus_count):
		var name := AudioServer.get_bus_name(i)
		if name == "Music": music_idx = i
		if name == "SFX": sfx_idx = i

	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")


func _parse_flags() -> void:
	autopilot = false
	force_lose = false
	skip_intro = false
	var seed_given: bool = false
	var seed_val: int = 0

	var args: Array = OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--autopilot":
			autopilot = true
		elif arg == "--force-lose":
			force_lose = true
		elif arg == "--skip-intro":
			skip_intro = true
		elif arg.begins_with("--seed="):
			seed_given = true
			seed_val = int(arg.substr(6))

	if seed_given:
		seed_value = seed_val
	elif autopilot:
		seed_value = 1
	else:
		seed_value = randi()


# ---------------------------------------------------------------------------
# Human input (only while playing and not in autopilot)
# ---------------------------------------------------------------------------

## The land cell under the mouse, or null if the ray misses a land tile
## (points at the sky or hits water).
func _cell_at(pos: Vector2) -> Variant:
	var origin: Vector3 = rig.camera.project_ray_origin(pos)
	var dir: Vector3 = rig.camera.project_ray_normal(pos)
	var hit: Variant = Hex.ray_to_ground(origin, dir)
	if hit == null:
		return null
	var cell: Vector2i = Hex.from_world(hit as Vector3)
	if not board.is_land(cell):
		return null
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if _finished or autopilot:
		return

	if event is InputEventMouseButton and event.pressed:
		if _playing:
			var pos: Vector2 = event.position
			if event.button_index == MOUSE_BUTTON_LEFT:
				_left_click(pos)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_right_click(pos)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _playing:
				menu.show_esc_menu()
				GameEvent.marker("MENU_OPEN")
				_playing = false
		elif event.keycode == KEY_H:
			if _playing:
				menu.show_help()
				GameEvent.marker("HELP_OPEN")
				_playing = false


func _left_click(pos: Vector2) -> void:
	var cell: Vector2i = _cell_at(pos) as Vector2i
	if cell == null:
		return
	if hud.selected_tool == "detector":
		if board.use_detector(cell) >= 0:
			_after_board_change({"action": "detector", "cell": cell})
	elif hud.selected_tool == "parrot":
		if board.use_parrot(cell) >= 0:
			hud.select_tool("")
			_after_board_change({"action": "parrot", "cell": cell})
	else:
		if board.revealed.has(cell):
			var cells: Array[Vector2i] = board.chord(cell)
			if not cells.is_empty():
				_after_board_change({"action": "chord", "cell": cell})
		else:
			var opened: Array[Vector2i] = board.reveal(cell)
			if not opened.is_empty():
				_after_board_change({"action": "reveal", "cell": cell, "opened": opened})


func _right_click(pos: Vector2) -> void:
	var cell: Vector2i = _cell_at(pos) as Vector2i
	if cell == null:
		return
	if board.toggle_flag(cell):
		_after_board_change({"action": "flag", "cell": cell})


func _on_tool_selected(tool: String) -> void:
	if tool == "towel" and _playing and not _finished:
		if board.buy_towel():
			_after_board_change({"action": "towel"})
		hud.select_tool("")


# ---------------------------------------------------------------------------
# Board-change bookkeeping (refresh view+HUD, log MOVE, check win/lose)
# ---------------------------------------------------------------------------

func _after_board_change(move: Dictionary) -> void:
	view.refresh(board)
	hud.update_from(board)

	# First reveal: drop the camp on the landing cell, then report the crew
	# after every move (figures -> skeletons as crewmates are lost).
	if not _camp_placed and move.get("action") == "reveal":
		var c := move.get("cell") as Vector2i
		var opened: Array = move.get("opened", [])
		if c == null:
			c = opened[0] if not opened.is_empty() else Vector2i(0, 0)
		_camp_placed = true
		decor.place_camp(board, c)
	decor.update_crew(board)

	GameEvent.marker("MOVE", _move_data(move))
	_check_tips(move)

	# SFX: gold
	if board.gold > _last_gold:
		sfx.play("coin")
	_last_gold = board.gold

	# SFX: action specific
	var action: String = move.get("action", "")
	if action == "reveal":
		sfx.play("dig")
		var opened = move.get("opened", []) as Array[Vector2i]
		for c in opened:
			if board.mines.has(c):
				sfx.play("boom")
				break
	elif action == "chord":
		sfx.play("dig")
	elif action == "flag":
		sfx.play("flag")
	elif action == "towel":
		sfx.play("tool")
	elif action == "detector" or action == "parrot":
		sfx.play("tool")

	if board.won or board.lost:
		_end_game()


func _move_data(move: Dictionary) -> String:
	var action: String = move.get("action", "")
	if move.has("cell"):
		var c := move.get("cell") as Vector2i
		return "%s %d %d" % [action, c.x, c.y]
	return action


func _check_tips(move: Dictionary) -> void:
	var action: String = move.get("action", "")

	# Tip 1: after first reveal
	if action == "reveal" and not _tips_shown.has(1):
		_show_tip(1, "Numbers count the mines next to a tile.")
		_tips_shown.append(1)

	# Tip 2: first time a number appears
	if action == "reveal" and not _tips_shown.has(2):
		var opened = move.get("opened", []) as Array[Vector2i]
		for c in opened:
			if board.number(c) > 0:
				_show_tip(2, "Click a number when all its mines have towels to open the rest.")
				_tips_shown.append(2)
				break

	# Tip 3: first tool use
	if (action == "detector" or action == "parrot" or action == "towel") and not _tips_shown.has(3):
		_show_tip(3, "Tools cost wood: chop palms by digging them up.")
		_tips_shown.append(3)


func _show_tip(n: int, text: String) -> void:
	GameEvent.marker("TIP", str(n))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)

	add_child(label)
	label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - label.size.x / 2, 50)

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(5.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): label.queue_free())


func _end_game() -> void:
	if _finished:
		return
	_finished = true
	_playing = false
	var result: String = "win" if board.won else "lose"
	GameEvent.marker("END", "result=%s score=%d turns=%d" % [result, board.score(), board.turns])
	Board.save_best(board.score())

	if result == "win":
		sfx.play("win")
	else:
		sfx.play("lose")

	var ending := Ending.new()
	add_child(ending)
	ending.show_ending(board, result)

	await ending.panel_shown
	await get_tree().create_timer(1.0).timeout
	GameEvent.marker("FINISH")
	GameEvent.quit(0)


# ---------------------------------------------------------------------------
# Autopilot (Solver, or forced-lose)
# ---------------------------------------------------------------------------

func _next_autopilot_move(b: Board) -> Dictionary:
	if force_lose:
		return _force_lose_move(b)
	return solver.next_move(b)


## Returns a move that reveals a mine cell the board will accept; if none is
## on the revealed territory's border yet, it reveals a safe border cell to
## grow the territory until a mine becomes reachable. This is the only place
## in the game that reads board.mines.
func _force_lose_move(b: Board) -> Dictionary:
	# 1. Reveal a mine that can be revealed right now (border, not flagged,
	#    not already revealed).
	for c in b.mines:
		if b.can_reveal(c):
			return {"action": "reveal", "cell": c}
	# 2. No revealable mine yet: reveal a safe border cell to grow the revealed
	#    territory until a mine sits on the border.
	for c in b.land:
		if not b.revealed.has(c) and not b.flagged.has(c) \
			and not b.mines.has(c) and b.can_reveal(c):
			return {"action": "reveal", "cell": c}
	# 3. Fallback (should not happen): reveal the first board-acceptable cell.
	for c in b.mines:
		if b.is_land(c) and b.can_reveal(c):
			return {"action": "reveal", "cell": c}
	return {"action": "reveal", "cell": b.land.keys()[0]}


func _play_autopilot() -> void:
	# 1. Open help, wait 0.5s, close it
	menu.show_help()
	await get_tree().create_timer(0.5).timeout
	_on_menu_help_closed()

	# 2. Open the Esc menu, wait 0.5s, resume
	menu.show_esc_menu()
	await get_tree().create_timer(0.5).timeout
	_on_menu_menu_closed()
	_on_menu_resume_requested()

	# 3. Play as before
	var move_count := 0
	const MAX_MOVES := 5000
	while not board.won and not board.lost and move_count < MAX_MOVES:
		await get_tree().create_timer(0.1).timeout
		var move: Dictionary = _next_autopilot_move(board)
		if Solver.apply(board, move, seed_value):
			move_count += 1
			_after_board_change(move)
		else:
			# Board refused the move; in a healthy run this only happens once
			# the game is already over (won/lost).
			break
	if not (board.won or board.lost) and not _finished:
		# Safety net: the autopilot could not end the game. Log a forced end.
		GameEvent.marker("END", "result=lose score=%d turns=%d" % [board.score(), board.turns])
		GameEvent.marker("FINISH")
		GameEvent.quit(0)


# ---------------------------------------------------------------------------
# Billboard numbers when the camera is zoomed out
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if rig != null and rig.camera != null and view != null:
		view.set_numbers_billboard(rig.distance > 12.0)


# ---------------------------------------------------------------------------
# Menu Handlers
# ---------------------------------------------------------------------------

func _on_hud_help_requested() -> void:
	menu.show_help()
	_playing = false
	GameEvent.marker("HELP_OPEN")

func _on_menu_help_requested() -> void:
	_playing = false
	GameEvent.marker("HELP_OPEN")

func _on_menu_help_closed() -> void:
	_playing = true
	GameEvent.marker("HELP_CLOSE")

func _on_menu_menu_requested() -> void:
	_playing = false
	GameEvent.marker("MENU_OPEN")

func _on_menu_menu_closed() -> void:
	_playing = true
	GameEvent.marker("MENU_CLOSE")

func _on_menu_resume_requested() -> void:
	_playing = true

func _on_menu_restart_requested() -> void:
	get_tree().reload_current_scene()

func _on_menu_quit_requested() -> void:
	get_tree().quit()
