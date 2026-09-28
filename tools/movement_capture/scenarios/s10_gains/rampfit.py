"""RL* (s10_gains): HUD accel on the ramp vs speed. Fits dv/dt = A - f*v over the on-ramp window (z still falling, HUD > 100).
Also the s7 RRUN/RBOT fast entries on the same ramp for comparison. Run from tools/movement_capture."""
import sys, os, glob
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
rows = []
def run(pattern, mark, tag):
    os.environ["MARK"] = mark
    import importlib, analyze as A; importlib.reload(A)
    for p in sorted(glob.glob(pattern)):
        t, d, lat, z, sp = [], [], [], [], []
        tt, dd, ll, zz, ss, yy = A.track(p)
        ok = np.isfinite(ss) & np.isfinite(zz)
        tt, zz, ss = tt[ok], zz[ok], ss[ok]
        # on the ramp: moving, and z still dropping over the next 50 ms
        for i in range(len(tt)):
            j = np.searchsorted(tt, tt[i] + 0.1)
            if j >= len(tt): break
            dz = zz[min(np.searchsorted(tt, tt[i] + 0.05), len(tt) - 1)] - zz[i]
            if ss[i] > 100 and ss[j] > 100 and dz < -3 and zz[j] - zz[i] < -3:
                rows.append((tag, 0.5 * (ss[i] + ss[j]), (ss[j] - ss[i]) / (tt[j] - tt[i])))
run("rec_auto/s10_gains/RL*/*.csv", "ramp1_slope", "RL")
run("rec_auto/s7_ramp/RRUN/*.csv", "ramp1_top", "RRUN")
run("rec_auto/s7_ramp/RBOT/*.csv", "ramp1_top", "RBOT")
for tag in ("RL", "RRUN", "RBOT"):
    r = np.array([(v, a) for g, v, a in rows if g == tag])
    if len(r) == 0: print(tag, "none"); continue
    for lo in range(100, 800, 50):
        m = (r[:, 0] >= lo) & (r[:, 0] < lo + 50)
        if m.sum() > 3: print("%-5s %3d-%3d  n %3d  accel %6.1f" % (tag, lo, lo + 50, m.sum(), np.median(r[m, 1])))
r = np.array([(v, a) for g, v, a in rows])
f, A0 = np.polyfit(r[:, 0], r[:, 1], 1)
print("all: accel = %.1f %+.3f*v  (rms %.1f)" % (A0, f, np.std(r[:, 1] - (A0 + f * r[:, 0]))))
