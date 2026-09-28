"""NK1/NK2 (s7_open): no-key air jump. Horizontal speed from camera-position finite differences (yaw/pitch constant,
so the camera moves with the hero) and from HUD^2 - vz^2. Fits h(t) = h0*exp(-k(t - t_aj)) after the air jump and
reports the step at the air jump (extrapolate the pre-jump drag line to t_aj vs the post fit at t_aj).
Usage (from tools/movement_capture): .venv/Scripts/python.exe scenarios/s7b_fit_air_wall/nk_fit.py NAME [LAG_TICKS]"""
import csv, glob, os, sys
import numpy as np
name = sys.argv[1]; LAG = float(sys.argv[2]) if len(sys.argv) > 2 else 3.5
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    f = lambda k: np.array([float(r[k]) if r[k] else np.nan for r in R])
    return f("t"), f("pos_x"), f("pos_y"), f("pos_z"), f("vel_scalar"), f("ang_yaw"), f("ang_pitch")
def dv(t, q, w=0.04):
    out = np.full_like(t, np.nan)
    for i in range(len(t)):
        j0 = np.searchsorted(t, t[i] - w); j1 = min(np.searchsorted(t, t[i] + w), len(t) - 1)
        if j1 > j0 and t[j1] > t[j0]: out[i] = (q[j1] - q[j0]) / (t[j1] - t[j0])
    return out
TJ = {"NK1": 1, "NK2": 40}[name]; TAJ = {"NK1": 20, "NK2": 66}[name]
for p in sorted(glob.glob("rec_auto/s7_open/%s/*.csv" % name)):
    t, x, y, z, hud, yaw, pit = load(p)
    vx, vy, vz = dv(t, x), dv(t, y), dv(t, z)
    hc = np.hypot(vx, vy)                           # camera horizontal speed
    hh = np.sqrt(np.clip(hud ** 2 - vz ** 2, 0, None))  # HUD-derived horizontal
    taj = (TAJ - 1 + LAG) / 64.0; tj = (TJ - 1 + LAG) / 64.0
    print("==", os.path.basename(p), "yaw range %.2f pitch range %.2f  t_jump %.3f t_airjump %.3f" % (np.ptp(yaw), np.ptp(pit), tj, taj))
    for tt in np.arange(max(tj - 0.1, t[0]), min(t[-1], taj + 1.3), 1 / 32):
        i = np.searchsorted(t, tt)
        if i >= len(t): break
        print("  t %.3f  hud %6.1f  vz %7.1f  h_cam %6.1f  h_hud %6.1f  dir %6.1f  z %6.1f" % (t[i], hud[i], vz[i], hc[i], hh[i],
              np.degrees(np.arctan2(vy[i], vx[i])) if hc[i] > 5 else np.nan, z[i]))
    # fits: before (tj+0.1 .. taj-0.02) and after (taj+0.06 .. landing-0.05)
    air = (t > tj + 0.1)
    land = t[np.argmax((t > taj + 0.3) & (np.abs(vz) < 5))] if np.any((t > taj + 0.3) & (np.abs(vz) < 5)) else t[-1]
    for lab, m in (("pre", air & (t < taj - 0.02)), ("post", (t > taj + 0.06) & (t < land - 0.06))):
        for nm, h in (("cam", hc), ("hud", hh)):
            mm = m & np.isfinite(h) & (h > 1)
            if mm.sum() < 4: print("  %s %s: too few" % (lab, nm)); continue
            A = np.c_[np.ones(mm.sum()), t[mm] - taj]
            c = np.linalg.lstsq(A, np.log(h[mm]), rcond=None)[0]
            print("  %-4s %s: h(t_aj) = %6.1f  k = %.3f /s  (n %d, %.2f..%.2f)" % (lab, nm, np.exp(c[0]), -c[1], mm.sum(), t[mm][0], t[mm][-1]))
