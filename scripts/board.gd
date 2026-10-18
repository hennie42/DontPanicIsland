class_name Board
extends RefCounted

const MINES := 42
const CHESTS := 12

var land: Dictionary = {}        # Vector2i -> String terrain
var water: Array[Vector2i] = []
var mines: Dictionary = {}       # Vector2i -> true, only the mine cells
var chests: Dictionary = {}      # Vector2i -> int gold, only the chest cells
var revealed: Dictionary = {}    # Vector2i -> true
var flagged: Dictionary = {}     # Vector2i -> true
var placed: bool = false         # mines placed (happens on the first reveal)
var exploded: Dictionary = {}    # Vector2i -> true: mine cells that were revealed (a crew loss, see later tickets)
var turns: int = 0

# T04 new variables
var crew: int = 3
var wood: int = 3
var gold: int = 0
var towel: bool = false          # towel of safety: the next mine costs no crewmate
var peeked: Dictionary = {}      # Vector2i -> int: numbers learned with the parrot scout
var lost: bool = false           # crew reached 0
var won: bool = false            # every safe land cell revealed

func _init(island_path: String = "res://data/island.json") -> void:
	var file := FileAccess.open(island_path, FileAccess.READ)
	if not file:
		return
	var json_string: String = file.get_as_text()
	var json_data: Dictionary = JSON.parse_string(json_string)
	if not json_data:
		return

	for entry in json_data["land"]:
		var c := Vector2i(entry["q"], entry["r"])
		land[c] = entry["terrain"]

	for entry in json_data["water"]:
		water.append(Vector2i(entry["q"], entry["r"]))

func is_land(c: Vector2i) -> bool:
	return land.has(c)

func number(c: Vector2i) -> int:
	var n := 0
	for nb in Hex.neighbors(c):
		if mines.has(nb):
			n += 1
	return n

