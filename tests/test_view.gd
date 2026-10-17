extends SceneTree
## Acceptance test for T06 (scripts/board_view.gd). Run: tools/test.sh tests/test_view.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func cell(v: BoardView, c: Vector2i) -> Node3D:
	return v.get_node_or_null("Cell_%d_%d" % [c.x, c.y]) as Node3D


func _init() -> void:
	var b := Board.new()
	var centre := Vector2i(9999, 9999)
	for c in b.land:
		if Hex.spiral(c, 4).all(func(x): return b.is_land(x)):
			centre = c
			break
	var m: Array[Vector2i] = []
	for c in b.land:
		if Hex.distance(c, centre) == 3:
			m.append(c)
	var chest_cell: Vector2i = Hex.spiral(centre, 1)[2]
	b.place_fixed(m, {chest_cell: 20})
	b.reveal(centre)
	var ring3: Array = Hex.ring(centre, 3)
	b.toggle_flag(ring3[0])
	b.reveal(ring3[5])            # a mine: exploded, crew 2
	b.peeked[ring3[8]] = 2

	var v := BoardView.new()
	root.add_child(v)
	v.build(b)
	v.refresh(b)

	check(v.cells.size() == b.land.size(), "one cell node per land cell (%d)" % v.cells.size())
	var waters := 0
	for ch in v.get_children():
		if ch.name.begins_with("Water_"):
			waters += 1
	check(waters == b.water.size(), "water tiles %d of %d" % [waters, b.water.size()])
	for c in [centre, ring3[0], ring3[5], ring3[8]]:
		var n := cell(v, c)
		check(n != null, "node Cell_%d_%d" % [c.x, c.y])
		if n == null:
			continue
		for part in ["Tile", "Props", "Fog", "Dug", "Number", "Peek", "Flag", "Skeleton", "Chest"]:
			check(n.get_node_or_null(part) != null, "Cell has %s" % part)
		check(n.position.distance_to(Hex.to_world(c) + Vector3(0, n.position.y, 0)) < 0.001, "cell placed at Hex.to_world")
	var nc := cell(v, centre)
	check(absf(nc.position.y) < 0.001, "revealed cell at y 0")
	check(not nc.get_node("Number").visible, "zero cell shows no number")
	check(nc.get_node("Dug").visible and not nc.get_node("Tile").visible, "revealed cell: sand (Dug) instead of the terrain tile")
	var border: Vector2i = Hex.ring(centre, 2)[0]
	var nb := cell(v, border)
	var lbl := nb.get_node("Number") as Label3D
	check(lbl.visible and lbl.text == str(b.number(border)), "number label shows %d" % b.number(border))
	var hid := cell(v, ring3[1])
	check(absf(hid.position.y - BoardView.HIDDEN_Y) < 0.001, "hidden cell raised")
	check(not hid.get_node("Fog").visible, "hidden-but-visible cell has no fog")
	check(hid.get_node("Tile").visible and not hid.get_node("Dug").visible, "hidden cell shows its terrain tile")
	var fogc := cell(v, Hex.ring(centre, 4)[12])
	check(fogc.get_node("Fog").visible, "fog beyond the territory")
	check(cell(v, ring3[0]).get_node("Flag").visible and not hid.get_node("Flag").visible, "flag only on the flagged cell")
	check(cell(v, ring3[5]).get_node("Skeleton").visible, "skeleton on the exploded cell")
	check(not cell(v, ring3[5]).get_node("Number").visible, "no number on an exploded cell")
	check(cell(v, chest_cell).get_node("Chest").visible, "chest on the revealed chest cell")
	var pk := cell(v, ring3[8]).get_node("Peek") as Label3D
	check(pk.visible and pk.text == "2", "parrot peek shown")
	for c in b.land:
		if b.land[c] == "palm":
			check(cell(v, c).get_node("Props").get_child_count() >= 1, "palm cell has a palm")
			break
	v.set_numbers_billboard(true)
	check((nb.get_node("Number") as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED, "billboard on")
	v.set_numbers_billboard(false)
	check((nb.get_node("Number") as Label3D).billboard == BaseMaterial3D.BILLBOARD_DISABLED, "billboard off")
	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
