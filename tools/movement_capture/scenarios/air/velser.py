"""Print fwd/lat velocity (local linear fit over ~60 ms) through the air window."""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
for p in sys.argv[1:]:
    t, f, l, z, sp, yaw = track(p)
    up = np.where(z > 2.0)[0]; t0 = t[up[0]]
    print(p)
    for tt in np.arange(t0, t[up[-1]] + 0.1, 0.05):
        a = (t > tt - 0.03) & (t < tt + 0.03) & np.isfinite(f) & np.isfinite(l)
        if a.sum() < 3: continue
        cf = np.polyfit(t[a], f[a], 1)[0]; cl = np.polyfit(t[a], l[a], 1)[0]
        print("  %.2f  vf %7.1f  vl %7.1f  z %6.1f" % (tt - t0, cf, cl, np.nanmean(z[a])))
