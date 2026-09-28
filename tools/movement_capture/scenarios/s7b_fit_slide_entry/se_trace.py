"""s7b: print game (lag-aligned, 4 ticks) vs sim speed per 2 ticks after the crouch press.
Usage: python scenarios/s7b_fit_slide_entry/se_trace.py NAME [TAG] [LAG]"""
import csv, glob, json, sys
import numpy as np
n = sys.argv[1]; TAG = sys.argv[2] if len(sys.argv) > 2 else "cur"; L = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0
sc = json.load(open("scenarios/s7_open/%s.json" % n))
N = [e["from"] for e in sc["timeline"] if "crouch" in e.get("buttons", [])][0]
S = list(csv.DictReader(open("../../tools_fit/_out/s7b_slide_entry/%s_%s.csv" % (TAG, n))))
G = []
for p in sorted(glob.glob("rec_auto/s7_open/%s/ts1_t*.csv" % n)):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    G.append((np.array([float(r["t"]) * 64 + 1 - L for r in R]), np.array([float(r["vel_scalar"]) for r in R])))
for k in range(N - 4, min(N + 80, len(S)), 2):
    g = [np.interp(k, a, b) for a, b in G]
    print("tick %3d (+%.3f s) game %s | sim %.1f %s" % (k, (k - N) / 64, " ".join("%.1f" % x for x in g), float(S[k]["speed_h"]), S[k]["loco"]))
