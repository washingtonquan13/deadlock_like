"""Air window fit: from takeoff to landing, fit fwd and lat positions with v0 + constant accel (u/s, u/s^2).
Drag alone (0.2/s) would give a = -0.2 v."""
import sys, glob, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        t, f, l, z, sp, yaw = track(p)
        up = np.where(z > 2.0)[0]
        if len(up) == 0:
            continue
        i0 = up[0]; i1 = up[-1]
        t0, t1 = t[i0], t[i1]
        out = []
        for a, b in ((t0 + 0.02, t0 + 0.25), (t0 + 0.02, t1 - 0.02)):
            m = (t > a) & (t < b) & np.isfinite(f) & np.isfinite(l)
            tau = t[m] - t0
            A = np.c_[np.ones_like(tau), tau, tau ** 2 / 2]
            cf = np.linalg.lstsq(A, f[m], rcond=None)[0]; cl = np.linalg.lstsq(A, l[m], rcond=None)[0]
            out.append("[%.2f s] v_f %6.1f a_f %6.0f | v_l %6.1f a_l %6.0f" % (b - a, cf[1], cf[2], cl[1], cl[2]))
        print("%-3s %s air %.2f-%.2f  " % (os.path.basename(d), p[-6:-4], t0, t1) + "  ||  ".join(out))