func place(first: Vector2i, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var zone := {first: true}
	for nb in Hex.neighbors(first):
		zone[nb] = true

	var land_cells := land.keys()

	var available_for_mines: Array[Vector2i] = []
	for c in land_cells:
		if not zone.has(c):
			available_for_mines.append(c)

	# Shuffle available_for_mines using rng
	for i in range(available_for_mines.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := available_for_mines[i]
		available_for_mines[i] = available_for_mines[j]
		available_for_mines[j] = tmp

	# Pick MINES
	for i in range(MINES):
		var m := available_for_mines[i]
		mines[m] = true

	# For chests
	var available_for_chests: Array[Vector2i] = []
	for c in land_cells:
		if not zone.has(c) and not mines.has(c) and land[c] != "wreck":
			available_for_chests.append(c)

	# Shuffle available_for_chests using rng
	for i in range(available_for_chests.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := available_for_chests[i]
		available_for_chests[i] = available_for_chests[j]
		available_for_chests[j] = tmp

	# Pick CHESTS
	for i in range(CHESTS):
		var ch := available_for_chests[i]
		chests[ch] = rng.randi_range(10, 30)

	placed = true

func place_fixed(mine_cells: Array[Vector2i], chest_gold: Dictionary) -> void:
	mines.clear()
	for m in mine_cells:
		mines[m] = true
	chests.clear()
	for ch in chest_gold:
		chests[ch] = chest_gold[ch]
	placed = true

func is_visible(c: Vector2i) -> bool:
	if not is_land(c):
		return false
	if revealed.is_empty():
		return true
	if revealed.has(c) or flagged.has(c):
		return true
	for nb in Hex.neighbors(c):
		if revealed.has(nb) or flagged.has(nb):
			return true
	return false

func can_reveal(c: Vector2i) -> bool:
	if not is_land(c) or flagged.has(c):
		return false
	if revealed.is_empty():
		return true
	if revealed.has(c):
		return false
	for nb in Hex.neighbors(c):
		if revealed.has(nb) or flagged.has(nb):
			return true
	return false

func toggle_flag(c: Vector2i) -> bool:
	if won or lost: return false
	if revealed.is_empty():
		return false
	if not is_visible(c) or revealed.has(c):
		return false

	if flagged.has(c):
		flagged.erase(c)
	else:
		flagged[c] = true
	return true

## Known mines around c: towels plus mines that already went off (skulls). Chording compares the number with this,
## so a 2 next to one towel and one skull opens the rest (counting towels only refused it).
func flags_around(c: Vector2i) -> int:
	var count := 0
	for nb in Hex.neighbors(c):
		if flagged.has(nb) or exploded.has(nb):
			count += 1
	return count

func chord(c: Vector2i) -> Array[Vector2i]:
	if won or lost: return []
	if not revealed.has(c):
		return []

	var n := number(c)
	if n > 0 and flags_around(c) == n:
		var newly_revealed: Array[Vector2i] = []
		for nb in Hex.neighbors(c):
			if is_land(nb) and not revealed.has(nb) and not flagged.has(nb):
				newly_revealed.append_array(_open(nb))

		if not newly_revealed.is_empty():
			turns += 1
		return newly_revealed
	return []

func _open(c: Vector2i) -> Array[Vector2i]:
	var newly_revealed: Array[Vector2i] = []
	if not is_land(c) or revealed.has(c) or flagged.has(c):
		return newly_revealed

	revealed[c] = true
	newly_revealed.append(c)

	if mines.has(c):
		exploded[c] = true
		if towel:
			towel = false
		else:
			crew -= 1
			if crew <= 0:
				lost = true
		return newly_revealed

	# c is safe
	_apply_gains(c)

	if number(c) == 0:
		var queue: Array[Vector2i] = [c]
		while queue.size() > 0:
			var curr: Vector2i = queue.pop_front()
			for nb in Hex.neighbors(curr):
				if is_land(nb) and not revealed.has(nb) and not flagged.has(nb) and not mines.has(nb):
					revealed[nb] = true
					newly_revealed.append(nb)
					_apply_gains(nb)
					if number(nb) == 0:
						queue.append(nb)

	_check_win()
	return newly_revealed

func _apply_gains(c: Vector2i) -> void:
	if land[c] == "palm":
		wood += 1
	elif land[c] == "wreck":
		gold += 50
		wood += 2

	if chests.has(c):
		gold += chests[c]

func _check_win() -> void:
	if revealed.size() == (land.size() - mines.size()):
		won = true

func reveal(c: Vector2i, seed_value: int = 0) -> Array[Vector2i]:
	if won or lost: return []
	if not placed:
		place(c, seed_value)

	if not can_reveal(c):
		return []

	var newly_revealed = _open(c)
	if not newly_revealed.is_empty():
		turns += 1
	return newly_revealed

func use_detector(c: Vector2i) -> int:
	if won or lost: return -1
	if not placed or not can_reveal(c) or wood < 3:
		return -1

	turns += 1
	wood -= 3
	if mines.has(c):
		flagged[c] = true
		return 1

	_open(c)
	return 0

func use_parrot(c: Vector2i) -> int:
	if won or lost: return -1
	if not placed or not is_visible(c) or revealed.has(c) or wood < 2:
		return -1

	turns += 1
	wood -= 2
	var val := number(c)
	peeked[c] = val
	return val

func buy_towel() -> bool:
	if won or lost: return false
	if towel or wood < 5:
		return false

	wood -= 5
	towel = true
	turns += 1
	return true

func score() -> int:
	return gold + crew * 100 + max(0, 400 - 2 * turns)

static func load_best(path: String = "user://best.json") -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	var json_string := file.get_as_text()
	var json_data: Variant = JSON.parse_string(json_string)
	if json_data and json_data.has("best"):
		return json_data["best"]
	return 0

static func save_best(value: int, path: String = "user://best.json") -> int:
	var current_best := load_best(path)
	if value > current_best:
		var file := FileAccess.open(path, FileAccess.WRITE)
		var json_data := {"best": value}
		file.store_string(JSON.stringify(json_data))
		return value
	return current_best
