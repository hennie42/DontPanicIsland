class_name Ending
extends Node3D

signal panel_shown

var board: Board
var result: String # "win" or "lose"
var score_val: int
var island_id: int
var seed_value: int

var _canvas: CanvasLayer
var _big_text: Control   # the win / lose line; it fades out when the panel (and its leaderboard) comes up
var _panel: PanelContainer
var _restart_button: Button
var _quit_button: Button
var _nick_edit: LineEdit
var _submit_button: Button
var _nick_error: Label
var _nick_row: Control
var _board_panel: LeaderboardPanel

const NICK_PATH := "user://nick.json"

func show_ending(b: Board, res: String, island: int = 0, seed_val: int = 0) -> void:
	board = b
	result = res
	island_id = island
	seed_value = seed_val
	score_val = board.score()

	# Create CanvasLayer for UI
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	if result == "win":
		_play_win_sequence()
	else:
		_play_lose_sequence()

func _play_win_sequence() -> void:
	GameEvent.marker("ENDING", "win")

	# 1. Confetti
	var confetti := CPUParticles3D.new()
	confetti.amount = 150
	confetti.spread = 180.0
	confetti.gravity = Vector3(0, -2, 0)
	confetti.initial_velocity_min = 5.0
	confetti.initial_velocity_max = 10.0
	confetti.scale_amount_min = 0.1
	confetti.scale_amount_max = 0.3
	confetti.color = Color.GOLD
	add_child(confetti)

	# the camp: the first revealed cell (testing it against (0, 0) skipped the pile there, a land cell on every island)
	if not board.revealed.is_empty():
		var first_cell: Vector2i = board.revealed.keys()[0]
		var pos := Hex.to_world(first_cell)
		confetti.global_position = pos + Vector3(0, 2, 0)

		# 2. Pile of coins at first revealed cell
		for i in range(10):
			var coin := Art.prop("coin_stack")
			add_child(coin)
			coin.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
			var tween := create_tween()
			tween.tween_property(coin, "global_position:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# 3. UFO flees upwards
	var ufo := Ufo.make()
	add_child(ufo)
	ufo.global_position = Vector3(0, 5, 5)
	var ufo_tween := create_tween()
	ufo_tween.tween_property(ufo, "global_position:y", 15.0, 2.0).set_trans(Tween.TRANS_SINE)

	# 4. Big text
	var label := Label.new()
	label.text = "So long, and thanks for all the treasure"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)

	var label_container := Control.new()
	_big_text = label_container
	_canvas.add_child(label_container)
	label_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_container.mouse_filter = Control.MOUSE_FILTER_IGNORE   # a layout box: the end panel's buttons must get clicks
	label_container.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	label.grow_vertical = Control.GROW_DIRECTION_BOTH

	await get_tree().create_timer(2.0).timeout
	_show_panel()

func _play_lose_sequence() -> void:
	GameEvent.marker("ENDING", "lose")

	# 1. Bombs rise from mine cells
	var mine_cells := board.mines.keys()
	var delay := 0.0
	var bomb_tween := create_tween().set_parallel(true)
	for c in mine_cells:
		var bomb := Art.prop("bomb_red")
		add_child(bomb)
		bomb.global_position = Hex.to_world(c) + Vector3(0, 0.2, 0)
		bomb_tween.tween_property(bomb, "global_position:y", 1.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay)
		delay += 0.05

	# 2. UFOs swoop back
	var ufo1 := Ufo.make()          # the alien rides in this one
	var ufo2 := Ufo.make(false)
	add_child(ufo1)
	add_child(ufo2)
	ufo1.global_position = Vector3(-8, 10, 0)
	ufo2.global_position = Vector3(8, 10, 0)


	var ufo_tween := create_tween().set_parallel(true)
	ufo_tween.tween_property(ufo1, "global_position", Vector3(-3, 2, 2), 2.0).set_trans(Tween.TRANS_SINE)
	ufo_tween.tween_property(ufo2, "global_position", Vector3(3, 2, 2), 2.0).set_trans(Tween.TRANS_SINE)

	# 3. Speech bubble
	var label := Label.new()
	label.text = "Resistance is useless! Your island has been bypassed."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)

	var label_container := Control.new()
	_big_text = label_container
	_canvas.add_child(label_container)
	label_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label_container.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	label_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	label_container.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	label.grow_vertical = Control.GROW_DIRECTION_BOTH

	await get_tree().create_timer(2.0).timeout
	_show_panel()

