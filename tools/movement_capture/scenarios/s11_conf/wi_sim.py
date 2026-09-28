"""G33 wall-jump interval: WI4/8/12/20 (wall jump at 88, second jump press at 88+k) vs WN_E (s10: no second press).
Game z and fwd (camera, relative to the press tick, lag-shifted 2.7) vs a sim replay against a wall 411 u ahead.
Usage (from tools/movement_capture): python scenarios/s11_conf/wi_sim.py [--set=name=value,...]"""
import csv, glob, json, os, subprocess, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GD = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
U = 0.0254; LAG = 2.7; FACE = 411.0
FIX = {}
for a in sys.argv[1:]:
    if a.startswith("--set="):
        for kv in a[6:].split(","):
            k, v = kv.split("="); FIX[k] = float(v)
out = os.path.join(ROOT, "tools_fit", "_out", "s11_wi"); os.makedirs(out, exist_ok=True)
CASES = [("WN_E", "s10_gains")] + [("WI%d" % k, "s11_conf") for k in (4, 8, 12, 20)]
OFF = [0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56]
def sim(n, d):
    s = json.load(open(os.path.join(os.path.dirname(__file__), "..", d, n + ".json")))
    face = FACE * U + 0.4064
    s["geometry"] = [{"type": "wall", "center": [0.0, 5.0, -(face + 0.25)], "size": [40.0, 10.0, 0.5]}]
    s["fixed"] = FIX
    p = os.path.join(out, n + ".json"); json.dump(s, open(p, "w"), indent=1)
    c = os.path.join(out, n + ".csv")
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + p.replace("\\", "/"), "--out=" + c.replace("\\", "/")], capture_output=True)
    R = list(csv.DictReader(open(c)))
    tk = np.array([float(r["tick"]) for r in R]); z = np.array([float(r["up"]) for r in R])
    f = np.array([float(r["fwd"]) for r in R])
    return tk, z, f
def row(tk, z, f, P):
    z0 = np.interp(P, tk, z); f0 = np.interp(P, tk, f)
    return ["%4.0f/%4.0f" % (np.interp(P + o, tk, z) - z0, np.interp(P + o, tk, f) - f0) for o in OFF]
print("ticks after the wall-jump press:", OFF, " cells: dz/dfwd (u)")
for n, d in CASES:
    tk, z, f = sim(n, d)
    print("%-5s sim  " % n + " ".join(row(tk, z, f, 88)))
    for p in sorted(glob.glob("rec_auto/%s/%s/ts1_t?.csv" % (d, n))):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        t, x, zz = (np.array([float(r[k]) for r in R]) for k in ("t", "pos_x", "pos_z"))
        print("      game " + " ".join(row(t * 64 + 1 - LAG, zz, x, 88)))
