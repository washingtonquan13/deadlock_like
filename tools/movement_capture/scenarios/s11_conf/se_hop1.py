"""SE hop 1 (dash 4, crouch 20..27, slide hop 26): game position-derived horizontal speed and height vs the sim, ticks
0..80 (game lag-shifted 2.7). Run se_sim.py first (it writes the sim CSVs).
Usage (from tools/movement_capture): python scenarios/s11_conf/se_hop1.py [SE2 ...]"""
import csv, glob, os, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
LAG = 2.7
TK = list(range(0, 81, 4))
print("tick        ", " ".join("%4d" % k for k in TK))
for n in sys.argv[1:] or ["SE2"]:
    R = list(csv.DictReader(open(os.path.join(ROOT, "tools_fit", "_out", "s11_se", n + ".csv"))))
    tk = np.array([float(r["tick"]) for r in R]); sh = np.array([float(r["speed_h"]) for r in R]); up = np.array([float(r["up"]) for r in R])
    print("%-5s sim  v %s" % (n, " ".join("%4.0f" % np.interp(k, tk, sh) for k in TK)))
    print("          z %s" % " ".join("%4.0f" % np.interp(k, tk, up) for k in TK))
    for g in sorted(glob.glob(os.path.join(os.path.dirname(__file__), "..", "..", "rec_auto", "s11_conf", n, "ts1_t?.csv"))):
        G = [r for r in csv.DictReader(open(g)) if r["valid"] == "1"]
        t, x, y, z = (np.array([float(r[q]) for r in G]) for q in ("t", "pos_x", "pos_y", "pos_z")); gt = t * 64 + 1 - LAG
        v = [np.hypot(np.interp(k + 2, gt, x) - np.interp(k - 2, gt, x), np.interp(k + 2, gt, y) - np.interp(k - 2, gt, y)) / (4 / 64) for k in TK]
        print("     game  v %s" % " ".join("%4.0f" % q for q in v))
        print("           z %s" % " ".join("%4.0f" % (np.interp(k, gt, z) - z[0]) for k in TK))
