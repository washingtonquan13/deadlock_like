"""F: strafe (sideways) run-speed multiplier from existing s6_diag recordings (no new game data).
DRD/DRA hold D/A only from tick 56 to 170; after the air jump (66) the hero lands ~tick 157 and runs sideways on the
ground for ~13 ticks. DRWA (W+A) and DRSA (S+A) are the same timing with a diagonal key (not strafe-multiplied).
Replays each in the sim at strafe_mult in MULTS and compares HUD speed on the ground stretch.
Run from tools/movement_capture: .venv/Scripts/python.exe scenarios/s7_fit_mantle_strafe/strafe_fit.py"""
import csv, glob, json, os, subprocess, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
GODOT = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
OUT = os.path.join(ROOT, "tools_fit", "_out", "s7_mantle_strafe")
REC = os.path.join(ROOT, "tools", "movement_capture", "rec_auto", "s6_diag")
SRC = os.path.join(ROOT, "tools", "movement_capture", "scenarios", "s6_diag")
NAMES = ["DRD", "DRA", "DRWA", "DRSA"]
MULTS = [1.0, 0.9, 0.85, 0.8]
TICKS = list(range(156, 172))


def game(name):
    per = {}
    for f in sorted(glob.glob(os.path.join(REC, name, "*.csv"))):
        for r in csv.DictReader(open(f)):
            if r["valid"] != "1" or not r["vel_scalar"]:
                continue
            tk = round(float(r["t"]) * 64) + 1
            per.setdefault(tk, []).append(float(r["vel_scalar"]))
    return {k: statistics.median(v) for k, v in per.items()}


def sim(name, mult):
    sc = json.load(open(os.path.join(SRC, name + ".json")))
    sc["params"] = [{"name": "strafe_mult", "min": 0, "max": 2, "init": mult}]
    p = os.path.join(OUT, f"strafe_{name}_{mult:.2f}.json")
    json.dump(sc, open(p, "w"), indent=1)
    o = os.path.join(OUT, f"strafe_{name}_{mult:.2f}.csv")
    rel = "res://" + os.path.relpath(p, ROOT).replace("\\", "/")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + rel, "--out=" + o], check=True, capture_output=True)
    return {int(r["tick"]): (float(r["speed3d"]), r["loco"]) for r in csv.DictReader(open(o))}


for n in NAMES:
    g = game(n)
    runs = {m: sim(n, m) for m in (MULTS if n in ("DRD", "DRA") else [1.0])}
    print(f"\n{n}  tick: game | " + " | ".join(f"sim m={m}" for m in runs))
    for t in TICKS:
        gv = g.get(t)
        cells = " | ".join(f"{runs[m][t][0]:.0f} {runs[m][t][1][:4]}" for m in runs)
        print(f"  {t}: {gv if gv is None else round(gv)} | {cells}")
    for m in runs:
        d = [runs[m][t][0] - g[t] for t in range(163, 171) if t in g]
        print(f"  m={m}: mean sim-game over 163-170 = {statistics.mean(d):+.1f}, max game {max(g[t] for t in range(160,171) if t in g):.0f}, max sim {max(runs[m][t][0] for t in range(160,171)):.0f}")


# landing alignment: first grounded tick after the air jump (sim) vs the HUD drop from ~600 (game)
for n in NAMES:
    g = game(n)
    s = sim(n, 1.0)
    sl = next(t for t in range(100, 200) if s[t][1].startswith("GROU") and not s[t - 1][1].startswith("GROU"))
    gl = next(t for t in range(140, 200) if t in g and t - 1 in g and g[t] < 0.7 * g[t - 1])
    rise_g = [round(g[t]) for t in range(gl, gl + 12) if t in g]
    rise_s = [round(s[t][0]) for t in range(sl, sl + 12)]
    print(f"{n}: land game {gl} sim {sl}\n   game from landing {rise_g}\n   sim  from landing {rise_s}")
