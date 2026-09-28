"""Game vs sim wall-jump table: the same pre/post measures (wj_table.py) on the sim traces in
tools_fit/_out/s7b_air_wall (route_export: tick, fwd, left, up in u). Game rows are the means of wj_table.json.
Usage (from this folder): python wj_compare.py"""
import csv, json, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "..", "tools_fit", "_out", "s7b_air_wall")
DRAG, W = 0.2, 0.45
def sim(p):
    R = list(csv.DictReader(open(p)))
    t = np.array([int(r["tick"]) for r in R]) / 64.0
    f = np.array([float(r["fwd"]) for r in R]); l = np.array([float(r["left"]) for r in R])
    vf = np.r_[0, np.diff(f) * 64]; vl = np.r_[0, np.diff(l) * 64]
    k = np.argmax((t > 80 / 64) & (vf < -60))
    pre = vl[k - 1]
    m = (t >= t[k]) & (t <= t[k] + W); tau = t[m] - t[k] + 1 / 64
    e = (1 - np.exp(-DRAG * tau)) / DRAG
    post_l = np.linalg.lstsq(np.c_[np.ones_like(e), e], l[m], rcond=None)[0][1]
    post_f = np.linalg.lstsq(np.c_[np.ones_like(e), e], f[m], rcond=None)[0][1]
    return pre, vl[k], post_l, post_f
G = json.load(open(os.path.join(HERE, "wj_table.json")))
print("%-12s | %-26s | %-26s | %-26s | %-26s" % ("case", "game pre/post_lat/post_fwd", "sim cur", "sim prop (107)", "sim prop105"))
for st, n in [("s7_open", "WJD"), ("s7_open", "WJA"), ("wall", "WJD"), ("wall", "WJA"), ("wall", "WJ0"), ("wall", "WJWA"), ("wall", "WJSA")]:
    g = np.array([[r[4], r[6], r[7]] for r in G if r[0] == st and r[1] == n], float)
    gm = np.nanmean(g, axis=0)
    cols = []
    for tag in ("cur", "prop", "prop105"):
        pre, v0, pl, pf = sim(os.path.join(OUT, "%s_%s_%s.csv" % (st, n, tag)))
        cols.append("%6.1f %7.1f %7.1f" % (pre, pl, pf))
    print("%-12s | %6.1f %7.1f %7.1f       | %s        | %s        | %s" % (st[:4] + "/" + n, gm[0], gm[1], gm[2], *cols))
