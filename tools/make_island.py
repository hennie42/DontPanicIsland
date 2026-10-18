#!/usr/bin/env python3
"""Generate the islands of Don't Panic Island (director-written; deterministic).

  python3 tools/make_island.py              island 0 -> data/island.json (the original, unchanged)
  python3 tools/make_island.py K OUT.json   island K: the coastline's phases, bumps, bay, peninsula and size vary
                                            with K (tools/make_islands.py makes and validates the whole pool)

Axial hex coordinates (q, r), pointy-top (scripts/hex.gd). Output:
  {"land": [{"q":..,"r":..,"terrain": "beach|palm|jungle|grass|rock|desert|wreck"}...],
   "water": [{"q":..,"r":..}...]}           water: a ring of non-playable sea hexes around the land
Terrain: beach = land touching the sea; palm groves just inside the beach; jungle and grass in the middle; a few
rock outcrops and desert patches; 3 wrecks on beach tiles, spread apart.
"""
import json
import math
import pathlib
import random
import sys

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


# the coastline parameters: island 0 is the original island; others draw theirs from K
ORIGINAL = {"r": 8.2, "amps": (1.3, 0.8, 0.5), "phases": (0.7, 2.1, 4.0), "bay": (2.3, 2.4), "pen": (-0.6, 2.0),
            "bay2": None, "salt": 0, "target": TARGET}


def params(k):
    if k == 0:
        return ORIGINAL
    rnd = random.Random(k * 7919)
    size = rnd.randint(180, 230)
    return {"r": 8.2 * math.sqrt(size / 202.0),
            "amps": (rnd.uniform(0.8, 1.7), rnd.uniform(0.4, 1.1), rnd.uniform(0.2, 0.7)),
            "phases": tuple(rnd.uniform(0, 2 * math.pi) for _ in range(3)),
            "bay": (rnd.uniform(-math.pi, math.pi), rnd.uniform(1.4, 2.8)),
            "pen": (rnd.uniform(-math.pi, math.pi), rnd.uniform(1.2, 2.4)),
            "bay2": (rnd.uniform(-math.pi, math.pi), rnd.uniform(0.8, 1.8)) if rnd.random() < 0.5 else None,
            "salt": k * 10, "target": (size - 8, size + 8)}


def ang_gauss(ang, centre, width):
    d = math.atan2(math.sin(ang - centre), math.cos(ang - centre))   # wrapped angle difference
    return math.exp(-(d ** 2) * width)


def shape(c, threshold, P=ORIGINAL):
    x, z = world(c)
    ang = math.atan2(z, x)
    rad = math.hypot(x, z)
    # an irregular coastline: a lumpy radius by angle, with a bay and a peninsula (and maybe a second bay)
    a, ph = P["amps"], P["phases"]
    edge = P["r"] + a[0] * math.sin(3 * ang + ph[0]) + a[1] * math.sin(5 * ang + ph[1]) + a[2] * math.sin(7 * ang + ph[2])
    if P is ORIGINAL:   # the original's exact formula (unwrapped angles), so island 0 stays byte for byte
        edge -= 2.4 * math.exp(-((ang - 2.3) ** 2) * 6)      # bay in the north-west
        edge += 2.0 * math.exp(-((ang + 0.6) ** 2) * 8)      # peninsula in the south-east
    else:
        edge -= P["bay"][1] * ang_gauss(ang, P["bay"][0], 6)
        edge += P["pen"][1] * ang_gauss(ang, P["pen"][0], 8)
        if P["bay2"]:
            edge -= P["bay2"][1] * ang_gauss(ang, P["bay2"][0], 7)
    return rad + (h(c, 1 + P["salt"]) - 0.5) * 0.6 < edge * threshold


def build(threshold, P=ORIGINAL):
    cells = [(q, r) for q in range(-16, 17) for r in range(-16, 17) if dist((q, r), (0, 0)) <= 15]
    land = {c for c in cells if shape(c, threshold, P)}
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


def main(k=0, out_path=None):
    P = params(k)
    target = P["target"]
    salt = P["salt"]
    t = 1.0
    land = build(t, P)
    for _ in range(200):
        if target[0] <= len(land) <= target[1]:
            break
        t *= 0.995 if len(land) > target[1] else 1.005
        land = build(t, P)
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
            terrain[c] = "palm" if h(c, 2 + salt) < 0.55 else ("desert" if h(c, 3 + salt) < 0.3 else "grass")
        else:
            terrain[c] = "jungle" if h(c, 4 + salt) < 0.6 else ("rock" if h(c, 5 + salt) < 0.25 else "grass")
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
    p = pathlib.Path(out_path) if out_path else pathlib.Path(__file__).resolve().parents[1] / "data/island.json"
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
    if len(sys.argv) == 3:
        main(int(sys.argv[1]), sys.argv[2])
    else:
        main()
