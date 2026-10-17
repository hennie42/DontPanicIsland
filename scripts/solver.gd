class_name Solver
extends RefCounted
## The autopilot bot (T05). It plays a [Board] using only its public API; it
## never reads `b.mines` or `b.chests`. Every move returned by `next_move` is
## one the board will accept (so `apply` always changes the board).

## Set when we hit a "dead" board (no legal move, yet not won or lost). This
## happens when a mine was hit and the board's win count is off: the board then
## has no accepted move but also does not flag a win. We force a clean ending
## by unflagging and detonating mines to reduce the crew to zero.
var _force_loss := false

# ---------------------------------------------------------------------------
# Helpers over the board's public state.
# ---------------------------------------------------------------------------

## The number we know about `c`: revealed-and-not-exploded -> its count,
## peeked -> the parrot's value, otherwise -1 (no number).
func _num(b: Board, c: Vector2i) -> int:
	if b.revealed.has(c) and not b.exploded.has(c):
		return b.number(c)
	if b.peeked.has(c):
		return b.peeked[c]
	return -1


## Known mines around `c`: flagged neighbours + exploded neighbours.
func _f(b: Board, c: Vector2i) -> int:
	var n: int = 0
	for d in Hex.DIRS:
		var nb := c + d
		if b.flagged.has(nb) or b.exploded.has(nb):
			n += 1
	return n


