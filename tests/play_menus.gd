extends ProbeBase
## Menu keys and camera keys with real key presses (review, 2026-10-25): Esc and H close what they opened (the menu
## closed the panel, then main.gd saw the same key and opened it again); the help opened from the Esc menu goes back
## to it; camera keys and the wheel do nothing while a menu is open or a text field has the keyboard.
## Run: tools/probe.sh tests/play_menus.tscn 60 "MENUS OK" --skip-intro


func run() -> void:
	var menu: Menu = main.menu
	var rig: CameraRig = main.rig

	await press(KEY_ESCAPE)
	check(menu._esc_panel.visible and not main._playing, "Esc opens the Esc menu and pauses")
	await press(KEY_ESCAPE)
	check(not menu._esc_panel.visible and main._playing, "Esc closes it again and plays on")
	await press(KEY_H)
	check(menu._help_panel.visible and not main._playing, "H opens the help")
	await press(KEY_H)
	check(not menu._help_panel.visible and main._playing, "H closes it again")
	await press(KEY_H)
	await press(KEY_ESCAPE)
	check(not menu._help_panel.visible and not menu._esc_panel.visible and main._playing, "Esc closes the help")

	# the help opened from the Esc menu: closing it goes back to the menu, still paused
	await press(KEY_ESCAPE)
	var help_btn := _button(menu._esc_vbox, "Help")
	check(help_btn != null, "the Esc menu has a Help button")
	if help_btn:
		await click(help_btn.get_global_rect().get_center())
	check(menu._help_panel.visible, "Help button opens the help")
	await press(KEY_ESCAPE)
	check(menu._esc_panel.visible and not menu._help_panel.visible and not main._playing,
		"closing that help returns to the Esc menu")

	# camera keys and the wheel: not while the menu is open
	var yaw := rig.yaw
	var dist := rig.distance
	await hold(KEY_Q, 0.3)
	await click(Vector2(300, 540), MOUSE_BUTTON_WHEEL_UP)
	check(is_equal_approx(rig.yaw, yaw) and is_equal_approx(rig.distance, dist),
		"no turn or zoom behind the menu (yaw %.1f -> %.1f, distance %.2f -> %.2f)" % [yaw, rig.yaw, dist, rig.distance])
	await press(KEY_ESCAPE)
	check(not menu._esc_panel.visible and main._playing, "Esc from the menu plays on")
	await hold(KEY_Q, 0.3)
	check(not is_equal_approx(rig.yaw, yaw), "Q turns the camera while playing (yaw %.1f -> %.1f)" % [yaw, rig.yaw])

	# typing in a text field (the nickname on the end panel) moves nothing
	var edit := LineEdit.new()
	main.hud.add_child(edit)
	edit.grab_focus()
	await frames(2)
	yaw = rig.yaw
	var target := rig.target
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_MINUS]:
		await hold(k, 0.15)
	check(is_equal_approx(rig.yaw, yaw) and rig.target.is_equal_approx(target) and is_equal_approx(rig.distance, dist),
		"typing W A S D Q E - in a text field leaves the camera alone")
	check(edit.text.length() >= 6, "the text field got the keys (%s)" % edit.text)
	edit.queue_free()

	print("MENUS OK" if fails == 0 else "MENUS FAILED: %d" % fails)


func _button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null
