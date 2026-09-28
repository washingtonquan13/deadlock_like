"""Sim replay of the wallAd wall jumps (s10_gains WN_*/WH_*) and a game-vs-sim table of the post-press velocity
(kick off the wall, along the wall) in 0.08 s windows. The wall face is 400 u ahead (game camera travel to contact).
Usage (from tools/movement_capture): python wall_sim.py [--set=name=value,...] [--face=U]
--face moves the wall (u from the start); the game reaches the wall ~5 ticks after the sim does at 400."""
import csv, glob, json, os, subprocess, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GD = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
U = 0.0254
NAMES = ["WN_E", "WN_F", "WH_A", "WH_WA", "WH_SA", "WH_S", "WH_W"]
PRESS = {"WN_F": 104}
WIN = [0.05, 0.10, 0.15, 0.20, 0.30]
FIX = {}
FACE = 400.0
for a in sys.argv[1:]:
    if a.startswith("--set="):
        for kv in a[6:].split(","):
            k, v = kv.split("="); FIX[k] = float(v)
    elif a.startswith("--face="):
        FACE = float(a[7:])
out = os.path.join(ROOT, "tools_fit", "_out", "s10_wall"); os.makedirs(out, exist_ok=True)
def gen_run(n):
    s = json.load(open(os.path.join(os.path.dirname(__file__), n + ".json")))
    face = FACE * U + 0.4064
    s["geometry"] = [{"type": "wall", "center": [0.0, 5.0, -(face + 0.25)], "size": [40.0, 10.0, 0.5]}]
    s["fixed"] = FIX
    p = os.path.join(out, n + "_sim.json"); json.dump(s, open(p, "w"), indent=1)
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + p.replace("\\", "/"), "--out=" + os.path.join(out, n + ".csv").replace("\\", "/")],
                   capture_output=True)
def sim_v(n, P):
    R = list(csv.DictReader(open(os.path.join(out, n + ".csv"))))
    t = np.array([int(r["tick"]) for r in R]) / 64.0
    f = np.array([float(r["fwd"]) for r in R]); l = np.array([float(r["left"]) for r in R])
    tp = (P - 1) / 64
    res = []
    for a in WIN:
        m = (t > tp + a) & (t < tp + a + 0.08)
        res.append((-np.polyfit(t[m], f[m], 1)[0], np.polyfit(t[m], l[m], 1)[0]))
    return res
def game_v(n, P):
    acc = []
    for p in sorted(glob.glob("rec_auto/s10_gains/%s/ts1_t?.csv" % n)):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        t, x, y = (np.array([float(r[k]) for r in R]) for k in ("t", "pos_x", "pos_y"))
        tp = (P - 1) / 64; row = []
        for a in WIN:
            m = (t > tp + a) & (t < tp + a + 0.08)
            row.append((-np.polyfit(t[m], x[m], 1)[0], np.polyfit(t[m], y[m], 1)[0]) if m.sum() > 3 else (np.nan, np.nan))
        acc.append(row)
    return np.nanmean(np.array(acc), axis=0)
for n in NAMES: gen_run(n)
print("window start after the press (s):", WIN, " cells: kick/along  game | sim")
for n in NAMES:
    P = PRESS.get(n, 88); g = game_v(n, P); s = sim_v(n, P)
    print("%-6s " % n + "  ".join("%4.0f/%4.0f|%4.0f/%4.0f" % (g[i][0], g[i][1], s[i][0], s[i][1]) for i in range(len(WIN))))
