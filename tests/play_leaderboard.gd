extends ProbeBase
## Probe for the shared leaderboard and the play counters (net faked: no network). A player game, not the autopilot:
## lands with a real click, finishes with the solver (win) or by digging mines with real clicks (--probe-lose),
## then drives the end panel with real key presses and clicks.
## Run: tools/probe.sh tests/play_leaderboard.tscn 150 "LEADERBOARD OK" --skip-intro --net=fake [--probe-lose]


func run() -> void:
	var lose := "--probe-lose" in OS.get_cmdline_user_args()
	check(Net.mode == "fake", "net is faked (%s)" % Net.mode)
	if not lose:
		Ending.save_nick("ANNA")   # a returning player: the name field is pre-filled
	check(_count("count_event", "loaded") == 1, "loaded counted once at boot")
	check(_count("count_event", "played") == 0, "nothing played before the first dig")

	# land with a real click; the mines come from this game's seed, not a fixed one
	var keys: Array = main.board.land.keys()
	var first: Vector2i = keys[keys.size() / 2]   # the cell ProbeBase.land() clicks
	await land()
	var b: Board = main.board
	check(b.placed and b.revealed.has(first), "camp landed on %s, mines placed" % first)
	var twin := Board.new(_island_file())
	twin.place(first, main.seed_value)
	check(twin.mines.size() == b.mines.size() and twin.mines.keys().all(func(m): return b.mines.has(m)),
		"mines follow seed_value %d" % main.seed_value)
	var zero := Board.new(_island_file())
	zero.place(first, 0)
	check(not zero.mines.keys().all(func(m): return b.mines.has(m)) or main.seed_value == 0,
		"mines differ from the old fixed seed 0")
	check(_count("count_event", "played") == 1, "played counted on the first dig")
	var played_island: int = _last("count_event", "played").get("p_island", -99)
	check(played_island == main.island_id, "counter carries the island (%d)" % played_island)

	# Esc menu > Leaderboard, mid-game
	var menu: Menu = main.menu
	await _press(KEY_ESCAPE)
	check(menu._esc_panel.visible and not main._playing, "Esc opens the menu and pauses")
	var board_btn := _button(menu._esc_vbox, "Leaderboard")
	check(board_btn != null, "Esc menu has a Leaderboard button")
	if board_btn:
		await click(board_btn.get_global_rect().get_center())
		await wait(0.5)
	check(menu._board_panel.visible and not menu._esc_panel.visible, "leaderboard panel open")
	check(_status(menu._board) == "", "menu board loaded")
	await GameEvent.shot("leaderboard_menu")
	# offline: the panel says so and nothing breaks
	Net.mode = "offline"
	await click(menu._board._tab_week.get_global_rect().get_center())
	await wait(0.5)
	check(_status(menu._board) == "Leaderboard offline", "offline message (%s)" % _status(menu._board))
	check(menu._board._grid.get_child_count() == 0, "no stale rows when offline")
	await GameEvent.shot("leaderboard_offline")
	Net.mode = "fake"
	var close := _button(menu._board_panel, "Close")
	await click(close.get_global_rect().get_center())
	await frames(3)
	check(not menu._board_panel.visible and menu._esc_panel.visible, "Close returns to the Esc menu")
	await click(_button(menu._esc_vbox, "Resume").get_global_rect().get_center())
	check(not menu._esc_panel.visible and main._playing, "Resume plays on")
	check(_count("submit_run", "") == 0, "browsing the board submits nothing")


	if lose:
		await _play_to_loss()
	else:
		await _play_to_win()
	var ending := _ending()
	check(ending != null, "ending shown")
	if ending == null:
		print("LEADERBOARD FAILED: %d" % fails)
		return
	var waited := 0.0
	while waited < 10.0 and ending._board_panel == null:
		await wait(0.25)
		waited += 0.25
	await wait(0.5)
	check(_count("count_event", "won" if not lose else "lost") == 1, "%s counted once" % ("won" if not lose else "lost"))
	check(_count("count_event", "lost" if not lose else "won") == 0, "the other outcome not counted")

	if lose:
		check(ending._nick_edit == null, "a loss asks for no name")
		check(_count("submit_run", "") == 0, "a loss submits nothing")
		check(_count("top_runs", "") >= 1, "a loss shows the board")
		check(_status(ending._board_panel) == "", "board loaded (status '%s')" % _status(ending._board_panel))
		check(ending._board_panel._grid.get_child_count() == 11 * 5, "header + 10 rows (%d cells)" % ending._board_panel._grid.get_child_count())
		await GameEvent.shot("leaderboard_lose")
	else:
		await _check_win_panel(ending)

	# the game does not close itself after the end panel (it used to quit 1 s later)
	await wait(2.5)
	check(is_instance_valid(main) and main.is_inside_tree(), "game still running after the end panel")

	check(_count("count_event", "loaded") == 1, "still one load")
	print("LEADERBOARD OK" if fails == 0 else "LEADERBOARD FAILED: %d" % fails)


