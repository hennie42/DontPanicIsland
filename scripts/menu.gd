class_name Menu
extends CanvasLayer

signal help_requested
signal menu_requested
signal resume_requested
signal restart_requested
signal quit_requested
signal help_closed
signal menu_closed

# UI elements
var _help_panel: PanelContainer
var _esc_panel: PanelContainer
var _help_label: Label
var _esc_vbox: VBoxContainer
var _board_panel: PanelContainer
var _board: LeaderboardPanel
var _music_slider: HSlider
var _sfx_slider: HSlider

var _font: FontFile

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_font = load("res://assets/kenney/kenney-fonts/Kenney Future.ttf") as FontFile
	if not _font:
		push_error("Menu: Font not found at res://assets/kenney/kenney-fonts/Kenney Future.ttf")

	_setup_ui()
	_style_buttons(self)
	_hide_all()
	update_sliders()

func _setup_ui() -> void:
	# HELP PANEL
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_help_panel)

	var help_vbox := VBoxContainer.new()
	_help_panel.add_child(help_vbox)

	var title := Label.new()
	title.text = "DON'T PANIC"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color("#ffd23f"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	help_vbox.add_child(title)

	var rules_label := Label.new()
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules_label.text = "Your first click lands the camp\nDig: left click\nTowel: right click, on a tile you think hides a mine\nNumbers count the mines around a tile (0-6)\nClick a number whose towels are all placed to open the rest\nYou can only dig next to your land or a towel\nPalms give wood, chests and wrecks give gold\n\nTools (wood):\nMetal detector (3): tests one tile, no risk\nParrot scout (2): shows a hidden number\nTowel of safety (5): the next mine costs no crewmate\n\n3 crew | Win by digging every safe tile"
	rules_label.add_theme_font_override("font", _font)
	rules_label.add_theme_font_size_override("font_size", 32)
	rules_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rules_label.add_theme_constant_override("outline_size", 4)
	help_vbox.add_child(rules_label)

	var help_close_btn := Button.new()
	help_close_btn.text = "Close"
	help_close_btn.add_theme_font_override("font", _font)
	help_close_btn.pressed.connect(_on_help_close_pressed)
	help_vbox.add_child(help_close_btn)

	# ESC PANEL
	_esc_panel = PanelContainer.new()
	_esc_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_esc_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	_esc_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_esc_panel)

	_esc_vbox = VBoxContainer.new()
	_esc_panel.add_child(_esc_vbox)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.add_theme_font_override("font", _font)
	resume_btn.pressed.connect(_on_resume_pressed)
	_esc_vbox.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.add_theme_font_override("font", _font)
	restart_btn.pressed.connect(_on_restart_pressed)
	_esc_vbox.add_child(restart_btn)

	var help_btn := Button.new()
	help_btn.text = "Help"
	help_btn.add_theme_font_override("font", _font)
	help_btn.pressed.connect(_on_help_requested)
	_esc_vbox.add_child(help_btn)

	var board_btn := Button.new()
	board_btn.text = "Leaderboard"
	board_btn.add_theme_font_override("font", _font)
	board_btn.pressed.connect(show_leaderboard)
	_esc_vbox.add_child(board_btn)

	var music_label := Label.new()
	music_label.text = "Music"
	music_label.add_theme_font_override("font", _font)
	_esc_vbox.add_child(music_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.05
	_music_slider.add_theme_font_override("font", _font)
	_music_slider.value_changed.connect(_on_music_slider_changed)
	_esc_vbox.add_child(_music_slider)

	var sfx_label := Label.new()
	sfx_label.text = "SFX"
	sfx_label.add_theme_font_override("font", _font)
	_esc_vbox.add_child(sfx_label)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.add_theme_font_override("font", _font)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	_esc_vbox.add_child(_sfx_slider)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.add_theme_font_override("font", _font)
	quit_btn.pressed.connect(_on_quit_pressed)
	_esc_vbox.add_child(quit_btn)

	# LEADERBOARD PANEL (from the Esc menu; Close goes back to it)
	_board_panel = PanelContainer.new()
	_board_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # centre on the anchor, not hang from it
	_board_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_board_panel)
	var board_style := StyleBoxFlat.new()   # opaque enough to read the rows over the island
	board_style.bg_color = Color(0, 0, 0, 0.8)
	board_style.set_corner_radius_all(10)
	board_style.set_content_margin_all(24)
	_board_panel.add_theme_stylebox_override("panel", board_style)
	var board_vbox := VBoxContainer.new()
	_board_panel.add_child(board_vbox)
	var board_title := Label.new()
	board_title.text = "TOP PLAYERS"
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_title.add_theme_font_override("font", _font)
	board_title.add_theme_font_size_override("font_size", 56)
	board_title.add_theme_color_override("font_color", Color("#ffd23f"))
	board_title.add_theme_color_override("font_outline_color", Color.BLACK)
	board_title.add_theme_constant_override("outline_size", 6)
	board_vbox.add_child(board_title)
	_board = LeaderboardPanel.new()
	board_vbox.add_child(_board)
	var board_close_btn := Button.new()
	board_close_btn.text = "Close"
	board_close_btn.add_theme_font_override("font", _font)
	board_close_btn.pressed.connect(_on_board_close_pressed)
	board_vbox.add_child(board_close_btn)

	# Apply theme to all
	var theme := Theme.new()
	theme.set_default_font(_font)
	_apply_theme_to_all(_help_panel, theme)
	_apply_theme_to_all(_esc_panel, theme)
	_apply_theme_to_all(_esc_vbox, theme)
	_apply_theme_to_all(_board_panel, theme)

