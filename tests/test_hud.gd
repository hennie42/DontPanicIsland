extends SceneTree
## Acceptance test for T08 (scripts/hud.gd). Run: tools/test.sh tests/test_hud.gd

var fails := 0
var got_signal := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _on_tool(t: String) -> void:
	got_signal = t


func _init() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	hud.tool_selected.connect(_on_tool)
	var b := Board.new()
	b.wood = 2
	b.gold = 120
	b.turns = 14
	hud.update_from(b)
	var crew := hud.find_child("Crew", true, false) as Label
	var wood := hud.find_child("Wood", true, false) as Label
	var gold := hud.find_child("Gold", true, false) as Label
	var turns := hud.find_child("Turns", true, false) as Label
	check(crew != null and wood != null and gold != null and turns != null, "labels Crew/Wood/Gold/Turns exist")
	if crew != null:
		check(crew.text == "Crew 3" and wood.text == "Wood 2" and gold.text == "Gold 120" and turns.text == "Turn 14", "label texts: %s / %s / %s / %s" % [crew.text, wood.text, gold.text, turns.text])
	var det := hud.find_child("Detector", true, false) as Button
	var par := hud.find_child("Parrot", true, false) as Button
	var tow := hud.find_child("Towel", true, false) as Button
	check(det != null and par != null and tow != null, "tool buttons exist")
	if det != null:
		check(det.disabled and not par.disabled and tow.disabled, "affordability with 2 wood")
		b.wood = 6
		hud.update_from(b)
		check(not det.disabled and not par.disabled and not tow.disabled, "affordability with 6 wood")
		det.pressed.emit()
		check(hud.selected_tool == "detector" and got_signal == "detector", "detector selected (%s)" % hud.selected_tool)
		hud.select_tool("detector")
		check(hud.selected_tool == "", "pressing the same tool again deselects")
		hud.select_tool("parrot")
		b.wood = 1
		hud.update_from(b)
		check(hud.selected_tool == "", "an unaffordable selected tool is dropped")
		b.wood = 9
		b.towel = true
		hud.update_from(b)
		check(tow.disabled, "towel disabled while holding one")
		check(crew.text.ends_with(" + towel"), "towel shown next to the crew")
	check(hud.find_child("Hint", true, false) is Label, "hint label")
	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
