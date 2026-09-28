"""Per trial: velocity (fwd, lat, z; local linear fit over ~50 ms) from the ground jump through the air jump.
Usage: MARK=street dsum.py CSV K   (K = air-jump tick after the ground jump)"""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
def fit(t, q, tt, w=0.025):
    a = (t > tt - w) & (t < tt + w) & np.isfinite(q)
    return np.polyfit(t[a], q[a], 1)[0] if a.sum() >= 3 else float("nan")
p, k = sys.argv[1], int(sys.argv[2])
t, f, l, z, sp, yaw = track(p)
up = np.where(z > 1.0)[0]; t0 = t[up[0]] - 1.0 / 64
print(p)
for dt in [-0.05] + list(np.arange(0.0, 1.2, 1 / 32)):
    tt = t0 + dt
    if tt > t[-1]: break
    mark = " <- air jump" if abs(dt - k / 64) < 1 / 64 else ""
    print("  %+.3f (tick %5.1f) vf %6.1f vl %6.1f vz %6.1f z %6.1f sp %6.1f%s" % (dt, dt * 64, fit(t, f, tt), fit(t, l, tt), fit(t, z, tt),
          np.interp(tt, t, z), np.interp(tt, t, sp), mark))
