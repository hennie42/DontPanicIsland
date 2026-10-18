class_name Ending
extends Node3D

signal panel_shown

var board: Board
var result: String # "win" or "lose"
var score_val: int

var _canvas: CanvasLayer
var _panel: PanelContainer
var _restart_button: Button
var _quit_button: Button

func show_ending(b: Board, res: String) -> void:
	board = b
	result = res
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

	var first_cell: Vector2i = Vector2i.ZERO
	for c in board.revealed.keys():
		first_cell = c
		break

	if first_cell != Vector2i.ZERO:
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
	score_info.text = "Gold: %d\nCrew: %d\nTurns: %d\nBest: %d" % [gold_val, crew_val * 100, turns_val, best_score]
	score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_info)

	var btn_hbox := HBoxContainer.new()
	vbox.add_child(btn_hbox)

	_restart_button = Button.new()
	_restart_button.text = "Play again"
	_restart_button.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(_restart_button)

	_quit_button = Button.new()
	_quit_button.text = "Quit"
	_quit_button.pressed.connect(_on_quit_pressed)
	btn_hbox.add_child(_quit_button)

	_apply_theme_to_all(panel_container)
	panel_shown.emit()

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