func _show_panel() -> void:
	GameEvent.marker("ENDING_PANEL")
	if _big_text:
		create_tween().tween_property(_big_text, "modulate:a", 0.0, 0.4)

	var panel_container := PanelContainer.new()
	panel_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_canvas.add_child(panel_container)

	var label_style := StyleBoxFlat.new()
	label_style.bg_color = Color(0, 0, 0, 0.7)
	label_style.set_corner_radius_all(10)
	label_style.set_content_margin_all(20)
	panel_container.add_theme_stylebox_override("panel", label_style)

	var vbox := VBoxContainer.new()
	panel_container.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER" if result == "lose" else "VICTORY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var score_info := Label.new()
	var gold_val := board.gold
	var crew_val := board.crew
	var turns_val := board.turns
	var best_score := Board.load_best()
	score_info.text = "Score: %d\nGold: %d\nCrew: %d (+%d)\nTurns: %d\nBest: %d" % [score_val, gold_val, crew_val, crew_val * 100, turns_val, best_score]
	score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_info.add_theme_font_size_override("font_size", 28)
	vbox.add_child(score_info)

	# Shared leaderboard: a win asks for a nickname and submits the run; a loss only shows the board.
	if result == "win":
		_build_nick_row(vbox)
	_board_panel = LeaderboardPanel.new()
	vbox.add_child(_board_panel)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	_restart_button = Button.new()
	_restart_button.text = "Play again"
	_restart_button.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(_restart_button)

	_quit_button = Button.new()
	_quit_button.text = "Quit"
	_quit_button.pressed.connect(_on_quit_pressed)
	btn_hbox.add_child(_quit_button)

	for btn: Button in [_restart_button, _quit_button]:
		btn.add_theme_font_size_override("font_size", 32)
		btn.custom_minimum_size = Vector2(240, 60)
	if OS.has_feature("web"):
		_quit_button.visible = false   # quitting in a browser tab only leaves a dead canvas

	_apply_theme_to_all(panel_container)
	if result == "win" and GameEvent.autopilot:
		_nick_edit.text = "AUTO"
		await _on_submit()
	elif result == "win":
		_nick_edit.grab_focus()
		_nick_edit.caret_column = _nick_edit.text.length()
	else:
		await _board_panel.load_board()
	panel_shown.emit()

func _build_nick_row(vbox: VBoxContainer) -> void:
	_nick_row = VBoxContainer.new()
	vbox.add_child(_nick_row)
	var prompt := Label.new()
	prompt.text = "Your name for the leaderboard (1-5 letters or digits)"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	_nick_row.add_child(prompt)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_nick_row.add_child(row)
	_nick_edit = LineEdit.new()
	_nick_edit.max_length = NickFilter.MAX_LEN
	_nick_edit.custom_minimum_size = Vector2(220, 56)
	_nick_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_edit.add_theme_font_size_override("font_size", 36)
	_nick_edit.text = load_nick()
	_nick_edit.text_changed.connect(_on_nick_changed)
	_nick_edit.text_submitted.connect(func(_t: String): _on_submit())
	row.add_child(_nick_edit)
	_submit_button = Button.new()
	_submit_button.text = "Submit"
	_submit_button.add_theme_font_size_override("font_size", 32)
	_submit_button.custom_minimum_size = Vector2(200, 56)
	_submit_button.pressed.connect(_on_submit)
	row.add_child(_submit_button)
	_nick_error = Label.new()
	_nick_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_error.add_theme_color_override("font_color", Color("#ff6b5b"))
	_nick_error.add_theme_font_size_override("font_size", 24)
	_nick_row.add_child(_nick_error)

func _on_nick_changed(t: String) -> void:
	var c := NickFilter.clean(t)
	if c != t:
		_nick_edit.text = c
		_nick_edit.caret_column = c.length()
	_nick_error.text = ""

func _on_submit() -> void:
	var nick := NickFilter.clean(_nick_edit.text)
	if nick.is_empty():
		_nick_error.text = "Type a name first"
		_nick_edit.grab_focus()
		return
	if not NickFilter.is_ok(nick):
		_nick_error.text = "Please pick another name"
		GameEvent.marker("NICK", "rejected")
		_nick_edit.grab_focus()   # the player types a new name straight away
		_nick_edit.select_all()
		return
	_submit_button.disabled = true
	_nick_edit.editable = false
	_nick_error.text = "Sending..."
	var res: Dictionary = await Net.submit_run(nick, board, island_id, seed_value)
	if res["ok"]:
		save_nick(nick)
		_nick_row.visible = false
		var d: Dictionary = res["data"]
		GameEvent.marker("SUBMIT", "nick=%s score=%d rank=%d" % [nick, int(d["score"]), int(d["rank_all"])])
		await _board_panel.load_board(int(d["id"]), int(d["rank_all"]), int(d["rank_week"]))
		return
	var err: String = res["error"]
	GameEvent.marker("SUBMIT", "error=%s" % err)
	match err:
		"bad_nick":
			_nick_error.text = "Please pick another name"
		"too_fast":
			_nick_error.text = "Too fast: try again in half a minute"
		"implausible":
			_nick_error.text = "This run could not be accepted"
		_:
			_nick_error.text = "Leaderboard offline"
	_submit_button.disabled = err == "implausible"
	_nick_edit.editable = err != "implausible"
	if _nick_edit.editable:
		_nick_edit.grab_focus()
	if err == "offline" or err == "implausible":
		await _board_panel.load_board()

static func load_nick() -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NICK_PATH)) if FileAccess.file_exists(NICK_PATH) else null
	return NickFilter.clean(String(data.get("nick", ""))) if data is Dictionary else ""

static func save_nick(nick: String) -> void:
	var file := FileAccess.open(NICK_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"nick": nick}))

func _apply_theme_to_all(node: Node) -> void:
	if node is Control:
		# Use the font from the project. We can't easily get the theme from Hud directly without a reference.
		# Let's just apply the font.
		var font := load("res://assets/kenney/kenney-fonts/Kenney Future.ttf") as FontFile
		node.add_theme_font_override("font", font)

	for child in node.get_children():
		_apply_theme_to_all(child)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
