"""Dash-jump launch fit. For each trial: takeoff time (relative to the dash press, tick 4), speed just before,
launch vz (z fit with gravity 800), horizontal launch speed and in-air accel (fwd fit), airtime, peak height,
and speed ~0.3 s after landing. Usage: MARK=street fitdj.py DIR..."""
import sys, glob, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
TD = 3 / 64
def lin(t, q, a, b):
    m = (t > a) & (t < b) & np.isfinite(q)
    return np.polyfit(t[m], q[m], 1)[0] if m.sum() >= 3 else float("nan")
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        t, f, l, z, sp, yaw = track(p)
        up = np.where(z > 1.5)[0]
        if len(up) == 0:
            print("%-5s %s no takeoff" % (os.path.basename(d), p[-6:-4])); continue
        i0 = up[0]; t0 = t[i0]
        # contiguous airborne run from takeoff
        j = i0
        while j + 1 < len(z) and z[j + 1] > 1.5: j += 1
        t1 = t[j]
        m = (t > t0 - 0.01) & (t < min(t0 + 0.25, t1 - 0.02)) & np.isfinite(z)
        tau = t[m] - t0
        A = np.c_[np.ones_like(tau), tau]
        c = np.linalg.lstsq(A, z[m] + 400 * tau ** 2, rcond=None)[0]
        mm = (t > t0 + 0.02) & (t < t1 - 0.03) & np.isfinite(f)
        tt = t[mm] - t0
        cf = np.polyfit(tt, f[mm], 2) if mm.sum() > 5 else [np.nan] * 3
        cl = np.polyfit(tt, l[mm], 2) if mm.sum() > 5 else [np.nan] * 3
        vpre = lin(t, f, t0 - 0.12, t0 - 0.015)
        vland = lin(t, f, t1 + 0.25, t1 + 0.4)
        print("%-5s %s takeoff %.3f s (%.1f ticks after dash)  pre %5.0f | vz %5.0f | vf %5.0f af %5.0f vl %5.0f | air %.2f s peak %4.0f | +0.3s after land %5.0f"
              % (os.path.basename(d), p[-6:-4], t0 - TD, (t0 - TD) * 64, vpre, c[1], cf[1], 2 * cf[0], cl[1], t1 - t0, z[i0:j + 1].max(), vland))