func _check_win_panel(ending: Ending) -> void:
	var edit: LineEdit = ending._nick_edit
	check(edit != null and edit.visible, "a win asks for a name")
	check(edit.text == "ANNA", "name pre-filled from the last game (%s)" % edit.text)
	check(edit.has_focus(), "name field has focus")
	check(_count("submit_run", "") == 0, "nothing submitted before the player confirms")
	await GameEvent.shot("leaderboard_nick")

	# typing is cleaned live: upper case, A-Z 0-9, max 5
	edit.text = ""
	edit.text_changed.emit("")
	await _type("f u-ck!")
	check(edit.text == "FUCK", "typed text cleaned (%s)" % edit.text)
	await click(ending._submit_button.get_global_rect().get_center())
	await wait(0.3)
	check(ending._nick_error.text == "Please pick another name", "offensive name refused locally (%s)" % ending._nick_error.text)
	check(_count("submit_run", "") == 0, "refused name never sent")

	check(edit.has_focus(), "name field focused again after the refusal")
	check(edit.get_selected_text() == "FUCK", "refused name selected, typing replaces it")
	await _type("probe42")
	check(edit.text == "PROBE", "max 5 chars (%s)" % edit.text)
	await _press(KEY_ENTER)   # Enter submits like the button
	await wait(0.8)
	check(_count("submit_run", "") == 1, "submitted once")
	var body := _last("submit_run", "")
	var b: Board = main.board
	check(body.get("p_nick") == "PROBE" and body.get("p_gold") == b.gold and body.get("p_crew") == b.crew
		and body.get("p_turns") == b.turns and body.get("p_island") == main.island_id
		and body.get("p_seed") == main.seed_value, "submit carries name, gold, crew, turns, island, seed (%s)" % body)
	check(not body.has("p_score"), "the client never sends a score")
	check(not ending._nick_row.visible, "name row hidden after submit")
	var panel: LeaderboardPanel = ending._board_panel
	check(_status(panel) == "", "board loaded after submit")
	check(panel.highlight_id >= 1000, "own run highlighted (id %d)" % panel.highlight_id)
	check(panel._rank_label.text.begins_with("Your rank: "), "rank shown (%s)" % panel._rank_label.text)
	check(Ending.load_nick() == "PROBE", "name remembered for next time")
	check(Board.load_best() >= b.score(), "local best saved on a win")
	await GameEvent.shot("leaderboard_win")
	# tabs
	await click(panel._tab_week.get_global_rect().get_center())
	await wait(0.5)
	check(panel.period == "week" and panel._tab_week.disabled and not panel._tab_all.disabled, "This week tab")
	await click(panel._tab_all.get_global_rect().get_center())
	await wait(0.5)
	check(panel.period == "all", "All-time tab")


func _play_to_win() -> void:
	var solver := Solver.new()
	var n := 0
	var b: Board = main.board
	while not b.won and not b.lost and n < 3000:
		var move := solver.next_move(b)
		if not Solver.apply(b, move, main.seed_value):
			break
		main._after_board_change(move)
		n += 1
		if n % 10 == 0:
			await frames(1)
	check(b.won, "solver won the game (%d moves, crew %d)" % [n, b.crew])
	await wait(4.0)   # win sequence: 2 s, then the panel


func _play_to_loss() -> void:
	var b: Board = main.board
	var tries := 0
	while not b.lost and tries < 20:
		var c := reachable(true)
		if c.x == 9999:
			break
		await click(screen_of(c))
		await wait(0.3)
		tries += 1
	check(b.lost, "lost by digging mines with real clicks (%d clicks)" % tries)
	await wait(4.0)


func _type(s: String) -> void:
	for ch in s:
		for pressed in [true, false]:
			var ev := InputEventKey.new()
			ev.pressed = pressed
			ev.unicode = ch.unicode_at(0) if pressed else 0
			ev.keycode = OS.find_keycode_from_string(ch.to_upper()) if ch != " " else KEY_SPACE
			Input.parse_input_event(ev)
			await frames(1)
	await frames(2)


func _press(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.pressed = pressed
		ev.keycode = key
		Input.parse_input_event(ev)
		await frames(1)
	await frames(2)


func _ending() -> Ending:
	for n in main.get_children():
		if n is Ending:
			return n
	return null


func _button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null


func _status(p: LeaderboardPanel) -> String:
	return p._status.text if p._status.visible else ""


func _island_file() -> String:
	if main.island_id == 0:
		return "res://data/island.json"
	return "res://data/islands/island_%02d.json" % main.island_id


func _count(fn: String, event: String) -> int:
	return Net.calls.filter(func(c): return c["fn"] == fn and (event == "" or c["body"].get("p_event") == event)).size()


func _last(fn: String, event: String) -> Dictionary:
	for i in range(Net.calls.size() - 1, -1, -1):
		var c: Dictionary = Net.calls[i]
		if c["fn"] == fn and (event == "" or c["body"].get("p_event") == event):
			return c["body"]
	return {}
