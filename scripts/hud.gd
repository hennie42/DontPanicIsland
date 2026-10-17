class_name Hud
extends CanvasLayer

signal tool_selected(tool: String)      # "detector", "parrot", "towel", or "" (back to digging)
signal help_requested                 # button in bottom-left
signal button_clicked                 # any button click

var selected_tool: String = ""

var _root: Control
var _crew_label: Label
var _wood_label: Label
var _gold_label: Label
var _turns_label: Label
var _detector_button: Button
var _parrot_button: Button
var _towel_button: Button
var _hint_label: Label
var _help_button: Button

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var theme := Theme.new()
	var font := load("res://assets/kenney/kenney-fonts/Kenney Future.ttf") as FontFile
	if not font:
		push_error("HUD: Font not found at res://assets/kenney/kenney-fonts/Kenney Future.ttf")

	theme.set_default_font(font)

	# Style for labels and buttons
	var label_style := StyleBoxFlat.new()
	label_style.bg_color = Color(0, 0, 0, 0.4)
	label_style.set_corner_radius_all(5)
	label_style.set_content_margin_all(5)

	# Top-left panel
	var top_left_panel := PanelContainer.new()
	top_left_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_left_panel.add_theme_stylebox_override("panel", label_style)
	_root.add_child(top_left_panel)

	var top_left_vbox := VBoxContainer.new()
	top_left_panel.add_child(top_left_vbox)

	_crew_label = Label.new()
	_crew_label.name = "Crew"
	top_left_vbox.add_child(_crew_label)

	_wood_label = Label.new()
	_wood_label.name = "Wood"
	top_left_vbox.add_child(_wood_label)

	_gold_label = Label.new()
	_gold_label.name = "Gold"
	top_left_vbox.add_child(_gold_label)

	_turns_label = Label.new()
	_turns_label.name = "Turns"
	top_left_vbox.add_child(_turns_label)

	# Bottom-centre panel
	var bottom_centre_panel := PanelContainer.new()
	bottom_centre_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_centre_panel.add_theme_stylebox_override("panel", label_style)
	_root.add_child(bottom_centre_panel)

	var bottom_centre_hbox := HBoxContainer.new()
	bottom_centre_panel.add_child(bottom_centre_hbox)

	_detector_button = Button.new()
	_detector_button.name = "Detector"
	_detector_button.text = "Metal detector (3)"
	_detector_button.toggle_mode = true
	_detector_button.pressed.connect(func():
		select_tool("detector")
		button_clicked.emit()
	)
	bottom_centre_hbox.add_child(_detector_button)

	_parrot_button = Button.new()
	_parrot_button.name = "Parrot"
	_parrot_button.text = "Parrot scout (2)"
	_parrot_button.toggle_mode = true
	_parrot_button.pressed.connect(func():
		select_tool("parrot")
		button_clicked.emit()
	)
	bottom_centre_hbox.add_child(_parrot_button)

	_towel_button = Button.new()
	_towel_button.name = "Towel"
	_towel_button.text = "Towel of safety (5)"
	_towel_button.pressed.connect(func():
		select_tool("towel")
		button_clicked.emit()
	)
	bottom_centre_hbox.add_child(_towel_button)

	# Bottom-left panel
	var bottom_left_panel := PanelContainer.new()
	bottom_left_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left_panel.add_theme_stylebox_override("panel", label_style)
	_root.add_child(bottom_left_panel)

	var bottom_left_hbox := HBoxContainer.new()
	bottom_left_panel.add_child(bottom_left_hbox)

	_help_button = Button.new()
	_help_button.name = "HelpButton"
	_help_button.text = "?"
	_help_button.custom_minimum_size = Vector2(40, 40)
	_help_button.pressed.connect(func():
		help_requested.emit()
		button_clicked.emit()
	)
	bottom_left_hbox.add_child(_help_button)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "Left click: dig   Right click: towel flag   H: help   Esc: menu"
	bottom_left_hbox.add_child(_hint_label)

	# Apply theme and outline after all children are added
	_apply_theme_to_all(_root, theme)
	_apply_outline_to_all(_root)

func _apply_theme_to_all(node: Node, theme: Theme) -> void:
	if node is Control:
		node.theme = theme
	for child in node.get_children():
		_apply_theme_to_all(child, theme)

func _apply_outline_to_all(node: Node) -> void:
	if node is Label:
		node.add_theme_color_override("font_outline_color", Color.BLACK)
		node.add_theme_constant_override("outline_size", 4)
	for child in node.get_children():
		_apply_outline_to_all(child)

func update_from(b: Board) -> void:
	_crew_label.text = "Crew %d%s" % [b.crew, " + towel" if b.towel else ""]
	_wood_label.text = "Wood %d" % b.wood
	_gold_label.text = "Gold %d" % b.gold
	_turns_label.text = "Turn %d" % b.turns

	# Disable buttons if wood is too low
	_detector_button.disabled = b.wood < 3
	_parrot_button.disabled = b.wood < 2
	_towel_button.disabled = b.wood < 5 or b.towel

	# If selected tool can no longer be afforded, un-press it
	if selected_tool == "detector" and b.wood < 3:
		_deselect_tools()
	elif selected_tool == "parrot" and b.wood < 2:
		_deselect_tools()

	# Update button visual state for selected tool
	_detector_button.button_pressed = (selected_tool == "detector")
	_parrot_button.button_pressed = (selected_tool == "parrot")

func select_tool(tool: String) -> void:
	if tool == selected_tool:
		selected_tool = ""
	else:
		selected_tool = tool

	tool_selected.emit(selected_tool)

func _deselect_tools() -> void:
	selected_tool = ""
	_detector_button.button_pressed = false
	_parrot_button.button_pressed = false
