extends SceneTree
## Acceptance test for T02 (scripts/board.gd core). Run: tools/test.sh tests/test_board_core.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func safe_zone(first: Vector2i) -> Dictionary:
	var z := {first: true}
	for n in Hex.neighbors(first):
		z[n] = true
	return z


func _init() -> void:
	var b := Board.new()
	check(b.land.size() >= 190 and b.land.size() <= 220, "island loaded: %d land cells" % b.land.size())
	check(b.water.size() > 0, "water loaded")
	var first: Vector2i = b.land.keys()[b.land.size() / 2]
	check(b.is_land(first) and not b.is_land(Vector2i(99, 99)), "is_land")

	# placement: counts, safe zone, chests, determinism
	b.place(first, 7)
	check(b.placed, "placed flag")
	check(b.mines.size() == Board.MINES, "42 mines, got %d" % b.mines.size())
	check(b.chests.size() == Board.CHESTS, "12 chests, got %d" % b.chests.size())
	var zone := safe_zone(first)
	for m in b.mines:
		check(b.is_land(m), "mine on land %s" % m)
		check(not zone.has(m), "no mine in the landing zone %s" % m)
	for ch in b.chests:
		check(not b.mines.has(ch) and b.land[ch] != "wreck" and not zone.has(ch), "chest placement %s" % ch)
		check(b.chests[ch] >= 10 and b.chests[ch] <= 30, "chest gold %d" % b.chests[ch])
	var b2 := Board.new()
	b2.place(first, 7)
	check(b2.mines.keys().size() == b.mines.keys().size() and b2.mines.keys().all(func(m): return b.mines.has(m)), "same seed, same mines")
	var b3 := Board.new()
	b3.place(first, 8)
	check(not b3.mines.keys().all(func(m): return b.mines.has(m)), "different seed, different mines")

	# numbers
	for c in b.land:
		var n := 0
		for nb in Hex.neighbors(c):
			if b.mines.has(nb):
				n += 1
		check(b.number(c) == n, "number at %s" % c)

	# reveal on an unplaced board places with the seed, and the first reveal is safe and opens the zone
	var b4 := Board.new()
	var got := b4.reveal(first, 7)
	check(b4.placed and b4.mines.size() == Board.MINES, "first reveal places mines")
	check(got.size() >= 7, "first reveal opens at least the landing zone (got %d)" % got.size())
	for c in got:
		check(not b4.mines.has(c), "first reveal is safe at %s" % c)
		check(b4.revealed.has(c), "returned cells are revealed")
	check(b4.reveal(first).is_empty(), "revealing again returns nothing")

	# flood fill on a hand-made board: one mine, everything else connected
	var b5 := Board.new()
	var cells: Array = b5.land.keys()
	var mine: Vector2i = cells[0]
	var mines: Array[Vector2i] = [mine]
	b5.place_fixed(mines, {})
	var far: Vector2i = cells[cells.size() - 1]
	var opened := b5.reveal(far)
	check(not b5.revealed.has(mine), "flood fill never reveals a mine")
	check(opened.size() == b5.land.size() - 1, "flood fill opens all safe land (%d of %d)" % [opened.size(), b5.land.size() - 1])
	# a flag stops the flood fill and is never revealed
	var b6 := Board.new()
	b6.place_fixed(mines, {})
	var flag_cell: Vector2i = cells[cells.size() / 2]
	b6.flagged[flag_cell] = true
	b6.reveal(far)
	check(not b6.revealed.has(flag_cell), "flagged cell not revealed by flood fill")
	check(b6.reveal(flag_cell).is_empty(), "revealing a flagged cell does nothing")
	# a mine reveal explodes, no flood fill
	var b7 := Board.new()
	b7.place_fixed(mines, {})
	var boom := b7.reveal(mine)
	check(boom.size() == 1 and b7.exploded.has(mine) and b7.revealed.has(mine), "mine reveal explodes")
	check(b7.reveal(Vector2i(99, 99)).is_empty(), "water/off-board reveal does nothing")

	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
