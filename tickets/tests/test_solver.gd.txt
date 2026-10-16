extends SceneTree
## Acceptance test for T05 (scripts/solver.gd). Run: tools/test.sh tests/test_solver.gd

const GAMES := 20
const MIN_WINS := 16

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	var wins := 0
	for g in GAMES:
		var b := Board.new()
		var s := Solver.new()
		var moves := 0
		var refused := 0
		while not b.won and not b.lost and moves < 1500:
			var m: Dictionary = s.next_move(b)
			if not Solver.apply(b, m, 1000 + g):
				refused += 1
				if refused > 3:
					break
			moves += 1
		check(b.won or b.lost, "game %d ended (moves %d, refused %d)" % [g, moves, refused])
		check(refused == 0, "game %d: %d refused moves" % [g, refused])
		if b.won:
			wins += 1
		print("game %d: %s in %d moves, %d turns, crew %d, gold %d, score %d" % [g, "WON" if b.won else "lost", moves, b.turns, b.crew, b.gold, b.score()])
	check(wins >= MIN_WINS, "won %d of %d (need %d)" % [wins, GAMES, MIN_WINS])
	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
