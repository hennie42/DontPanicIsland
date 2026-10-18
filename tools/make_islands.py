"""make_islands.py: the island pool. Generates island K = 1, 2, ... with tools/make_island.py, keeps the first
COUNT that pass the shape checks, bakes each one's distance-to-shore field for the sea, and writes
data/islands/index.json. The solver check (tests/check_islands.gd, in Godot) then plays each island and drops the
ones it can't win often enough (--drop K,K,...).

  python3 tools/make_islands.py [--count 24] [--drop 7,12]
Island 0 is the original (data/island.json): the autopilot, the tests and the first game use it.
"""
import argparse
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def shape_ok(path):
    d = json.loads(path.read_text())
    land = {(c["q"], c["r"]): c["terrain"] for c in d["land"]}
    n = len(land)
    counts = {}
    for t in land.values():
        counts[t] = counts.get(t, 0) + 1
    # inland depth: an island needs a middle (not a ring of beach), and enough of each terrain to play with
    problems = []
    if not 175 <= n <= 238:
        problems.append(f"size {n}")
    if counts.get("wreck", 0) != 3:
        problems.append("wrecks")
    if counts.get("palm", 0) < 30:
        problems.append(f"palms {counts.get('palm', 0)}")
    if counts.get("jungle", 0) + counts.get("grass", 0) + counts.get("rock", 0) < 50:
        problems.append("small middle")
    if counts.get("beach", 0) > 0.36 * n:
        problems.append("too much beach (thin island)")
    return problems, n, counts


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--count", type=int, default=24)
    ap.add_argument("--drop", default="", help="island numbers the solver check rejected")
    a = ap.parse_args()
    drop = {int(x) for x in a.drop.split(",") if x}
    out_dir = ROOT / "data/islands"
    out_dir.mkdir(parents=True, exist_ok=True)
    gen_dir = ROOT / "assets/generated/islands"
    gen_dir.mkdir(parents=True, exist_ok=True)
    kept, k = [], 0
    while len(kept) < a.count and k < 200:
        k += 1
        if k in drop:
            continue
        p = out_dir / f"island_{k:02d}.json"
        subprocess.run([sys.executable, str(ROOT / "tools/make_island.py"), str(k), str(p)], check=True,
                       capture_output=True)
        problems, n, counts = shape_ok(p)
        if problems:
            print(f"island {k}: rejected ({', '.join(problems)})")
            p.unlink()
            continue
        kept.append({"id": k, "file": f"res://data/islands/island_{k:02d}.json", "land": n})
        print(f"island {k}: {n} land {counts}")
    # the sea's distance fields, one per island (island 0's stays where it is)
    rects = {}
    for it in kept:
        png = gen_dir / f"shore_{it['id']:02d}.png"
        r = subprocess.run([sys.executable, str(ROOT / "tools/make_shore_field.py"), "--island",
                            str(out_dir / f"island_{it['id']:02d}.json"), "--out", str(png)],
                           check=True, capture_output=True, text=True).stdout
        rects[it["id"]] = json.loads(r.strip().splitlines()[-1])
        it["shore"] = f"res://assets/generated/islands/shore_{it['id']:02d}.png"
        it["rect"] = rects[it["id"]]
    (out_dir / "index.json").write_text(json.dumps({"islands": kept}, indent=1) + "\n")
    print(f"kept {len(kept)} islands -> data/islands/index.json")


if __name__ == "__main__":
    main()
