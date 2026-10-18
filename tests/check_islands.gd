extends SceneTree
## Island pool check (director): the solver plays island 0 and every pool island with several seeds; islands it
## wins clearly less often than the original are reported for dropping (tools/make_islands.py --drop).
## Run: studio godot-script tests/check_islands.gd  -> one ISLAND line per island, then ISLANDS OK / ISLANDS DROP
const SEEDS := [1, 2, 3, 4, 5, 6]

func play(path: String, seed_value: int) -> Array:
	var b := Board.new(path)
	var solver := Solver.new()
	var moves := 0
	while not b.won and not b.lost and moves < 5000:
		var m: Dictionary = solver.next_move(b)
		if not Solver.apply(b, m, seed_value):
			break
		moves += 1
	return [b.won, b.mine_count, b.land.size(), b.crew]

func _init() -> void:
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/islands/index.json"))
	var entries: Array = [{"id": 0, "file": "res://data/island.json"}]
	entries.append_array(idx["islands"])
	var base_rate := -1.0
	var drop: Array = []
	for e in entries:
		var wins := 0
		var info: Array = []
		for s in SEEDS:
			info = play(e["file"], s)
			wins += 1 if info[0] else 0
		var rate := float(wins) / SEEDS.size()
		if int(e["id"]) == 0:
			base_rate = rate
		var flag := ""
		if int(e["id"]) != 0 and rate < base_rate - 0.34:   # two or more wins fewer than the original out of 6
			flag = "  <- drop"
			drop.append(int(e["id"]))
		print("ISLAND %02d land=%d mines=%d wins=%d/%d%s" % [int(e["id"]), info[2], info[1], wins, SEEDS.size(), flag])
	print("ISLANDS OK" if drop.is_empty() else "ISLANDS DROP " + ",".join(drop.map(func(x): return str(x))))
	quit()
