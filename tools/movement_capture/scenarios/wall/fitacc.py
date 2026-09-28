"""Launch velocity with a constant-accel term on both horizontal axes (air control from held keys)."""
import sys, glob, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from analyze import track
TP = float(os.environ["TPRESS"]); tj = TP + 1 / 64
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        t, f, l, z, sp, yaw = track(p)
        res = []
        for W in (0.2, 0.3, 0.45):
            m = (t > tj + 0.015) & (t < tj + W)
            tau = t[m] - tj
            A = np.c_[np.ones_like(tau), tau, tau ** 2 / 2]
            cf = np.linalg.lstsq(A, f[m], rcond=None)[0]; cl = np.linalg.lstsq(A, l[m], rcond=None)[0]
            res.append("W%.2f n=%2d v_n %6.1f a_n %6.0f | v_t %6.1f a_t %6.0f" % (W, m.sum(), cf[1], cf[2], cl[1], cl[2]))
        print("%-5s %s  " % (os.path.basename(d), p[-10:-4]) + "  ||  ".join(res))
