#!/usr/bin/env python3
"""Generate data/island.json: the fixed island of Don't Panic Island (director-written; deterministic).

Axial hex coordinates (q, r), pointy-top (scripts/hex.gd). Output:
  {"land": [{"q":..,"r":..,"terrain": "beach|palm|jungle|grass|rock|desert|wreck"}...],
   "water": [{"q":..,"r":..}...]}           water: a ring of non-playable sea hexes around the land
Terrain: beach = land touching the sea; palm groves just inside the beach; jungle and grass in the middle; a few
rock outcrops and desert patches; 3 wrecks on beach tiles, spread apart.
"""
import json
import math
import pathlib

DIRS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]
TARGET = (195, 210)


def dist(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return (abs(dq) + abs(dr) + abs(dq + dr)) // 2


def world(c):
    return (c[0] + c[1] * 0.5, c[1] * 0.866)


def h(c, salt):
    """Deterministic hash in [0, 1)."""
    x = math.sin(c[0] * 127.1 + c[1] * 311.7 + salt * 74.7) * 43758.5453
    return x - math.floor(x)


def shape(c, threshold):
    x, z = world(c)
    ang = math.atan2(z, x)
    rad = math.hypot(x, z)
    # an irregular coastline: a lumpy radius by angle, with two bays and a peninsula
    edge = 8.2 + 1.3 * math.sin(3 * ang + 0.7) + 0.8 * math.sin(5 * ang + 2.1) + 0.5 * math.sin(7 * ang + 4.0)
    edge -= 2.4 * math.exp(-((ang - 2.3) ** 2) * 6)      # bay in the north-west
    edge += 2.0 * math.exp(-((ang + 0.6) ** 2) * 8)      # peninsula in the south-east
    return rad + (h(c, 1) - 0.5) * 0.6 < edge * threshold


def build(threshold):
    cells = [(q, r) for q in range(-14, 15) for r in range(-14, 15) if dist((q, r), (0, 0)) <= 13]
    land = {c for c in cells if shape(c, threshold)}
    # keep the largest connected piece (no floating islets)
    best = set()
    seen = set()
    for c in land:
        if c in seen:
            continue
        comp, stack = set(), [c]
        while stack:
            x = stack.pop()
            if x in comp:
                continue
            comp.add(x)
            stack += [(x[0] + d[0], x[1] + d[1]) for d in DIRS if (x[0] + d[0], x[1] + d[1]) in land]
        seen |= comp
        best = max(best, comp, key=len)
    return best


def main():
    t = 1.0
    land = build(t)
    for _ in range(200):
        if TARGET[0] <= len(land) <= TARGET[1]:
            break
        t *= 0.995 if len(land) > TARGET[1] else 1.005
        land = build(t)
    coast = {c for c in land if any((c[0] + d[0], c[1] + d[1]) not in land for d in DIRS)}
    depth = {c: 0 for c in coast}
    frontier = list(coast)
    while frontier:  # distance from the sea, by BFS
        nxt = []
        for c in frontier:
            for d in DIRS:
                n = (c[0] + d[0], c[1] + d[1])
                if n in land and n not in depth:
                    depth[n] = depth[c] + 1
                    nxt.append(n)
        frontier = nxt
    terrain = {}
    for c in sorted(land):
        d = depth[c]
        if d == 0:
            terrain[c] = "beach"
        elif d <= 2:
            terrain[c] = "palm" if h(c, 2) < 0.55 else ("desert" if h(c, 3) < 0.3 else "grass")
        else:
            terrain[c] = "jungle" if h(c, 4) < 0.6 else ("rock" if h(c, 5) < 0.25 else "grass")
    # 3 wrecks on beach tiles, as far apart as possible (greedy), starting from the most southern beach
    beaches = sorted((c for c in land if terrain[c] == "beach"), key=lambda c: (-c[1], c[0]))
    wrecks = [beaches[0]]
    while len(wrecks) < 3:
        wrecks.append(max(beaches, key=lambda c: min(dist(c, w) for w in wrecks)))
    for w in wrecks:
        terrain[w] = "wreck"
    water = sorted({(c[0] + dx, c[1] + dy) for c in land for dx in range(-3, 4) for dy in range(-3, 4)
                    if dist((c[0] + dx, c[1] + dy), c) <= 2} - land)
    out = {"land": [{"q": q, "r": r, "terrain": terrain[(q, r)]} for q, r in sorted(land)],
           "water": [{"q": q, "r": r} for q, r in water]}
    p = pathlib.Path(__file__).resolve().parents[1] / "data/island.json"
    p.parent.mkdir(exist_ok=True)
    p.write_text(json.dumps(out, indent=0) + "\n")
    counts = {}
    for c in terrain.values():
        counts[c] = counts.get(c, 0) + 1
    print(f"{p}: {len(land)} land ({counts}), {len(water)} water")
    # ascii preview (rows of r; offset by r/2 like the pointy-top layout)
    sym = {"beach": ".", "palm": "T", "jungle": "#", "grass": ",", "rock": "^", "desert": ":", "wreck": "W"}
    for r in range(min(c[1] for c in land) - 1, max(c[1] for c in land) + 2):
        line = " " * (r + 14)
        for q in range(-15, 16):
            c = (q, r)
            line += (sym[terrain[c]] if c in land else ("~" if c in water else " ")) + " "
        print(line.rstrip())


if __name__ == "__main__":
    main()
