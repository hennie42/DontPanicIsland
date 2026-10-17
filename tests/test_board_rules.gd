extends SceneTree
## Acceptance test for T03 (territory, flags, chording, turns). Run: tools/test.sh tests/test_board_rules.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


## A board with mines on every land cell at hex distance exactly 3 from `centre`: revealing `centre` opens a
## zero region (distance 0-1) plus its border (distance 2), and nothing beyond the mine ring.
func ring_board(centre: Vector2i) -> Board:
	var b := Board.new()
	var m: Array[Vector2i] = []
	for c in b.land:
		if Hex.distance(c, centre) == 3:
			m.append(c)
	b.place_fixed(m, {})
	return b


func inner_cell(b: Board) -> Vector2i:
	# a land cell whose whole radius-4 neighbourhood is land (exists on this island)
	for c in b.land:
		if Hex.spiral(c, 4).all(func(x): return b.is_land(x)):
			return c
	return Vector2i(9999, 9999)


func _init() -> void:
	var probe := Board.new()
	var centre := inner_cell(probe)
	check(probe.is_land(centre), "the island has a cell with land all around (radius 4)")

	# before placement: everything visible and revealable, no flags
	check(probe.is_visible(centre) and probe.can_reveal(centre), "unplaced: visible and revealable")
	check(not probe.toggle_flag(centre), "no flags before the landing")

	var b := ring_board(centre)
	var opened := b.reveal(centre)
	check(b.turns == 1, "one reveal = one turn (got %d)" % b.turns)
	var exp_open := 0
	for c in b.land:
		if Hex.distance(c, centre) <= 2:
			exp_open += 1
	check(opened.size() == exp_open, "opened the inner region: %d, expected %d" % [opened.size(), exp_open])
	# territory: distance-3 cells (the mine ring) are visible and revealable; distance 4 is fog
	var d3: Vector2i = Hex.ring(centre, 3)[0]
	var d4: Vector2i = Hex.ring(centre, 4)[0]
	check(b.is_visible(d3) and b.can_reveal(d3), "next to territory: visible + revealable")
	check(not b.is_visible(d4) and not b.can_reveal(d4), "beyond territory: fog, not revealable")
	check(b.reveal(d4).is_empty() and b.turns == 1, "revealing in the fog does nothing and costs no turn")
	check(not b.toggle_flag(d4), "no flag in the fog")
	check(not b.can_reveal(centre), "a revealed cell is not revealable")

	# flags: toggle on a visible hidden cell, block reveal, free
	check(b.toggle_flag(d3) and b.flagged.has(d3), "flag placed")
	check(not b.can_reveal(d3) and b.reveal(d3).is_empty(), "a flagged cell can't be revealed")
	check(b.turns == 1, "flags cost no turn")
	# a flag extends the reach: the fog cell behind a flagged ring cell becomes visible and revealable
	var behind: Vector2i = Vector2i(9999, 9999)
	for n in Hex.neighbors(d3):
		if Hex.distance(n, centre) == 4 and b.is_land(n):
			behind = n
	check(b.is_visible(behind) and b.can_reveal(behind), "a flag extends the reach")
	check(b.toggle_flag(d3) and not b.flagged.has(d3), "flag removed")
	check(not b.can_reveal(behind), "reach shrinks again when the flag is removed")
	check(not b.toggle_flag(centre), "no flag on a revealed cell")

	# chording: a distance-2 cell touches mines at distance 3; flag them all, chord opens nothing new (all
	# neighbours are revealed or flagged) -> no turn; with one flag missing -> chord refuses
	var border: Vector2i = Hex.ring(centre, 2)[0]
	var ms: Array[Vector2i] = []
	for n in Hex.neighbors(border):
		if b.mines.has(n):
			ms.append(n)
	check(b.number(border) == ms.size() and ms.size() > 0, "border number counts the ring mines")
	for i in ms.size() - 1:
		b.toggle_flag(ms[i])
	check(b.flags_around(border) == ms.size() - 1, "flags_around")
	check(b.chord(border).is_empty(), "chord refuses when flags != number")
	b.toggle_flag(ms[ms.size() - 1])
	var t := b.turns
	var ch := b.chord(border)
	check(ch.is_empty() and b.turns == t, "chord with nothing left to open: empty, no turn")

	# chording that opens cells: a board with one mine next to the centre
	# chording that opens cells: one mine next to the centre; territory = just the centre (number 1)
	var m2: Array[Vector2i] = [centre + Hex.DIRS[0]]
	var b3 := Board.new()
	b3.place_fixed(m2, {})
	b3.revealed[centre] = true                     # hand-set territory: just the centre
	check(b3.number(centre) == 1, "centre number 1")
	b3.toggle_flag(m2[0])
	var got := b3.chord(centre)
	check(not got.is_empty() and b3.turns == 1, "chord opens the other neighbours as one turn")
	for n in Hex.neighbors(centre):
		if n != m2[0] and b3.is_land(n):
			check(b3.revealed.has(n), "chord revealed %s" % n)
	check(not b3.revealed.has(m2[0]) and b3.exploded.is_empty(), "chord never opens a flagged mine")

	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
