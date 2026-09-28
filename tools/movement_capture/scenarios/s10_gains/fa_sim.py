"""Sim replay of the s10_gains fast air strafe runs (FA_A/D/N from a ~470 u/s slide hop, FA_L from a ~330 u/s jump)
and a game-vs-sim table of the forward and left velocity (u/s, start-view frame) in 0.08 s windows.
Usage (from tools/movement_capture): python fa_sim.py [--set=name=value,...] [--t0=S --t1=S --dt=S]"""
import csv, glob, json, os, subprocess, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GD = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
U = 0.0254
NAMES = ["FA_A", "FA_D", "FA_N", "FA_L"]
FIX = {}; OPT = {"t0": 0.3, "t1": 2.8, "dt": 0.1}
for a in sys.argv[1:]:
    if a.startswith("--set="):
        for kv in a[6:].split(","):
            k, v = kv.split("="); FIX[k] = float(v)
    elif a.startswith("--"):
        k, v = a[2:].split("="); OPT[k] = float(v)
out = os.path.join(ROOT, "tools_fit", "_out", "s10_fa"); os.makedirs(out, exist_ok=True)
def gen_run(n):
    s = json.load(open(os.path.join(os.path.dirname(__file__), n + ".json")))
    s["fixed"] = FIX
    p = os.path.join(out, n + "_sim.json"); json.dump(s, open(p, "w"), indent=1)
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + p.replace("\\", "/"), "--out=" + os.path.join(out, n + ".csv").replace("\\", "/")],
                   capture_output=True)
def slope(t, y, a):
    m = (t > a) & (t < a + 0.08)
    return np.polyfit(t[m], y[m], 1)[0] if m.sum() > 3 else np.nan
def sim_v(n, W):
    R = list(csv.DictReader(open(os.path.join(out, n + ".csv"))))
    t = np.array([int(r["tick"]) for r in R]) / 64.0 - 1 / 64
    f = np.array([float(r["fwd"]) for r in R]); l = np.array([float(r["left"]) for r in R])
    return np.array([(slope(t, f, a), slope(t, l, a)) for a in W])
def game_v(n, W):
    acc = []
    for p in sorted(glob.glob("rec_auto/s10_gains/%s/ts1_t?.csv" % n)):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        t, x, y = (np.array([float(r[k]) for r in R]) for k in ("t", "pos_x", "pos_y"))
        yw = np.radians(float(R[0]["ang_yaw"]))
        f = x * np.cos(yw) + y * np.sin(yw); l = -x * np.sin(yw) + y * np.cos(yw)
        acc.append([(slope(t, f, a), slope(t, l, a)) for a in W])
    return np.nanmean(np.array(acc), axis=0)
if __name__ == "__main__":
    W = np.arange(OPT["t0"], OPT["t1"] + 1e-9, OPT["dt"])
    for n in NAMES: gen_run(n)
    print("cells: fwd/left u/s  game | sim")
    for n in NAMES:
        g = game_v(n, W); s = sim_v(n, W)
        print(n)
        for i, a in enumerate(W):
            print("  %.2f  %5.0f/%5.0f | %5.0f/%5.0f   |h| %4.0f | %4.0f" % (a, g[i][0], g[i][1], s[i][0], s[i][1], np.hypot(*g[i]), np.hypot(*s[i])))
