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
var _music_slider: HSlider
var _sfx_slider: HSlider

var _font: FontFile

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_font = load("res://assets/kenney/kenney-fonts/Kenney Future.ttf") as FontFile
	if not _font:
		push_error("Menu: Font not found at res://assets/kenney/kenney-fonts/Kenney Future.ttf")

	_setup_ui()
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
	rules_label.text = "dig (left click)\ntowel flag (right click)\nnumbers count mines around a tile (0-6)\nclick a number whose flags are all placed to open the rest\nyou can only dig next to your land or a flag\npalms give wood\nchests and wrecks give gold\n\nTools:\nMetal detector (3 wood)\nParrot scout (2 wood)\nTowel of safety (5 wood)\n\n3 crew | Win by digging every safe tile"
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

	# Apply theme to all
	var theme := Theme.new()
	theme.set_default_font(_font)
	_apply_theme_to_all(_help_panel, theme)
	_apply_theme_to_all(_esc_panel, theme)
	_apply_theme_to_all(_esc_vbox, theme)

func _apply_theme_to_all(node: Node, theme: Theme) -> void:
	if node is Control:
		node.theme = theme
	for child in node.get_children():
		_apply_theme_to_all(child, theme)

func _hide_all() -> void:
	_help_panel.visible = false
	_esc_panel.visible = false

func show_help() -> void:
	_hide_all()
	_help_panel.visible = true
	help_requested.emit()

func show_esc_menu() -> void:
	_hide_all()
	_esc_panel.visible = true
	menu_requested.emit()

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
	if not _help_panel.visible and not _esc_panel.visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _help_panel.visible:
				_on_help_close_pressed()
			elif _esc_panel.visible:
				_on_resume_pressed()
		elif event.keycode == KEY_H:
			if _help_panel.visible:
				_on_help_close_pressed()
			else:
				show_help()
