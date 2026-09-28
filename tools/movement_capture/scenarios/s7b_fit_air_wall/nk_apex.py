"""NK1/NK2 apex method: at an apex vz = 0 so HUD = h. Takes the HUD minimum near each apex (parabola fit through the
5 lowest-HUD samples) and compares the ratio with pure 0.2/s air drag between the two apex times.
Also prints the camera horizontal displacement over the airtime (NK1: should be ~0).
Usage (from tools/movement_capture): .venv/Scripts/python.exe scenarios/s7b_fit_air_wall/nk_apex.py NK1 NK2"""
import csv, glob, os, sys
import numpy as np
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    f = lambda k: np.array([float(r[k]) if r[k] else np.nan for r in R])
    return f("t"), f("pos_x"), f("pos_y"), f("pos_z"), f("vel_scalar")
def hud_min(t, v, a, b):
    m = (t >= a) & (t <= b) & np.isfinite(v)
    tt, vv = t[m], v[m]
    i = np.argmin(vv); j0, j1 = max(0, i - 3), min(len(tt), i + 4)
    c = np.polyfit(tt[j0:j1] - tt[i], vv[j0:j1], 2)
    if c[0] <= 0: return tt[i], vv[i]
    x = -c[1] / (2 * c[0]); return tt[i] + x, np.polyval(c, x)
W = {"NK1": ((0.25, 0.40), (0.60, 1.10)), "NK2": ((0.95, 1.075), (1.55, 1.90))}
for name in sys.argv[1:]:
    for p in sorted(glob.glob("../../rec_auto/s7_open/%s/*.csv" % name) or glob.glob("rec_auto/s7_open/%s/*.csv" % name)):
        t, x, y, z, v = load(p)
        (a1, b1), (a2, b2) = W[name]
        t1, h1 = hud_min(t, v, a1, b1); t2, h2 = hud_min(t, v, a2, b2)
        air = (t > 0.0) & (t < b2 + 0.3)
        dxy = np.hypot(x[air] - x[air][0], y[air] - y[air][0])
        print("%s %s apex1 t %.3f HUD %.1f | apex2 t %.3f HUD %.1f | ratio %.4f  drag-only %.4f -> pred %.1f (resid %+.1f) | max cam xy disp %.1f u"
              % (name, os.path.basename(p)[:-4], t1, h1, t2, h2, h2 / h1, np.exp(-0.2 * (t2 - t1)), h1 * np.exp(-0.2 * (t2 - t1)),
                 h2 - h1 * np.exp(-0.2 * (t2 - t1)), np.nanmax(dxy)))