## Hidden (not revealed, not flagged) land neighbours of `c`, in neighbour order.
func _h(b: Board, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Hex.DIRS:
		var nb := c + d
		if b.is_land(nb) and not b.revealed.has(nb) and not b.flagged.has(nb):
			out.append(nb)
	return out


## Count of hidden land neighbours of `c` (no allocation, for the hot path).
func _hidden_count(b: Board, c: Vector2i) -> int:
	var n: int = 0
	for d in Hex.DIRS:
		var nb := c + d
		if b.is_land(nb) and not b.revealed.has(nb) and not b.flagged.has(nb):
			n += 1
	return n


## The land cell farthest from the sea (max distance to the nearest water hex).
## Ties are broken by the first entry in `b.land`.
func _most_inland(b: Board) -> Vector2i:
	var best: Vector2i = b.land.keys()[0]
	var best_d: int = -1
	for c in b.land:
		var d: int = 1_000_000
		for w in b.water:
			var dd: int = Hex.distance(c, w)
			if dd < d:
				d = dd
		if d > best_d:
			best_d = d
			best = c
	return best


## Every cell the board would accept a reveal on, in `b.land` order.
func _revealable(b: Board) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in b.land:
		if b.can_reveal(c):
			out.append(c)
	return out


## Every cell the board would accept a flag on, in `b.land` order.
func _flaggable(b: Board) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in b.land:
		if b.is_visible(c) and not b.revealed.has(c) and not b.flagged.has(c):
			out.append(c)
	return out


## First flagged cell, in `b.flagged` order. In the dead state every flagged
## cell is a mine; unflagging it (via toggle_flag) makes it revealable so the
## next move can detonate it. Returns a non-land sentinel when there are none.
func _any_flagged_cell(b: Board) -> Vector2i:
	for c in b.flagged:
		return c
	return Vector2i(0, 1000)


## Risk of `c` = max over its revealed, un-exploded, numbered neighbours of
## (N - F) / H (F = known mines, H = hidden-land neighbour count). 0.25 when
## it has no such neighbour.
func _risk(b: Board, c: Vector2i) -> float:
	var best: float = 0.0
	var has: bool = false
	for d in Hex.DIRS:
		var nb := c + d
		if b.revealed.has(nb) and not b.exploded.has(nb):
			var n: int = b.number(nb)
			if n > 0:
				has = true
				var f: int = _f(b, nb)
				var h: int = _hidden_count(b, nb)
				var contrib: float
				if h > 0:
					contrib = float(n - f) / float(h)
				else:
					contrib = 0.0
				if contrib > best:
					best = contrib
	if not has:
		return 0.25
	return best


## Cell with the lowest risk among `cells`; ties keep the first (b.land order).
func _lowest_risk(b: Board, cells: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = cells[0]
	var best_risk: float = _risk(b, best)
	for i in range(1, cells.size()):
		var c := cells[i]
		var r: float = _risk(b, c)
		if r < best_risk:
			best_risk = r
			best = c
	return best


## First cell of `cells` the board would accept for `kind` ("reveal" =>
## can_reveal, "flag" => visible/hidden/unflagged). If none exists, returns
## the first cell of `cells`, which the same test rejects; the caller re-checks
## the board before emitting so a refusal is impossible.
func _first_valid(cells: Array[Vector2i], b: Board, kind: String) -> Vector2i:
	for c in cells:
		if kind == "reveal" and b.can_reveal(c):
			return c
		if kind == "flag" and b.is_visible(c) and not b.revealed.has(c) and not b.flagged.has(c):
			return c
	return cells[0]


# ---------------------------------------------------------------------------
# Public API.
# ---------------------------------------------------------------------------

## Chooses one move that the board will accept (see [apply]).
func next_move(b: Board) -> Dictionary:
	# 1. Nothing revealed yet: land the camp on the most-inland cell.
	if b.revealed.is_empty():
		return {"action": "reveal", "cell": _most_inland(b)}

	# Forced-loss path: the board is dead (no legal move, not won/lost).
	# Detonate mines one by one (unflag -> reveal) to reduce crew to zero.
	if _force_loss:
		var revealable: Array[Vector2i] = _revealable(b)
		if not revealable.is_empty():
			return {"action": "reveal", "cell": revealable[0]}
		var fc: Vector2i = _any_flagged_cell(b)
		if b.flagged.has(fc):
			return {"action": "flag", "cell": fc}   # toggle_flag unflags it
		return {"action": "towel"}

	# 2. Safe deductions on every numbered cell (revealed and/or peeked).
	for c in b.land:
		var n: int = _num(b, c)
		if n < 0:
			continue
		var f: int = _f(b, c)
		var h: Array[Vector2i] = _h(b, c)
		if n == f and not h.is_empty():
			# Every remaining neighbour is safe: chord when the board will
			# (requires all flags to be set), otherwise reveal a safe cell.
			if b.revealed.has(c) and b.flags_around(c) == n:
				return {"action": "chord", "cell": c}
			var rc: Vector2i = _first_valid(h, b, "reveal")
			if b.can_reveal(rc):
				return {"action": "reveal", "cell": rc}
		elif n - f == h.size() and not h.is_empty():
			# Every remaining neighbour is a mine: flag the first valid one.
			var fc: Vector2i = _first_valid(h, b, "flag")
			if b.is_visible(fc) and not b.revealed.has(fc) and not b.flagged.has(fc):
				return {"action": "flag", "cell": fc}

	# 3. Stuck: towel, then detector, then the safest reveal.
	if not b.towel and b.wood >= 5:
		return {"action": "towel"}

	var revealable: Array[Vector2i] = _revealable(b)
	if revealable.is_empty():
		# A "dead" board: every remaining hidden land cell is flagged (no cell
		# is revealable and none is flaggable) yet the game has not ended. This
		# is the off-by-one the board's win check cannot resolve (a mine was hit
		# and all safe cells are revealed). Force a clean ending as a loss.
		_force_loss = true
		var fc: Vector2i = _any_flagged_cell(b)
		if b.flagged.has(fc):
			return {"action": "flag", "cell": fc}   # unflag a mine to detonate
		# No flagged mine left (should not happen): fall back to a towel.
		return {"action": "towel"}

	if b.wood >= 3:
		return {"action": "detector", "cell": _lowest_risk(b, revealable)}
	return {"action": "reveal", "cell": _lowest_risk(b, revealable)}


## Performs `move` on `b` and returns true iff the board changed (the move
## was accepted). `seed_value` is only used for the first reveal.
static func apply(b: Board, move: Dictionary, seed_value: int = 0) -> bool:
	var action: String = move.get("action")
	if action == "reveal":
		var cells: Array[Vector2i] = b.reveal(move.get("cell") as Vector2i, seed_value)
		return cells.size() > 0
	if action == "flag":
		return b.toggle_flag(move.get("cell") as Vector2i)
	if action == "chord":
		var cells: Array[Vector2i] = b.chord(move.get("cell") as Vector2i)
		return cells.size() > 0
	if action == "detector":
		return b.use_detector(move.get("cell") as Vector2i) >= 0
	if action == "parrot":
		return b.use_parrot(move.get("cell") as Vector2i) >= 0
	if action == "towel":
		return b.buy_towel()
	return false
