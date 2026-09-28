"""G09 flag clear time: SE2/8/12/16/24/40 sim replay vs game. Prints the horizontal speed around hop 2 (sim: speed_h;
game: position-derived, lag-shifted 2.7), the sim landing ticks and the game's hop-1 landing tick (camera z back to
the ground).
Usage (from tools/movement_capture): python scenarios/s11_conf/se_sim.py [--set=name=value,...] [SE|SL]"""
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
out = os.path.join(ROOT, "tools_fit", "_out", "s11_se"); os.makedirs(out, exist_ok=True)
OFF = list(range(-8, 48, 6))
print("offsets from hop 2:", " ".join("%4d" % o for o in OFF))
PRE = sys.argv[-1] if sys.argv[1:] and not sys.argv[-1].startswith("--") else "SE"
for k in ((2, 8, 12, 16, 24, 40) if PRE == "SE" else (4, 8, 12, 16, 20, 24, 32, 48)):
    n = PRE + "%d" % k; hop = (73 if PRE == "SE" else 77) + k + 6
    s = json.load(open(os.path.join(os.path.dirname(__file__), n + ".json"))); s["fixed"] = FIX
    p = os.path.join(out, n + ".json"); json.dump(s, open(p, "w"), indent=1)
    c = os.path.join(out, n + ".csv")
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + p.replace("\\", "/"), "--out=" + c.replace("\\", "/")], capture_output=True, check=True)
    R = list(csv.DictReader(open(c)))
    tk = np.array([float(r["tick"]) for r in R]); sh = np.array([float(r["speed_h"]) for r in R]); up = np.array([float(r["up"]) for r in R])
    air = up > 0.5; lands = [int(tk[i]) for i in range(1, len(tk)) if air[i - 1] and not air[i]]
    print("%-5s sim  %s   lands %s" % (n, " ".join("%4.0f" % np.interp(hop + o, tk, sh) for o in OFF), lands[:3]))
    for g in sorted(glob.glob(os.path.join(os.path.dirname(__file__), "..", "..", "rec_auto", "s11_conf", n, "ts1_t?.csv"))):
        G = [r for r in csv.DictReader(open(g)) if r["valid"] == "1"]
        t, x, y, z = (np.array([float(r[q]) for r in G]) for q in ("t", "pos_x", "pos_y", "pos_z")); gt = t * 64 + 1 - LAG
        v = [np.hypot(np.interp(hop + o + 2, gt, x) - np.interp(hop + o - 2, gt, x), np.interp(hop + o + 2, gt, y) - np.interp(hop + o - 2, gt, y)) / (4 / 64) for o in OFF]
        z0 = z[0]; up1 = np.where((gt > 30) & (z - z0 > 20))[0]
        land = next((gt[i] for i in range(up1[0], len(gt)) if z[i] - z0 < 10), float("nan")) if len(up1) else float("nan")
        print("      game %s   land1 ~%.0f" % (" ".join("%4.0f" % q for q in v), land))
