"""Wall-jump launch vs approach (s10_gains WN_*/WH_*, s9_open WK_*; mark wallAd, wall normal = -x, tangent = +y (A)).
Quadratic fits of the HUD position over [P+0.10, P+0.40] s (P = the press tick's time), velocity evaluated at P+0.02;
the pre-press velocity from a linear fit over [P-0.20, P-0.03]. Prints kick (-vx), along-wall vy, vz."""
import csv, glob, sys, os
import numpy as np
PRESS = {"WN_E": 88, "WN_R": 72, "WN_F": 104}
def press(s): return PRESS.get(s, 88)
def fit(p, P):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    t, x, y, z = (np.array([float(r[k]) for r in R]) for k in ("t", "pos_x", "pos_y", "pos_z"))
    tp = (P - 1) / 64.0
    m = (t > tp + 0.10) & (t < tp + 0.40)
    pre = (t > tp - 0.20) & (t < tp - 0.03)
    if m.sum() < 8 or pre.sum() < 4: return None
    post = [np.polyval(np.polyder(np.polyfit(t[m] - tp, q[m], 2)), 0.02) for q in (x, y, z)]
    before = [np.polyfit(t[pre], q[pre], 1)[0] for q in (x, y, z)]
    return before, post
names = sys.argv[1:] or ["WN_E", "WN_R", "WN_F", "WH_A", "WH_WA", "WH_SA", "WH_S", "WH_W"]
for s in names:
    d = "rec_auto/s10_gains/" + s if os.path.isdir("rec_auto/s10_gains/" + s) else "rec_auto/s9_open/" + s
    ks = []
    for p in sorted(glob.glob(d + "/ts1_t?.csv")):
        r = fit(p, press(s))
        if r is None: print(s, p[-6:-4], "no fit"); continue
        (bx, by, bz), (ax, ay, az) = r
        ks.append((-ax, ay, az))
        print("%-6s %s  before vx %5.0f vy %4.0f vz %5.0f | after kick %5.0f along %5.0f vz %5.0f" % (s, p[-6:-4], bx, by, bz, -ax, ay, az))
    if ks:
        k = np.array(ks); print("%-6s mean kick %5.0f along %5.0f vz %5.0f  |h| %5.0f" % (s, *k.mean(0), np.hypot(k[:, 0], k[:, 1]).mean()))
