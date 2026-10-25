extends SceneTree
## Rules found in the human playtest (director, 2026-10-18). Run: tools/test.sh tests/test_playtest_rules.gd
## - chording counts skulls (mines that went off) as known mines, like towels
## - the metal detector: costs 3 wood and one turn; a mine gets a towel, a safe tile opens; refused moves change
##   nothing
## - (review, 2026-10-25) a win after a crew loss counts safe tiles only; a chord stops at the game-ending mine

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func inner_cell(b: Board) -> Vector2i:
	for c in b.land:
		if Hex.spiral(c, 4).all(func(x): return b.is_land(x)):
			return c
	return Vector2i(9999, 9999)


## Mines: the given cells plus a ring at distance 3 from the centre, which fences the flood fill in (with only a
## couple of mines the first click opens the whole island and wins).
func fenced(centre: Vector2i, extra: Array[Vector2i]) -> Board:
	var b := Board.new()
	var m: Array[Vector2i] = extra.duplicate()
	for c in b.land:
		if Hex.distance(c, centre) == 3:
			m.append(c)
	b.place_fixed(m, {})
	return b


func _hidden_safe(b: Board) -> int:
	var n := 0
	for c in b.land:
		if not b.mines.has(c) and not b.revealed.has(c):
			n += 1
	return n


func _init() -> void:
	var probe := Board.new()
	var centre := inner_cell(probe)
	check(centre != Vector2i(9999, 9999), "the island has an inner cell")
	var nbs: Array[Vector2i] = Hex.neighbors(centre)

	# --- chording with a towel and a skull: centre sees two mines (nbs[0], nbs[1])
	var two: Array[Vector2i] = [nbs[0], nbs[1]]
	var b := fenced(centre, two)
	b.reveal(centre)                      # lands on the 2 itself: a number, so nothing else opens
	check(b.revealed.has(centre) and b.number(centre) == 2, "centre shows 2")
	b.toggle_flag(nbs[0])                 # one towel, and the other mine opened as a player would: a skull
	var crew_before := b.crew
	b.reveal(nbs[1])
	check(b.exploded.has(nbs[1]) and b.crew == crew_before - 1, "second mine went off (skull, one crewmate)")
	check(b.flags_around(centre) == 2, "a towel and a skull are two known mines (got %d)" % b.flags_around(centre))
	var opened: Array[Vector2i] = b.chord(centre)
	check(not opened.is_empty(), "chord on the 2 opens tiles")
	for x in [nbs[2], nbs[3], nbs[4], nbs[5]]:
		check(b.revealed.has(x), "chord opened neighbour %s" % x)
	check(not b.exploded.has(nbs[0]) and b.flagged.has(nbs[0]), "the towelled mine stays shut")

	# --- metal detector on a mine: towel placed, 3 wood, one turn, no crew loss
	var one: Array[Vector2i] = [nbs[0]]
	var d := fenced(centre, one)
	d.reveal(centre)
	d.wood = 6
	var turns := d.turns
	var crew := d.crew
	check(d.use_detector(nbs[0]) == 1, "detector finds the mine (returns 1)")
	check(d.flagged.has(nbs[0]) and not d.revealed.has(nbs[0]), "the mine gets a towel and stays shut")
	check(d.wood == 3 and d.turns == turns + 1 and d.crew == crew, "3 wood, one turn, no crewmate lost")
	# on a safe tile: it opens (gains from what it opens may add wood back)
	var safe := nbs[3]
	var wood_before := d.wood
	check(d.use_detector(safe) == 0 and d.revealed.has(safe), "detector opens a safe tile (returns 0)")
	check(d.wood >= wood_before - 3 and d.wood <= wood_before - 3 + 20, "3 wood spent (plus gains)")
	# refused: no wood, or a tile out of reach: nothing changes
	var reachable := Vector2i(9999, 9999)
	var far := Vector2i(9999, 9999)
	for c in d.land:
		if d.revealed.has(c) or d.flagged.has(c):
			continue
		if d.can_reveal(c) and reachable == Vector2i(9999, 9999):
			reachable = c
		elif not d.can_reveal(c) and far == Vector2i(9999, 9999):
			far = c
	d.wood = 2
	check(reachable != Vector2i(9999, 9999) and d.use_detector(reachable) == -1 and not d.revealed.has(reachable)
		and d.wood == 2, "refused without 3 wood")
	d.wood = 5
	check(far != Vector2i(9999, 9999) and d.use_detector(far) == -1 and d.wood == 5, "refused out of reach, wood kept")

	# --- winning after a crew loss (review, 2026-10-25): the skull's cell is in `revealed`, and the win check counted
	# it as a safe tile: a win one tile early, or never when the last move opened two or more tiles
	var far_mine := Vector2i(9999, 9999)
	for c in probe.land:
		if Hex.distance(c, centre) > 6:
			far_mine = c
			break
	var zero := Vector2i(9999, 9999)   # next to nbs[0], two from the centre mine: a 0 that floods the island
	for c in Hex.neighbors(nbs[0]):
		if Hex.distance(c, centre) == 2 and Hex.distance(c, far_mine) > 1:
			zero = c
			break
	var two_mines: Array[Vector2i] = [centre, far_mine]
	var w := Board.new()
	w.place_fixed(two_mines, {})
	w.reveal(nbs[0])
	w.reveal(centre)                      # a skull: one crewmate lost
	check(w.crew == 2 and not w.won, "a mine went off, game on")
	w.reveal(zero)                        # one flood opens every other safe tile
	check(_hidden_safe(w) == 0 and w.won and not w.lost, "won when the last move opens many tiles after a loss")

	var e := Board.new()
	e.place_fixed(two_mines, {})
	e.reveal(nbs[0])
	e.reveal(centre)
	e.toggle_flag(nbs[2])                 # a towel on a safe tile keeps it out of the flood
	e.reveal(zero)
	check(_hidden_safe(e) == 1 and not e.won, "not won while a safe tile is still hidden (one skull)")
	e.toggle_flag(nbs[2])
	e.reveal(nbs[2])
	check(_hidden_safe(e) == 0 and e.won, "won once it is dug")

	# --- chording over wrong towels with the last crewmate: the first mine ends the game, the rest stays shut
	var lc := fenced(centre, two)          # centre shows 2: mines nbs[0], nbs[1]
	lc.reveal(centre)
	lc.toggle_flag(nbs[2])                 # two wrong towels: the chord is accepted and opens both mines
	lc.toggle_flag(nbs[3])
	lc.crew = 1
	lc.chord(centre)
	check(lc.lost and lc.crew == 0 and not lc.won, "the last crewmate lost: crew 0, lost, not won (crew %d)" % lc.crew)
	check(lc.exploded.size() == 1 and not lc.revealed.has(nbs[1]), "the chord stops at the game-ending mine")

	if fails == 0:
		print("ALL TESTS PASSED")
	quit()