func _apply_theme_to_all(node: Node, theme: Theme) -> void:
	if node is Control:
		node.theme = theme
	for child in node.get_children():
		_apply_theme_to_all(child, theme)

func _hide_all() -> void:
	_help_panel.visible = false
	_esc_panel.visible = false
	_board_panel.visible = false

func show_help() -> void:
	_hide_all()
	_help_panel.visible = true
	help_requested.emit()

func show_esc_menu() -> void:
	_hide_all()
	_esc_panel.visible = true
	menu_requested.emit()

func show_leaderboard() -> void:
	_hide_all()
	_board_panel.visible = true
	GameEvent.marker("LEADERBOARD_OPEN")
	_board.load_board()

func _on_board_close_pressed() -> void:
	_board_panel.visible = false
	_esc_panel.visible = true

func _on_help_close_pressed() -> void:
	_help_panel.visible = false
	help_closed.emit()

func _on_help_requested() -> void:
	show_help()

func _on_resume_pressed() -> void:
	_hide_all()
	resume_requested.emit()
	menu_closed.emit()

func _on_restart_pressed() -> void:
	_hide_all()
	restart_requested.emit()
	menu_closed.emit()

func _on_quit_pressed() -> void:
	_hide_all()
	quit_requested.emit()

func _on_music_slider_changed(value: float) -> void:
	_set_bus_volume("Music", value)

func _on_sfx_slider_changed(value: float) -> void:
	_set_bus_volume("SFX", value)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db := linear_to_db(value) if value > 0 else -80.0
		AudioServer.set_bus_volume_db(idx, db)

func update_sliders() -> void:
	_update_slider("Music", _music_slider)
	_update_slider("SFX", _sfx_slider)

func _update_slider(bus_name: String, slider: HSlider) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db := AudioServer.get_bus_volume_db(idx)
		slider.value = db_to_linear(db)

func linear_to_db(lin: float) -> float:
	if lin <= 0: return -80.0
	return 20.0 * log(lin) / log(10.0)

func db_to_linear(db: float) -> float:
	if db <= -80.0: return 0.0
	return pow(10.0, db / 20.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _help_panel.visible and not _esc_panel.visible and not _board_panel.visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _help_panel.visible:
				_on_help_close_pressed()
			elif _board_panel.visible:
				_on_board_close_pressed()
			elif _esc_panel.visible:
				_on_resume_pressed()
		elif event.keycode == KEY_H:
			if _help_panel.visible:
				_on_help_close_pressed()
			else:
				show_help()


## Menu buttons at a readable size (the theme default was tiny at 1920 wide).
func _style_buttons(node: Node) -> void:
	for b in node.find_children("*", "Button", true, false):
		var btn := b as Button
		btn.add_theme_font_size_override("font_size", 40)
		btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 260), maxf(btn.custom_minimum_size.y, 64))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
