"""Dash slide entry (DC*): game HUD speed (horizontal on the ground, lag-shifted 2.7) vs the sim's speed_h, from the
crouch press c-2 to c+40. Also RUN (plain W run): HUD at 0.4/0.6/0.8/1.0/1.5/2.0 s vs the sim.
Usage (from tools/movement_capture): python scenarios/s11_conf/dc_sim.py [--set=name=value,...]"""
import csv, glob, json, os, subprocess, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GD = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
LAG = 2.7
FIX = {}
for a in sys.argv[1:]:
    if a.startswith("--set="):
        for kv in a[6:].split(","):
            k, v = kv.split("="); FIX[k] = float(v)
out = os.path.join(ROOT, "tools_fit", "_out", "s11_dc"); os.makedirs(out, exist_ok=True)
HERE = os.path.dirname(__file__)


def sim(n):
    s = json.load(open(os.path.join(HERE, n + ".json"))); s["fixed"] = FIX
    p = os.path.join(out, n + ".json"); json.dump(s, open(p, "w"), indent=1)
    c = os.path.join(out, n + ".csv")
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + p.replace("\\", "/"), "--out=" + c.replace("\\", "/")], capture_output=True, check=True)
    R = list(csv.DictReader(open(c)))
    return np.array([float(r["tick"]) for r in R]), np.array([float(r["speed_h"]) for r in R])


def game(n):
    for g in sorted(glob.glob(os.path.join(HERE, "..", "..", "rec_auto", "s11_conf", n, "ts1_t?.csv"))):
        G = [r for r in csv.DictReader(open(g)) if r["valid"] == "1" and r["vel_scalar"] not in ("", "nan")]
        yield np.array([float(r["t"]) * 64 + 1 - LAG for r in G]), np.array([float(r["vel_scalar"]) for r in G])


OFF = [-2, 0, 1, 2, 3, 4, 6, 8, 12, 16, 20, 25, 30, 35, 40]
print("offsets from crouch:", " ".join("%4d" % o for o in OFF))
for c in (12, 20, 24):
    for w in "WR":
        n = "DC%d%s" % (c, w)
        if not os.path.exists(os.path.join(HERE, n + ".json")): continue
        tk, sh = sim(n)
        print("%-6s sim  %s" % (n, " ".join("%4.0f" % np.interp(c + o, tk, sh) for o in OFF)))
        for gt, v in game(n):
            print("       game %s" % " ".join("%4.0f" % np.interp(c + o, gt, v) for o in OFF))
TS = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]
print("RUN s:      ", " ".join("%5.1f" % t for t in TS))
tk, sh = sim("RUN")
print("RUN    sim  ", " ".join("%5.0f" % np.interp(1 + t * 64, tk, sh) for t in TS))
for gt, v in game("RUN"):
    print("       game ", " ".join("%5.0f" % np.interp(1 + t * 64, gt, v) for t in TS))
