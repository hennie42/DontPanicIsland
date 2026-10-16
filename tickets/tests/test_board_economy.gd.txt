extends SceneTree
## Acceptance test for T04 (crew, resources, tools, win/lose, score). Run: tools/test.sh tests/test_board_economy.gd

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


func ring_board(centre: Vector2i, chest_gold: Dictionary = {}) -> Board:
	var b := Board.new()
	var m: Array[Vector2i] = []
	for c in b.land:
		if Hex.distance(c, centre) == 3:
			m.append(c)
	b.place_fixed(m, chest_gold)
	return b


func first_of(b: Board, terrain: String) -> Vector2i:
	for c in b.land:
		if b.land[c] == terrain:
			return c
	return Vector2i(9999, 9999)


func _init() -> void:
	var probe := Board.new()
	var centre := inner_cell(probe)
	check(probe.crew == 3 and probe.wood == 3 and probe.gold == 0 and not probe.towel, "start values")

	# gains: open the inner region; count palms/wrecks/chests in it
	var region: Array = Hex.spiral(centre, 2)
	var chest_cell: Vector2i = region[3]
	var b := ring_board(centre, {chest_cell: 25})
	var palms := 0
	var wrecks := 0
	for c in region:
		if b.land[c] == "palm":
			palms += 1
		elif b.land[c] == "wreck":
			wrecks += 1
	b.reveal(centre)
	check(b.wood == 3 + palms + 2 * wrecks, "wood from palms/wrecks: %d, expected %d" % [b.wood, 3 + palms + 2 * wrecks])
	check(b.gold == 25 + 50 * wrecks, "gold from the chest: %d" % b.gold)

	# no mines: one reveal floods the whole island -> all 3 wrecks (150 gold, +6 wood) and every palm
	var bw := Board.new()
	bw.place_fixed([] as Array[Vector2i], {})
	var all_palms := 0
	for c in bw.land:
		if bw.land[c] == "palm":
			all_palms += 1
	bw.reveal(bw.land.keys()[0])
	check(bw.gold == 150 and bw.wood == 3 + all_palms + 6, "wrecks + palms: gold %d wood %d" % [bw.gold, bw.wood])
	check(bw.won, "won after opening everything")

	# mines cost crew; towel saves one; 0 crew = lost
	var bm := ring_board(centre)
	bm.reveal(centre)
	var ring3: Array = Hex.ring(centre, 3)
	bm.wood = 10
	check(bm.buy_towel() and bm.towel and bm.wood == 5, "buy towel for 5 wood")
	check(not bm.buy_towel(), "only one towel at a time")
	bm.reveal(ring3[0])
	check(bm.crew == 3 and not bm.towel and bm.exploded.has(ring3[0]), "towel absorbs the first mine")
	bm.reveal(ring3[1])
	check(bm.crew == 2, "a mine costs a crewmate")
	bm.reveal(ring3[2])
	bm.reveal(ring3[3])
	check(bm.crew == 0 and bm.lost, "three mines without a towel = lost")
	var t := bm.turns
	check(bm.reveal(ring3[4]).is_empty() and bm.turns == t, "no moves after losing")
	check(bm.use_parrot(ring3[5]) == -1 and not bm.toggle_flag(ring3[5]), "no tools or flags after losing")

	# detector: mine -> flagged, safe -> opened; costs and turns; refused when invalid
	var bd := ring_board(centre)
	bd.reveal(centre)
	bd.wood = 6
	var t0 := bd.turns
	check(bd.use_detector(ring3[0]) == 1 and bd.flagged.has(ring3[0]) and bd.crew == 3, "detector finds a mine and flags it")
	check(bd.wood == 3 and bd.turns == t0 + 1, "detector costs 3 wood and a turn")
	var fog: Vector2i = Hex.ring(centre, 4)[12]    # the far side, not next to the flag just placed
	check(bd.use_detector(fog) == -1 and bd.wood == 3, "detector refused in the fog")
	var bs := Board.new()
	bs.place_fixed([] as Array[Vector2i], {})
	var start: Vector2i = bs.land.keys()[0]
	bs.revealed[start] = true
	bs.wood = 3
	var nb: Vector2i = Vector2i(9999, 9999)
	for n in Hex.neighbors(start):
		if bs.is_land(n):
			nb = n
			break
	check(bs.use_detector(nb) == 0 and bs.revealed.has(nb), "detector opens a safe cell")
	check(bs.use_detector(nb) == -1, "detector refused without wood / on revealed")

	# parrot: number of a visible hidden cell, 2 wood, a turn
	var bp := ring_board(centre)
	bp.reveal(centre)
	bp.wood = 2
	var t1 := bp.turns
	var target: Vector2i = ring3[0]
	check(bp.use_parrot(target) == bp.number(target) and bp.peeked.get(target, -9) == bp.number(target), "parrot peeks the number")
	check(bp.wood == 0 and bp.turns == t1 + 1 and not bp.revealed.has(target), "parrot costs 2 wood and a turn, reveals nothing")
	check(bp.use_parrot(ring3[1]) == -1, "parrot refused without wood")

	# winning: one mine; reveal everything else
	var bwin := Board.new()
	var only_mine: Vector2i = bwin.land.keys()[0]
	bwin.place_fixed([only_mine] as Array[Vector2i], {})
	bwin.reveal(bwin.land.keys()[bwin.land.size() - 1])
	check(bwin.won and not bwin.lost, "won when all safe land is revealed")
	check(bwin.score() == bwin.gold + 3 * 100 + maxi(0, 400 - 2 * bwin.turns), "score formula")
	check(not bwin.toggle_flag(only_mine), "no flags after winning")

	# best score
	var path := "user://test_best_%d.json" % Time.get_ticks_usec()
	check(Board.load_best(path) == 0, "no best yet")
	check(Board.save_best(300, path) == 300 and Board.save_best(200, path) == 300, "best keeps the higher score")
	check(Board.load_best(path) == 300, "best persisted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
